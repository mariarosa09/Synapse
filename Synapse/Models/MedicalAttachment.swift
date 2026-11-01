//
//  MedicalAttachment.swift
//  Synapse
//
//  A file attached to a medical record: metadata lives in public.medical_record_attachments,
//  the bytes live in the private `medical-records` Storage bucket at `storagePath`
//  ("<user id>/<record id>/<attachment id>.<ext>").
//

import Foundation
import UniformTypeIdentifiers

nonisolated enum AttachmentKind: Sendable {
    case image, pdf, document, spreadsheet, text, other
}

nonisolated struct MedicalAttachment: Identifiable, Codable, Sendable, Equatable, Hashable {
    var id: UUID = UUID()
    var recordID: UUID
    /// Original file name, shown to the user.
    var fileName: String
    var fileExtension: String
    var mimeType: String
    var sizeBytes: Int
    var storagePath: String
    var createdAt: Date? = nil

    /// 20 MB, matching the bucket's file_size_limit in supabase/schema.sql.
    static let maxFileSize = 20 * 1024 * 1024

    /// Extensions the document picker and uploader accept.
    static let allowedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "bmp", "webp",   // images
        "pdf",                                                                        // PDF
        "doc", "docx", "rtf", "pages", "odt",                                         // documents
        "txt", "md", "xml", "json",                                                   // text
        "xls", "xlsx", "csv", "numbers", "ods",                                       // spreadsheets
        "dcm"                                                                         // DICOM medical images
    ]

    /// Content types offered by the iOS document picker.
    static var pickerTypes: [UTType] {
        var types: [UTType] = [.image, .jpeg, .png, .heic, .pdf, .plainText, .rtf, .commaSeparatedText,
                               .spreadsheet, .json, .xml]
        for ext in ["doc", "docx", "xls", "xlsx", "pages", "numbers", "odt", "ods", "dcm", "md"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }

    static func isAllowed(extension ext: String) -> Bool {
        allowedExtensions.contains(ext.lowercased())
    }

    static func mimeType(forExtension ext: String) -> String {
        let lower = ext.lowercased()
        let known: [String: String] = [
            "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "heic": "image/heic", "heif": "image/heif",
            "gif": "image/gif", "tif": "image/tiff", "tiff": "image/tiff", "bmp": "image/bmp", "webp": "image/webp",
            "pdf": "application/pdf",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "rtf": "application/rtf", "odt": "application/vnd.oasis.opendocument.text",
            "pages": "application/vnd.apple.pages",
            "txt": "text/plain", "md": "text/markdown", "xml": "application/xml", "json": "application/json",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "csv": "text/csv", "ods": "application/vnd.oasis.opendocument.spreadsheet",
            "numbers": "application/vnd.apple.numbers",
            "dcm": "application/dicom"
        ]
        if let mime = known[lower] { return mime }
        return UTType(filenameExtension: lower)?.preferredMIMEType ?? "application/octet-stream"
    }

    var kind: AttachmentKind {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "bmp", "webp", "dcm": return .image
        case "pdf": return .pdf
        case "doc", "docx", "rtf", "pages", "odt": return .document
        case "xls", "xlsx", "csv", "numbers", "ods": return .spreadsheet
        case "txt", "md", "xml", "json": return .text
        default: return mimeType.hasPrefix("image/") ? .image : .other
        }
    }

    /// Images iOS can draw directly (DICOM files are opened with another app instead).
    var showsThumbnail: Bool { kind == .image && fileExtension.lowercased() != "dcm" }

    /// SF Symbol matching the file type.
    var iconName: String {
        switch kind {
        case .image: return "photo.fill"
        case .pdf: return "doc.richtext.fill"
        case .document: return "doc.text.fill"
        case .spreadsheet: return "tablecells.fill"
        case .text: return "doc.plaintext.fill"
        case .other: return "doc.fill"
        }
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }

    init(id: UUID = UUID(), recordID: UUID, fileName: String, fileExtension: String, mimeType: String,
         sizeBytes: Int, storagePath: String, createdAt: Date? = nil) {
        self.id = id
        self.recordID = recordID
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.storagePath = storagePath
        self.createdAt = createdAt
    }

    // MARK: - Supabase coding

    enum CodingKeys: String, CodingKey {
        case id
        case recordID = "record_id"
        case fileName = "file_name"
        case fileExtension = "file_extension"
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case storagePath = "storage_path"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        recordID = try c.decode(UUID.self, forKey: .recordID)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName) ?? "Attachment"
        fileExtension = try c.decodeIfPresent(String.self, forKey: .fileExtension) ?? ""
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType) ?? "application/octet-stream"
        sizeBytes = try c.decodeIfPresent(Int.self, forKey: .sizeBytes) ?? 0
        storagePath = try c.decode(String.self, forKey: .storagePath)
        createdAt = DBDate.timestamp(from: try c.decodeIfPresent(String.self, forKey: .createdAt))
    }

    /// `created_at` is set by the database, so it is never sent.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(recordID, forKey: .recordID)
        try c.encode(fileName, forKey: .fileName)
        try c.encode(fileExtension, forKey: .fileExtension)
        try c.encode(mimeType, forKey: .mimeType)
        try c.encode(sizeBytes, forKey: .sizeBytes)
        try c.encode(storagePath, forKey: .storagePath)
    }
}
