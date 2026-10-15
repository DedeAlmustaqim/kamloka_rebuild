# KAMLOKA Android Release Build

This guide prepares a locally signed release APK for device testing and an Android App Bundle (AAB) for Google Play Console.

## 1. Create the upload keystore (Windows)

Run this from the repository root in Command Prompt or PowerShell. Install a JDK and make sure `keytool` is available on PATH.

```powershell
keytool -genkey -v -keystore android\app\kamloka-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kamloka-upload
```

Choose strong passwords and store them securely. Keep a secure backup of the `.jks` file and its passwords. **Never commit or send the keystore or passwords to anyone.** The repository's Android gitignore excludes `*.jks` and `key.properties`.

## 2. Create the local signing properties

Create `android/key.properties` locally (do not commit it):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=kamloka-upload
storeFile=kamloka-upload-key.jks
```

Replace the password placeholders with the values you chose. Since `storeFile` is resolved relative to the Android app module, keep the keystore at `android/app/kamloka-upload-key.jks`.

## 3. Check dependencies and code

From the repository root:

```powershell
flutter doctor
flutter clean
flutter pub get
flutter analyze
flutter test
```

Fix any blocking errors before creating release artifacts. Review warnings rather than assuming a successful build means every feature has been tested.

## 4. Build a release APK for device testing

```powershell
flutter build apk --release
```

Output:

`build\app\outputs\flutter-apk\app-release.apk`

Install on a connected Android device:

```powershell
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

If a debug build with the same application ID is already installed and Android reports a signature conflict, uninstall that build first. Uninstalling removes app-local data, so back up any test data you need.

## 5. Build the AAB for Play Console

```powershell
flutter build appbundle --release
```

Output:

`build\app\outputs\bundle\release\app-release.aab`

Upload the AAB to **Play Console → Testing → Internal testing**. Complete the Play Console setup, app signing, store listing and required declarations as prompted. For a first upload, enable Google Play App Signing and retain a secure backup of the upload key.

## 6. Versioning

Current version in `pubspec.yaml` is `1.0.0+1` (version name 1.0.0, version code 1). This is suitable for the first upload if no artifact has been uploaded before. For each subsequent Play Console release, increase the build number after `+`, for example `1.0.0+2`.

## 7. GitHub Actions: CI and signed AAB artifact

Workflow file: `.github/workflows/kamloka-ci.yml`.

- Pushes and pull requests targeting `feature/kamloka-pro-travel-reports` run `flutter analyze` and `flutter test`.
- A manually started workflow also builds a signed release AAB after validation succeeds.
- The AAB is published as a GitHub Actions artifact named `kamloka-release-aab` for 14 days.
- This first stage does **not** upload directly to Google Play. Play upload automation will be added after the Google Play Developer API service account is configured and tested.

### Add GitHub Actions secrets

Open the repository on GitHub → **Settings → Secrets and variables → Actions → New repository secret**. Add these four secrets:

- `UPLOAD_KEYSTORE_BASE64`: base64 representation of the exact `android/app/kamloka-upload-key.jks` upload keystore.
- `KEYSTORE_PASSWORD`: keystore password.
- `KEY_PASSWORD`: password for alias `kamloka-upload`.
- `KEY_ALIAS`: `kamloka-upload`.

On Windows PowerShell, copy the keystore's base64 value to the clipboard without printing it in the terminal:

```powershell
$bytes = [System.IO.File]::ReadAllBytes("android\app\kamloka-upload-key.jks")
[Convert]::ToBase64String($bytes) | Set-Clipboard
```

Paste that clipboard value into the `UPLOAD_KEYSTORE_BASE64` secret. Do not paste it into source code, issues, chat, or a committed file. Keep the original keystore and passwords backed up securely. Never regenerate the keystore just to configure CI.

### Run the signed AAB workflow

1. Add and verify all four repository secrets.
2. Open the GitHub repository's **Actions** tab.
3. Select **KAMLOKA CI**, click **Run workflow**, and choose `feature/kamloka-pro-travel-reports`.
4. Wait for both `Analyze and test` and `Build signed release AAB` to pass.
5. Open the completed run and download the `kamloka-release-aab` artifact. Extract the ZIP and upload `app-release.aab` to Play Console when ready.

If validation fails, fix the reported issues before using the release artifact. Never share Actions logs that may contain sensitive information; secrets should be masked by GitHub, but avoid printing them.

## 8. Release checklist

- [ ] Keystore and passwords backed up securely, outside the repository.
- [ ] `android/key.properties` exists locally and is not tracked by Git.
- [ ] `flutter analyze` reviewed and `flutter test` completed.
- [ ] Release APK installs and launches on a real device.
- [ ] Camera permissions, photo capture/save, orientation, location watermark, PDF export, trip/location deletion, and Pro/free behavior tested.
- [ ] AAB build completes and is uploaded to Internal testing.
- [ ] Internal tester access and Play Console pre-launch report reviewed.

**Important:** A successful build is not proof that the app has passed device testing. Do not distribute the APK or promote the AAB to production until the release checklist and Play Console requirements have been reviewed.
