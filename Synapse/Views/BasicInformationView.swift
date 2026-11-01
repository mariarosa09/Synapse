//
//  BasicInformationView.swift
//  Synapse
//
//  Created by Mac-LAB on 9/17/26.
//
//  Allergies and medical conditions: live search, All / Active / Inactive filters, and add,
//  view, edit, delete and change status. Saved to Supabase by BasicInformationController.
//

import SwiftUI

struct BasicInformationView: View {
    @Environment(SessionController.self) private var session
    @State private var filter: StatusFilter = .all
    @State private var searchText = ""
    @State private var popupVisible = false
    @State private var draft = BasicInformationModel()
    @State private var isEditing = false
    @State private var formError: String?
    @State private var pendingDelete: BasicInformationModel?

    private var controller: BasicInformationController { session.basicInfo }
    private var visible: [BasicInformationModel] { controller.entries(matching: filter, search: searchText) }

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                HeadingNoDesc(back: true, title: "Basic Information")
                SearchBar(text: $searchText, prompt: "Search allergies & conditions")
                    .padding(.top, 8)
                UpperTab(filter: $filter)

                if let message = controller.errorMessage, !popupVisible {
                    ErrorBanner(message: message) { controller.errorMessage = nil }
                }

                if controller.isLoading && controller.entries.isEmpty {
                    ProgressView().tint(Color.myDarkBlue).padding(.top, 40)
                    Spacer()
                } else if visible.isEmpty {
                    EmptyStateText(message: emptyMessage,
                                   systemImage: searchText.trimmed.isEmpty ? "list.bullet.clipboard" : "magnifyingglass")
                    Spacer()
                } else {
                    BasicInformationEntry(
                        items: visible,
                        onEdit: { openEditor(for: $0, editing: true) },
                        onToggleActive: { controller.setActive($0, active: !$0.active) },
                        onDelete: { pendingDelete = $0 }
                    )
                    .padding(.horizontal, 30)
                }
            }
            .floatingAddButton {
                openEditor(for: BasicInformationModel(), editing: false)
            }

            if popupVisible {
                Color.black.opacity(0.2).ignoresSafeArea()
                BasicInfoInput(title: isEditing ? "Edit Basic Information" : "Basic Information",
                               draft: $draft, errorMessage: formError) {
                    popupVisible = false
                } onSave: {
                    if let message = controller.validationError(for: draft) {
                        formError = message
                    } else if controller.save(draft) {
                        popupVisible = false
                    } else {
                        formError = controller.errorMessage
                    }
                }
            }

            if let item = pendingDelete {
                ConfirmationPopup(
                    title: "Delete Entry",
                    message: "\(item.title) (\(item.kind.title.lowercased())) will be permanently removed.",
                    confirmTitle: "Delete",
                    onCancel: { pendingDelete = nil },
                    onConfirm: {
                        controller.delete(item)
                        pendingDelete = nil
                    }
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var emptyMessage: String {
        let query = searchText.trimmed
        if controller.entries.isEmpty { return "Nothing added yet. Tap + to add an allergy or condition." }
        if !query.isEmpty {
            return filter == .all ? "No entries match “\(query)”."
                                  : "No \(filter.title.lowercased()) entries match “\(query)”."
        }
        return "No \(filter.title.lowercased()) entries."
    }

    private func openEditor(for entry: BasicInformationModel, editing: Bool) {
        draft = entry
        isEditing = editing
        formError = nil
        controller.errorMessage = nil
        popupVisible = true
    }
}

struct BasicInformationEntry: View {
    let items: [BasicInformationModel]
    let onEdit: (BasicInformationModel) -> Void
    let onToggleActive: (BasicInformationModel) -> Void
    let onDelete: (BasicInformationModel) -> Void

    var body: some View {
        List {
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        InfoRow(label: "What:", value: item.title)
                        InfoRow(label: "Type:", value: item.kind.title)
                        InfoRow(label: "When:", value: item.startDate.formatted(date: .long, time: .omitted))
                        if let end = item.endDate, !item.active {
                            InfoRow(label: "Until:", value: end.formatted(date: .long, time: .omitted))
                        }
                        if !item.notes.isEmpty {
                            InfoRow(label: "Notes:", value: item.notes, lineLimit: 3)
                        }
                        // Tap the badge to switch between Active and Inactive.
                        Button { onToggleActive(item) } label: { StatusBadge(active: item.active) }
                            .buttonStyle(.borderless)
                            .padding(.top, 2)
                            .accessibilityHint(item.active ? "Marks this entry inactive" : "Marks this entry active")
                    }

                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundStyle(Color.myDarkBlue)
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.myDarkBlue, lineWidth: 1))
                .padding(.bottom, 10)
                .contentShape(Rectangle())
                .onTapGesture { onEdit(item) }
                .swipeActions(edge: .leading) {
                    Button { onToggleActive(item) } label: {
                        SwipeActionLabel(title: item.active ? "Inactive" : "Active",
                                         systemImage: item.active ? "pause.circle" : "play.circle")
                    }
                    .tint(Color.myDarkBlue)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { onDelete(item) } label: {
                        SwipeActionLabel(title: "Delete", systemImage: "trash")
                    }
                    Button { onEdit(item) } label: {
                        SwipeActionLabel(title: "Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { onEdit(item) }
                    Button(item.active ? "Mark Inactive" : "Mark Active", systemImage: item.active ? "pause.circle" : "play.circle") { onToggleActive(item) }
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

/// Add / edit pop-up for an allergy or medical condition.
struct BasicInfoInput: View {
    var title: String = "Basic Information"
    @Binding var draft: BasicInformationModel
    var errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        PopupForm(title: title, errorMessage: errorMessage, onCancel: onCancel, onSave: onSave) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TYPE")
                    .font(.synLabel)
                Picker("Type", selection: $draft.kind) {
                    ForEach(BasicInfoKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            PopupField(title: "NAME", text: $draft.title)

            PopupDateRow(title: "Start date", date: $draft.startDate, maximum: Date())

            PopupTextArea(title: "NOTES", text: $draft.notes,
                          placeholder: "Reactions, triggers, treatment…")

            PopupToggleRow(title: "Active", isOn: $draft.active)
        }
    }
}

#Preview {
    NavigationStack { BasicInformationView() }
        .environment(SessionController())
}
