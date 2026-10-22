//
//  MedicalRecord.swift
//  Synapse
//
//  Created by Mac-LAB on 9/8/26.
//

import SwiftUI

struct MedicalRecord: View {
    // Instantiate the custom controller state
    @State private var controller = MedicalRecordController()
    @State private var navigateToNewRecord = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack (spacing: 10) {
                HeadingNoDesc(back: true, title: "Medical Record")
                NavigationLink {
                    BasicInformation()
                } label: {
                    ButtonBasicInformation()
                }

                if let message = controller.errorMessage {
                    ErrorBanner(message: message) { controller.errorMessage = nil }
                }
                
                if controller.isLoading && controller.records.isEmpty {
                    ProgressView()
                        .tint(Color.myDarkBlue)
                        .padding(.top, 40)
                    Spacer()
                } else if controller.records.isEmpty {
                    Text("No medical records found.")
                        .font(.custom("DM Sans", size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                    Spacer()
                } else {
                    MedicalEntry(controller: controller)
                        .padding(.horizontal, 30)
                }
                Spacer()
            }
            AddFloatingButton {
                navigateToNewRecord = true
            }
        }
        .navigationDestination(isPresented: $navigateToNewRecord) {
            Notes(
                recordTitle: "",
                date: .now,
                notes: "",
                controller: controller,
                isNewRecord: true
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            controller.startListening()
        }
        .onDisappear {
            controller.stopListening()
        }
    }
}


struct ButtonBasicInformation: View {
    var body: some View {
        VStack {
            HStack {
                Text("Basic Information")
                    .font(.custom("Graduate", size: 16))
                    .foregroundStyle(Color.myDarkBlue)
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .foregroundStyle(Color.myDarkBlue)

            }
            .padding()
            .background(Color.myLightBlue)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 15)
                .stroke(Color.myDarkBlue, lineWidth: 1))
            .padding(.horizontal, 30)
            .padding(.top, 20)
        }
    }
}

struct MedicalEntry: View {
    var controller: MedicalRecordController
    
    var body: some View {
        List {
            ForEach(controller.records) { item in
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("What: ")
                                .font(.custom("DM Sans", size: 15))
                                .fontWeight(.semibold)
                            Text(item.title)
                                .font(.custom("DM Sans", size: 15))
                            Spacer()
                        }
                        HStack {
                            Text("When: ")
                                .font(.custom("DM Sans", size: 15))
                                .fontWeight(.semibold)
                            Text(item.date, style: .date)
                                .font(.custom("DM Sans", size: 15))
                            Spacer()
                        }
                    }
                    
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundStyle(Color.myDarkBlue)
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.myDarkBlue, lineWidth: 1))
                .padding(.bottom, 10)
                .background {
                    NavigationLink(destination: Notes(recordTitle: item.title, date: item.date, notes: item.notes, files: item.file, controller: controller, isNewRecord: false, recordID: item.id)) {
                        EmptyView()
                    }
                    .opacity(0)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: { indexSet in
                controller.deleteRecord(at: indexSet)
            })
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    MedicalRecord()
}
