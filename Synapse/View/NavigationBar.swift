//
//  NavigationBar.swift
//  Synapse
//
//  Created by Mac-LAB on 9/1/26.
//

import SwiftUI

struct NavigationBar: View {
    var body: some View {
        TabView {
            VStack {
                Home()
            }
                .tabItem {
                    Image(systemName: "house.fill")
                }
            VStack {
                CalendarView()
            }
                .tabItem {
                    Image(systemName: "calendar")
                }
            VStack {
                Profile()
            }
                .tabItem {
                    Image(systemName: "person.fill")
                }
        }
        .tint(Color.myDarkBlue)
    }
}

#Preview {
    NavigationBar()
}
