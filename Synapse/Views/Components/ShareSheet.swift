//
//  ShareSheet.swift
//  Synapse
//
//  iOS share sheet for an attachment: "Open in…" another app, "Save to Files", AirDrop, print…
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
