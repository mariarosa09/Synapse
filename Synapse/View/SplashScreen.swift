//
//  SplashScreen.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//

import SwiftUI

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.myDarkBlue.ignoresSafeArea()

            Image("Logo")
                .resizable()
                .scaledToFit()
                .padding()
                .background(Color.white)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 50))
        }
    }
}

#Preview {
    SplashScreen()
}
