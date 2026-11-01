//
//  CreateAccountModel.swift
//  Synapse
//
//  Form state for the Create Account screen.
//

import Foundation

struct CreateAccountModel {
    // Input properties
    var firstname: String = ""
    var mi: String = ""
    var surname: String = ""
    var email: String = ""
    var password: String = ""
    var repassword: String = ""

    // Validation tracks
    var validFirstname: Bool = true
    var validMI: Bool = true
    var validSurname: Bool = true
    var validEmail: Bool = true
    var isPasswordValid: Bool = true
    var isRepasswordValid: Bool = true
    var passwordErrorMessage: String = ""

    // Submission state
    var isLoading: Bool = false
    var submissionError: String? = nil
    /// Set once Supabase has accepted the sign-up and emailed a verification code.
    var awaitingVerification: Bool = false
}
