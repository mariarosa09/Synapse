//
//  FormComponents.swift
//  Synapse
//
//  Small reusable controls shared by several screens: text inputs, pop-up fields, rows and
//  buttons, date pickers, filters, the search bar, swipe-action labels and the OTP code field.
//  All of them use the app's type scale (see Branding.swift) so sizes match everywhere.
//

import SwiftUI

// MARK: - Auth / account inputs

/// Labelled, outlined input used on the auth and account screens. Titles containing
/// "PASSWORD" become secure fields with a show / hide toggle.
struct Input: View {
    let title: String?
    let logoName: String?
    @Binding var text: String
    @Binding var isValid: Bool
    let errorMessage: String
    var keyboard: UIKeyboardType = .default

    @State private var isPasswordVisible: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                Text(title)
                    .font(.synLabel)
            }

            HStack {
                if let logoName = logoName, !logoName.isEmpty {
                    Image(systemName: logoName)
                        .foregroundStyle(Color.myDarkBlue)
                        .font(.system(size: 18))
                        .frame(width: 24)
                        .padding(.trailing, 6)
                }

                if title?.contains("PASSWORD") == true {
                    Group {
                        if isPasswordVisible {
                            TextField("", text: $text)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("", text: $text)
                        }
                    }
                    .font(.synBody)
                    .textInputAutocapitalization(.never)

                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(.myDarkBlue)
                            .font(.system(size: 18))
                    }
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                } else {
                    TextField("", text: $text)
                        .font(.synBody)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(keyboard)
                }
            }
            .padding()
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isValid ? Color.myDarkBlue : Color.red, lineWidth: 1)
            )

            if !isValid && !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.synCaption)
                    .foregroundColor(.red)
                    .padding(.leading, 5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Six-to-ten digit one-time code entry (pasting a code from Mail works too).
struct OTPCodeField: View {
    @Binding var code: String
    var maxLength: Int = 10

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VERIFICATION CODE")
                .font(.synLabel)
            HStack {
                Image(systemName: "number.square.fill")
                    .foregroundStyle(Color.myDarkBlue)
                    .font(.system(size: 18))
                    .frame(width: 24)
                    .padding(.trailing, 6)
                TextField("", text: $code, prompt: Text("Enter code").foregroundStyle(.gray.opacity(0.6)))
                    .font(.custom("DM Sans", size: 22))
                    .tracking(6)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onChange(of: code) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(maxLength))
                        if digits != value { code = digits }
                    }
            }
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.myDarkBlue, lineWidth: 1))
        }
        .onAppear { focused = true }
    }
}

// MARK: - Lists: search, filters, badges, empty states

/// Rounded search field matching the outlined inputs; filters lists as the user types.
/// Placed as the first element in the white area under a screen's header.
struct SearchBar: View {
    @Binding var text: String
    var prompt: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.myDarkBlue)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(.gray.opacity(0.7)))
                .font(.synBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.myDarkBlue.opacity(0.6))
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.myDarkBlue, lineWidth: 1))
        .padding(.horizontal, 30)
    }
}

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top) {
            Text(message)
                .font(.synCaption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.08)))
        .padding(.horizontal, 30)
    }
}

struct StatusBadge: View {
    let active: Bool

    var body: some View {
        Text(active ? "Active" : "Inactive")
            .font(.synLabel)
            .fontWeight(.semibold)
            .foregroundStyle(active ? Color.myDarkBlue : Color.gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(active ? Color.myLightBlue : Color.gray.opacity(0.15)))
    }
}

/// All / Active / Inactive selector.
struct UpperTab: View {
    @Binding var filter: StatusFilter
    var body: some View {
        HStack(spacing: 10) {
            ForEach(StatusFilter.allCases) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.title)
                        .font(.synSection)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(filter == option ? .white : Color.myDarkBlue)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(filter == option ? Color.myDarkBlue : Color.myLightBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.myDarkBlue, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 30)
    }
}

/// Centered gray message for empty lists and empty search results.
struct EmptyStateText: View {
    let message: String
    var systemImage: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 36))
                    .foregroundStyle(Color.myDarkBlue.opacity(0.35))
            }
            Text(message)
                .font(.synBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
        .padding(.horizontal, 30)
    }
}

/// "Label: value" line used by every list card (Medicines, Basic Information, Medical Records).
struct InfoRow: View {
    let label: String
    let value: String
    var lineLimit: Int? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.synBody)
                .fontWeight(.semibold)
            Text(value)
                .font(.synBody)
                .lineLimit(lineLimit)
            Spacer(minLength: 0)
        }
    }
}

/// Swipe-action button content: icon with its label underneath.
struct SwipeActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
    }
}

// MARK: - Pop-up building blocks

/// Pop-up title, left-aligned.
struct PopupTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(Color.myDarkBlue)
            .font(.synSection)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "LABEL" + rounded single-line text field.
struct PopupField: View {
    let title: String
    @Binding var text: String
    var capitalization: TextInputAutocapitalization = .words

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.synLabel)
            TextField("", text: $text)
                .font(.synBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(capitalization)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.myDarkBlue, lineWidth: 1))
        }
    }
}

/// "LABEL" + rounded multi-line field that grows with the text (notes, instructions).
struct PopupTextArea: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var minLines: Int = 3
    var maxLines: Int = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.synLabel)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.gray.opacity(0.6)), axis: .vertical)
                .font(.synBody)
                .lineLimit(minLines...maxLines)
                .textInputAutocapitalization(.sentences)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.myDarkBlue, lineWidth: 1))
        }
    }
}

/// "Label ............ control" row (steppers, toggles, pickers). The label uses the body size so it
/// matches the text inside the picker next to it.
struct PopupRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.synBody)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            content()
        }
        .frame(minHeight: 36)
    }
}

/// "Label ............ [date]" row with an optional allowed range.
struct PopupDateRow: View {
    let title: String
    @Binding var date: Date
    var components: DatePickerComponents = .date
    var minimum: Date? = nil
    var maximum: Date? = nil

    var body: some View {
        PopupRow(title: title) {
            picker
                .labelsHidden()
                .tint(Color.myDarkBlue)
        }
    }

    @ViewBuilder
    private var picker: some View {
        if let minimum, let maximum, minimum <= maximum {
            DatePicker(title, selection: $date, in: minimum...maximum, displayedComponents: components)
        } else if let minimum {
            DatePicker(title, selection: $date, in: minimum..., displayedComponents: components)
        } else if let maximum {
            DatePicker(title, selection: $date, in: ...maximum, displayedComponents: components)
        } else {
            DatePicker(title, selection: $date, displayedComponents: components)
        }
    }
}

/// "Label ............ (switch)" row.
struct PopupToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.synBody)
                .foregroundStyle(.primary)
        }
        .tint(Color.myDarkBlue)
        .frame(minHeight: 36)
    }
}

/// Small gray helper line inside pop-ups.
struct PopupHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.synCaption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Cancel / Save pair used at the bottom of pop-ups.
struct PopupButtons: View {
    var saveTitle: String = "Save"
    var saveEnabled: Bool = true
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.synLabel)
                    .foregroundStyle(Color.gray)
                    .padding()
            }
            Button(action: onSave) {
                Text(saveTitle)
                    .font(.synLabel)
                    .foregroundStyle(saveEnabled ? Color.myDarkBlue : Color.gray)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(saveEnabled ? Color.myLightBlue : Color.gray.opacity(0.15)))
            }
            .disabled(!saveEnabled)
        }
        .padding(.top, 4)
    }
}

extension View {
    /// The white rounded card used by every pop-up.
    func popupCard() -> some View {
        self
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.myDarkBlue, lineWidth: 1))
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
    }
}

/// Scrollable pop-up form: title, consistently spaced fields, then Cancel / Save.
/// Grows with its content and scrolls once it would be taller than the screen allows.
struct PopupForm<Content: View>: View {
    let title: String
    var errorMessage: String? = nil
    let onCancel: () -> Void
    let onSave: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PopupTitle(text: title)
            // Shows the fields as they are when they fit; otherwise the same fields in a scroll view.
            ViewThatFits(in: .vertical) {
                fields
                ScrollView {
                    fields
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
            PopupButtons(onCancel: onCancel, onSave: onSave)
        }
        .popupCard()
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
            if let errorMessage {
                Text(errorMessage)
                    .font(.synCaption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

/// Floating "+" button used on list screens.
struct AddFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.myDarkBlue)
                .padding(-4)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .padding(.trailing, 35)
        .padding(.bottom, 15)
        .accessibilityLabel("Add")
    }
}

// MARK: - Date pickers (outside pop-ups)

/// Date picker limited to past dates (birthdate, start dates).
struct DatePick: View {
    @Binding var selectedDate: Date

    var body: some View {
        DatePicker("Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
            .labelsHidden()
            .tint(Color.myDarkBlue)
    }
}

// MARK: - Buttons and messages

/// Full-width dark-blue button with a spinner while working (LOG IN, CREATE ACCOUNT, VERIFY, SAVE…).
struct PrimaryActionButton: View {
    let title: String
    var isWorking: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.synButton)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(enabled ? Color.myDarkBlue : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .disabled(isWorking || !enabled)
    }
}

/// Light-blue outlined companion to PrimaryActionButton (Resend Code, secondary actions).
struct SecondaryActionButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.synButton)
                .foregroundStyle(enabled ? Color.myDarkBlue : Color.gray)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.myLightBlue)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(enabled ? Color.myDarkBlue : Color.gray, lineWidth: 1))
        }
        .disabled(!enabled)
    }
}

/// Red error / dark-blue success lines shown under a form.
struct FormMessages: View {
    var error: String?
    var success: String?

    var body: some View {
        VStack(spacing: 6) {
            if let error {
                Text(error)
                    .font(.synCaption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let success {
                Text(success)
                    .font(.synCaption)
                    .foregroundStyle(Color.myDarkBlue)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension View {
    /// Pins a floating "+" button to the bottom-right corner, on every screen size.
    func floatingAddButton(action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            AddFloatingButton(action: action)
        }
    }
}

/// Light-blue information card (e.g. "managed by your Google account").
struct NoticeCard: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundStyle(Color.myDarkBlue)
            Text(text)
                .font(.synBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.myLightBlue))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.myDarkBlue, lineWidth: 1))
    }
}
