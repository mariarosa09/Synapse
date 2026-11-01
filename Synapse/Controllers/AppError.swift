//
//  AppError.swift
//  Synapse
//
//  App-level error type and translation of Supabase errors into messages a person can act on.
//

import Foundation
import Supabase

struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum ErrorMessages {
    static func message(for error: Error) -> String {
        if let app = error as? AppError { return app.message }

        if let auth = error as? AuthError {
            switch auth.errorCode {
            case .invalidCredentials, .userNotFound:
                return "Incorrect email or password."
            case .emailNotConfirmed:
                return "Please verify your email with the code we sent you."
            case .emailExists, .userAlreadyExists:
                return "That email address is already in use."
            case .weakPassword:
                return "That password is too weak. " + auth.message
            case .samePassword:
                return "Choose a password different from the current one."
            case .otpExpired:
                return "That code is invalid or has expired. Check the latest email or tap Resend Code."
            case .overEmailSendRateLimit:
                return "Too many emails were sent. Please wait a minute before requesting another code."
            case .overRequestRateLimit:
                return "Too many attempts. Please wait a moment and try again."
            case .validationFailed:
                return auth.message.isEmpty ? "Please check the details you entered." : auth.message
            case .sessionNotFound, .sessionExpired, .refreshTokenNotFound, .refreshTokenAlreadyUsed:
                return "Your session expired. Please log in again."
            case .userBanned:
                return "This account has been disabled."
            case .reauthenticationNeeded:
                return "Please log in again before making this change."
            default:
                return auth.message
            }
        }

        if let storage = error as? StorageError {
            if storage.statusCode == "413" || storage.message.localizedCaseInsensitiveContains("exceeded") {
                return "That file is too large."
            }
            if storage.statusCode == "404" || storage.message.localizedCaseInsensitiveContains("not found") {
                return "The file could not be found. It may have been deleted."
            }
            if storage.statusCode == "403" || storage.message.localizedCaseInsensitiveContains("row-level security") {
                return "You don't have permission to access that file."
            }
            return storage.message
        }

        if let postgrest = error as? PostgrestError {
            if postgrest.code == "42501" { return "You don't have permission to change that data." }
            if postgrest.code == "23514" { return "Some of the values aren't allowed. Please check the form." }
            return postgrest.message
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "No internet connection. Please try again."
            case .timedOut:
                return "The server took too long to respond. Please try again."
            default:
                return urlError.localizedDescription
            }
        }

        return error.localizedDescription
    }

    static func isEmailNotConfirmed(_ error: Error) -> Bool {
        (error as? AuthError)?.errorCode == .emailNotConfirmed
    }

    /// True when the stored session can no longer be used (token revoked, user removed...).
    static func isSessionInvalid(_ error: Error) -> Bool {
        guard let auth = error as? AuthError else { return false }
        if case .sessionMissing = auth { return true }
        return [.sessionNotFound, .sessionExpired, .refreshTokenNotFound, .refreshTokenAlreadyUsed,
                .userNotFound, .userBanned, .badJWT].contains(auth.errorCode)
    }
}
