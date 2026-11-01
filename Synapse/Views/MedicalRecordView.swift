//
//  MedicalRecordView.swift
//  Synapse
//
//  Created by Mac-LAB on 9/8/26.
//
//  Medical records list with live search (title, category, notes, date, attachment names),
//  a shortcut to Basic Information, and delete with confirmation. Data comes from the
//  signed-in user's rows in Supabase via MedicalRecordController.
//

import SwiftUI

struct MedicalRecordView: View {
    @Environment(SessionController.self) private var session
    @State private var searchText = ""
    @State private var navigateToNewRecord = false
    @State private var pendingDelete: MedicalInformation?

    private var controller: MedicalRecordController { session.medicalRecords }
    private var visible: [MedicalInformation] { controller.records(matching: searchText) }

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                HeadingNoDesc(back: true, title: "Medical Record")
                SearchBar(text: $searchText, prompt: "Search records")
                    .padding(.top, 8)
                NavigationLink {
                    BasicInformationView()
                } label: {
                    ButtonBasicInformation()
                }

                if let message = controller.errorMessage {
                    ErrorBanner(message: message) { controller.errorMessage = nil }
                }

                if controller.isLoading && controller.records.isEmpty {
                    ProgressView()
                        .tint(Color.myDarkBlue)
                        .padding(.top, 40)
                    Spacer()
                } else if visible.isEmpty {
                    EmptyStateText(message: controller.records.isEmpty
                                   ? "No medical records yet. Tap + to add one."
                                   : "No records match “\(searchText.trimmed)”.",
                                   systemImage: controller.records.isEmpty ? "doc.text" : "magnifyingglass")
                    Spacer()
                } else {
                    MedicalEntry(items: visible) { pendingDelete = $0 }
                        .padding(.horizontal, 30)
                }
            }
            .floatingAddButton {
                navigateToNewRecord = true
            }

            if let item = pendingDelete {
                ConfirmationPopup(
                    title: "Delete Record",
                    message: "\(item.title) and its \(item.attachments.count) attachment\(item.attachments.count == 1 ? "" : "s") will be permanently deleted.",
                    confirmTitle: "Delete",
                    onCancel: { pendingDelete = nil },
                    onConfirm: {
                        controller.delete(item)
                        pendingDelete = nil
                    }
                )
            }
        }
        .navigationDestination(isPresented: $navigateToNewRecord) {
            MedicalRecordDetailView(record: nil)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await controller.reload() }
    }
}

struct ButtonBasicInformation: View {
    var body: some View {
        VStack {
            HStack {
                Text("Basic Information")
                    .font(.synSection)
                    .foregroundStyle(Color.myDarkBlue)
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .foregroundStyle(Color.myDarkBlue)
            }
            .padding()
            .background(Color.myLightBlue)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 15)
                .stroke(Color.myDarkBlue, lineWidth: 1))
            .padding(.horizontal, 30)
        }
    }
}

struct MedicalEntry: View {
    let items: [MedicalInformation]
    let onDelete: (MedicalInformation) -> Void

    var body: some View {
        List {
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        InfoRow(label: "What:", value: item.title, lineLimit: 2)
                        InfoRow(label: "When:", value: item.date.formatted(date: .long, time: .omitted))
                        if !item.category.isEmpty {
                            InfoRow(label: "Category:", value: item.category, lineLimit: 2)
                        }
                        if !item.attachments.isEmpty {
                            Label("\(item.attachments.count) file\(item.attachments.count == 1 ? "" : "s")", systemImage: "paperclip")
                                .font(.synCaption)
                                .foregroundStyle(Color.myDarkBlue)
                        }
                    }

                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundStyle(Color.myDarkBlue)
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.myDarkBlue, lineWidth: 1))
                .padding(.bottom, 10)
                .background {
                    NavigationLink(destination: MedicalRecordDetailView(record: item)) {
                        EmptyView()
                    }
                    .opacity(0)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { onDelete(item) } label: {
                        SwipeActionLabel(title: "Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(item) }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Color.clear.frame(height: 70)   // room above the + button
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    NavigationStack { MedicalRecordView() }
        .environment(SessionController())
}
