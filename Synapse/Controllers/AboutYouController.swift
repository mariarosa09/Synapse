//
//  AboutYouController.swift
//  Synapse
//
//  Onboarding ("Tell Us About You"): collects personal details, allergies and medical
//  conditions, saves them to Supabase and marks onboarding complete.
//

import SwiftUI
import Supabase

@Observable
@MainActor
final class AboutYouController {
    var selectedSex: Sex? = nil
    var selectedBlood: Blood? = nil
    var birthdate: Date = .now
    var allergies: [BasicInformationModel] = []
    var medicalConditions: [BasicInformationModel] = []
    var isSaving = false
    var errorMessage: String?

    func addAllergy(title: String, startDate: Date) {
        let trimmed = title.trimmed
        guard !trimmed.isEmpty else { return }
        allergies.append(BasicInformationModel(kind: .allergy, title: trimmed, startDate: startDate))
    }

    func addMedicalCondition(title: String, startDate: Date) {
        let trimmed = title.trimmed
        guard !trimmed.isEmpty else { return }
        medicalConditions.append(BasicInformationModel(kind: .condition, title: trimmed, startDate: startDate))
    }

    func remove(_ entry: BasicInformationModel) {
        allergies.removeAll { $0.id == entry.id }
        medicalConditions.removeAll { $0.id == entry.id }
    }

    private func validationError() -> String? {
        if selectedSex == nil { return "Please select your sex." }
        if selectedBlood == nil { return "Please select your blood group." }
        if birthdate >= Calendar.current.startOfDay(for: .now) { return "Please choose your birthdate." }
        return nil
    }

    /// Saves the entries first, then flips `onboarding_complete`, then lets the session move to Home.
    /// Entries are upserted by id, so pressing the button again after a failure never duplicates them.
    func saveAndContinue(session: SessionController) async {
        if let message = validationError() {
            errorMessage = message
            return
        }
        guard let uid = session.userID, let sex = selectedSex, let blood = selectedBlood else {
            errorMessage = "You need to be logged in."
            return
        }
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let entries = allergies + medicalConditions
            if !entries.isEmpty {
                try await supabase.from(Table.basicInformation)
                    .upsert(entries, onConflict: "id", returning: .minimal)
                    .execute()
            }
            let profileUpdate: [String: AnyJSON] = [
                "sex": .string(sex.name),
                "blood_group": .string(blood.name),
                "birthdate": .string(DBDate.dayString(birthdate)),
                "onboarding_complete": .bool(true)
            ]
            try await supabase.from(Table.profiles)
                .update(profileUpdate, returning: .minimal)
                .eq("id", value: uid)
                .execute()
            await session.reloadProfile()
        } catch {
            errorMessage = ErrorMessages.message(for: error)
        }
    }
}
