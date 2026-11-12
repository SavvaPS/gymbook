# GymSmith iPhone app: build and TestFlight

The iPhone app is the same `index.html` as the web version, wrapped with Capacitor.
The `ios/` folder is the Xcode project. GitHub builds it on a Mac, so no Mac is needed.

App ID (bundle ID): `com.gymsmith.app` (permanent, never change it).

## 0. Add the build file (once)

The build instructions live in `.github/workflows/ios.yml`. In File Explorer, inside the `gymbook` folder, create a folder `.github`, inside it a folder `workflows`, and move `ios.yml` into it. Then push.

## 1. Check it builds (works now, no Apple account needed)

1. Push to GitHub.
2. On github.com open the repo, go to **Actions**, then **iPhone build**, then **Run workflow**.
3. Leave **Upload to TestFlight** unticked and press **Run workflow**.
4. A green tick after about 10 minutes means the app builds.

## 2. One-off Apple set-up (once your developer account is approved)

**a. Team ID.** developer.apple.com, then **Account**, then **Membership details**. Copy the 10-character Team ID.

**b. Register the app ID.** developer.apple.com, then **Certificates, Identifiers & Profiles**, then **Identifiers**, then **+**.
Choose **App IDs**, then **App**. Description `GymSmith`, Bundle ID **Explicit** `com.gymsmith.app`. Register (iCloud is switched on in the next step).

**b2. Set up iCloud (for automatic iCloud backups).** Still in **Identifiers**, press **+**, choose **iCloud Containers**, Description `GymSmith`, Identifier `iCloud.com.gymsmith.app`, then Register.
Then open the `com.gymsmith.app` App ID, tick **iCloud**, choose **Include CloudKit support** if asked, press **Edit** (or Configure) next to iCloud, tick `iCloud.com.gymsmith.app`, Continue and Save.

**c. Create the app in App Store Connect.** appstoreconnect.apple.com, then **Apps**, then **+**, then **New App**.
Platform iOS, Name `GymSmith: Workout Tracker`, Primary language English (U.K.), Bundle ID `com.gymsmith.app`, SKU `gymsmith-ios`, User access Full access.

**d. Make an API key for GitHub.** App Store Connect, then **Users and Access**, then **Integrations**, then **App Store Connect API**, then **Team Keys**, then **+**.
Name `GitHub`, Access **Admin** (needed so the build can create its own signing certificate).
Download the `.p8` file. **Apple only lets you download it once.** Keep it somewhere safe and private, never in the repo.
Note the **Key ID** (next to the key) and the **Issuer ID** (top of the page).

**e. Add four secrets to GitHub.** Repo, then **Settings**, then **Secrets and variables**, then **Actions**, then **New repository secret**:

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | Team ID from step a |
| `ASC_KEY_ID` | Key ID from step d |
| `ASC_ISSUER_ID` | Issuer ID from step d |
| `ASC_KEY_P8` | Open the .p8 file in Notepad and paste everything, including the BEGIN and END lines |

Secrets are encrypted. They never show in the code or the build logs, even though the repo is public.

## 3. Send a build to TestFlight

1. **Actions**, then **iPhone build**, then **Run workflow**, tick **Upload to TestFlight**, then **Run workflow**.
2. After 10–30 minutes it appears in App Store Connect under **TestFlight**.
3. The first time, answer the export compliance question if asked. The app already declares it uses no special encryption.
4. In TestFlight, create an **Internal Testing** group, add yourself, and install the **TestFlight** app on your iPhone. Every new upload then arrives there.

Each run gets a new build number automatically. To change the version people see (1.0 to 1.1), change `MARKETING_VERSION` in `ios/App/App.xcodeproj/project.pbxproj`.

## Updating the app

Change `index.html` as usual. The web version updates when you push. For the iPhone app, run the workflow with upload ticked.
