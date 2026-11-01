# Synapse – Supabase setup

Synapse uses Supabase for authentication (email + password with **OTP codes**), the database
(PostgreSQL with Row Level Security) and file storage (two private buckets).
Firebase has been removed completely.

Do the steps below once per Supabase project.

---

## 1. Project URL and key

The app reads them from `Synapse/Controllers/SupabaseManager.swift`:

```swift
static let url = URL(string: "https://<project-ref>.supabase.co")!
static let anonKey = "<anon public key>"
```

Find both in **Dashboard → Project Settings → API**. The file already contains the values of the
project the app was using. The anon key is meant to be public: every table and bucket is
protected by RLS. **Never** put the `service_role` key in the app.

## 2. Database, RLS and storage

Open **Dashboard → SQL Editor → New query**, paste the whole of `supabase/schema.sql` and run it.
It is safe to run again later. It creates:

| Table | What it holds | Owner column |
|---|---|---|
| `profiles` | name, email (mirrors Auth), avatar path, sex, blood group, birthdate, onboarding / deletion flags | `id` = `auth.users.id` |
| `user_settings` | notifications on/off, medicine reminders, appointment reminders | `user_id` |
| `basic_information` | allergies & medical conditions with active / inactive status | `user_id` |
| `medicines` | name, dosage, times per day (1–4), intake times, start/end date, instructions, active | `user_id` |
| `appointments` | title, doctor, location, start/end, notes, status | `user_id` |
| `medical_records` | title, date, category, notes | `user_id` |
| `medical_record_attachments` | file name, extension, MIME type, size, storage path, record id | `user_id` + `record_id` (FK, cascade) |

* Every `user_id` defaults to `auth.uid()`, so the app never sends it.
* RLS policies let a signed-in user select / insert / update / delete **only their own rows**.
  Anonymous users get nothing.
* Triggers create the profile and settings rows when someone signs up, keep `profiles.email`
  equal to the Auth email (including after an email change), and refuse attachments that point
  at another user's record.
* Indexes cover the per-user queries (`user_id` + date / status columns).

Storage buckets (both **private**):

| Bucket | Path | Limit |
|---|---|---|
| `avatars` | `<user id>/avatar-<uuid>.jpg` | 5 MB, images only |
| `medical-records` | `<user id>/<record id>/<attachment id>.<ext>` | 20 MB, any type |

Storage policies allow reading, uploading, updating and deleting only inside the folder named
after your own user id. The app shows private files through **signed URLs** (profile picture,
image thumbnails) or downloads them with the user's session (preview / open in another app).

## 3. Auth settings (OTP codes instead of links)

**Authentication → Sign In / Providers → Email**

* **Enable Email provider**: on
* **Confirm email**: **on**. Users can't use the app until they enter the code.
* **Secure email change**: **off**. The code is sent only to the *new* address, and that one
  code completes the change. With it on, Supabase also emails the old address and expects both
  codes.
* **Email OTP expiration**: e.g. `600` seconds (10 minutes). Codes older than this are rejected
  and the app shows "That code is invalid or has expired… tap Resend Code".
* **Email OTP length**: `6` (the app accepts 6–10 digits).

**Authentication → URL Configuration**: no redirect URLs are needed; the app never uses links.

## 4. Email templates (show the code, not a link)

**Authentication → Emails → Templates**. Replace the body of these three templates so they
contain `{{ .Token }}` and **no** `{{ .ConfirmationURL }}` link.

**Confirm signup**: subject `Your Synapse verification code`
```html
<h2>Welcome to Synapse</h2>
<p>Enter this code in the app to verify your email address:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
<p>The code expires soon. If you didn't create a Synapse account, ignore this email.</p>
```

**Change Email Address**: subject `Confirm your new Synapse email`
```html
<h2>Confirm your new email</h2>
<p>Enter this code in Synapse to change your email to {{ .NewEmail }}:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
```

**Reset Password**: subject `Your Synapse password reset code`
```html
<h2>Reset your password</h2>
<p>Enter this code in Synapse to choose a new password:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
<p>If you didn't ask for this, you can ignore this email.</p>
```

Flows that use them:

| Flow | App call | Email template |
|---|---|---|
| Sign up → OTP screen | `auth.signUp` → `auth.verifyOTP(type: .signup)` | Confirm signup |
| Resend code | `auth.resend(type: .signup / .emailChange)` | same template |
| Login with unverified email | sends a new code, opens the OTP screen | Confirm signup |
| Change email | `auth.update(user: email)` → `auth.verifyOTP(type: .emailChange)` | Change Email Address |
| Forgot password | `auth.resetPasswordForEmail` → `auth.verifyOTP(type: .recovery)` → `auth.update(password)` | Reset Password |

## 5. Email delivery

Supabase's built-in mailer is limited to a few emails per hour and is meant for testing.
For real use, set up your own SMTP server under **Authentication → Emails → SMTP Settings**
and raise the limits in **Authentication → Rate Limits**. The app shows a clear message when
the rate limit is hit and enforces a 60-second resend cooldown.

## 6. Xcode

* The project now links only the `supabase-swift` package (2.55+). The Firebase package,
  `GoogleService-Info.plist`, `firebase.json` and the Firestore / Storage rules were removed.
* If Xcode still shows old packages: **File → Packages → Reset Package Caches**, then
  **Resolve Package Versions**.
* Minimum iOS version is unchanged (project setting).

## 6b. Google and Apple sign-in

The Login screen has **Continue with Apple** and **Continue with Google**. Both open a secure
in-app web sheet (Supabase OAuth). After signing in, the user returns to the app through the
redirect URL `synapse://login-callback` (set in `SupabaseManager.swift`). New users get a profile
with the name and email from Google or Apple, then continue to "Tell Us About You". Until a
provider is enabled, its button shows "…sign-in isn't set up yet".

**Redirect URL (both providers):** Authentication → URL Configuration → Redirect URLs →
Add URL → `synapse://login-callback` → Save URLs.

**Google logo on the button:** download the official "G" logo from Google's sign-in branding
guidelines (developers.google.com/identity/branding-guidelines). In Xcode, open
`Assets.xcassets → GoogleLogo` and drag the image (PNG or PDF/SVG) into the slot. Until then the
button shows a plain "G" symbol.

**Google** (free):
1. In Google Cloud Console (console.cloud.google.com) create a project, then
   **APIs & Services → OAuth consent screen** (External, app name "Synapse", your email).
2. **Credentials → Create credentials → OAuth client ID → Web application.**
   Under *Authorized redirect URIs* add
   `https://cmgdfrryzdsjmqfqddks.supabase.co/auth/v1/callback`.
3. Copy the **Client ID** and **Client secret**.
4. Supabase → **Authentication → Sign In / Providers → Google** → enable, paste both, Save.
5. While the consent screen is in "Testing", add the Google accounts you test with under
   *Test users*.

**Apple** (needs a paid Apple Developer Program membership):
1. developer.apple.com → Certificates, IDs & Profiles → **Identifiers**: create a
   **Services ID** (e.g. `ph.edu.mseuf.synapse.signin`), enable *Sign in with Apple*, and set
   *Return URLs* to `https://cmgdfrryzdsjmqfqddks.supabase.co/auth/v1/callback`.
2. **Keys** → create a key with *Sign in with Apple* → download the `.p8` file and note the
   Key ID and your Team ID.
3. Supabase → **Authentication → Sign In / Providers → Apple** → enable, enter the Services ID
   as Client ID, and generate the secret from the Team ID, Key ID and `.p8` key as the form
   describes. Save. (Apple secrets expire after 6 months; generate a new one then.)

Accounts created with Google or Apple have no Synapse password, so the Change Password and
Change Email screens explain that the password and email are managed by that provider.

## 7. Deleted accounts (optional server job)

"Delete Account" flags the profile (`deleted = true`, `deleted_at = now()`) and signs the user out.
Logging in again within 30 days restores it; after that the app refuses the login.
Permanently erasing old accounts needs a server-side job (the app can't delete Auth users).
Example with the `pg_cron` extension (Database → Extensions → enable `pg_cron`), run as
`postgres` in the SQL Editor:

```sql
select cron.schedule('purge-deleted-synapse-accounts', '0 3 * * *', $$
  delete from auth.users
  where id in (select id from public.profiles
               where deleted and deleted_at < now() - interval '30 days');
$$);
```

Deleting the Auth user cascades to every table. Files in the buckets must be removed through the
Storage API (for example from an Edge Function using the service role) because Supabase does not
allow deleting `storage.objects` rows with SQL.

## 8. Test checklist

1. **Sign up** with a real address → OTP screen appears, an email with a 6-digit code arrives
   (no link). Wrong code → error. Wait past the expiry → "expired" error. **Resend Code** (after
   60 s) → new code works, old one doesn't. Correct code → "Tell Us About You".
2. **RLS**: in the SQL editor run `select * from medicines;` as `anon` (Role selector) → 0 rows.
   A second test account never sees the first account's data.
3. **Login / logout**: Logout opens the custom pop-up; Cancel closes it; Logout signs out and shows
   the Login screen. Logging in with an unverified account sends a new code and opens the OTP screen.
4. **Forgot password**: code arrives → new password saved → signed in.
5. **Profile**: change name → updates on Home and Profile. Upload a picture → file appears in
   Storage → `avatars/<uid>/…`, `profiles.avatar_path` is set; restart the app / log out and in →
   picture is still shown. Replace → old file deleted. Remove → default picture.
6. **Change email** (Data & Account or Edit Profile) → code to the new address → after verifying,
   both Auth and `profiles.email` show the new address.
7. **Basic information**: add, edit, delete, tap the status badge (or swipe) → All / Active /
   Inactive filters update immediately and the rows change in `basic_information`.
8. **Medicines**: the pop-up shows "N reminders a day" and the reminder times for 1, 2, 3 and 4
   times per day (defaults 8:00 · 8:00/20:00 · 8:00/14:00/20:00 · every 4 h from 8:00). Turn on
   "Set intake times myself", set a dose 2 minutes ahead, lock the phone → the reminder arrives.
   Deactivating, deleting or ending a medicine removes its reminders. Search + filters combine
   (e.g. "Active" + "para").
9. **Appointments**: create one starting in 7 minutes → a notification arrives 5 minutes before.
   Edit the time → reminder moves; mark completed or delete → reminder cancelled; past
   appointments never get a reminder. Calendar shows a dot on the day; tapping an appointment shows
   all details with Edit / Delete.
10. **Medical records**: search by title, category, notes or file name. Attach a photo (HEIC/PNG/JPG),
    a PDF, a .docx, an .xlsx, a .csv and a .txt → save → rows in `medical_record_attachments`,
    files in `medical-records/<uid>/<record id>/`. Restart the app → files listed with their
    original names and icons; tap to preview; swipe → Open In… / Replace / Delete.
11. **Settings**: toggle All / Medicine / Appointment notifications → restart or log in again → the
    toggles are restored from `user_settings`. Turning reminders off keeps all medicines and
    appointments. There is no appearance option.
