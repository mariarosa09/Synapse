//
//  MedicalRecordDetailView.swift
//  Synapse
//
//  Created by Mac-LAB on 9/11/26.
//
//  Create or edit one medical record: title, date, category, notes and attached files.
//  Saving writes the record row and commits attachment changes (MedicalRecordController +
//  AttachmentController). Leaving without saving deletes files uploaded in the meantime.
//

import SwiftUI

struct MedicalRecordDetailView: View {
    @Environment(SessionController.self) private var session
    @Environment(\.dismiss) private var dismiss

    private let isNewRecord: Bool
    private let recordID: UUID
    @State private var recordTitle: String
    @State private var date: Date
    @State private var category: String
    @State private var notes: String
    @State private var attachments: AttachmentController
    @State private var errorText: String?
    @State private var showFiles = false
    @State private var saved = false

    init(record: MedicalInformation?) {
        let id = record?.id ?? UUID()
        isNewRecord = record == nil
        recordID = id
        _recordTitle = State(initialValue: record?.title ?? "")
        _date = State(initialValue: record?.date ?? Calendar.current.startOfDay(for: .now))
        _category = State(initialValue: record?.category ?? "")
        _notes = State(initialValue: record?.notes ?? "")
        _attachments = State(initialValue: AttachmentController(recordID: id, attachments: record?.attachments ?? []))
    }

    private var controller: MedicalRecordController { session.medicalRecords }
    private var canSave: Bool {
        !recordTitle.trimmed.isEmpty && !controller.isSaving && !attachments.isUploading
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                EditableHeading(title: $recordTitle, date: $date)
                ViewFiles(count: attachments.attachments.count, hasUnsavedChanges: attachments.hasChanges) {
                    showFiles = true
                }
                .padding(.top, 20)
                CategoryField(category: $category)
                NotesView(textNotes: $notes)
                Spacer().frame(height: 90)   // room for the save button
            }

            VStack(spacing: 6) {
                if let errorText {
                    Text(errorText)
                        .font(.synLabel)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                Button {
                    save()
                } label: {
                    HStack {
                        if controller.isSaving {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 8)
                        }
                        Text(buttonTitle)
                            .font(.synSection)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSave ? Color.myDarkBlue : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 4)
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showFiles) {
            AttachmentsView(controller: attachments)
        }
        .onDisappear {
            // Leaving the record (not just opening its files) without saving: drop new uploads.
            if !showFiles && !saved {
                Task { await attachments.discard() }
            }
        }
    }

    private var buttonTitle: String {
        if controller.isSaving { return "Saving..." }
        return isNewRecord ? "Save Record" : "Save Changes"
    }

    private func save() {
        errorText = nil
        Task {
            do {
                try await controller.save(id: recordID, title: recordTitle, date: date,
                                          category: category, notes: notes, attachments: attachments)
                saved = true
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

/// Blue header whose title and date can be edited in place.
struct EditableHeading: View {
    @Binding var title: String
    @Binding var date: Date

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading) {
                Spacer().frame(height: 45)

                HStack(alignment: .top) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(Color.white)
                            .padding(.trailing, 5)
                            .padding(.top, 5)
                    }
                    .accessibilityLabel("Back")

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("", text: $title,
                                  prompt: Text("Enter Title").foregroundStyle(.white.opacity(0.8)))
                            .font(.synTitle)
                            .foregroundStyle(Color.white)
                            .textFieldStyle(.plain)
                            .padding(.trailing, 80)   // keep clear of the logo badge

                        DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .font(.synBody)
                            .environment(\.colorScheme, .dark)
                            .tint(.white)
                    }

                    Spacer()
                }
            }

            Logo()
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .background(Color.myDarkBlue)
        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 10)
    }
}

/// Optional category used for organising and searching records.
struct CategoryField: View {
    @Binding var category: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag.fill")
                .foregroundStyle(Color.myDarkBlue)
            TextField("", text: $category,
                      prompt: Text("Category (e.g. Lab result, Prescription)").foregroundStyle(.gray.opacity(0.7)))
                .font(.synBody)
                .textInputAutocapitalization(.words)
        }
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.myDarkBlue, lineWidth: 1))
        .padding(.horizontal, 30)
    }
}

struct ViewFiles: View {
    let count: Int
    var hasUnsavedChanges: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("View Files")
                    .font(.synSection)
                    .foregroundStyle(Color.myDarkBlue)
                if hasUnsavedChanges {
                    Text("Unsaved")
                        .font(.synLabel)
                        .foregroundStyle(.orange)
                }
                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.synBody)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.myDarkBlue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right.circle.fill")
                    .foregroundStyle(Color.myDarkBlue)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.myLightBlue)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.myDarkBlue, lineWidth: 1))
        }
        .padding(.horizontal, 30)
    }
}

struct NotesView: View {
    @Binding var textNotes: String

    var body: some View {
        TextField("Notes", text: $textNotes, axis: .vertical)
            .font(.synBody)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.myDarkBlue, lineWidth: 1))
            .padding(.horizontal, 30)
    }
}

#Preview {
    NavigationStack { MedicalRecordDetailView(record: nil) }
        .environment(SessionController())
}
