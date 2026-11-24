# Synapse

**Your personal medical assistant for iPhone.**

Synapse keeps your health information in one place. Record your medical history and attach files, track your medicines and appointments, and get reminded when it's time for a dose or a check-up.

> Synapse is a personal organization tool. It does not diagnose, predict health outcomes or give medical advice, and it must not be relied on in an emergency.

---

## Features

### Account and security
- Sign up with email and password, verified with a **one-time code (OTP)** sent by email. There are no verification links.
- Log in with email and password, or **Continue with Apple / Google**.
- Forgot password with an emailed reset code.
- Change your email (verified with a code) or password.
- Delete your account; it can be restored by logging in within 30 days.
- Every user can only see and change their own data, enforced by Row Level Security in the database.

### Profile
- Edit your name, and upload, replace or remove a profile picture.
- Onboarding ("Tell Us About You"): sex, blood group, birthdate, allergies and medical conditions.

### Medical records
- Create records with a title, date, category and notes.
- Attach **photos and documents**: JPG, PNG, HEIC, PDF, Word, Excel, CSV, text and more.
- Preview attachments in the app, open them in another app, save them to Files, replace or remove them.
- **Search** by title, category, notes, date or file name.

### Basic information
- Allergies and medical conditions with an **Active / Inactive** status.
- **All / Active / Inactive** filters and search.

### Medicines
- Medication name, dosage, times per day (1–4), intake times, start and end date, and instructions.
- Activate or deactivate a medicine; filter and search the list.
- **Reminders** follow the dosage: once daily = 1 notification a day, up to 4 for four times daily. Reminders stop automatically when a medicine is deactivated, deleted or its course ends.

### Appointments and calendar
- Title, doctor, location, start and end time, notes and status (Scheduled / Completed / Cancelled).
- Month calendar with dots on days that have appointments; tap an appointment for its full details, then edit or delete it.
- **Reminder 5 minutes before** every scheduled appointment.
- "Schedule For Today" on the Home screen.

### Settings
- Turn all notifications, medicine reminders or appointment reminders on and off. Settings are saved to your account and restored on every device you log in to.
- Clear all data.

---

## Tech stack

| | |
|---|---|
| Platform | iOS (iPhone) |
| Language / UI | Swift, SwiftUI |
| Architecture | **MVC** (Models, Views, Controllers) |
| Backend | [Supabase](https://supabase.com): Auth, PostgreSQL, Storage |
| SDK | [supabase-swift](https://github.com/supabase/supabase-swift) 2.55+ (Swift Package Manager) |
| Notifications | Apple UserNotifications (local notifications) |
| Fonts | Graduate, DM Sans |

---

## Project structure

```
Synapse/
├── Synapse.xcodeproj
├── Synapse/
│   ├── SynapseApp.swift          App entry point and notification setup
│   ├── Models/                   Data types, one per file (UserProfile, Appointment, MedicineInformation…)
│   ├── Controllers/              Logic: auth, database, storage and notifications
│   │   ├── SupabaseManager.swift Supabase client, table and bucket names
│   │   ├── SessionController.swift
│   │   ├── NotificationController.swift
│   │   └── …one controller per screen or feature
│   ├── Views/                    One file per screen (LoginView, HomeView, CalendarView…)
│   │   ├── Components/           Shared UI: inputs, buttons, headers, fonts and colors
│   │   ├── Popups/               Custom pop-ups and a few standalone screens
│   │   └── Fonts/
│   └── Assets.xcassets
└── supabase/
    ├── schema.sql                Tables, indexes, triggers, RLS and storage policies
    └── SETUP.md                  Full backend setup guide
```

**How MVC is applied:**
- **Models** are plain data types that match the database tables.
- **Views** only show data and forward user actions.
- **Controllers** do the work: they talk to Supabase, validate input and schedule notifications.

---

## Getting started

### Requirements
- A Mac with **Xcode 26** or later.
- An iPhone or simulator running **iOS 26.5** or later.
- A free [Supabase](https://supabase.com) account.

### 1. Clone the project
```bash
git clone https://github.com/mariarosa09/Synapse.git
cd Synapse
open Synapse.xcodeproj
```
Xcode downloads the Supabase package automatically. If it doesn't, use **File → Packages → Resolve Package Versions**.

### 2. Set up Supabase
1. Create a project at [supabase.com/dashboard](https://supabase.com/dashboard).
2. Open **SQL Editor**, paste the contents of `supabase/schema.sql` and click **Run**. This creates every table, security rule and storage bucket.
3. Configure email OTP. Under **Authentication**:
   - turn **Confirm email** on;
   - turn **Secure email change** off;
   - edit the email templates so they show the code (`{{ .Token }}`) instead of a link.
4. Add your own SMTP server (for example Gmail with an App Password) so codes can be sent reliably.

Step-by-step instructions, ready-to-paste email templates and Google/Apple sign-in setup are in **[`supabase/SETUP.md`](supabase/SETUP.md)**.

### 3. Connect the app to your project
In `Synapse/Controllers/SupabaseManager.swift`, set your project's values from **Project Settings → API**:
```swift
static let url = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
static let anonKey = "YOUR-ANON-PUBLIC-KEY"
```
The anon key is meant to be public; your data is protected by Row Level Security. **Never** put the `service_role` key in the app.

### 4. Run
Choose an iPhone or simulator and press **⌘R**. Allow notifications when asked, so reminders work.

---

## Database overview

| Table | Contents |
|---|---|
| `profiles` | Name, email, profile picture path, sex, blood group, birthdate |
| `user_settings` | Notification preferences |
| `basic_information` | Allergies and medical conditions |
| `medicines` | Medicines, dosage and intake times |
| `appointments` | Appointments and their status |
| `medical_records` | Medical records |
| `medical_record_attachments` | File name, type, size and storage path of each attachment |

**Storage buckets** (both private):
- `avatars`: profile pictures.
- `medical-records`: record attachments.

Files are stored in a folder named after the user's ID and shown through short-lived signed URLs.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "A server with the specified hostname could not be found" | The Supabase project is **paused**. Free projects pause after about a week without use. Open the dashboard and click **Restore project**. |
| "Error sending confirmation email" | The SMTP settings are wrong. Check the username, the App Password and the sender email in **Authentication → Emails → SMTP Settings**. |
| The verification email contains a link instead of a code | Edit the email templates to use `{{ .Token }}` (see `supabase/SETUP.md`). |
| Google / Apple button says "not set up yet" | Enable the provider in **Authentication → Sign In / Providers** (see `supabase/SETUP.md`). |
| Reminders don't appear | Allow notifications for Synapse in iOS **Settings → Notifications**, and check the toggles in the app's **Profile → Notifications**. |

---

## Disclaimer

Synapse stores and organizes information that you enter yourself. It is not a medical device and does not replace advice from a healthcare professional. Reminders depend on your device's notification settings; do not rely on Synapse as your only reminder for critical medication.
