//
//  OverviewView.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//
//  Welcome screen shown on first launch while signed out.
//

import SwiftUI

struct OverviewView: View {
    var body: some View {
        VStack {
            OverviewHeading()
                .padding(.bottom, 20)
            OverviewContent()
            OverviewContinue()
            Spacer()
        }
    }
}

struct OverviewHeading: View {
    var body: some View {
        VStack {
            Logo()

            HStack {
                VStack(alignment: .leading) {
                    Text("YOUR PERSONAL")
                        .font(.synBody)
                        .foregroundStyle(.white)
                    Text("Medical\nAssistant")
                        .font(.synHero)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
        }
        .padding(30)
        .background(Color.myDarkBlue)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct OverviewContent: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Track Your Medical Information With Confidence")
                .font(.synBody)
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
                .padding(.bottom, 10)

            Text("Record your medical history, medications, and appointments. Get notified about your appointments and medication. Take better care of yourself.")
                .font(.synBody)
                .foregroundStyle(.gray)
                .padding(.bottom, 30)

            HStack {
                Spacer()
                Icons(name: "Record", icon: "doc.text.fill")
                Spacer()
                Icons(name: "Notify", icon: "bell.fill")
                Spacer()
                Icons(name: "Care", icon: "heart.fill")
                Spacer()
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 10)
        .padding(.bottom, 60)
    }
}

struct Icons: View {
    let name: String
    let icon: String

    var body: some View {
        VStack {
            Image(systemName: icon)
                .foregroundStyle(Color.myDarkBlue)
                .font(.system(size: 35))
                .padding(15)
                .background(Color.myLightBlue)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Text(name)
                .font(.synBody)
                .foregroundStyle(.gray)
                .padding(.top, 10)
        }
    }
}

struct OverviewContinue: View {
    var body: some View {
        NavigationLink {
            LoginView()
        } label: {
            Text("CONTINUE")
                .font(.synRow)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 50)
                .background(Color.myDarkBlue)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

#Preview {
    NavigationStack { OverviewView() }
        .environment(SessionController())
}
