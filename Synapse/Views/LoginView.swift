//
//  LoginView.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//
//  Email + password login through Supabase Auth (LoginController), plus "Continue with 
//  Google". Accounts that haven't verified their email are sent a fresh code and taken to the
//  OTP screen.
//

import SwiftUI
import UIKit

struct LoginView: View {
    @Environment(SessionController.self) private var session
    @State private var controller = LoginController()
    @State private var email: String = ""
    @State private var validEmail: Bool = true
    @State private var password: String = ""
    @State private var passwordErrorMessage: String = ""
    @State private var isPasswordValid: Bool = true

    var body: some View {
        ScrollView {
            VStack {
                LoginHeading()

                Input(
                    title: "EMAIL",
                    logoName: "envelope.fill",
                    text: $email,
                    isValid: $validEmail,
                    errorMessage: "Please enter a valid email address.",
                    keyboard: .emailAddress
                )
                .onChange(of: email) { _, newValue in
                    validEmail = newValue.isEmpty || newValue.isValidEmail
                }

                Spacer().frame(height: 20)

                Input(
                    title: "PASSWORD",
                    logoName: "lock.fill",
                    text: $password,
                    isValid: $isPasswordValid,
                    errorMessage: passwordErrorMessage
                )
                .onChange(of: password) { _, newValue in
                    validatePassword(newValue)
                }

                ForgotPassword(email: email)
                    .padding(.top, 8)

                FormMessages(error: controller.model.errorMessage ?? session.notice,
                             success: controller.infoMessage)
                    .padding(.top, 10)

                Spacer().frame(height: 24)
                PrimaryActionButton(title: "LOG IN", isWorking: controller.model.isLoading,
                                    enabled: controller.socialInProgress == nil) {
                    session.notice = nil
                    Task { await controller.signIn(email: email, password: password) }
                }

                SocialLoginSection(controller: controller) { provider in
                    session.notice = nil
                    Task { await controller.signIn(with: provider) }
                }
                .padding(.top, 20)

                CreateAccountLink()
                    .padding(.top, 16)
            }
            .padding(30)
        }
        .scrollBounceBehavior(.basedOnSize)
        .toolbar(.hidden, for: .navigationBar)
        // Unverified account: finish verification with the emailed code.
        .navigationDestination(item: $controller.verificationEmail) { address in
            OTPVerificationView(email: address, purpose: .signup)
        }
    }

    private func validatePassword(_ text: String) {
        if text.isEmpty {
            passwordErrorMessage = ""
            isPasswordValid = true
        } else if let problem = PasswordRules.validate(text) {
            isPasswordValid = false
            passwordErrorMessage = problem
        } else {
            isPasswordValid = true
            passwordErrorMessage = ""
        }
    }
}

struct LoginHeading: View {
    var body: some View {
        VStack(alignment: .leading) {
            Logo()

            Text("Welcome!")
                .font(.synHero)
                .foregroundStyle(.primary)
                .padding(.vertical, 10)

            Text("Login to track your\nMedical Information with Synapse")
                .font(.synBody)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "or continue with" divider plus the Apple and Google buttons, side by side.
struct SocialLoginSection: View {
    var controller: LoginController
    let onSelect: (LoginController.SocialProvider) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.myDarkBlue.opacity(0.3)).frame(height: 1)
                Text("or continue with")
                    .font(.synCaption)
                    .foregroundStyle(.gray)
                    .fixedSize()
                Rectangle().fill(Color.myDarkBlue.opacity(0.3)).frame(height: 1)
            }

            HStack(spacing: 12) {
                socialButton(.google) {
                    GoogleLogo()
                }
            }
        }
    }

    /// Plain white button with a dark-blue border and black text.
    private func socialButton<Icon: View>(_ provider: LoginController.SocialProvider,
                                          @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            onSelect(provider)
        } label: {
            HStack(spacing: 8) {
                if controller.socialInProgress == provider {
                    ProgressView().tint(.black)
                } else {
                    icon()
                        .frame(width: 20, height: 20)
                    Text(provider.title)
                        .font(.synButton)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.myDarkBlue, lineWidth: 1))
        }
        .disabled(controller.isBusy)
        .opacity(controller.isBusy && controller.socialInProgress != provider ? 0.5 : 1)
        .accessibilityLabel("Continue with \(provider.title)")
    }
}

/// Google's official "G" logo from Assets.xcassets → GoogleLogo (add the file Google provides in
/// its sign-in branding guidelines). Until that file is added, a plain "G" symbol is shown instead.
struct GoogleLogo: View {
    var body: some View {
        if UIImage(named: "GoogleLogo") != nil {
            Image("GoogleLogo")
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "g.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black)
        }
    }
}

struct ForgotPassword: View {
    let email: String

    var body: some View {
        HStack {
            Spacer()
            NavigationLink {
                ForgotPasswordView(email: email)
            } label: {
                Text("Forgot Password?")
                    .font(.synLabel)
                    .foregroundColor(.myDarkBlue)
            }
        }
    }
}

struct CreateAccountLink: View {
    var body: some View {
        NavigationLink {
            CreateAccountView()
        } label: {
            Text("New here? Create an Account")
                .font(.synCaption)
                .foregroundColor(.myDarkBlue)
        }
    }
}

#Preview {
    NavigationStack { LoginView() }
        .environment(SessionController())
}
