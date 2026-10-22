//
//  Authentication.swift
//  Synapse
//
//  Created by Mac-LAB on 9/24/26.
//

import Foundation
import FirebaseAuth
import Firebase

@MainActor
@Observable
final class CreateAccountController {
    var model = CreateAccountModel()
    private let db = Firestore.firestore()
    
    // Core submission function
    func createAccount() async {
        // Run full evaluation pass before trying to contact network
        guard validateAllFields() else { return }
        
        model.isLoading = true
        model.submissionError = nil
        
        do {
            // 1. Write user credentials to Firebase Auth
            let authResult = try await Auth.auth().createUser(
                withEmail: model.email,
                password: model.password
            )
            let user = authResult.user
            let uid = user.uid
            
            try await user.sendEmailVerification()
            print("Verification email cleanly dispatched.")
            
            // 2. Put user name components into Firestore document named after their UID
            let userData: [String: Any] = [
                "uid": uid,
                "firstname": model.firstname.trimmingCharacters(in: .whitespacesAndNewlines),
                "middleInitial": model.mi.trimmingCharacters(in: .whitespacesAndNewlines),
                "surname": model.surname.trimmingCharacters(in: .whitespacesAndNewlines),
                "email": model.email.trimmingCharacters(in: .whitespacesAndNewlines),
                "createdAt": FieldValue.serverTimestamp(),
                "onboardingComplete": false,
                "deleted": false
            ]
            
            try await db.collection("users").document(uid).setData(userData)
            print("Successfully authenticated and populated Firestore user metadata profile.")
            
        } catch {
            print("Firebase Account Generation Failure: \(error.localizedDescription)")
            model.submissionError = error.localizedDescription
        }
        
        model.isLoading = false
    }
    
    // Interactive Input Monitoring Logic
    func validateFirstname(_ value: String) {
        model.validFirstname = !value.isEmpty
    }
    
    func validateSurname(_ value: String) {
        model.validSurname = !value.isEmpty
    }
    
    func validateEmail(_ value: String) {
        model.validEmail = value.contains("@") && value.contains(".")
    }
    
    func validatePassword(_ text: String) {
        if text.isEmpty {
            model.passwordErrorMessage = ""
            model.isPasswordValid = true
            return
        }
       
        var missingRequirements: [String] = []
       
        if text.count < 8 {
            missingRequirements.append("at least 8 characters")
        }
        if !text.contains(where: { $0.isUppercase }) {
            missingRequirements.append("an uppercase letter")
        }
        if !text.contains(where: { $0.isLowercase }) {
            missingRequirements.append("a lowercase letter")
        }
        let specialCharacterSet = CharacterSet.alphanumerics.inverted
        if text.rangeOfCharacter(from: specialCharacterSet) == nil {
            missingRequirements.append("a special character")
        }
       
        if missingRequirements.isEmpty {
            model.isPasswordValid = true
            model.passwordErrorMessage = ""
        } else {
            model.isPasswordValid = false
            model.passwordErrorMessage = "Password needs: " + missingRequirements.joined(separator: ", ") + "."
        }
    }
    
    func validateRepassword(_ value: String) {
        if value.isEmpty {
            model.isRepasswordValid = true
        } else {
            model.isRepasswordValid = (value == model.password)
        }
    }

    
    // Final explicit check before submitting to Firestore
    private func validateAllFields() -> Bool {
        validateFirstname(model.firstname)
        validateSurname(model.surname)
        validateEmail(model.email)
        validatePassword(model.password)
        validateRepassword(model.repassword)
        
        return model.validFirstname &&
               model.validSurname &&
               model.validEmail &&
               model.isPasswordValid &&
               model.isRepasswordValid &&
               !model.firstname.isEmpty &&
               !model.surname.isEmpty
    }
    
    func isFormValidToSubmit() -> Bool {
        validateFirstname(model.firstname)
        validateSurname(model.surname)
        validateEmail(model.email)
        validatePassword(model.password)
        
        if model.repassword.isEmpty {
            model.isRepasswordValid = false
        } else {
            model.isRepasswordValid = (model.repassword == model.password)
        }
        
        let fieldsNotEmpty = !model.firstname.isEmpty &&
                             !model.surname.isEmpty &&
                             !model.email.isEmpty &&
                             !model.password.isEmpty &&
                             !model.repassword.isEmpty
                             
        let togglesAreValid = model.validFirstname &&
                              model.validSurname &&
                              model.validEmail &&
                              model.isPasswordValid &&
                              model.isRepasswordValid
                              
        return fieldsNotEmpty && togglesAreValid
    }
    
    func checkEmailVerificationStatus() async {
            guard let currentUser = Auth.auth().currentUser else { return }
            
            model.isLoading = true
            model.submissionError = nil
            
            do {
                // 1. Force Firebase client to sync with the server
                try await currentUser.reload()
                
                // 2. Evaluate fresh status flag
                if currentUser.isEmailVerified {
                    print("User successfully verified their email!")
                    model.isVerifiedByFirebase = true
                    
                    // 3. Update Firestore flag to match if desired
                    let db = Firestore.firestore()
                    try await db.collection("users").document(currentUser.uid).updateData([
                        "isEmailVerified": true
                    ])
                } else {
                    model.submissionError = "Email is not verified yet. Please check your inbox."
                }
            } catch {
                model.submissionError = error.localizedDescription
            }
            
            model.isLoading = false
        }

    func resendVerificationEmail() async {
        guard let currentUser = Auth.auth().currentUser else { return }
        model.submissionError = nil
        do {
            try await currentUser.sendEmailVerification()
        } catch {
            model.submissionError = AuthMessages.message(for: error)
        }
    }
}

// MARK: - Login

@MainActor
@Observable
final class LoginController {
    var model = SignInModel()
    var infoMessage: String? = nil

    /// Signs in with Firebase Auth. On success SessionController reacts to the auth change and swaps the screen.
    func signIn(email: String, password: String) async {
        model.errorMessage = nil
        infoMessage = nil
        let trimmedEmail = email.trimmed
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            model.errorMessage = "Please enter a valid email address."
            return
        }
        guard !password.isEmpty else {
            model.errorMessage = "Please enter your password."
            return
        }

        model.isLoading = true
        defer { model.isLoading = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
            if !result.user.isEmailVerified {
                try? await result.user.sendEmailVerification()
                try? Auth.auth().signOut()
                model.errorMessage = "Please verify your email first. We just sent you a new verification link."
            }
        } catch {
            model.errorMessage = AuthMessages.message(for: error)
        }
    }

    func sendPasswordReset(email: String) async {
        model.errorMessage = nil
        infoMessage = nil
        let trimmedEmail = email.trimmed
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            model.errorMessage = "Enter your email address above, then tap Forgot Password."
            return
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
            infoMessage = "If an account exists for \(trimmedEmail), a password reset link is on its way."
        } catch {
            model.errorMessage = AuthMessages.message(for: error)
        }
    }
}
