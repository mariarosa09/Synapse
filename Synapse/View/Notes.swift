//
//  MedicalRecordPreview.swift
//  Synapse
//
//  Created by Mac-LAB on 9/11/26.
//

import SwiftUI

struct Notes: View {
    @State private var recordTitle: String
    @State private var date: Date
    @State private var notes: String
    @State private var files: [String]
    @State private var errorText: String? = nil

    var controller: MedicalRecordController? = nil
    var isNewRecord: Bool = false
    var recordID: UUID? = nil
    
    @Environment(\.dismiss) private var dismiss

    init(recordTitle: String, date: Date = .now, notes: String, files: [String] = [],
         controller: MedicalRecordController? = nil, isNewRecord: Bool = false, recordID: UUID? = nil) {
        self._recordTitle = State(initialValue: recordTitle)
        self._date = State(initialValue: date)
        self._notes = State(initialValue: notes)
        self._files = State(initialValue: files)
        self.controller = controller
        self.isNewRecord = isNewRecord
        self.recordID = recordID
    }

    private var canSave: Bool {
        controller != nil && !recordTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack (spacing: 10) {
                EditableHeading(title: $recordTitle, description: $date)
                ViewFiles(controller: controller, files: $files)
                NotesView(textNotes: $notes)
                Spacer()
            }
            
            if controller != nil {
                VStack(spacing: 6) {
                    if let errorText {
                        Text(errorText)
                            .font(.custom("DM Sans", size: 12))
                            .foregroundStyle(.red)
                    }
                    Button {
                        saveAndDismiss()
                    } label: {
                        HStack {
                            if controller?.isSaving == true {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text(buttonTitle)
                                .font(.custom("Graduate", size: 16))
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.myDarkBlue : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 4)
                    }
                    .disabled(!canSave || controller?.isSaving == true)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var buttonTitle: String {
        if controller?.isSaving == true { return "Saving..." }
        return isNewRecord ? "Save Record" : "Save Changes"
    }
    
    private func saveAndDismiss() {
        guard let controller = controller else { return }
        errorText = nil
        
        Task {
            do {
                if isNewRecord {
                    try await controller.addRecord(title: recordTitle, date: date, notes: notes, files: files)
                } else if let recordID {
                    try await controller.updateRecord(id: recordID, title: recordTitle, date: date, notes: notes, files: files)
                }
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

struct EditableHeading: View {
    @Binding var title: String
    @Binding var description: Date
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack (alignment: .top) {
            VStack (alignment: .leading) {
                Spacer().frame(height: 45)
                
                HStack(alignment: .top) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(Color.white)
                            .padding(.trailing, 5)
                            .padding(.top, 5)
                    }
                    
                    VStack (alignment: .leading, spacing: 10) {
                        TextField("", text: $title,
                                  prompt: Text("Enter Title").foregroundStyle(.white.opacity(1)))
                            .font(Font.custom("Graduate", size: 20))
                            .foregroundStyle(Color.white)
                            .textFieldStyle(.plain)
                        
                        DatePicker("", selection: $description,  in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .font(Font.custom("DM Sans", size: 14))
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

struct ViewFiles: View {
    var controller: MedicalRecordController?
    @Binding var files: [String]
    
    var body: some View {
        NavigationLink(destination: FileManagementView(controller: controller, files: $files)) {
            HStack {
                Text("View Files")
                    .font(.custom("Graduate", size: 16))
                    .foregroundStyle(Color.myDarkBlue)
                Spacer()
                
                if !files.isEmpty {
                    Text("\(files.count)")
                        .font(.custom("DM Sans", size: 14))
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.myDarkBlue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.myLightBlue)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(lineWidth: 1)
                    .fill(Color.myDarkBlue)
            )
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
    }
}

struct NotesView: View {
    @Binding var textNotes: String
    var body: some View {
        TextField("Notes", text: $textNotes, axis: .vertical)
            .font(.custom("DM Sans", size: 14))
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(lineWidth: 1).fill(Color.myDarkBlue))
            .padding(.horizontal, 30)
    }
}

#Preview {
    Notes(recordTitle: "", date: .now, notes: "")
}
