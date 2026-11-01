//
//  MedicalRecordController.swift
//  Synapse
//
//  CRUD and search for public.medical_records. Attachments are embedded in each record
//  (`medical_record_attachments`) and edited through AttachmentController.
//

import SwiftUI
import Supabase

@Observable
@MainActor
final class MedicalRecordController {
    var records: [MedicalInformation] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    @ObservationIgnored private var userId: UUID?

    // MARK: - Loading

    func start(uid: UUID) {
        stop()
        userId = uid
        Task { await reload() }
    }

    func stop() {
        userId = nil
        records = []
        isLoading = false
        isSaving = false
        errorMessage = nil
    }

    func reload() async {
        guard let uid = userId else { return }
        isLoading = true
        defer { if userId == uid { isLoading = false } }
        do {
            let items: [MedicalInformation] = try await supabase.from(Table.medicalRecords)
                .select("id, title, record_date, category, notes, medical_record_attachments(*)")
                .eq("user_id", value: uid)
                .order("record_date", ascending: false)
                .execute()
                .value
            guard userId == uid else { return }
            records = Self.sorted(items)
        } catch {
            guard userId == uid else { return }
            errorMessage = ErrorMessages.message(for: error)
        }
    }

    private static func sorted(_ items: [MedicalInformation]) -> [MedicalInformation] {
        items.sorted { $0.date > $1.date }
    }

    func record(withID id: UUID) -> MedicalInformation? {
        records.first { $0.id == id }
    }

    // MARK: - Search

    /// Records whose title, category, notes, date or attachment names contain the search text.
    func records(matching search: String) -> [MedicalInformation] {
        records.filter { $0.matches(search: search) }
    }

    // MARK: - Save

    /// Creates or updates the record row, then commits the attachment changes made in the editor.
    func save(id: UUID, title: String, date: Date, category: String, notes: String,
              attachments: AttachmentController) async throws {
        let trimmedTitle = title.trimmed
        guard !trimmedTitle.isEmpty else { throw AppError("Please enter a title.") }
        guard trimmedTitle.count <= 200 else { throw AppError("The title is too long.") }
        guard category.trimmed.count <= 100 else { throw AppError("The category is too long.") }
        guard userId != nil else { throw AppError("You need to be logged in.") }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let record = MedicalInformation(id: id, title: trimmedTitle, date: date,
                                        category: category.trimmed, notes: notes.trimmed)
        do {
            try await supabase.from(Table.medicalRecords)
                .upsert(record, onConflict: "id", returning: .minimal)
                .execute()
            try await attachments.commit()
        } catch {
            throw AppError(ErrorMessages.message(for: error))
        }
        await reload()
    }

    // MARK: - Delete

    func delete(_ record: MedicalInformation) {
        guard let uid = userId else { return }
        records.removeAll { $0.id == record.id }
        Task {
            do {
                let paths = record.attachments.map(\.storagePath)
                if !paths.isEmpty {
                    _ = try await supabase.storage.from(Bucket.medicalRecords).remove(paths: paths)
                }
                // Attachment rows are removed by ON DELETE CASCADE.
                try await supabase.from(Table.medicalRecords).delete(returning: .minimal).eq("id", value: record.id).execute()
            } catch {
                guard userId == uid else { return }
                errorMessage = ErrorMessages.message(for: error)
                await reload()
            }
        }
    }
}
