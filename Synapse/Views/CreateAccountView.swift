//
//  CreateAccountView.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//
//  Registration form. After the Terms are accepted, CreateAccountController signs the user up
//  with Supabase Auth, which emails a one-time code; the OTP screen then verifies it.
//

import SwiftUI

struct CreateAccountView: View {
    @State private var controller = CreateAccountController()

    var body: some View {
        ScrollView {
            VStack {
                AuthHeading(title: "Create Account", subtitle: "Fill in your details to get started")

                Spacer().frame(height: 10)

                CreateAccountInputs(controller: controller)

                Spacer()
            }
            .padding(30)
        }
        .scrollBounceBehavior(.basedOnSize)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $controller.model.awaitingVerification) {
            OTPVerificationView(email: controller.normalizedEmail, purpose: .signup)
        }
    }
}

struct CreateAccountInputs: View {
    @Bindable var controller: CreateAccountController

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Input(
                    title: "FIRSTNAME*",
                    logoName: "",
                    text: $controller.model.firstname,
                    isValid: $controller.model.validFirstname,
                    errorMessage: "First name is required"
                )
                .onChange(of: controller.model.firstname) { _, newValue in
                    controller.validateFirstname(newValue)
                }

                Input(
                    title: "MI",
                    logoName: "",
                    text: $controller.model.mi,
                    isValid: $controller.model.validMI,
                    errorMessage: ""
                )
                .frame(maxWidth: 70)
            }

            Spacer().frame(height: 20)

            Input(
                title: "SURNAME*",
                logoName: "",
                text: $controller.model.surname,
                isValid: $controller.model.validSurname,
                errorMessage: "Surname is required"
            )
            .onChange(of: controller.model.surname) { _, newValue in
                controller.validateSurname(newValue)
            }

            Spacer().frame(height: 20)

            Input(
                title: "EMAIL*",
                logoName: "",
                text: $controller.model.email,
                isValid: $controller.model.validEmail,
                errorMessage: "Please enter a valid email address.",
                keyboard: .emailAddress
            )
            .onChange(of: controller.model.email) { _, newValue in
                controller.validateEmail(newValue)
            }

            Spacer().frame(height: 20)

            Input(
                title: "PASSWORD*",
                logoName: "",
                text: $controller.model.password,
                isValid: $controller.model.isPasswordValid,
                errorMessage: controller.model.passwordErrorMessage
            )
            .onChange(of: controller.model.password) { _, newValue in
                controller.validatePassword(newValue)
                controller.validateRepassword(controller.model.repassword)
            }

            Spacer().frame(height: 20)

            Input(
                title: "RE-ENTER PASSWORD*",
                logoName: "",
                text: $controller.model.repassword,
                isValid: $controller.model.isRepasswordValid,
                errorMessage: "Re-entered password is incorrect"
            )
            .onChange(of: controller.model.repassword) { _, newValue in
                controller.validateRepassword(newValue)
            }

            Spacer().frame(height: 30)

            if let networkError = controller.model.submissionError {
                Text(networkError)
                    .font(.synCaption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
            }

            CreateAccountButton(controller: controller)
        }
    }
}

struct CreateAccountButton: View {
    var controller: CreateAccountController

    @State private var showTermsSheet = false

    var body: some View {
        PrimaryActionButton(title: "CREATE ACCOUNT", isWorking: controller.model.isLoading) {
            if controller.isFormValidToSubmit() {
                showTermsSheet = true
            }
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsAndConditionsSheet(isPresented: $showTermsSheet) {
                showTermsSheet = false
                // On success the controller sets `awaitingVerification`, which opens the OTP screen.
                Task { await controller.createAccount() }
            }
        }
    }
}

struct TermsAndConditionsSheet: View {
    @Binding var isPresented: Bool
    var onAccept: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Please read these Terms and Conditions carefully before using the App. By creating an account, you agree to be bound by these Terms.")
                        .font(.synLabel)
                        .foregroundColor(.primary)

                    groupHeader("1. Scope of Service: Storage & Scheduling Utilities")
                    groupBody("The App is designed and provided solely as a personal organization and digital utility tool. The features are strictly limited to:\n\n• Medical Record Storage: A passive digital repository for storing and organizing your historical medical files and notes.\n• Medication Intake Reminders: A tool allowing you to manually input schedules to trigger notifications for your medications.\n• Appointment Tracking: A digital calendar allowing you to manually log and track your scheduled healthcare appointments.\n\nThe App does not communicate with your doctors, pharmacies, or electronic health record (EHR) systems. Every record, reminder, and appointment must be entered manually by you.")

                    groupHeader("2. Strict No-Diagnosis & No-Prediction Clause")
                    groupBody("The App does not predict health outcomes, analyze symptoms, or make medical diagnoses of any kind. There are no clinical tools, artificial intelligence (AI), or algorithms built into this App to interpret your health data.\n\nNo Medical Advice: The information provided is for general knowledge, should not be taken as medical advice, and you should consult with a healthcare provider.")

                    groupHeader("3. Critical Emergency & System Failure Warning")
                    groupBody("This App must never be used or relied upon during a medical emergency. \n\nNotification Reliability: Medication reminders depend entirely on your device's operating system, battery life, and notification settings. You must not rely on the App as your sole method for taking critical, life-sustaining medications.")

                    groupHeader("4. User Data Accuracy & Responsibility")
                    groupBody("Because the App only acts on what you input, you are entirely responsible for the data inside your account. We do not verify the accuracy or validity of any medical records, dosage amounts, or appointment dates you log.")

                    groupHeader("5. Privacy and Security")
                    groupBody("We take the security of your stored medical records seriously. We use encryption to help protect your records, but no digital storage method is 100% secure. You are responsible for keeping your credentials safe.")

                    groupHeader("6. Limitation of Liability")
                    groupBody("To the maximum extent permitted by law, we shall not be liable for any direct, indirect, or incidental damages resulting from missed medication doses, incorrect dosages taken, missed appointments, or temporary inability to access your records.")
                }
                .padding()
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Decline") {
                        isPresented = false
                    }
                    .font(.synBody)
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("I Agree") {
                        onAccept()
                    }
                    .font(.synBody)
                    .fontWeight(.bold)
                    .foregroundColor(Color.myDarkBlue)
                }
            }
        }
    }

    private func groupHeader(_ text: String) -> some View {
        Text(text)
            .font(.synLabel)
            .fontWeight(.bold)
            .foregroundColor(Color.myDarkBlue)
    }

    private func groupBody(_ text: String) -> some View {
        Text(text)
            .font(.synLabel)
            .foregroundColor(.primary)
            .lineSpacing(3)
    }
}

#Preview {
    NavigationStack { CreateAccountView() }
        .environment(SessionController())
}
