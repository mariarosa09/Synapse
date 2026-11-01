//
//  BasicInformationController.swift
//  Synapse
//
//  CRUD, status changes and filtering for public.basic_information (allergies and medical conditions).
//

import SwiftUI
import Supabase

@Observable
@MainActor
final class BasicInformationController {
    var entries: [BasicInformationModel] = []
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private var userId: UUID?

    func start(uid: UUID) {
        stop()
        userId = uid
        Task { await reload() }
    }

    func stop() {
        userId = nil
        entries = []
        isLoading = false
        errorMessage = nil
    }

    func reload() async {
        guard let uid = userId else { return }
        isLoading = true
        defer { if userId == uid { isLoading = false } }
        do {
            let items: [BasicInformationModel] = try await supabase.from(Table.basicInformation)
                .select()
                .eq("user_id", value: uid)
                .order("start_date", ascending: false)
                .execute()
                .value
            guard userId == uid else { return }
            entries = Self.sorted(items)
        } catch {
            guard userId == uid else { return }
            errorMessage = ErrorMessages.message(for: error)
        }
    }

    private static func sorted(_ items: [BasicInformationModel]) -> [BasicInformationModel] {
        items.sorted { $0.startDate > $1.startDate }
    }

    func entries(matching filter: StatusFilter, search: String = "") -> [BasicInformationModel] {
        entries.filter { filter.includes(active: $0.active) && $0.matches(search: search) }
    }

    func validationError(for entry: BasicInformationModel) -> String? {
        if entry.title.trimmed.isEmpty { return "Please enter a name." }
        if entry.startDate > Date() { return "The start date can't be in the future." }
        return nil
    }

    @discardableResult
    func save(_ entry: BasicInformationModel) -> Bool {
        if let message = validationError(for: entry) {
            errorMessage = message
            return false
        }
        guard let uid = userId else {
            errorMessage = "You need to be logged in."
            return false
        }
        var item = entry
        item.title = item.title.trimmed
        item.notes = item.notes.trimmed
        // Keep the end date consistent with the status.
        if item.active { item.endDate = nil } else if item.endDate == nil { item.endDate = Date() }
        errorMessage = nil

        var updated = entries
        if let index = updated.firstIndex(where: { $0.id == item.id }) { updated[index] = item } else { updated.append(item) }
        entries = Self.sorted(updated)

        Task {
            do {
                try await supabase.from(Table.basicInformation).upsert(item, onConflict: "id", returning: .minimal).execute()
            } catch {
                await fail(error, uid: uid)
            }
        }
        return true
    }

    func setActive(_ entry: BasicInformationModel, active: Bool) {
        var item = entry
        item.active = active
        save(item)
    }

    func delete(_ entry: BasicInformationModel) {
        guard let uid = userId else { return }
        entries.removeAll { $0.id == entry.id }
        Task {
            do {
                try await supabase.from(Table.basicInformation).delete(returning: .minimal).eq("id", value: entry.id).execute()
            } catch {
                await fail(error, uid: uid)
            }
        }
    }

    private func fail(_ error: Error, uid: UUID) async {
        guard userId == uid else { return }
        errorMessage = ErrorMessages.message(for: error)
        await reload()
    }
}
