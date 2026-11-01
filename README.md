# Records Portal — Native Flutter Android App

Native Android application replicating the **Student & Faculty Records Portal** (`index.html`) paired with an **offline-first QR + NFC Classroom Scanner** and background JSON batch sync to Google Apps Script (`code.gs`).

---

## 1. Deploy the Updated Google Apps Script (`code gs.txt`)

1. Open your Google Apps Script project and paste the updated contents of `code gs.txt` into `Code.gs`.
2. Ensure the account deploying the script has edit access to your scan log workbook:
   - **Scan Workbook ID**: `12DvradQOqCeswwKMtdx7jaIKDRjMUuxWRRD_p1WBCQQ`
   - **Reference Tab**: `"Reference"` (Column C holds your selectable Subjects)
   - **Attendance Tab**: `"Attendance Log"` (`[Log_ID, Timestamp, Student_ID, Subject]`)
   - **Recitation Tab**: `"Recitation_Log"` (`[Log_ID, Timestamp, Student_ID, Subject, Points_Awarded=1]`)
3. Click **Deploy → Manage deployments → Edit (pencil icon) → New version → Deploy** (or **New deployment → Web app**):
   - **Execute as**: `Me`
   - **Who has access**: `Anyone`
4. Copy the generated `https://script.google.com/macros/s/.../exec` URL.

---

## 2. Configure & Build the Flutter Android App

1. *(Optional)* Paste your `/exec` URL into `lib/config/app_config.dart` (`defaultScriptUrl`), **or** configure it directly inside the app by tapping the **⚙️ gear icon** on the top-left of the Login screen.
2. Fetch packages and build the APK:
   ```powershell
   flutter pub get
   flutter run
   # Or build a standalone Android APK:
   flutter build apk --release
   ```
