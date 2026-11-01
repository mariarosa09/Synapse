//
//  SupabaseManager.swift
//  Synapse
//
//  The single Supabase client used by every controller, plus the names of the
//  tables and storage buckets created by supabase/schema.sql.
//

import Foundation
import Supabase

enum SupabaseConfig {
    /// Project URL and public anon key (Dashboard → Project Settings → API).
    /// The anon key is safe to ship: every table and bucket is protected by Row Level Security.
    static let url = URL(string: "https://cmgdfrryzdsjmqfqddks.supabase.co")!
    /// Where Google / Apple sign-in returns to. Must be listed in Supabase → Authentication →
    /// URL Configuration → Redirect URLs.
    static let authRedirectURL = URL(string: "synapse://login-callback")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtZ2RmcnJ5emRzam1xZnFkZGtzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwODEyMDgsImV4cCI6MjEwODY1NzIwOH0.i-62P_d36lU5IbK7_hCfRFlrAsG8sP8vGxDihIBtgq8"
}

enum Table {
    static let profiles = "profiles"
    static let settings = "user_settings"
    static let basicInformation = "basic_information"
    static let medicines = "medicines"
    static let appointments = "appointments"
    static let medicalRecords = "medical_records"
    static let attachments = "medical_record_attachments"
}

enum Bucket {
    /// Private bucket, path "<user id>/avatar-<uuid>.jpg".
    static let avatars = "avatars"
    /// Private bucket, path "<user id>/<record id>/<attachment id>.<ext>".
    static let medicalRecords = "medical-records"
    /// Lifetime of signed URLs handed to the UI.
    static let signedURLLifetime = 60 * 60 * 24
}

/// The stored session is emitted right away on launch; SessionController refreshes it before use.
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
)
