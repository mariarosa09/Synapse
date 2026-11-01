//
//  AttachmentsView.swift
//  Synapse
//
//  Files attached to one medical record. Any supported format can be uploaded from Files
//  (document picker) or Photos: images, PDF, Word, text, spreadsheets, CSV, DICOM…
//  Files are stored in the private Supabase Storage bucket; images show a thumbnail, every
//  file can be previewed (Quick Look), opened in / shared to another app, replaced or deleted.
//

import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

struct AttachmentsView: View {
    @Bindable var controller: AttachmentController

    @State private var showImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false
    /// The attachment being replaced by the next picked file, if any.
    @State private var replacing: MedicalAttachment?
    @State private var pendingDelete: MedicalAttachment?
    @State private var replaceSourcePickerFor: MedicalAttachment?

    private var busy: Bool { controller.isUploading || controller.isPreparingFile }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeadingNoDesc(back: true, title: "Attachments")

                if let message = controller.errorMessage {
                    ErrorBanner(message: message) { controller.errorMessage = nil }
                        .padding(.top, 12)
                }

                if controller.attachments.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "paperclip.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.myDarkBlue.opacity(0.4))
                        Text("No files attached yet.")
                            .font(.synRow)
                            .foregroundStyle(.secondary)
                        Text("Add photos, PDFs, Word or Excel files, CSV or text documents (up to 20 MB each).")
                            .font(.synCaption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(controller.attachments) { attachment in
                            AttachmentRow(attachment: attachment,
                                          thumbnailURL: controller.thumbnailURLs[attachment.id],
                                          pending: controller.isPending(attachment)) {
                                pendingDelete = attachment
                            }
                                .contentShape(Rectangle())
                                .onTapGesture { Task { await controller.preview(attachment) } }
                                // Long press: more options.
                                .contextMenu {
                                    Button("Preview", systemImage: "eye") { Task { await controller.preview(attachment) } }
                                    Button("Open With… / Save to Files", systemImage: "square.and.arrow.up") {
                                        Task { await controller.share(attachment) }
                                    }
                                    Button("Replace", systemImage: "arrow.triangle.2.circlepath") { replaceSourcePickerFor = attachment }
                                    Divider()
                                    Button("Remove", systemImage: "trash", role: .destructive) { pendingDelete = attachment }
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .padding(.horizontal, 30)
                    .padding(.top, 12)

                    Text(controller.hasChanges ? "Tap Save on the record to keep these changes." : "Tap a file to open it. Long-press for more options.")
                        .font(.synLabel)
                        .foregroundStyle(controller.hasChanges ? .orange : .secondary)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 6)
                }

                HStack(spacing: 10) {
                    uploadButton(title: "Upload File", icon: "arrow.up.doc.fill") {
                        replacing = nil
                        showImporter = true
                    }
                    uploadButton(title: "Photo", icon: "photo.fill") {
                        replacing = nil
                        showPhotoPicker = true
                    }
                    .frame(maxWidth: 130)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
                .padding(.top, 6)
            }

            if let attachment = replaceSourcePickerFor {
                ReplaceSourcePopup(fileName: attachment.fileName) {
                    replaceSourcePickerFor = nil
                } onFiles: {
                    replacing = attachment
                    replaceSourcePickerFor = nil
                    showImporter = true
                } onPhotos: {
                    replacing = attachment
                    replaceSourcePickerFor = nil
                    showPhotoPicker = true
                }
            }

            if let attachment = pendingDelete {
                ConfirmationPopup(
                    title: "Delete File",
                    message: "“\(attachment.fileName)” will be removed from this record when you save it.",
                    confirmTitle: "Delete",
                    onCancel: { pendingDelete = nil },
                    onConfirm: {
                        controller.remove(attachment)
                        pendingDelete = nil
                    }
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .quickLookPreview($controller.previewURL)
        .sheet(isPresented: Binding(get: { controller.shareURL != nil },
                                    set: { if !$0 { controller.shareURL = nil } })) {
            if let url = controller.shareURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: MedicalAttachment.pickerTypes,
                      allowsMultipleSelection: true) { result in
            handleImport(result)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            let target = replacing
            replacing = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await controller.addPhoto(data: data, contentType: item.supportedContentTypes.first, replacing: target)
                    await controller.loadThumbnails()
                } else {
                    controller.errorMessage = "That photo couldn't be loaded."
                }
                selectedPhoto = nil
            }
        }
        .task(id: controller.attachments.map(\.id)) {
            await controller.loadThumbnails()
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        let target = replacing
        replacing = nil
        switch result {
        case .success(let urls):
            Task {
                for (index, url) in urls.enumerated() {
                    // Only the first picked file replaces; any others are added.
                    await controller.addFile(at: url, replacing: index == 0 ? target : nil)
                }
                await controller.loadThumbnails()
            }
        case .failure(let error):
            controller.errorMessage = "Couldn't open the file: \(error.localizedDescription)"
        }
    }

    private func uploadButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: icon)
                    Text(title)
                        .font(.synSection)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(busy ? Color.gray : Color.myDarkBlue)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 4)
        }
        .disabled(busy)
    }
}

/// One attachment: thumbnail (images) or a type icon, original file name, type and size.
struct AttachmentRow: View {
    let attachment: MedicalAttachment
    let thumbnailURL: URL?
    let pending: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.synBody)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(attachment.fileExtension.uppercased())
                    Text("·")
                    Text(attachment.sizeText)
                    if pending {
                        Text("· Not saved yet").foregroundStyle(.orange)
                    }
                }
                .font(.synLabel)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.myDarkBlue.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(attachment.fileName)")
        }
        .padding()
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.myDarkBlue, lineWidth: 1))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if attachment.showsThumbnail, let thumbnailURL {
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    icon
                default:
                    ZStack { Color.myLightBlue; ProgressView().tint(Color.myDarkBlue) }
                }
            }
        } else {
            icon
        }
    }

    private var icon: some View {
        ZStack {
            Color.myLightBlue
            Image(systemName: attachment.iconName)
                .font(.system(size: 20))
                .foregroundStyle(Color.myDarkBlue)
        }
    }
}

/// Small custom pop-up asking where the replacement file should come from.
struct ReplaceSourcePopup: View {
    let fileName: String
    let onCancel: () -> Void
    let onFiles: () -> Void
    let onPhotos: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 10) {
                Text("Replace File")
                    .foregroundStyle(Color.myDarkBlue)
                    .font(.synSection)
                Text("Choose a new file to replace “\(fileName)”.")
                    .font(.synBody)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.synLabel)
                            .foregroundStyle(Color.gray)
                            .padding()
                    }
                    Button(action: onPhotos) {
                        Text("Photos")
                            .font(.synLabel)
                            .foregroundStyle(Color.myDarkBlue)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.myLightBlue))
                    }
                    Button(action: onFiles) {
                        Text("Files")
                            .font(.synLabel)
                            .foregroundStyle(Color.myDarkBlue)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.myLightBlue))
                    }
                }
            }
            .popupCard()
        }
        .transition(.opacity)
    }
}

#Preview {
    NavigationStack {
        AttachmentsView(controller: AttachmentController(recordID: UUID(), attachments: []))
    }
}
