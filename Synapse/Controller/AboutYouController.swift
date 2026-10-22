//
//  AboutYouController.swift
//  Synapse
//
//  Onboarding ("Tell Us About You"): collects personal details, allergies and medical
//  conditions, then saves everything to Firestore in one batch and marks onboarding complete.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

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

    private let db = Firestore.firestore()

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

    /// Saves everything atomically. When it succeeds the profile listener sees `onboardingComplete`
    /// and SessionController moves the app to the home screen.
    func saveAndContinue() async {
        if let message = validationError() {
            errorMessage = message
            return
        }
        guard let uid = Auth.auth().currentUser?.uid, let sex = selectedSex, let blood = selectedBlood else {
            errorMessage = "You need to be logged in."
            return
        }
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let userRef = db.collection("users").document(uid)
        let batch = db.batch()
        for entry in allergies + medicalConditions {
            batch.setData(entry.dictionary, forDocument: userRef.collection("basicInformation").document(entry.id.uuidString))
        }
        batch.setData([
            "sex": sex.name,
            "bloodGroup": blood.name,
            "birthdate": Timestamp(date: birthdate),
            "onboardingComplete": true
        ], forDocument: userRef, merge: true)

        do {
            try await batch.commit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
