//
//  Branding.swift
//  Synapse
//
//  App colors, the logo badge and the blue screen headers shared by every screen.
//

import SwiftUI

extension Color {
    static let myDarkBlue = Color(red: 0/255, green: 74/255, blue: 173/255)
    static let myLightBlue = Color(red: 224/255, green: 239/255, blue: 251/255)
}

/// The app's type scale. Every screen uses these so the same kind of text always has the same size.
extension Font {
    /// Big welcome titles (Overview, Login).
    static let synHero = Font.custom("Graduate", size: 30)
    /// Titles of the signed-out screens (Create Account, Verify Email, Reset Password).
    static let synAuthTitle = Font.custom("Graduate", size: 24)
    /// Blue screen headers.
    static let synTitle = Font.custom("Graduate", size: 20)
    /// Section titles, card titles and pop-up titles.
    static let synSection = Font.custom("Graduate", size: 16)
    /// Primary buttons and settings rows.
    static let synButton = Font.custom("DM Sans", size: 16).weight(.semibold)
    /// Settings row titles.
    static let synRow = Font.custom("DM Sans", size: 16)
    /// Body text, list rows and every text input.
    static let synBody = Font.custom("DM Sans", size: 15)
    /// Secondary lines, hints, errors and success messages.
    static let synCaption = Font.custom("DM Sans", size: 13)
    /// Field labels ("TITLE", "START DATE"), badges and small buttons.
    static let synLabel = Font.custom("DM Sans", size: 12)
}

struct Logo: View {
    var body: some View {
        HStack {
            Spacer()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .padding(7)
                .background(Color.white)
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .shadow(radius: 3)
        }
        .padding(.bottom, 30)
    }
}

struct Heading: View {
    let back: Bool
    let title: String
    let description: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading) {
                Spacer().frame(height: 45)

                HStack {
                    if back {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 25))
                                .foregroundStyle(Color.white)
                                .padding(.trailing, 5)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.synTitle)
                            .foregroundStyle(Color.white)
                            .padding(.bottom, 5)
                        Text(description)
                            .font(.synBody)
                            .foregroundStyle(Color.white)
                    }

                    Spacer()
                }
            }

            Logo()
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .background(Color.myDarkBlue)
        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 10)
    }
}

/// Blue header with a left-aligned title, used at the top of every main screen.
struct HeadingNoDesc: View {
    let back: Bool
    let title: String
    /// Runs instead of the default "go back" when provided.
    var onBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading) {
                Spacer().frame(height: 45)

                HStack {
                    if back {
                        Button(action: { if let onBack { onBack() } else { dismiss() } }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 25))
                                .foregroundStyle(Color.white)
                                .padding(.trailing, 5)
                        }
                    }

                    Text(title)
                        .font(.synTitle)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Logo()
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .background(Color.myDarkBlue)
        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 10)
    }
}

/// White header used by the signed-out screens (Create Account, Verify Email, Forgot Password):
/// dark-blue back arrow, large title, gray subtitle and the logo badge on the right.
struct AuthHeading: View {
    let title: String
    let subtitle: String
    var showsBack: Bool = true
    /// Runs instead of the default "go back" when provided.
    var onBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading) {
                Spacer().frame(height: 40)
                HStack(alignment: .center) {
                    if showsBack {
                        Button(action: { if let onBack { onBack() } else { dismiss() } }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 25))
                                .foregroundStyle(Color.myDarkBlue)
                                .padding(.trailing, 5)
                        }
                        .accessibilityLabel("Back")
                    }
                    Text(title)
                        .font(.synAuthTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }

                Spacer().frame(height: 10)
                Text(subtitle)
                    .font(.synBody)
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 30)
            }
            Logo()
        }
    }
}
