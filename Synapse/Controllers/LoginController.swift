//
//  LoginController.swift
//  Synapse
//
//  Logs in with Supabase Auth: email + password, or Google / Apple. On success SessionController
//  reacts to the auth change and swaps the screen. Unverified email accounts are sent a fresh OTP
//  and routed to the code screen.
//
//  Google and Apple use Supabase's OAuth flow in a secure in-app web sheet
//  (ASWebAuthenticationSession), so no extra SDK is needed. Each provider must be enabled in
//  Supabase (see supabase/SETUP.md, "Google and Apple sign-in").
//

import Foundation
import AuthenticationServices
import Supabase

@MainActor
@Observable
final class LoginController {
    enum SocialProvider: String, Identifiable {
        case apple, google
        var id: String { rawValue }
        var title: String { self == .apple ? "Apple" : "Google" }
        var supabaseProvider: Provider { self == .apple ? .apple : .google }
    }

    var model = SignInModel()
    var infoMessage: String? = nil
    /// Set when the account still needs its email verified; the Login screen then opens the OTP screen.
    var verificationEmail: String? = nil
    /// The provider whose sign-in sheet is open, if any.
    var socialInProgress: SocialProvider? = nil

    var isBusy: Bool { model.isLoading || socialInProgress != nil }

    func signIn(email: String, password: String) async {
        model.errorMessage = nil
        infoMessage = nil
        let trimmedEmail = email.trimmed.lowercased()
        guard trimmedEmail.isValidEmail else {
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
            try await supabase.auth.signIn(email: trimmedEmail, password: password)
        } catch {
            if ErrorMessages.isEmailNotConfirmed(error) {
                // Send a new code and let the user finish verifying.
                do {
                    try await supabase.auth.resend(email: trimmedEmail, type: .signup)
                } catch {
                    // A rate-limit error still means a recent code exists; continue to the code screen.
                    print("Resend before verification failed: \(ErrorMessages.message(for: error))")
                }
                verificationEmail = trimmedEmail
            } else {
                model.errorMessage = ErrorMessages.message(for: error)
            }
        }
    }

    /// "Continue with Google / Apple". New users get a profile from the provider's name and email,
    /// then continue to "Tell Us About You"; returning users go straight to Home.
    func signIn(with provider: SocialProvider) async {
        guard !isBusy else { return }
        model.errorMessage = nil
        infoMessage = nil
        socialInProgress = provider
        defer { socialInProgress = nil }
        do {
            _ = try await supabase.auth.signInWithOAuth(
                provider: provider.supabaseProvider,
                redirectTo: SupabaseConfig.authRedirectURL,
                scopes: provider == .apple ? "name email" : nil
            )
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // The user closed the sheet; nothing to report.
        } catch {
            let message = ErrorMessages.message(for: error)
            if message.localizedCaseInsensitiveContains("provider is not enabled")
                || message.localizedCaseInsensitiveContains("unsupported provider") {
                model.errorMessage = "\(provider.title) sign-in isn't set up yet. Please use your email and password."
            } else {
                model.errorMessage = "\(provider.title) sign-in failed: \(message)"
            }
        }
    }
}
