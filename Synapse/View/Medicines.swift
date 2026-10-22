//
//  Medicines.swift
//  Synapse
//
//  Created by Mac-LAB on 9/17/26.
//

import SwiftUI

struct Medicines: View {
    @Environment(SessionController.self) private var session
    @State private var filter: StatusFilter = .all
    @State private var popupVisible = false
    @State private var draft = MedicineInformation()
    @State private var isEditing = false
    @State private var formError: String?

    private var controller: MedicineController { session.medicines }
    private var visible: [MedicineInformation] { controller.medicines.filter { filter.includes(active: $0.active) } }

    var body: some View {
        ZStack {
            VStack (spacing: 10){
                HeadingNoDesc(back: true, title: "Medicines")
                UpperTab(filter: $filter).padding(.top, 20)

                if let message = controller.errorMessage {
                    ErrorBanner(message: message) { controller.errorMessage = nil }
                }

                if controller.isLoading && controller.medicines.isEmpty {
                    ProgressView().tint(Color.myDarkBlue).padding(.top, 40)
                    Spacer()
                } else if visible.isEmpty {
                    Text(controller.medicines.isEmpty ? "No medicines yet. Tap + to add one."
                                                      : "No \(filter.title.lowercased()) medicines.")
                        .font(.custom("DM Sans", size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                    Spacer()
                } else {
                    MedicineEntry(
                        items: visible,
                        onEdit: { openEditor(for: $0, editing: true) },
                        onToggleActive: { controller.setActive($0, active: !$0.active) },
                        onDelete: { controller.delete($0) }
                    )
                    .padding(.horizontal, 30)
                }
            }

            AddFloatingButton {
                openEditor(for: MedicineInformation(), editing: false)
            }
            .offset(x: 160, y: 370)
            
            if popupVisible {
                Color.black.opacity(0.2).ignoresSafeArea()
                MedicineInput(title: isEditing ? "Edit Medicine" : "Medicine", draft: $draft, errorMessage: formError) {
                    popupVisible = false
                } onSave: {
                    if let message = controller.validationError(for: draft) {
                        formError = message
                    } else if controller.save(draft) {
                        popupVisible = false
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func openEditor(for medicine: MedicineInformation, editing: Bool) {
        draft = medicine
        isEditing = editing
        formError = nil
        controller.errorMessage = nil
        popupVisible = true
    }
}

private struct MedicineRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.custom("DM Sans", size: 15))
                .fontWeight(.semibold)
            Text(value)
                .font(.custom("DM Sans", size: 15))
            Spacer()
        }
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
                        MedicineRow(label: "Medication: ", value: item.medication)
                        MedicineRow(label: "Amount: ", value: item.amount)
                        MedicineRow(label: "Frequency: ", value: item.frequencyText)
                        MedicineRow(label: "Times: ", value: item.timesText)
                        HStack {
                            Text("Start Date: ")
                                .font(.custom("DM Sans", size: 15))
                                .fontWeight(.semibold)
                            Text(item.startDate, style: .date)
                                .font(.custom("DM Sans", size: 15))
                            Spacer()
                        }
                        HStack {
                            Text("End Date: ")
                                .font(.custom("DM Sans", size: 15))
                                .fontWeight(.semibold)
                            Text(item.endDate, style: .date)
                                .font(.custom("DM Sans", size: 15))
                            Spacer()
                        }
                        if !item.instructions.isEmpty {
                            MedicineRow(label: "Instructions: ", value: item.instructions)
                        }
                        HStack {
                            StatusBadge(active: item.active)
                            if item.isExpired {
                                Text("Course ended")
                                    .font(.custom("DM Sans", size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
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
                    Button(item.active ? "Deactivate" : "Activate") { onToggleActive(item) }
                        .tint(Color.myDarkBlue)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) { onDelete(item) }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

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
        ScrollView {
            VStack (alignment: .leading) {
                Text(title)
                    .foregroundStyle(Color.myDarkBlue)
                    .font(.custom("Graduate", size: 16))
                PopupField(title: "MEDICATION", text: $draft.medication)
                PopupField(title: "DOSAGE (e.g. 1 pill, 5 ml)", text: $draft.amount, capitalization: .never)

                Stepper(value: frequencyBinding, in: MedicineInformation.allowedFrequencies, step: 1) {
                    HStack {
                        Text("TIMES PER DAY: ")
                            .font(.custom("DM Sans", size: 12))
                        Text(draft.frequency.formatted())
                            .font(.custom("DM Sans", size: 16))
                    }
                }
                .padding(.top, 10)

                Toggle(isOn: customTimesBinding) {
                    Text("SET INTAKE TIMES MYSELF")
                        .font(.custom("DM Sans", size: 12))
                }
                .tint(Color.myDarkBlue)
                .padding(.top, 6)

                if draft.usesCustomTimes {
                    ForEach(0..<draft.frequency, id: \.self) { index in
                        HStack {
                            Text("DOSE \(index + 1): ")
                                .font(.custom("DM Sans", size: 12))
                            DatePicker("", selection: timeBinding(index), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            Spacer()
                        }
                    }
                } else {
                    Text("Reminders: \(draft.timesText)")
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("START DATE: ")
                        .font(.custom("DM Sans", size: 12))
                    MedicineDatePick(selectedDate: $draft.startDate)
                }
                .padding(.top, 10)
                HStack {
                    Text("END DATE: ")
                        .font(.custom("DM Sans", size: 12))
                    MedicineDatePick(selectedDate: $draft.endDate, from: draft.startDate)
                }

                PopupField(title: "INSTRUCTIONS", text: $draft.instructions, capitalization: .sentences)

                Toggle(isOn: $draft.active) {
                    Text("ACTIVE")
                        .font(.custom("DM Sans", size: 12))
                }
                .tint(Color.myDarkBlue)
                .padding(.top, 10)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(.red)
                        .padding(.top, 6)
                }

                PopupButtons(onCancel: onCancel, onSave: onSave)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 600)
        .popupCard()
        .onChange(of: draft.startDate) { _, newStart in
            if draft.endDate < newStart { draft.endDate = newStart }
        }
    }
}

/// Date picker without the "past only" / "future only" limits of the onboarding pickers.
struct MedicineDatePick: View {
    @Binding var selectedDate: Date
    var from: Date? = nil

    var body: some View {
        HStack {
            Group {
                if let from {
                    DatePicker("", selection: $selectedDate, in: Calendar.current.startOfDay(for: from)..., displayedComponents: .date)
                } else {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                }
            }
            .font(.custom("DM Sans", size: 19))
            .fontWeight(.semibold)
            .scaleEffect(0.85)
            .padding(.horizontal, -15)
        }
    }
}

#Preview {
    Medicines()
        .environment(SessionController())
}
