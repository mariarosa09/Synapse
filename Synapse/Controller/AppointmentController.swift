//
//  AppointmentController.swift
//  Synapse
//
//  CRUD for users/{uid}/appointments. Shared by Home ("today") and the Calendar.
//

import SwiftUI
import FirebaseFirestore

@Observable
@MainActor
final class AppointmentController {
    var appointments: [Appointment] = []
    var isLoading = false
    var errorMessage: String?

    private let db = Firestore.firestore()
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var userId: String?

    private var collection: CollectionReference? {
        guard let userId else { return nil }
        return db.collection("users").document(userId).collection("appointments")
    }

    // MARK: - Listening

    func start(uid: String) {
        stop()
        userId = uid
        isLoading = true
        listener = collection?.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            let items = (snapshot?.documents ?? [])
                .compactMap { Appointment(dictionary: $0.data()) }
                .sorted { $0.startDate < $1.startDate }
            self.appointments = items
            NotificationController.shared.update(appointments: items)
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        userId = nil
        appointments = []
        isLoading = false
    }

    // MARK: - Queries used by the calendar

    func appointments(on date: Date) -> [Appointment] {
        appointments.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    func hasAppointments(on date: Date) -> Bool {
        appointments.contains { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    func appointment(withID id: UUID?) -> Appointment? {
        guard let id else { return nil }
        return appointments.first { $0.id == id }
    }

    // MARK: - Validation

    func validationError(for appointment: Appointment) -> String? {
        if appointment.title.trimmed.isEmpty { return "Please enter a title." }
        if appointment.endDate <= appointment.startDate { return "The end time must be after the start time." }
        return nil
    }

    // MARK: - CRUD

    @discardableResult
    func save(_ appointment: Appointment) -> Bool {
        if let message = validationError(for: appointment) {
            errorMessage = message
            return false
        }
        guard let collection else {
            errorMessage = "You need to be logged in."
            return false
        }
        var item = appointment
        item.title = item.title.trimmed
        item.doctor = item.doctor.trimmed
        item.location = item.location.trimmed
        item.notes = item.notes.trimmed
        errorMessage = nil
        collection.document(item.id.uuidString).setData(item.dictionary) { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
        return true
    }

    func setStatus(_ appointment: Appointment, completed: Bool) {
        guard let collection else { return }
        let status: AppointmentStatus = completed ? .completed : .scheduled
        collection.document(appointment.id.uuidString).updateData(["status": status.rawValue]) { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
    }

    func delete(_ appointment: Appointment) {
        guard let collection else { return }
        collection.document(appointment.id.uuidString).delete { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
    }
}
