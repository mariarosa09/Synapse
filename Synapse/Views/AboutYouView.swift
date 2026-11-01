//
//  AboutYouView.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//
//  Onboarding ("Tell Us About You"): sex, blood group, birthdate, allergies and medical conditions.
//  AboutYouController saves everything to Supabase and completes onboarding.
//

import SwiftUI

struct AboutYouView: View {
    @State private var controller = AboutYouController()
    @State private var allergyPopup: Bool = false
    @State private var medicalConditionPopup: Bool = false
    @State private var allergyText: String = ""
    @State private var medicalConditionText: String = ""
    @State private var startDate = Date()

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                Heading(back: false, title: "Tell Us About You", description: "Help us personalize your medical assistant")
                Spacer().frame(height: 10)
                ScrollView {
                    AboutYouBasicInformation(controller: controller)
                    Spacer().frame(height: 10)
                    AboutYouMedicalInformation(controller: controller, allergyPopUp: $allergyPopup, conditionPopUp: $medicalConditionPopup)
                        .padding(.bottom, 20)
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

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        VStack(alignment: .leading) {
            Text("Basic Information")
                .font(.synSection)
                .fontWeight(.semibold)

            Spacer().frame(height: 10)

            Text("Sex")
                .font(.synRow)
                .fontWeight(.semibold)

            RadioButtonView(Sex.all, selection: $controller.selectedSex) { variation in
                HStack {
                    Image(systemName: variation == controller.selectedSex ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(Color.myDarkBlue)
                        .font(.system(size: 15))
                    Text(variation.name)
                        .font(.synRow)
                }
            }

            Spacer().frame(height: 15)

            Text("Blood Group")
                .font(.synRow)
                .fontWeight(.semibold)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Blood.all) { variation in
                    HStack {
                        Image(systemName: variation == controller.selectedBlood ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color.myDarkBlue)
                            .font(.system(size: 15))
                        Text(variation.name)
                            .font(.synRow)
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
                    .font(.synRow)
                    .fontWeight(.semibold)
                DatePick(selectedDate: $controller.birthdate)
                Spacer()
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

    init(_ options: [T], selection: Binding<T?>, @ViewBuilder content: @escaping (T) -> Content) {
        self.options = options
        self._selection = selection
        self.content = content
    }

    var body: some View {
        Group {
            ForEach(options, id: \.self) { option in
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

// The section for the Medical Information Input
struct AboutYouMedicalInformation: View {
    @Environment(SessionController.self) private var session
    @Bindable var controller: AboutYouController
    @Binding var allergyPopUp: Bool
    @Binding var conditionPopUp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Medical Information")
                .font(.synSection)
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
                        Entry(title: allergy.title) { controller.remove(allergy) }
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
                        Entry(title: condition.title) { controller.remove(condition) }
                    }
                }
            }

            Spacer()

            if let message = controller.errorMessage {
                Text(message)
                    .font(.synCaption)
                    .foregroundColor(.red)
            }

            PrimaryActionButton(title: "SAVE & CONTINUE", isWorking: controller.isSaving) {
                Task { await controller.saveAndContinue(session: session) }
            }
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
                .font(.synRow)
                .fontWeight(.semibold)
                .foregroundStyle(.black)
        }
    }
}

/// A chip for an added allergy / condition. Long-press (or the x) removes it.
struct Entry: View {
    let title: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.synRow)
                .foregroundStyle(Color.myDarkBlue)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.myDarkBlue.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(title)")
            }
        }
        .padding(9)
        .background(Color.myLightBlue)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            if let onRemove {
                Button("Remove", role: .destructive, action: onRemove)
            }
        }
    }
}

/// Pop-up used to add an allergy or a medical condition during onboarding.
struct MedicalInformationInput: View {
    let title: String
    @Binding var text: String
    @Binding var isVisible: Bool
    @Binding var startDate: Date
    var onSave: () -> Void = {}

    private var canSave: Bool { !text.trimmed.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PopupTitle(text: title)
            PopupField(title: "NAME", text: $text, capitalization: .sentences)
            PopupDateRow(title: "Start date", date: $startDate, maximum: Date())
            PopupButtons(saveEnabled: canSave) {
                close()
            } onSave: {
                onSave()
                close()
            }
        }
        .popupCard()
    }

    private func close() {
        isVisible = false
        text = ""
        startDate = .now
    }
}

/// Wraps chips onto as many lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews, place: false, bounds: .zero)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = arrange(proposal: proposal, subviews: subviews, place: true, bounds: bounds)
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews, place: Bool, bounds: CGRect) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            if place {
                subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
            }
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
            maxHeight = max(maxHeight, y + lineHeight)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: maxHeight)
    }
}

#Preview {
    AboutYouView()
        .environment(SessionController())
}
