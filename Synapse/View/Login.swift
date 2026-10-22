//
//  Login.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//

import SwiftUI


struct Login: View {
    @Environment(SessionController.self) private var session
    @State private var controller = LoginController()
    @State private var email: String = ""
    @State private var validEmail: Bool = true
    @State private var password: String = ""
   
    @State private var passwordErrorMessage: String = ""
    @State private var isPasswordValid: Bool = true
   
    var body: some View {
        VStack {
            
            LoginHeading()

            Input(
                title: "EMAIL",
                logoName: "envelope.fill",
                text: $email,
                isValid: $validEmail,
                errorMessage: "Please enter a valid email address."
            )
            .onChange(of: email) { _, newValue in
                validEmail = newValue.contains("@") && newValue.contains(".")
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
            
            ForgotPassword {
                Task { await controller.sendPasswordReset(email: email) }
            }

            if let message = controller.model.errorMessage ?? session.notice {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            if let info = controller.infoMessage {
                Text(info)
                    .font(.caption)
                    .foregroundColor(Color.myDarkBlue)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }

            Spacer().frame(height: 30)
            LoginButton(isLoading: controller.model.isLoading) {
                session.notice = nil
                Task { await controller.signIn(email: email, password: password) }
            }
            Spacer().frame(height: 5)
            CreateAccountLink()
            
            Spacer()
        }
        .padding(30)
        .toolbar(.hidden, for: .navigationBar)
    }
   
    private func validatePassword(_ text: String) {
        if text.isEmpty {
            passwordErrorMessage = ""
            isPasswordValid = true
            return
        }
       
        var missingRequirements: [String] = []
       
        if text.count < 8 {
            missingRequirements.append("at least 8 characters")
        }
        if !text.contains(where: { $0.isUppercase }) {
            missingRequirements.append("an uppercase letter")
        }
        if !text.contains(where: { $0.isLowercase }) {
            missingRequirements.append("a lowercase letter")
        }
        let specialCharacterSet = CharacterSet.alphanumerics.inverted
        if text.rangeOfCharacter(from: specialCharacterSet) == nil {
            missingRequirements.append("a special character")
        }
       
        if missingRequirements.isEmpty {
            isPasswordValid = true
            passwordErrorMessage = ""
        } else {
            isPasswordValid = false
            passwordErrorMessage = "Password needs: " + missingRequirements.joined(separator: ", ") + "."
        }
    }
}

struct LoginHeading: View {
    var body: some View {
        VStack (alignment: .leading) {
            Logo()

            Text("Welcome!")
                .font(.custom("Graduate", size: 30))
                .foregroundStyle(.primary)
                .padding(.vertical, 10)


            Text("Login to track your\nMedical Information with Synapse")
                .font(.custom("DM Sans", size: 14))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 60)
        }
    }
}


struct Input: View {
    let title: String?
    let logoName: String?
    @Binding var text: String
    @Binding var isValid: Bool
    let errorMessage: String

    @State private var isPasswordVisible: Bool = false
   
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let title = title {
                Text(title)
                    .font(.custom("DM Sans", size: 12))
            }
           
            HStack {
                if let logoName = logoName, !logoName.isEmpty {
                    Image(systemName: logoName)
                        .foregroundStyle(Color.myDarkBlue)
                        .font(.system(size: 20))
                        .padding(.trailing, 10)
                }

                if title?.contains("PASSWORD") == true {
                    if isPasswordVisible {
                        TextField("", text: $text)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("", text: $text)
                            .textInputAutocapitalization(.never)
                    }

                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(.myDarkBlue)
                            .font(.system(size: 20))
                    }
                } else {
                    TextField("", text: $text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .padding()
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isValid ? Color.myDarkBlue : Color.red, lineWidth: 1)
            )
           
            if !isValid {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ForgotPassword: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Text("Forgot Password?")
                    .font(.custom("DM Sans", size: 12))
                    .foregroundColor(.myDarkBlue)
            }
        }
    }
}

struct LoginButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("LOG IN")
                        .font(.custom("DM Sans", size: 16))
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 50)
            .frame(maxWidth: .infinity)
            .background(Color.myDarkBlue)
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .disabled(isLoading)
    }
}

struct CreateAccountLink: View {
    var body: some View {
        NavigationLink {
            CreateAccount()
        }
        label: {
            Text("New here? Create an Account")
                .font(.custom("DM Sans", size: 12))
                .foregroundColor(.myDarkBlue)
        }
    }
}

#Preview {
    Login()
        .environment(SessionController())
}
