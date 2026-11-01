//
//  AttachmentController.swift
//  Synapse
//
//  Attachments of one medical record while it is being edited.
//
//  - New files (document picker or photo library) are uploaded to the private `medical-records`
//    bucket right away, at "<user id>/<record id>/<attachment id>.<ext>".
//  - Their metadata rows are inserted, and removed / replaced files are deleted, only when the
//    record is saved (`commit`). Leaving without saving deletes the files uploaded meanwhile (`discard`).
//  - Files are previewed and shared from a local copy downloaded with the user's session,
//    so private files never need a public URL.
//

import SwiftUI
import UniformTypeIdentifiers
import Supabase

@Observable
@MainActor
final class AttachmentController {
    let recordID: UUID
    /// What the editor shows: saved attachments minus removed ones, plus new uploads.
    private(set) var attachments: [MedicalAttachment]
    var isUploading = false
    var isPreparingFile = false
    var errorMessage: String?
    /// Local file handed to QuickLook.
    var previewURL: URL?
    /// Local file handed to the share sheet ("Open in…", "Save to Files").
    var shareURL: URL?

    @ObservationIgnored private var pendingUploads: Set<UUID> = []
    @ObservationIgnored private var pendingDeletes: [MedicalAttachment] = []

    init(recordID: UUID, attachments: [MedicalAttachment]) {
        self.recordID = recordID
        self.attachments = attachments
    }

    var hasChanges: Bool { !pendingUploads.isEmpty || !pendingDeletes.isEmpty }

    func isPending(_ attachment: MedicalAttachment) -> Bool { pendingUploads.contains(attachment.id) }

    private var bucket: StorageFileApi { supabase.storage.from(Bucket.medicalRecords) }

    // MARK: - Adding files

    /// A file chosen with the iOS document picker. Replaces `replacing` when given.
    func addFile(at url: URL, replacing: MedicalAttachment? = nil) async {
        errorMessage = nil
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        guard MedicalAttachment.isAllowed(extension: ext) else {
            errorMessage = "“\(url.lastPathComponent)” isn't a supported file type."
            return
        }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > MedicalAttachment.maxFileSize {
            errorMessage = "“\(url.lastPathComponent)” is larger than 20 MB."
            return
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            errorMessage = "“\(url.lastPathComponent)” couldn't be read."
            return
        }
        await upload(data: data, fileName: url.lastPathComponent, ext: ext, replacing: replacing)
    }

    /// A photo chosen from the library (kept in its original format, e.g. HEIC or PNG).
    func addPhoto(data: Data, contentType: UTType?, replacing: MedicalAttachment? = nil) async {
        errorMessage = nil
        var ext = contentType?.preferredFilenameExtension?.lowercased() ?? "jpg"
        if !MedicalAttachment.isAllowed(extension: ext) { ext = "jpg" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = "Photo \(formatter.string(from: Date())).\(ext)"
        await upload(data: data, fileName: name, ext: ext, replacing: replacing)
    }

    private func upload(data: Data, fileName: String, ext: String, replacing: MedicalAttachment?) async {
        guard data.count > 0 else { errorMessage = "That file is empty."; return }
        guard data.count <= MedicalAttachment.maxFileSize else { errorMessage = "That file is larger than 20 MB."; return }
        guard let uid = supabase.auth.currentUser?.id else { errorMessage = "You need to be logged in."; return }

        isUploading = true
        defer { isUploading = false }

        let attachmentID = UUID()
        // Folder names must match auth.uid()::text, which PostgreSQL prints in lowercase.
        let path = "\(uid.uuidString.lowercased())/\(recordID.uuidString.lowercased())/\(attachmentID.uuidString.lowercased()).\(ext)"
        let mime = MedicalAttachment.mimeType(forExtension: ext)
        do {
            try await bucket.upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: mime, upsert: false))
        } catch {
            errorMessage = "Upload failed: \(ErrorMessages.message(for: error))"
            return
        }

        let attachment = MedicalAttachment(id: attachmentID, recordID: recordID, fileName: fileName, fileExtension: ext,
                                           mimeType: mime, sizeBytes: data.count, storagePath: path, createdAt: Date())
        pendingUploads.insert(attachmentID)
        // Keep a local copy so the new file can be previewed immediately.
        try? data.write(to: localURL(for: attachment), options: .atomic)

        if let replacing, let index = attachments.firstIndex(where: { $0.id == replacing.id }) {
            attachments[index] = attachment
            await forget(replacing)
        } else {
            attachments.append(attachment)
        }
    }

    // MARK: - Removing

    func remove(_ attachment: MedicalAttachment) {
        attachments.removeAll { $0.id == attachment.id }
        Task { await forget(attachment) }
    }

    /// A new upload is deleted from storage at once; a saved file is deleted when the record is saved.
    private func forget(_ attachment: MedicalAttachment) async {
        thumbnailURLs[attachment.id] = nil
        try? FileManager.default.removeItem(at: localURL(for: attachment))
        if pendingUploads.remove(attachment.id) != nil {
            _ = try? await bucket.remove(paths: [attachment.storagePath])
        } else if !pendingDeletes.contains(where: { $0.id == attachment.id }) {
            pendingDeletes.append(attachment)
        }
    }

    // MARK: - Save / discard (called by the record editor)

    func commit() async throws {
        let newRows = attachments.filter { pendingUploads.contains($0.id) }
        if !newRows.isEmpty {
            try await supabase.from(Table.attachments).insert(newRows, returning: .minimal).execute()
        }
        pendingUploads.removeAll()

        if !pendingDeletes.isEmpty {
            let ids = pendingDeletes.map(\.id.uuidString)
            try await supabase.from(Table.attachments).delete(returning: .minimal).in("id", values: ids).execute()
            _ = try? await bucket.remove(paths: pendingDeletes.map(\.storagePath))
            pendingDeletes.removeAll()
        }
    }

    func discard() async {
        let orphans = attachments.filter { pendingUploads.contains($0.id) }.map(\.storagePath)
        pendingUploads.removeAll()
        pendingDeletes.removeAll()
        if !orphans.isEmpty { _ = try? await bucket.remove(paths: orphans) }
    }

    // MARK: - Image thumbnails

    /// Displayable image URL per attachment: a local file for new uploads, otherwise a short-lived
    /// signed URL for the private bucket. Non-image files have no entry and show a file icon.
    private(set) var thumbnailURLs: [UUID: URL] = [:]

    func loadThumbnails() async {
        for attachment in attachments where attachment.showsThumbnail && thumbnailURLs[attachment.id] == nil {
            let local = localURL(for: attachment)
            if FileManager.default.fileExists(atPath: local.path) {
                thumbnailURLs[attachment.id] = local
                continue
            }
            guard !pendingUploads.contains(attachment.id) else { continue }
            if let url = try? await bucket.createSignedURL(path: attachment.storagePath, expiresIn: 60 * 60) {
                thumbnailURLs[attachment.id] = url
            }
        }
    }

    // MARK: - Preview / share

    func preview(_ attachment: MedicalAttachment) async {
        if let url = await localCopy(of: attachment) { previewURL = url }
    }

    func share(_ attachment: MedicalAttachment) async {
        if let url = await localCopy(of: attachment) { shareURL = url }
    }

    /// Downloads the file with the signed-in session (private bucket) into a temporary folder,
    /// keeping the original file name so other apps see e.g. "Lab results.pdf".
    private func localCopy(of attachment: MedicalAttachment) async -> URL? {
        errorMessage = nil
        let url = localURL(for: attachment)
        if FileManager.default.fileExists(atPath: url.path) { return url }

        isPreparingFile = true
        defer { isPreparingFile = false }
        do {
            let data = try await bucket.download(path: attachment.storagePath)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = "Couldn't open “\(attachment.fileName)”: \(ErrorMessages.message(for: error))"
            return nil
        }
    }

    private func localURL(for attachment: MedicalAttachment) -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SynapseAttachments", isDirectory: true)
            .appendingPathComponent(attachment.id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var name = attachment.fileName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        if name.isEmpty { name = "Attachment" }
        if (name as NSString).pathExtension.isEmpty, !attachment.fileExtension.isEmpty { name += ".\(attachment.fileExtension)" }
        return folder.appendingPathComponent(name)
    }
}
