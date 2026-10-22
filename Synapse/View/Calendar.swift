//
//  Calendar.swift
//  Synapse
//
//  Created by Mac-LAB on 9/1/26.
//

import SwiftUI

// Main View for the Calendar Screen
struct CalendarView: View {
    @Environment(SessionController.self) private var session
    @State private var selectedDate = Date()
    @State private var appointmentPopUp: Bool = false
    @State private var draft = Appointment.newDraft()
    @State private var isEditing = false
    @State private var formError: String?
    @State private var detailID: UUID? = nil
    @State private var pendingDelete: Appointment? = nil

    private var appointments: AppointmentController { session.appointments }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    HeadingNoDesc(back: false, title: "Calendar")
                        .padding(.top, 60)                         .background(Color.myDarkBlue)
                    Spacer().frame(height: 20)
                    
                    CustomCalendarView(selectedDate: $selectedDate) { date in
                        appointments.hasAppointments(on: date)
                    }
                    .padding(.horizontal, 30)

                    if let message = appointments.errorMessage {
                        ErrorBanner(message: message) { appointments.errorMessage = nil }
                            .padding(.top, 10)
                    }
                    
                    Spacer().frame(height: 20)
                    
                    ListOfSchedule(
                        date: selectedDate,
                        appointments: appointments.appointments(on: selectedDate),
                        isLoading: appointments.isLoading,
                        onToggle: { appointments.setStatus($0, completed: !$0.isChecked) },
                        onSelect: { detailID = $0.id }
                    )
                    Spacer().frame(height: 100)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            AddFloatingButton {
                openEditor(for: Appointment.newDraft(on: selectedDate), editing: false)
            }
            .offset(x: 160, y: 340)
            
            if appointmentPopUp {
                Color.black.opacity(0.2).ignoresSafeArea()
                AppointmentInput(title: isEditing ? "Edit Appointment" : "Appointment",
                                 draft: $draft, isEditing: isEditing, errorMessage: formError) {
                    appointmentPopUp = false
                } onSave: {
                    if let message = appointments.validationError(for: draft) {
                        formError = message
                    } else if appointments.save(draft) {
                        // Show the day the appointment landed on.
                        selectedDate = draft.startDate
                        appointmentPopUp = false
                    }
                }
                .offset(y: -40)
            }

            if let item = appointments.appointment(withID: detailID), !appointmentPopUp {
                Color.black.opacity(0.2).ignoresSafeArea()
                    .onTapGesture { detailID = nil }
                AppointmentDetailCard(appointment: item) {
                    detailID = nil
                    openEditor(for: item, editing: true)
                } onDelete: {
                    pendingDelete = item
                } onClose: {
                    detailID = nil
                }
            }
        }
        .alert("Delete appointment?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let item = pendingDelete {
                    appointments.delete(item)
                    detailID = nil
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("\(pendingDelete?.title ?? "This appointment") will be removed and its reminder cancelled.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func openEditor(for appointment: Appointment, editing: Bool) {
        draft = appointment
        isEditing = editing
        formError = nil
        appointments.errorMessage = nil
        appointmentPopUp = true
    }
}

// Calendar Section of the screen
struct CustomCalendarView: View {
    @State private var currentMonthDate = Date()
    @Binding var selectedDate: Date
    var hasAppointments: (Date) -> Bool = { _ in false }
    private let calendar = Calendar.current
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

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
}

private extension CustomCalendarView {
    
    // Format for the month
    var headerView: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.myDarkBlue)
            }
            Spacer()
            Text(currentMonthDate.formatted(.dateTime.month(.wide).year()))
                .font(.custom("Graduate", size: 20))
                .bold()
                .foregroundStyle(Color.myDarkBlue)
            
            Spacer()

            
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.myDarkBlue)
            }
        }
    }
    
    // Format for weekdays
    var weekdayHeaderView: some View {
        Grid(alignment: .center, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.custom("DM Sans", size: 15))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.myDarkBlue)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // Format for the days grid
    var daysGridView: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<firstWeekdayOfMonthOffset(), id: \.self) { _ in
                Text("")
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            
            ForEach(daysInMonth(), id: \.self) { date in
                dayCell(for: date)
            }
        }
    }
    
    // Format for the days
    func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let marked = hasAppointments(date)
        
        return Text(calendar.component(.day, from: date).description)
            .font(.custom("DM Sans", size: 17))
            .fontWeight(isSelected || isToday ? .bold : .regular)
            .foregroundStyle(isSelected ? .white : (isToday ? Color.myDarkBlue : Color.myDarkBlue))
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
                if isSelected {
                    Circle()
                        .fill(Color.myDarkBlue)
                } else if isToday {
                    Circle()
                        .stroke(Color.myDarkBlue, lineWidth: 2)
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
            .onTapGesture {
                selectedDate = date
            }
    }
}

private extension CustomCalendarView {
    
    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonthDate) {
            currentMonthDate = newMonth
        }
    }
    

    func firstWeekdayOfMonthOffset() -> Int {
        let components = calendar.dateComponents([.year, .month], from: currentMonthDate)
        guard let firstOfMonth = calendar.date(from: components) else { return 0 }
        
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }
    
    func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonthDate) else { return [] }
        
        let components = calendar.dateComponents([.year, .month], from: currentMonthDate)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }
}

// View for the list of schedule for the day
struct ListOfSchedule: View {
    var date: Date
    var appointments: [Appointment]
    var isLoading: Bool = false
    var onToggle: (Appointment) -> Void
    var onSelect: (Appointment) -> Void
    
    var body: some View {
        VStack (alignment: .leading) {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.custom("Graduate", size: 16))
            if isLoading && appointments.isEmpty {
                ProgressView().tint(Color.myDarkBlue).frame(maxWidth: .infinity).padding(.top, 20)
            } else {
                ChecklistUI(appointments: appointments, onToggle: onToggle, onSelect: onSelect)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 190)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.myDarkBlue, lineWidth: 1)
        )
        .padding(.horizontal, 30)
    }
}

// Checklist of appointments. Ticking a box marks the appointment completed (and cancels its reminder).
struct ChecklistUI: View {
    let appointments: [Appointment]
    var onToggle: (Appointment) -> Void
    var onSelect: ((Appointment) -> Void)? = nil
    
    var body: some View {
        if appointments.isEmpty {
            Text("No appointments.")
                .font(.custom("DM Sans", size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(appointments) { item in
                    HStack(spacing: 10) {
                        Button {
                            onToggle(item)
                        } label: {
                            Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                                .foregroundColor(item.isChecked ? Color.myDarkBlue : .secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.custom("DM Sans", size: 14))
                                .strikethrough(item.isChecked)
                                .foregroundColor(item.isChecked ? .secondary : .primary)
                            Text(item.timeRangeText)
                                .font(.custom("DM Sans", size: 12))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()

                        if onSelect != nil {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.myDarkBlue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect?(item) }
                }
            }
            .padding(.top, 8)
        }
    }
}

// Full details of one appointment, with edit and delete.
struct AppointmentDetailCard: View {
    let appointment: Appointment
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.custom("DM Sans", size: 14))
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.custom("DM Sans", size: 14))
            Spacer()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appointment.title)
                .foregroundStyle(Color.myDarkBlue)
                .font(.custom("Graduate", size: 16))
            row("Doctor", appointment.doctor)
            row("Location", appointment.location)
            row("Date", appointment.startDate.formatted(date: .complete, time: .omitted))
            row("Time", appointment.timeRangeText)
            row("Status", appointment.status.title)
            row("Notes", appointment.notes)

            HStack {
                Button(role: .destructive, action: onDelete) {
                    Text("Delete")
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(.red)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.1)))
                }
                Spacer()
                Button(action: onClose) {
                    Text("Close")
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(Color.gray)
                        .padding()
                }
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(Color.myDarkBlue)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.myLightBlue))
                }
            }
            .padding(.top, 6)
        }
        .popupCard()
    }
}

struct AppointmentInput: View {
    let title: String
    @Binding var draft: Appointment
    var isEditing: Bool
    var errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack (alignment: .leading) {
                Text(title)
                    .foregroundStyle(Color.myDarkBlue)
                    .font(.custom("Graduate", size: 16))
                PopupField(title: "TITLE", text: $draft.title)
                PopupField(title: "DOCTOR", text: $draft.doctor)
                PopupField(title: "LOCATION", text: $draft.location)
                HStack {
                    Text("START: ")
                        .font(.custom("DM Sans", size: 12))
                    DatetimePick(selectedDate: $draft.startDate, limitToFuture: !isEditing)
                }
                .padding(.top, 10)
                HStack {
                    Text("END: ")
                        .font(.custom("DM Sans", size: 12))
                    DatetimePick(selectedDate: $draft.endDate, limitToFuture: false)
                }
                PopupField(title: "NOTES", text: $draft.notes, capitalization: .sentences)

                if isEditing {
                    Picker("Status", selection: $draft.status) {
                        ForEach(AppointmentStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 10)
                }

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
        .frame(maxHeight: 530)
        .popupCard()
        .onChange(of: draft.startDate) { old, new in
            // Moving the start moves the end with it, keeping the same length.
            draft.endDate = draft.endDate.addingTimeInterval(new.timeIntervalSince(old))
        }
    }
}

struct DatetimePick: View {
    @Binding var selectedDate: Date
    var limitToFuture: Bool = true
    var body: some View {
        HStack {
            Group {
                if limitToFuture {
                    DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                } else {
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
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
    NavigationBar()
        .environment(SessionController())
}
