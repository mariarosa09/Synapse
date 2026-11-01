//
//  AppointmentChecklist.swift
//  Synapse
//
//  Appointment checklist shared by Home ("Schedule For Today") and the Calendar day list.
//  Ticking a box marks the appointment completed (which cancels its reminder).
//

import SwiftUI

struct ChecklistUI: View {
    let appointments: [Appointment]
    var onToggle: (Appointment) -> Void
    var onSelect: ((Appointment) -> Void)? = nil

    var body: some View {
        if appointments.isEmpty {
            Text("No appointments.")
                .font(.synBody)
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
                        .accessibilityLabel(item.isChecked ? "Mark as scheduled" : "Mark as completed")

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.synBody)
                                .strikethrough(item.isChecked || item.status == .cancelled)
                                .foregroundColor(item.isChecked || item.status == .cancelled ? .secondary : .primary)
                            Text(item.status == .cancelled ? "\(item.timeRangeText) · Cancelled" : item.timeRangeText)
                                .font(.synLabel)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if onSelect != nil {
                            Image(systemName: "chevron.right")
                                .font(.synCaption)
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
