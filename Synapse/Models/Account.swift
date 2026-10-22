//
//  User.swift
//  Synapse
//
//  Created by Mac-LAB on 9/10/26.
//

import Foundation

struct SignInModel {
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil
}

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
    
    // Global Submission State
    var isLoading: Bool = false
    var submissionError: String? = nil
    var isVerifiedByFirebase: Bool = false 
}
