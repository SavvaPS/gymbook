# GymSmith Android app: build and Google Play

The Android app is the same `index.html` as the web and iPhone versions, wrapped with Capacitor.
The `android/` folder is the Android Studio project. GitHub builds it, so you don't need Android Studio.

Package name (app ID): `com.gymsmith.app` (permanent, never change it).

## 0. Add the build file (once)

Move `android.yml` from `Claude outputs\Android build` into `gymbook\.github\workflows\`, next to `ios.yml`. Push.

## 1. Build a test app (no Google account needed)

1. On github.com: **Actions**, then **Android build**, then **Run workflow**. Leave **Signed release** unticked.
2. After about 5–10 minutes, open the finished run. Under **Artifacts** at the bottom, download `GymSmith-android-N` and unzip it.
3. It contains `GymSmith-test-N.apk`. Send it to an Android phone (email it to yourself, or Google Drive), tap it, and allow "install unknown apps" when asked. Good for quick checks only.

## 2. Add the upload key to GitHub (once)

The upload key proves that updates come from you. It's in `Claude outputs\Android signing`:

- `gymsmith-upload.p12`: the key itself
- `ANDROID-SIGNING.txt`: its password and the values for GitHub

Back both up somewhere safe and private, like a password manager or an encrypted drive. Never put them in the gymbook folder or on GitHub.
If the key is ever lost, Google can reset it (Play Console, then **App integrity**), but that takes a few days.

On github.com, open the repo, then **Settings**, then **Secrets and variables**, then **Actions**, then **New repository secret**. Add the four secrets listed in `ANDROID-SIGNING.txt`.

## 3. Create the app in Play Console (once your account is verified)

1. play.google.com/console, then **Create app**: name `GymSmith`, language English (United Kingdom), **App**, **Free** (the unlock is an in-app purchase).
2. Accept the declarations.
3. On the dashboard, start **Set up your app**: privacy policy URL `https://savvaps.github.io/gymbook/privacy.html`, app access (no login needed), ads (no), content rating questionnaire, target audience (18+), data safety (no data collected or shared), category Health & Fitness.

## 4. First upload: internal testing

1. Run **Android build** with **Signed release** ticked. Download the `.aab` from Artifacts.
2. Play Console, then **Testing**, then **Internal testing**, then **Create new release**, then upload the `.aab`.
   The first time, accept **Play App Signing** (Google keeps the final signing key; you keep the upload key).
3. Add yourself as a tester, then open the opt-in link on an Android phone and install from Google Play.

## 5. Closed test: 12+ testers for 14 days

1. Create a Google Group, e.g. `gymsmith-testers@googlegroups.com`, set so anyone with the link can join.
2. Play Console, then **Testing**, then **Closed testing**, then create a track. Add the Google Group as the testers. Upload the same `.aab` (or a newer one).
3. Send testers two links: join the group, then the closed-test opt-in link from Play Console.
4. When at least 12 have opted in, the 14-day clock starts. Aim for 15–20, and ask them to keep it installed and open it a few times.
5. After 14 days, **Apply for production** appears on the dashboard.

## Updating the app

Change `index.html` as usual, run **Android build** with **Signed release** ticked, and upload the new `.aab` to the track you want. The build number goes up automatically.
