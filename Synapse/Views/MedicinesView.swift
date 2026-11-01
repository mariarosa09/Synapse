//
//  MedicinesView.swift
//  Synapse
//
//  Created by Mac-LAB on 9/17/26.
//
//  Medicine list with live search and All / Active / Inactive filters, plus the add / edit pop-up.
//  MedicineController saves to Supabase and keeps the intake reminders in sync.
//

import SwiftUI

struct MedicinesView: View {
    @Environment(SessionController.self) private var session
    @State private var filter: StatusFilter = .all
    @State private var searchText = ""
    @State private var popupVisible = false
    @State private var draft = MedicineInformation()
    @State private var isEditing = false
    @State private var formError: String?
    @State private var pendingDelete: MedicineInformation?

    private var controller: MedicineController { session.medicines }
    private var visible: [MedicineInformation] { controller.medicines(matching: filter, search: searchText) }

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                HeadingNoDesc(back: true, title: "Medicines")
                SearchBar(text: $searchText, prompt: "Search medicines")
                    .padding(.top, 8)
                UpperTab(filter: $filter)

                if let message = controller.errorMessage, !popupVisible {
                    ErrorBanner(message: message) { controller.errorMessage = nil }
                }

                if controller.isLoading && controller.medicines.isEmpty {
                    ProgressView().tint(Color.myDarkBlue).padding(.top, 40)
                    Spacer()
                } else if visible.isEmpty {
                    EmptyStateText(message: emptyMessage,
                                   systemImage: searchText.trimmed.isEmpty ? "pills" : "magnifyingglass")
                    Spacer()
                } else {
                    MedicineEntry(
                        items: visible,
                        onEdit: { openEditor(for: $0, editing: true) },
                        onToggleActive: { controller.setActive($0, active: !$0.active) },
                        onDelete: { pendingDelete = $0 }
                    )
                    .padding(.horizontal, 30)
                }
            }
            .floatingAddButton {
                openEditor(for: MedicineInformation(), editing: false)
            }

            if popupVisible {
                Color.black.opacity(0.2).ignoresSafeArea()
                MedicineInput(title: isEditing ? "Edit Medicine" : "Medicine", draft: $draft, errorMessage: formError) {
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
                    title: "Delete Medicine",
                    message: "\(item.medication) will be removed and its reminders cancelled.",
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
        if controller.medicines.isEmpty { return "No medicines yet. Tap + to add one." }
        if !query.isEmpty {
            return filter == .all ? "No medicines match “\(query)”."
                                  : "No \(filter.title.lowercased()) medicines match “\(query)”."
        }
        return "No \(filter.title.lowercased()) medicines."
    }

    private func openEditor(for medicine: MedicineInformation, editing: Bool) {
        draft = medicine
        isEditing = editing
        formError = nil
        controller.errorMessage = nil
        popupVisible = true
    }
}

struct MedicineEntry: View {
    let items: [MedicineInformation]
    let onEdit: (MedicineInformation) -> Void
    let onToggleActive: (MedicineInformation) -> Void
    let onDelete: (MedicineInformation) -> Void

    var body: some View {
        List {
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        InfoRow(label: "Medication:", value: item.medication)
                        InfoRow(label: "Amount:", value: item.amount)
                        InfoRow(label: "Frequency:", value: item.frequencyText)
                        InfoRow(label: "Times:", value: item.timesText)
                        InfoRow(label: "Start Date:", value: item.startDate.formatted(date: .long, time: .omitted))
                        InfoRow(label: "End Date:", value: item.endDate.formatted(date: .long, time: .omitted))
                        if !item.instructions.isEmpty {
                            InfoRow(label: "Instructions:", value: item.instructions, lineLimit: 3)
                        }
                        HStack(spacing: 8) {
                            // Tap the badge to switch between Active and Inactive.
                            Button { onToggleActive(item) } label: { StatusBadge(active: item.active) }
                                .buttonStyle(.borderless)
                                .accessibilityHint(item.active ? "Deactivates this medicine" : "Activates this medicine")
                            if item.isExpired {
                                Text("Course ended")
                                    .font(.synLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 2)
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
                        SwipeActionLabel(title: item.active ? "Deactivate" : "Activate",
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
                    Button(item.active ? "Deactivate" : "Activate", systemImage: item.active ? "pause.circle" : "play.circle") { onToggleActive(item) }
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

/// Add / edit pop-up for a medicine.
struct MedicineInput: View {
    let title: String
    @Binding var draft: MedicineInformation
    var errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    private var frequencyBinding: Binding<Int> {
        Binding(
            get: { draft.frequency },
            set: { newValue in
                let wasCustom = draft.usesCustomTimes
                draft.frequency = newValue
                // Keep manual times in step with the number of doses.
                if wasCustom { draft.intakeMinutes = MedicineInformation.defaultIntakeMinutes(for: newValue) }
            }
        )
    }

    private var customTimesBinding: Binding<Bool> {
        Binding(
            get: { draft.usesCustomTimes },
            set: { on in
                draft.intakeMinutes = on ? MedicineInformation.defaultIntakeMinutes(for: draft.frequency) : []
            }
        )
    }

    private func timeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                let minutes = draft.intakeMinutes.indices.contains(index) ? draft.intakeMinutes[index] : 8 * 60
                return Date.minutesToDate(minutes)
            },
            set: { newValue in
                if draft.intakeMinutes.indices.contains(index) {
                    draft.intakeMinutes[index] = newValue.minutesSinceMidnight
                }
            }
        )
    }

    var body: some View {
        PopupForm(title: title, errorMessage: errorMessage, onCancel: onCancel, onSave: onSave) {
            PopupField(title: "MEDICATION", text: $draft.medication)
            PopupField(title: "DOSAGE (e.g. 1 pill, 5 ml)", text: $draft.amount, capitalization: .never)

            VStack(alignment: .leading, spacing: 4) {
                PopupRow(title: "Times per day") {
                    Text(draft.frequency.formatted())
                        .font(.synBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.myDarkBlue)
                    Stepper("Times per day", value: frequencyBinding, in: MedicineInformation.allowedFrequencies)
                        .labelsHidden()
                }
                PopupHint(text: "\(draft.frequencyText) · \(draft.frequency) reminder\(draft.frequency == 1 ? "" : "s") a day")
            }

            VStack(alignment: .leading, spacing: 4) {
                PopupToggleRow(title: "Set intake times myself", isOn: customTimesBinding)
                if draft.usesCustomTimes {
                    ForEach(0..<draft.frequency, id: \.self) { index in
                        PopupRow(title: "Dose \(index + 1)") {
                            DatePicker("Dose \(index + 1)", selection: timeBinding(index), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(Color.myDarkBlue)
                        }
                    }
                } else {
                    PopupHint(text: "Reminders at \(draft.timesText)")
                }
            }

            PopupDateRow(title: "Start date", date: $draft.startDate)
            PopupDateRow(title: "End date", date: $draft.endDate,
                         minimum: Calendar.current.startOfDay(for: draft.startDate))

            PopupTextArea(title: "INSTRUCTIONS", text: $draft.instructions,
                          placeholder: "e.g. Take after meals with water")

            PopupToggleRow(title: "Active", isOn: $draft.active)
        }
        .onChange(of: draft.startDate) { _, newStart in
            if draft.endDate < newStart { draft.endDate = newStart }
        }
    }
}

#Preview {
    NavigationStack { MedicinesView() }
        .environment(SessionController())
}
