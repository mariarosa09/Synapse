//
//  CalendarView.swift
//  Synapse
//
//  Created by Mac-LAB on 9/1/26.
//
//  Appointment calendar: month grid with dots on days that have appointments, the selected
//  day's appointments, and pop-ups to add, view, edit and delete appointments.
//  CalendarController holds the screen logic; AppointmentController (shared with Home) the data.
//
//  Layout: the blue header sits at the top of the screen exactly like the other main screens
//  (Synapse, Profile…), with the title left-aligned on the same 30 pt margin.
//

import SwiftUI

struct CalendarView: View {
    @Environment(SessionController.self) private var session
    @State private var controller = CalendarController()

    private var appointments: AppointmentController { session.appointments }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeadingNoDesc(back: false, title: "Calendar")

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 20)

                        CustomCalendarView(controller: controller) { date in
                            appointments.hasAppointments(on: date)
                        }
                        .padding(.horizontal, 30)

                        if let message = appointments.errorMessage, !controller.isEditorVisible {
                            ErrorBanner(message: message) { appointments.errorMessage = nil }
                                .padding(.top, 10)
                        }

                        Spacer().frame(height: 20)

                        ListOfSchedule(
                            date: controller.selectedDate,
                            appointments: appointments.appointments(on: controller.selectedDate),
                            isLoading: appointments.isLoading,
                            onToggle: { controller.toggleCompleted($0, using: appointments) },
                            onSelect: { controller.showDetails($0) }
                        )
                        Spacer().frame(height: 100)
                    }
                }
            }
            .floatingAddButton {
                appointments.errorMessage = nil
                controller.openNewAppointment()
            }

            if controller.isEditorVisible {
                Color.black.opacity(0.2).ignoresSafeArea()
                AppointmentInput(controller: controller) {
                    controller.closeEditor()
                } onSave: {
                    controller.saveDraft(using: appointments)
                }
            }

            if let item = appointments.appointment(withID: controller.detailID),
               !controller.isEditorVisible, controller.pendingDelete == nil {
                Color.black.opacity(0.2).ignoresSafeArea()
                    .onTapGesture { controller.closeDetails() }
                AppointmentDetailCard(appointment: item) {
                    controller.openEditor(for: item, editing: true)
                } onDelete: {
                    controller.requestDelete(item)
                } onClose: {
                    controller.closeDetails()
                }
            }

            if let item = controller.pendingDelete {
                ConfirmationPopup(
                    title: "Delete Appointment",
                    message: "\(item.title.isEmpty ? "This appointment" : item.title) will be removed and its reminder cancelled.",
                    confirmTitle: "Delete",
                    onCancel: { controller.cancelDelete() },
                    onConfirm: { controller.confirmDelete(using: appointments) }
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Month grid

struct CustomCalendarView: View {
    var controller: CalendarController
    var hasAppointments: (Date) -> Bool = { _ in false }

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 20) {
            headerView
            weekdayHeaderView
            daysGridView
        }
        .padding()
        .background(Color.myLightBlue)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.myDarkBlue, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var headerView: some View {
        HStack {
            Button(action: { controller.changeMonth(by: -1) }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.myDarkBlue)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Button(action: { controller.goToToday() }) {
                Text(controller.monthTitle)
                    .font(.synTitle)
                    .bold()
                    .foregroundStyle(Color.myDarkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityHint("Go to today")
            Spacer()
            Button(action: { controller.changeMonth(by: 1) }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.myDarkBlue)
            }
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayHeaderView: some View {
        Grid(alignment: .center, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(controller.weekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.synBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.myDarkBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var daysGridView: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<controller.leadingBlankDays, id: \.self) { _ in
                Text("")
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            ForEach(controller.daysInMonth, id: \.self) { date in
                dayCell(for: date)
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = controller.isSelected(date)
        let isToday = controller.isToday(date)
        let marked = hasAppointments(date)

        return Text(controller.dayNumber(date))
            .font(.synRow)
            .fontWeight(isSelected || isToday ? .bold : .regular)
            .foregroundStyle(isSelected ? .white : Color.myDarkBlue)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
                if isSelected {
                    Circle().fill(Color.myDarkBlue)
                } else if isToday {
                    Circle().stroke(Color.myDarkBlue, lineWidth: 2)
                }
            }
            .overlay(alignment: .bottom) {
                // Dot under days that have appointments.
                if marked {
                    Circle()
                        .fill(isSelected ? Color.white : Color.myDarkBlue)
                        .frame(width: 5, height: 5)
                        .padding(.bottom, 3)
                }
            }
            .contentShape(Circle())
            .onTapGesture { controller.select(date) }
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted) + (marked ? ", has appointments" : ""))
    }
}

// MARK: - Selected day list

struct ListOfSchedule: View {
    var date: Date
    var appointments: [Appointment]
    var isLoading: Bool = false
    var onToggle: (Appointment) -> Void
    var onSelect: (Appointment) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.synSection)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isLoading && appointments.isEmpty {
                ProgressView().tint(Color.myDarkBlue).frame(maxWidth: .infinity).padding(.top, 20)
            } else {
                ChecklistUI(appointments: appointments, onToggle: onToggle, onSelect: onSelect)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.myDarkBlue, lineWidth: 1)
        )
        .padding(.horizontal, 30)
    }
}

// MARK: - Pop-ups

/// Full details of one appointment, with edit and delete.
struct AppointmentDetailCard: View {
    let appointment: Appointment
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.synBody)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.synBody)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appointment.title)
                .foregroundStyle(Color.myDarkBlue)
                .font(.synSection)
                .frame(maxWidth: .infinity, alignment: .leading)
            row("Doctor", appointment.doctor)
            row("Location", appointment.location)
            row("Date", appointment.startDate.formatted(date: .complete, time: .omitted))
            row("Time", appointment.timeRangeText)
            row("Status", appointment.status.title)
            row("Reminder", reminderText)
            row("Notes", appointment.notes)
                .lineLimit(8)

            HStack {
                Button(role: .destructive, action: onDelete) {
                    Text("Delete")
                        .font(.synLabel)
                        .foregroundStyle(.red)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.1)))
                }
                Spacer()
                Button(action: onClose) {
                    Text("Close")
                        .font(.synLabel)
                        .foregroundStyle(Color.gray)
                        .padding()
                }
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.synLabel)
                        .foregroundStyle(Color.myDarkBlue)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.myLightBlue))
                }
            }
            .padding(.top, 6)
        }
        .popupCard()
    }

    private var reminderText: String {
        guard appointment.status == .scheduled else { return "None (\(appointment.status.title.lowercased()))" }
        guard appointment.reminderDate > Date() else { return "None (already started)" }
        return appointment.reminderDate.formatted(date: .omitted, time: .shortened) + " (5 minutes before)"
    }
}

/// Add / edit pop-up. The title is left-aligned like every other pop-up and screen header.
struct AppointmentInput: View {
    @Bindable var controller: CalendarController
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        PopupForm(title: controller.isEditing ? "Edit Appointment" : "Appointment",
                  errorMessage: controller.formError, onCancel: onCancel, onSave: onSave) {
            PopupField(title: "TITLE", text: $controller.draft.title)
            PopupField(title: "DOCTOR", text: $controller.draft.doctor)
            PopupField(title: "LOCATION", text: $controller.draft.location)

            PopupDateRow(title: "Starts", date: $controller.draft.startDate,
                         components: [.date, .hourAndMinute],
                         minimum: controller.isEditing ? nil : Date())
            PopupDateRow(title: "Ends", date: $controller.draft.endDate,
                         components: [.date, .hourAndMinute],
                         minimum: controller.draft.startDate)

            PopupTextArea(title: "NOTES", text: $controller.draft.notes,
                          placeholder: "What to bring, questions to ask…")

            if controller.isEditing {
                VStack(alignment: .leading, spacing: 6) {
                    Text("STATUS")
                        .font(.synLabel)
                    Picker("Status", selection: $controller.draft.status) {
                        ForEach(AppointmentStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            PopupHint(text: "You'll be reminded 5 minutes before the start time.")
        }
        .onChange(of: controller.draft.startDate) { old, new in
            controller.startDateChanged(from: old, to: new)
        }
    }
}

#Preview {
    NavigationStack { MainTabView() }
        .environment(SessionController())
}
