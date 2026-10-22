//
//  VerifyEmail.swift
//  Synapse
//
//  Created by Mac-LAB on 10/15/26.
//

import SwiftUI


struct VerifyEmailView: View {
    var controller: CreateAccountController
    @Environment(SessionController.self) private var session
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.myDarkBlue)
                    .padding(.trailing, 5)
                    .offset(x: -150, y: -140)
            }
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 60))
                .foregroundColor(Color.myDarkBlue)
            
            Text("Verify your Email")
                .font(.custom("Graduate", size: 25))
                .bold()
            
            Text("We sent a verification link to your email address. Please click it to continue.")
                .font(.custom("DM Sans", size: 16))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if let error = controller.model.submissionError {
                Text(error)
                    .font(.custom("DM Sans", size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 50)
            
            Button(action: {
                Task {
                    await controller.checkEmailVerificationStatus()
                    if controller.model.isVerifiedByFirebase {
                        // The session sees the verified user and moves on to "Tell Us About You".
                        await session.refresh()
                    }
                }
            }) {
                if controller.model.isLoading {
                    ProgressView()
                } else {
                    Text("I HAVE VERIFIED MY EMAIL")
                        .font(.custom("DM Sans", size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.myDarkBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 30)
            Button {
                Task { await controller.resendVerificationEmail() }
            } label: {
                Text("RESEND VERIFICATION EMAIL")
                    .font(.custom("DM Sans", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(Color.myDarkBlue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.myLightBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.myDarkBlue, lineWidth: 1))
                    .padding(.horizontal, 30)
            }

        }
        .toolbar(.hidden, for: .navigationBar)
    }
}


#Preview {
    VerifyEmailView(controller: CreateAccountController())
        .environment(SessionController())
}
