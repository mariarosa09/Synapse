//
//  OTPPurpose.swift
//  Synapse
//
//  What a one-time email code is being used for. Maps to Supabase's email OTP types.
//

import Foundation
import Supabase

nonisolated enum OTPPurpose: Sendable, Hashable {
    /// Confirming a brand-new account (Supabase "Confirm signup" email).
    case signup
    /// Confirming a new address for an existing account (Supabase "Change email address" email).
    case emailChange

    var verifyType: EmailOTPType {
        switch self {
        case .signup: return .signup
        case .emailChange: return .emailChange
        }
    }

    var resendType: ResendEmailType {
        switch self {
        case .signup: return .signup
        case .emailChange: return .emailChange
        }
    }
}
