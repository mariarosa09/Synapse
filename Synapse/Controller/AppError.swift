//
//  AppError.swift
//  Synapse
//

import Foundation
import FirebaseAuth

struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Turns Firebase Auth errors into messages a person can act on.
enum AuthMessages {
    static func message(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == "FIRAuthErrorDomain", let code = AuthErrorCode(rawValue: nsError.code) else {
                    return error.localizedDescription
        }
        switch code {
        case .wrongPassword, .invalidCredential, .userNotFound:
            return "Incorrect email or password."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .emailAlreadyInUse:
            return "That email address is already in use."
        case .weakPassword:
            return "That password is too weak."
        case .networkError:
            return "No internet connection. Please try again."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        case .requiresRecentLogin:
            return "Please log in again before making this change."
        case .userDisabled:
            return "This account has been disabled."
        default:
            return error.localizedDescription
        }
    }

    /// True when the stored session can no longer be used (token revoked, user removed...).
    static func isSessionInvalid(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == "FIRAuthErrorDomain", let code = AuthErrorCode(rawValue: nsError.code) else { return false }
        switch code {
        case .userTokenExpired, .invalidUserToken, .userNotFound, .userDisabled: return true
        default: return false
        }
    }
}
