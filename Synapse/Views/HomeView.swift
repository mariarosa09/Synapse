//
//  HomeView.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//
//  Profile summary, shortcuts to Medical Records and Medicines, and today's appointments.
//

import SwiftUI

struct HomeView: View {
    @Environment(SessionController.self) private var session
    @State private var controller = HomeController()

    var body: some View {
        VStack(alignment: .leading) {
            HeadingNoDesc(back: false, title: "Synapse")
            VStack {
                ProfileContainer(name: controller.displayName(for: session.profile),
                                 ageText: controller.ageText(for: session.profile),
                                 bloodTypeText: controller.bloodTypeText(for: session.profile),
                                 avatarURL: session.avatarURL,
                                 avatarImage: session.avatarImage)
                Spacer().frame(height: 10)
                HStack {
                    NavigationLink {
                        MedicalRecordView()
                    } label: {
                        FeatureButton(title: "Medical\nRecords", image: "Medical Record")
                    }
                    Spacer().frame(width: 10)
                    NavigationLink {
                        MedicinesView()
                    } label: {
                        FeatureButton(title: "Medicines", image: "Medicine")
                    }
                }
                Spacer().frame(height: 10)
                ScheduleToday(controller: controller)
            }
            .padding(.horizontal, 30)
            .padding(.vertical)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ProfileContainer: View {
    let name: String
    let ageText: String
    let bloodTypeText: String
    let avatarURL: URL?
    var avatarImage: UIImage? = nil

    var body: some View {
        HStack(spacing: 20) {
            AvatarView(url: avatarURL, localImage: avatarImage, size: 100)
            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.synSection)
                    .foregroundStyle(Color.myDarkBlue)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer().frame(height: 5)
                Text(ageText)
                    .font(.synBody)
                    .foregroundStyle(Color.myDarkBlue)
                Text(bloodTypeText)
                    .font(.synBody)
                    .foregroundStyle(Color.myDarkBlue)
            }
            Spacer()
        }
        .padding()
        .background(Color.myLightBlue)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15)
            .stroke(Color.myDarkBlue, lineWidth: 1))
    }
}

struct FeatureButton: View {
    let title: String
    let image: String

    var body: some View {
        HStack {
            ZStack {
                Image("IconBg")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 120)
                    .offset(x: -12)
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .offset(x: -35, y: 20)
                Text(title)
                    .font(.synSection)
                    .foregroundStyle(Color.myDarkBlue)
                    .offset(x: 30, y: -28)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color.myLightBlue)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15)
            .stroke(Color.myDarkBlue, lineWidth: 1))
    }
}

struct ScheduleToday: View {
    @Environment(SessionController.self) private var session
    var controller: HomeController

    var body: some View {
        let appointments = session.appointments
        HStack {
            VStack(alignment: .leading) {
                Text("Schedule For Today")
                    .font(.synSection)
                ScrollView {
                    if controller.isLoading(appointments) {
                        ProgressView().tint(Color.myDarkBlue).frame(maxWidth: .infinity).padding(.top, 20)
                    } else {
                        ChecklistUI(appointments: controller.todaysAppointments(from: appointments)) { item in
                            controller.toggleCompleted(item, in: appointments)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer()
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 285, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15)
            .stroke(Color.myDarkBlue, lineWidth: 1))
    }
}

#Preview {
    NavigationStack { MainTabView() }
        .environment(SessionController())
}
