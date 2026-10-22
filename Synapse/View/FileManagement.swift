//  FileManagementView.swift
//  Synapse

import SwiftUI
import PhotosUI
import QuickLook

struct FileManagementView: View {
    // Linked controller dependency instance
    var controller: MedicalRecordController?
    @Binding var files: [String]
    
    // UI Local State Properties
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    
    // QuickLook State Management
    @State private var previewURL: URL? = nil // Tracks the local URL to be previewed
    @State private var isDownloadingForPreview = false // Tracks downloading indicator
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HeadingNoDesc(back: true, title: "Attachments")
            if files.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "paperclip.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.myDarkBlue.opacity(0.4))
                    Text("No files attached yet.")
                        .font(.custom("DM Sans", size: 16))
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(files, id: \.self) { fileURL in
                        Button {
                            // Uses Swift's native Task container for detached async work
                            Task {
                                await downloadAndPreview(urlString: fileURL)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(Color.myDarkBlue)
                                
                                Text(shortenURL(fileURL))
                                    .font(.custom("DM Sans", size: 15))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding()
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.myDarkBlue, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        files.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(.plain)
                .padding(.horizontal, 30)
                .padding(.top, 20)
            }
            
            Spacer()
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 10) {
                    if isUploading || isDownloadingForPreview {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up.doc.fill")
                        Text("Upload New File")
                            .font(.custom("Graduate", size: 16))
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background((isUploading || isDownloadingForPreview) ? Color.gray : Color.myDarkBlue)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 4)
            }
            .disabled(isUploading || isDownloadingForPreview || controller == nil)
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .quickLookPreview($previewURL)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem = newItem else { return }
            
            Task {
                isUploading = true
                defer {
                    isUploading = false
                    selectedItem = nil
                }
                
                guard let controller = controller else { return }
                
                do {
                    // 1. Unpack data smoothly via structured concurrency paths
                    if let data = try await newItem.loadTransferable(type: Data.self) {
                        // 2. Call the newly updated throwing controller routine via await
                        let downloadURLString = try await controller.uploadFile(data: data, mimeType: "image/jpeg")
                        self.files.append(downloadURLString)
                    }
                } catch {
                    // Controller internal errors automatically map to controller.errorMessage
                    print("Error during image file processing sequence: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Rewritten with Swift's native async/await URLSession pattern
    @MainActor
    private func downloadAndPreview(urlString: String) async {
        guard let remoteURL = URL(string: urlString) else { return }
        isDownloadingForPreview = true
        
        defer { isDownloadingForPreview = false }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            
            let rawFilename = remoteURL.lastPathComponent.components(separatedBy: "?").first ?? ""
            let cleanedFilename = rawFilename.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalFilename = cleanedFilename.isEmpty ? "\(UUID().uuidString).jpg" : cleanedFilename
            
            let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(finalFilename)
            try data.write(to: localURL)
            
            self.previewURL = localURL
        } catch {
            print("Failed saving file locally for preview: \(error)")
        }
    }
    
    private func shortenURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Attachment Document" }
        let filename = url.lastPathComponent.components(separatedBy: "?").first ?? ""
        let cleaned = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "Attachment Document" }
        return cleaned.contains("medicalRecords%") ? "Medical_Image.jpg" : cleaned
    }
}

#Preview {
    struct FileManagementPreviewContainer: View {
        @State private var sampleFiles: [String] = [
            "https://picsum.photos/200/300.jpg"
        ]
        
        var body: some View {
            FileManagementView(
                controller: MedicalRecordController(), // Provide an instance here
                files: $sampleFiles
            )
        }
    }
    return FileManagementPreviewContainer()
}

