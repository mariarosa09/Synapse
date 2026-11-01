//
//  AvatarView.swift
//  Synapse
//
//  Profile picture loaded from a Supabase Storage signed URL, falling back to the default picture
//  when there is no photo, the URL is invalid, or the download fails.
//

import SwiftUI

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = 100

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        DefaultAvatar()
                    default:
                        ZStack {
                            Color.myLightBlue
                            ProgressView().tint(Color.myDarkBlue)
                        }
                    }
                }
                .id(url)   // a new signed URL (replaced photo) reloads the image
            } else {
                DefaultAvatar()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.myDarkBlue, lineWidth: 1))
    }
}

private struct DefaultAvatar: View {
    var body: some View {
        Image("Profile").resizable().scaledToFit()
    }
}

#Preview("Placeholder / No Photo") {
    AvatarView(url: nil)
}
