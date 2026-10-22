//
//  Home.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//

import SwiftUI

struct Home: View {
    @Environment(SessionController.self) private var session
    var body: some View {
        VStack (alignment: .leading) {
            HeadingNoDesc(back: false, title: "Synapse")
            VStack {
                ProfileContainer(name: session.profile?.fullName ?? "",
                                 age: session.profile?.age,
                                 bloodType: session.profile?.bloodGroup,
                                 photoURL: session.profile?.photoURL)
                Spacer().frame(height: 10)
                HStack {
                    NavigationLink {
                        MedicalRecord()
                    } label: {
                        FeatureButton(title: "Medical\nRecords", image: "Medical Record")
                    }
                    Spacer().frame(width: 10)
                    NavigationLink {
                        Medicines()
                    } label: {
                        FeatureButton(title: "Medicines", image: "Medicine")
                    }
                }
                Spacer().frame(height: 10)
                ScheduleToday()
            }
            .padding(.horizontal, 30)
            .padding(.vertical)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ProfileContainer: View {
    let name: String
    let age: Int?
    let bloodType: String?
    let photoURL: String?
    var body: some View {
        HStack (spacing: 20) {
            AvatarView(photoURL: photoURL, size: 100)
            VStack (alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.custom("Graduate", size: 16))
                    .foregroundStyle(Color.myDarkBlue)
                Spacer().frame(height: 5)
                Text(age.map { "\($0) years old" } ?? "Age not set")
                    .font(.custom("DM Sans", size: 14))
                    .foregroundStyle(Color.myDarkBlue)
                Text(bloodType.map { "\($0) type" } ?? "Blood type not set")
                    .font(.custom("DM Sans", size: 14))
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
                    .font(.custom("Graduate", size: 16))
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
    var body: some View {
        let appointments = session.appointments
        HStack {
            VStack (alignment: .leading) {
                Text("Schedule For Today")
                    .font(.custom("Graduate", size: 16))
                ScrollView {
                    if appointments.isLoading && appointments.appointments.isEmpty {
                        ProgressView().tint(Color.myDarkBlue).frame(maxWidth: .infinity).padding(.top, 20)
                    } else {
                        ChecklistUI(appointments: appointments.appointments(on: .now)) { item in
                            appointments.setStatus(item, completed: !item.isChecked)
                        }
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
    NavigationBar()
        .environment(SessionController())
}
