//
//  AboutYou.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//

import SwiftUI

// Main About You View
struct AboutYou: View {
    @State private var controller = AboutYouController()
    @State private var allergyPopup: Bool = false
    @State private var medicalConditionPopup: Bool = false
    @State private var allergyText: String = ""
    @State private var medicalConditionText: String = ""
    @State private var startDate = Date()
    
    var body: some View {
        ZStack {
            VStack (alignment: .leading) {
                Heading(back: false, title: "Tell Us About You", description: "Help us personalize your medical assistant")
                Spacer().frame(height: 10)
                ScrollView {
                    AboutYouBasicInformation(controller: controller)
                    Spacer().frame(height: 10)
                    AboutYouMedicalInformation(controller: controller, allergyPopUp: $allergyPopup, conditionPopUp: $medicalConditionPopup)
                }
                Spacer()
                
            }
            if allergyPopup {
                Color.black.opacity(0.2).ignoresSafeArea()
                MedicalInformationInput(title: "Allergy", text: $allergyText, isVisible: $allergyPopup, startDate: $startDate) {
                    controller.addAllergy(title: allergyText, startDate: startDate)
                }
            }
            if medicalConditionPopup {
                Color.black.opacity(0.2).ignoresSafeArea()
                MedicalInformationInput(title: "Medical Condition", text: $medicalConditionText, isVisible: $medicalConditionPopup, startDate: $startDate) {
                    controller.addMedicalCondition(title: medicalConditionText, startDate: startDate)
                }
            }

        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// The section for Basic Information Input
struct AboutYouBasicInformation: View {
    @Bindable var controller: AboutYouController
    let sex = [
        Sex(name: "Female"),
        Sex(name: "Male")
    ]
    
    let bloodGroup = [
        Blood(name: "A+"),
        Blood(name: "B+"),
        Blood(name: "AB+"),
        Blood(name: "O+"),
        Blood(name: "A-"),
        Blood(name: "B-"),
        Blood(name: "AB-"),
        Blood(name: "O-")
    ]
    
    var body: some View {
        VStack (alignment: .leading) {
            Text("Basic Information")
                .font(.custom("Graduate", size: 18))
                .fontWeight(.semibold)
            
            Spacer().frame(height: 10)
            
            Text("Sex")
                .font(.custom("DM Sans", size: 16))
                .fontWeight(.semibold)
            
            
            RadioButtonView(sex, selection: $controller.selectedSex) {
                variation in
                HStack {
                    Image(systemName: variation == controller.selectedSex ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(Color.myDarkBlue)
                        .font(.system(size: 15))
                    Text(variation.name)
                        .font(.custom("DM Sans", size: 16))
                }
            }
            
            Spacer().frame(height: 15)
            
            Text("Blood Group")
                .font(.custom("DM Sans", size: 16))
                .fontWeight(.semibold)
            
            // Formatting the radio button for blood group
            let columns = [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
            
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(bloodGroup, id: \.self) { variation in
                    HStack {
                        Image(systemName: variation == controller.selectedBlood ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color.myDarkBlue)
                            .font(.system(size: 15))
                        Text(variation.name)
                            .font(.custom("DM Sans", size: 16))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        controller.selectedBlood = variation
                    }
                }
            }
            .padding(.top, -10)
            
            Spacer().frame(height: 15)
            
            HStack {
                Text("Birthdate: ")
                    .font(.custom("DM Sans", size: 16))
                    .fontWeight(.semibold)
                DatePick(selectedDate: $controller.birthdate)
                Spacer().frame(width: 120)
            }
            
            Spacer().frame(height: 10)
            
            Divider()
                .frame(height: 1)
                .background(Color.myDarkBlue)
            
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
    }
}

// Format for the radio button
struct RadioButtonView<T: Identifiable & Hashable, Content: View>: View {
    let options: [T]
    @Binding var selection: T?
    @ViewBuilder let content: (T) -> Content
    init(
        _ options: [T],
        selection: Binding<T?>,
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.options = options
        self._selection = selection
        self.content = content
    }
    
    var body: some View {
        Group {
            ForEach(options, id: \.self) {option in
                Button {
                    selection = option
                } label: {
                    content(option)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Date picker for the birthday
struct DatePick: View {
    @Binding var selectedDate: Date
    var body: some View {
        HStack {
            DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                .font(.custom("DM Sans", size: 19))
                .fontWeight(.semibold)
                .scaleEffect(0.85)
                .padding(.horizontal, -15)
            
        }
    }
}

struct EndDatePick: View {
    @Binding var selectedDate: Date
    var body: some View {
        HStack {
            DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                .font(.custom("DM Sans", size: 19))
                .fontWeight(.semibold)
                .scaleEffect(0.85)
                .padding(.horizontal, -15)
            
        }
    }
}

// The section for the Medical Information Input
struct AboutYouMedicalInformation: View {
    @Bindable var controller: AboutYouController
    @Binding var allergyPopUp: Bool
    @Binding var conditionPopUp: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Medical Information")
                .font(.custom("Graduate", size: 18))
                .fontWeight(.semibold)
            
            // --- ALLERGIES SECTION ---
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    allergyPopUp.toggle()
                } label: {
                    AddButtonView(title: "Allergy")
                }
                
                FlowLayout(spacing: 8) {
                    ForEach(controller.allergies) { allergy in
                        Entry(title: allergy.title)
                            .contextMenu {
                                Button("Remove", role: .destructive) { controller.remove(allergy) }
                            }
                    }
                }
            }
            
            // --- MEDICAL CONDITIONS SECTION ---
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    conditionPopUp.toggle()
                } label: {
                    AddButtonView(title: "Medical Condition")
                }
                
                FlowLayout(spacing: 8) {
                    ForEach(controller.medicalConditions) { condition in
                        Entry(title: condition.title)
                            .contextMenu {
                                Button("Remove", role: .destructive) { controller.remove(condition) }
                            }
                    }
                }
            }
            
            Spacer()

            if let message = controller.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // --- SAVE ACTION BUTTON ---
            Button {
                Task { await controller.saveAndContinue() }
            } label: {
                Group {
                    if controller.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("SAVE & CONTINUE")
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
            .disabled(controller.isSaving)
        }
        .padding(.horizontal, 30)
    }
}

// Format for the add button for allergy and medical condition
struct AddButtonView: View {
    let title: String
    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.myDarkBlue)
            Text(title)
                .font(.custom("DM Sans", size: 16))
                .fontWeight(.semibold)
                .foregroundStyle(.black)
        }
    }
}

// Format for entry to be improved with the iteration and database
struct Entry: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.custom("DM Sans", size: 16))
            .foregroundStyle(Color.myDarkBlue)
            .padding(9)
            .background(Color.myLightBlue)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MedicalInformationInput: View {
    let title: String
    @Binding var text: String
    @Binding var isVisible: Bool
    @Binding var startDate: Date
    var onSave: () -> Void = {}

    private var canSave: Bool { !text.trimmed.isEmpty }

    var body: some View {
        VStack (alignment: .leading) {
            Text(title)
                .foregroundStyle(Color.myDarkBlue)
                .font(.custom("Graduate", size: 16))
            TextField("", text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.myDarkBlue, lineWidth: 1))
            HStack {
                Text("START DATE: ")
                    .font(.custom("DM Sans", size: 12))
                DatePick(selectedDate: $startDate)
            }
            .padding(.top, 10)
            PopupButtons(saveEnabled: canSave) {
                isVisible = false
                text = ""
                startDate = .now
            } onSave: {
                onSave()
                isVisible = false
                text = ""
                startDate = .now
            }
        }
        .popupCard()
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews, doLayout: false)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = arrangeSubviews(proposal: proposal, subviews: subviews, doLayout: true, bounds: bounds)
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews, doLayout: Bool, bounds: CGRect = .zero) -> (size: CGSize, maxContentWidth: CGFloat) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentX + subviewSize.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            if doLayout {
                subview.place(at: CGPoint(x: bounds.minX + currentX, y: bounds.minY + currentY), proposal: .unspecified)
            }

            lineHeight = max(lineHeight, subviewSize.height)
            currentX += subviewSize.width + spacing
            maxHeight = max(maxHeight, currentY + lineHeight)
        }

        return (CGSize(width: maxWidth, height: maxHeight), maxWidth)
    }
}


#Preview {
    AboutYou()
}
