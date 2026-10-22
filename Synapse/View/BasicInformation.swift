//
//  BasicInformation.swift
//  Synapse
//
//  Created by Mac-LAB on 9/17/26.
//

import SwiftUI

struct BasicInformation: View {
    @Environment(SessionController.self) private var session
    @State private var filter: StatusFilter = .all
    @State private var popupVisible = false
    @State private var draft = BasicInformationModel()
    @State private var formError: String?

    private var controller: BasicInformationController { session.basicInfo }
    private var visible: [BasicInformationModel] { controller.entries(matching: filter) }

    var body: some View {
        ZStack {
            VStack (spacing: 10){
                HeadingNoDesc(back: true, title: "Basic Information")
                UpperTab(filter: $filter).padding(.top, 20)

                if let message = controller.errorMessage {
                    ErrorBanner(message: message) { controller.errorMessage = nil }
                }

                if controller.isLoading && controller.entries.isEmpty {
                    ProgressView().tint(Color.myDarkBlue).padding(.top, 40)
                    Spacer()
                } else if visible.isEmpty {
                    Text(controller.entries.isEmpty ? "Nothing added yet. Tap + to add an allergy or condition."
                                                    : "No \(filter.title.lowercased()) entries.")
                        .font(.custom("DM Sans", size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 60)
                        .padding(.horizontal, 30)
                    Spacer()
                } else {
                    BasicInformationEntry(
                        items: visible,
                        onEdit: { openEditor(for: $0) },
                        onToggleActive: { controller.setActive($0, active: !$0.active) },
                        onDelete: { controller.delete($0) }
                    )
                    .padding(.horizontal, 30)
                }
            }

            AddFloatingButton {
                openEditor(for: BasicInformationModel())
            }
            .offset(x: 160, y: 370)

            if popupVisible {
                Color.black.opacity(0.2).ignoresSafeArea()
                BasicInfoInput(draft: $draft, errorMessage: formError) {
                    popupVisible = false
                } onSave: {
                    if let message = controller.validationError(for: draft) {
                        formError = message
                    } else if controller.save(draft) {
                        popupVisible = false
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func openEditor(for entry: BasicInformationModel) {
        draft = entry
        formError = nil
        controller.errorMessage = nil
        popupVisible = true
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
                        .font(.custom("Graduate", size: 16))
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

struct BasicInformationEntry: View {
    let items: [BasicInformationModel]
    let onEdit: (BasicInformationModel) -> Void
    let onToggleActive: (BasicInformationModel) -> Void
    let onDelete: (BasicInformationModel) -> Void

    var body: some View {
        List {
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("What: ")
                                .font(.custom("DM Sans", size: 15))
                                .fontWeight(.semibold)
                            Text(item.title)
                                .font(.custom("DM Sans", size: 15))
                            Spacer()
                        }
                        HStack {
                            Text("Type: ")
                                .font(.custom("DM Sans", size: 15))
                                .fontWeight(.semibold)
                            Text(item.kind.title)
                                .font(.custom("DM Sans", size: 15))
                            Spacer()
                        }
                        HStack {
                            Text("When: ")
                                .font(.custom("DM Sans", size: 15))
                                .fontWeight(.semibold)
                            Text(item.startDate, style: .date)
                                .font(.custom("DM Sans", size: 15))
                            Spacer()
                        }
                        StatusBadge(active: item.active)
                    }
                    
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundStyle(Color.myDarkBlue)
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.myDarkBlue, lineWidth: 1))
                .padding(.bottom, 10)
                .contentShape(Rectangle())
                .onTapGesture { onEdit(item) }
                .swipeActions(edge: .leading) {
                    Button(item.active ? "Deactivate" : "Activate") { onToggleActive(item) }
                        .tint(Color.myDarkBlue)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) { onDelete(item) }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

/// Add / edit pop-up for an allergy or medical condition.
struct BasicInfoInput: View {
    @Binding var draft: BasicInformationModel
    var errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Basic Information")
                    .foregroundStyle(Color.myDarkBlue)
                    .font(.custom("Graduate", size: 16))

                Picker("Type", selection: $draft.kind) {
                    ForEach(BasicInfoKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 10)

                PopupField(title: "NAME", text: $draft.title)

                HStack {
                    Text("START DATE: ")
                        .font(.custom("DM Sans", size: 12))
                    DatePick(selectedDate: $draft.startDate)
                }
                .padding(.top, 10)

                PopupField(title: "NOTES", text: $draft.notes, capitalization: .sentences)

                Toggle(isOn: $draft.active) {
                    Text("ACTIVE")
                        .font(.custom("DM Sans", size: 12))
                }
                .tint(Color.myDarkBlue)
                .padding(.top, 10)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(.red)
                        .padding(.top, 6)
                }

                PopupButtons(onCancel: onCancel, onSave: onSave)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 400)
        .popupCard()
    }
}

#Preview {
    BasicInformation()
        .environment(SessionController())
}
