//
//  CreateAccount.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//

import SwiftUI

// Main View for Create Account Screen
struct CreateAccount: View {
    var body: some View {
        VStack {
            CreateAccountHeading()
            
            Spacer().frame(height: 10)
            
            CreateAccountInputs()
            
            Spacer()
        }
        .padding(30)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// Heading of the Create Account
struct CreateAccountHeading: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack (alignment: .top) {
            VStack (alignment: .leading) {
                Spacer().frame(height: 40)
                HStack (alignment: .center) {
                    Button(action: {dismiss()}) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(Color.myDarkBlue)
                            .padding(.trailing, 5)
                    }
                    Text("Create Account")
                        .font(Font.custom("Graduate", size: 24))
                        
                    Spacer()
                }
                
                Spacer().frame(height: 10)
                Text("Fill in your details to get started")
                    .font(.custom("DM Sans", size: 14))
                    .foregroundStyle(.gray)
                    .padding(.bottom, 30)

            }
            Logo()
        }
    }
}

// Input Section of the create account
struct CreateAccountInputs: View {
    @State private var controller = CreateAccountController()
    
    var body: some View {
        VStack {
            HStack {
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
                errorMessage: "Please enter a valid email address."
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
                    .font(.caption)
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
    @State private var navigateToVerifyEmail = false
    
    var body: some View {
        VStack {
            Button(action: {
                if controller.isFormValidToSubmit() {
                    showTermsSheet = true
                } else {
                    print("--- VALIDATION FAILED ---")
                            print("Firstname valid: \(controller.model.validFirstname) (Value: '\(controller.model.firstname)')")
                            print("Surname valid:   \(controller.model.validSurname) (Value: '\(controller.model.surname)')")
                            print("Email valid:     \(controller.model.validEmail) (Value: '\(controller.model.email)')")
                            print("Password valid:  \(controller.model.isPasswordValid) (Value: '\(controller.model.password)')")
                            print("Re-enter valid:  \(controller.model.isRepasswordValid) (Value: '\(controller.model.repassword)')")
                }
            }) {
                if controller.model.isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("CREATE ACCOUNT")
                        .font(.custom("DM Sans", size: 16))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 50)
                        .frame(maxWidth: .infinity)
                }
            }
            .background(Color.myDarkBlue)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .disabled(controller.model.isLoading) // Disable button during networking
            .navigationDestination(isPresented: $navigateToVerifyEmail) {
                VerifyEmailView(controller: controller)
            }
            .sheet(isPresented: $showTermsSheet) {
                TermsAndConditionsSheet(
                    isPresented: $showTermsSheet,
                    onAccept: {
                        showTermsSheet = false
                        
                        Task {
                            await controller.createAccount()
                            if let error = controller.model.submissionError {
                                print("--- NAVIGATION BLOCKED BY FIREBASE ERROR ---")
                                print("Firebase Error Message: \(error)")
                            } else {
                                print("--- SUCCESS: Navigating to AboutYou ---")
                                performPreNavigationSetup()
                                navigateToVerifyEmail = true
                            }
                        }
                    }
                )
            }
        }
    }
    
    private func performPreNavigationSetup() {
        print("Executing custom logic block...")
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
                        .font(.custom("DM Sans", size: 11))
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
                    .font(.custom("DM Sans", size: 14))
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("I Agree") {
                        isPresented = false
                        onAccept()
                    }
                    .font(.custom("DM Sans", size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(Color.myDarkBlue)
                }
            }
        }
    }
    
    private func groupHeader(_ text: String) -> some View {
        Text(text)
            .font(.custom("DM Sans", size: 12))
            .fontWeight(.bold)
            .foregroundColor(Color.myDarkBlue)
    }
    
    private func groupBody(_ text: String) -> some View {
        Text(text)
            .font(.custom("DM Sans", size: 12))
            .foregroundColor(.primary)
            .lineSpacing(3)
    }
}

#Preview {
    CreateAccount()
}
