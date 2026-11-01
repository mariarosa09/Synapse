# Synapse – revision notes (Supabase migration)

Backend setup, SQL and the test checklist are in **`supabase/SETUP.md`** and **`supabase/schema.sql`**.

## Project structure (MVC only)

```
Synapse/
  SynapseApp.swift            app entry + notification delegate
  Models/                     one data model per file (Codable rows of the Supabase tables)
  Controllers/                business logic: auth, database, storage, notifications
  Views/                      one file per screen
    Components/               small reusable pieces (inputs, buttons, header, avatar, checklist)
    Popups/ConfirmationPopup  the custom pop-up used for Logout and every delete / clear action
```

| Screen (Views/) | Controller(s) |
|---|---|
| RootView (routing) | SessionController |
| SplashScreenView, OverviewView | static screens, no logic |
| LoginView | LoginController |
| CreateAccountView | CreateAccountController |
| OTPVerificationView | OTPVerificationController |
| ForgotPasswordView | PasswordResetController |
| AboutYouView (onboarding) | AboutYouController |
| MainTabView (tabs + logout pop-up) | SessionController |
| HomeView | HomeController, AppointmentController |
| CalendarView (appointments) | CalendarController, AppointmentController |
| MedicinesView | MedicineController |
| MedicalRecordView | MedicalRecordController |
| MedicalRecordDetailView | MedicalRecordController, AttachmentController |
| AttachmentsView | AttachmentController |
| BasicInformationView | BasicInformationController |
| ProfileView, EditProfileView, ChangeEmailView, ChangePasswordView, DataAccountView | ProfileController |
| SettingsView (notifications) | SettingsController |

NotificationController schedules all local notifications. SupabaseManager holds the single
Supabase client plus the table and bucket names.

## What changed

* **Firebase removed**: Firebase packages, `GoogleService-Info.plist`, `firebase.json`,
  Firestore / Storage rules, and the old Firebase-based `View/` and `Controller/` folders and
  models. The duplicate copies made the project fail to build.
* **Supabase Auth with OTP codes**: sign-up, login, logout, password reset and email change
  all use emailed codes (no links), with resend cooldown, expiry / invalid-code messages.
  Unverified users can't reach the app.
* **PostgreSQL + RLS** for profiles, settings, basic information, medicines, appointments,
  medical records and attachment metadata.
* **Storage**: profile pictures (upload / replace / remove, signed URLs, default picture fallback)
  and medical attachments of any common type (images, PDF, Word, text, Excel, CSV, DICOM…) via the
  document picker or Photos, with thumbnails, Quick Look preview, Open In… / Save to Files,
  replace and delete. Original file names, types, MIME types, sizes and paths are saved.
* **Search** on Medical Records (title, category, notes, date, file names) and Medicines
  (combined with All / Active / Inactive).
* **Reminders**: medicines get 1–4 notifications a day following the frequency (custom times or
  spread automatically); appointments get one exactly 5 minutes before the start. Edits, status
  changes, deletes, expiry and the settings switches update or cancel them; identifiers are
  deterministic, so duplicates are impossible. The 64-notification iOS limit is handled with a
  rolling window that is refilled from Supabase whenever the app becomes active.
* **Calendar**: dots on days with appointments, month navigation (tap the month to return to
  today), tap an appointment for full details with Edit / Delete; updates live.
* **Appointment screen header**: placed and left-aligned exactly like the other screen headers.
  The add/edit pop-up title is left-aligned too.
* **Settings**: notification switches are saved per user and restored at login. The appearance
  options are gone and the app always uses its light design.
* **Logout**: the custom Synapse pop-up (Cancel / Logout) replaces the iOS dialog, covers the whole
  screen including the tab bar, signs out of Supabase and returns to the Login screen.
* Floating "+" buttons are pinned to the bottom-right corner on every iPhone size instead of
  fixed offsets.

## UI revision (round 2)

* **One type scale** (`Font.synTitle`, `.synSection`, `.synBody`, `.synCaption`, `.synLabel`,
  `.synButton`, … in `Views/Components/Branding.swift`) used by every screen and input.
* **Edit pop-ups** (medicine, basic information, appointment, onboarding entries) rebuilt
  with shared pieces (`PopupForm`, `PopupField`, `PopupTextArea`, `PopupRow`, `PopupDateRow`,
  `PopupToggleRow`). Spacing is even, labels are aligned, date pickers sit on the right, and
  Notes / Instructions grow from 3 to 10 lines. Pop-ups fit their content and only scroll
  when needed.
* **Search bars** are the first thing under the header (Medicines, Basic Information, Medical
  Records). **Basic Information** now has search, combined with the filters.
* **Swipe actions** show an icon with its label underneath (Edit, Delete, Activate/Deactivate).
* **Medical record details**: View Files now sits above Category.
* **Attachments**: an ✕ button removes a file (with confirmation); tap the row to open it;
  long-press for Preview, Open With… / Save to Files, Replace and Remove. No swipe actions.
* **Login**: Continue with Apple / Continue with Google (Supabase OAuth). See
  `supabase/SETUP.md` → "Google and Apple sign-in". Google/Apple accounts see a note instead of
  the Change Password / Change Email forms.

## UI revision (round 3)

* Pop-up rows with pickers (dates, times, times-per-day, switches) use body-size labels that
  match the picker text.
* All pickers (date/time, segmented) and system controls are tinted dark blue (AccentColor set to
  `myDarkBlue`, plus a global tint and UIKit appearance for segmented pickers).
* Login: Apple and Google buttons side by side, plain white with a dark-blue border and black
  text. Google's official logo goes in `Assets.xcassets/GoogleLogo` (see SETUP.md).
