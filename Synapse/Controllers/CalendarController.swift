//
//  CalendarController.swift
//  Synapse
//
//  Logic behind the Calendar (appointments) screen: month navigation, the selected day,
//  the add / edit pop-up, the details pop-up and delete confirmation.
//  Appointment rows are read and written through the session's AppointmentController,
//  so the calendar updates immediately whenever an appointment changes anywhere in the app.
//

import SwiftUI

@MainActor
@Observable
final class CalendarController {
    private let calendar = Calendar.current

    /// Any date inside the month being shown.
    var displayedMonth: Date = .now
    var selectedDate: Date = .now

    // Add / edit pop-up
    var isEditorVisible = false
    var isEditing = false
    var draft = Appointment.newDraft()
    var formError: String?

    // Details pop-up and delete confirmation
    var detailID: UUID?
    var pendingDelete: Appointment?

    let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // MARK: - Month grid

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    func changeMonth(by value: Int) {
        if let month = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = month
        }
    }

    func goToToday() {
        displayedMonth = .now
        selectedDate = .now
    }

    private var firstOfMonth: Date? {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
    }

    /// Empty cells before day 1 (the grid starts on Sunday).
    var leadingBlankDays: Int {
        guard let firstOfMonth else { return 0 }
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }

    var daysInMonth: [Date] {
        guard let firstOfMonth, let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstOfMonth) }
    }

    func dayNumber(_ date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    func isSelected(_ date: Date) -> Bool { calendar.isDate(date, inSameDayAs: selectedDate) }
    func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }

    func select(_ date: Date) {
        selectedDate = date
    }

    // MARK: - Add / edit

    func openNewAppointment() {
        openEditor(for: Appointment.newDraft(on: selectedDate), editing: false)
    }

    func openEditor(for appointment: Appointment, editing: Bool) {
        draft = appointment
        isEditing = editing
        formError = nil
        detailID = nil
        isEditorVisible = true
    }

    func closeEditor() {
        isEditorVisible = false
        formError = nil
    }

    /// Validates and saves the draft; the calendar then jumps to the day the appointment is on.
    func saveDraft(using appointments: AppointmentController) {
        appointments.errorMessage = nil
        if let message = appointments.validationError(for: draft) {
            formError = message
            return
        }
        if appointments.save(draft) {
            selectedDate = draft.startDate
            displayedMonth = draft.startDate
            isEditorVisible = false
            formError = nil
        } else {
            formError = appointments.errorMessage
        }
    }

    /// Moving the start time moves the end time with it, keeping the same length.
    func startDateChanged(from old: Date, to new: Date) {
        draft.endDate = draft.endDate.addingTimeInterval(new.timeIntervalSince(old))
    }

    // MARK: - Details / delete

    func showDetails(_ appointment: Appointment) {
        detailID = appointment.id
    }

    func closeDetails() {
        detailID = nil
    }

    func requestDelete(_ appointment: Appointment) {
        pendingDelete = appointment
    }

    func cancelDelete() {
        pendingDelete = nil
    }

    func confirmDelete(using appointments: AppointmentController) {
        guard let item = pendingDelete else { return }
        appointments.delete(item)   // also cancels its reminder
        pendingDelete = nil
        detailID = nil
    }

    func toggleCompleted(_ appointment: Appointment, using appointments: AppointmentController) {
        appointments.setStatus(appointment, completed: !appointment.isChecked)
    }
}
