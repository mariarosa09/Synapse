//
//  CreateAccountController.swift
//  Synapse
//
//  Validates the sign-up form and registers the user with Supabase Auth. Supabase then emails
//  a one-time verification code (see supabase/SETUP.md for the "Confirm signup" template).
//  The profile row is created by the database trigger from the metadata sent here.
//

import Foundation
import Supabase

@MainActor
@Observable
final class CreateAccountController {
    var model = CreateAccountModel()

    var normalizedEmail: String { model.email.trimmed.lowercased() }

    func createAccount() async {
        // Run full evaluation pass before trying to contact the network.
        guard validateAllFields() else { return }

        model.isLoading = true
        model.submissionError = nil
        model.awaitingVerification = false
        defer { model.isLoading = false }

        do {
            let metadata: [String: AnyJSON] = [
                "firstname": .string(model.firstname.trimmed),
                "middle_initial": .string(model.mi.trimmed),
                "surname": .string(model.surname.trimmed)
            ]
            let response = try await supabase.auth.signUp(email: normalizedEmail, password: model.password, data: metadata)

            if response.session != nil {
                // Email confirmation is turned off in this Supabase project: the session routes the app on its own.
                return
            }
            // Supabase hides whether an address is registered: an existing user comes back with no identities.
            if let identities = response.user.identities, identities.isEmpty {
                model.submissionError = "That email address is already registered. Please log in instead."
                return
            }
            model.awaitingVerification = true
        } catch {
            model.submissionError = ErrorMessages.message(for: error)
        }
    }

    // MARK: - Interactive input validation

    func validateFirstname(_ value: String) {
        model.validFirstname = !value.trimmed.isEmpty
    }

    func validateSurname(_ value: String) {
        model.validSurname = !value.trimmed.isEmpty
    }

    func validateEmail(_ value: String) {
        model.validEmail = value.isValidEmail
    }

    func validatePassword(_ text: String) {
        if text.isEmpty {
            model.passwordErrorMessage = ""
            model.isPasswordValid = true
            return
        }
        if let problem = PasswordRules.validate(text) {
            model.isPasswordValid = false
            model.passwordErrorMessage = problem
        } else {
            model.isPasswordValid = true
            model.passwordErrorMessage = ""
        }
    }

    func validateRepassword(_ value: String) {
        model.isRepasswordValid = value.isEmpty || value == model.password
    }

    /// Final explicit check before submitting.
    private func validateAllFields() -> Bool {
        isFormValidToSubmit()
    }

    func isFormValidToSubmit() -> Bool {
        validateFirstname(model.firstname)
        validateSurname(model.surname)
        validateEmail(model.email)
        validatePassword(model.password)
        model.isRepasswordValid = !model.repassword.isEmpty && model.repassword == model.password

        let fieldsNotEmpty = !model.firstname.trimmed.isEmpty &&
                             !model.surname.trimmed.isEmpty &&
                             !model.email.isEmpty &&
                             !model.password.isEmpty &&
                             !model.repassword.isEmpty

        if model.password.isEmpty {
            model.isPasswordValid = false
            model.passwordErrorMessage = "Please enter a password."
        }

        return fieldsNotEmpty &&
               model.validFirstname &&
               model.validSurname &&
               model.validEmail &&
               model.isPasswordValid &&
               model.isRepasswordValid
    }
}
