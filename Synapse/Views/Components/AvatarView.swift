//
//  AvatarView.swift
//  Synapse
//
//  Profile picture loaded from a Supabase Storage signed URL. While that loads (or if it fails) the
//  picture the user just chose is shown instead; with no photo at all it falls back to the default picture.
//

import SwiftUI

struct AvatarView: View {
    let url: URL?
    /// The picture that was just uploaded (kept in memory by SessionController).
    var localImage: UIImage? = nil
    var size: CGFloat = 100

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallback
                    default:
                        if localImage != nil {
                            fallback      // no spinner flash: show the new picture while the stored copy loads
                        } else {
                            ZStack {
                                Color.myLightBlue
                                ProgressView().tint(Color.myDarkBlue)
                            }
                        }
                    }
                }
                .id(url)   // a new signed URL (replaced photo) reloads the image
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.myDarkBlue, lineWidth: 1))
    }

    @ViewBuilder private var fallback: some View {
        if let localImage {
            Image(uiImage: localImage).resizable().scaledToFill()
        } else {
            DefaultAvatar()
        }
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
