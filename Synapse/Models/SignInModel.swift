//
//  SignInModel.swift
//  Synapse
//
//  Form state for the Login screen.
//

import Foundation

struct SignInModel {
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil
}
