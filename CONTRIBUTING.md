# Setting up Trainlog from zero

This guide gets the app running on a fresh machine — building, running, testing,
and shipping the iOS build to TestFlight via the GitHub Actions CI.

## 1. Prerequisites

The project manages its toolchain with **mise** (`mise.toml`). Once mise is
installed, running `mise install` inside the repo installs the pinned tools
(including **Flutter** and the Node-based tools) automatically.

- **mise** — <https://mise.jdx.dev>. On macOS (Homebrew):
  ```bash
  brew install mise
  ```
  Then, in this repo:
  ```bash
  mise install   # installs the pinned toolchain from mise.toml
  # ensure mise shims are on your PATH:
  eval "$(mise activate zsh)"   # for zsh; adjust for your shell
  ```
  The Flutter version is pinned to **`3.47.7-stable`** (project revision
  `abaf9c523780a608bd46686fd5e53740a07077f8`), which satisfies the project's
  Dart `^3.8.0` constraint. Github Actions CI pins the same version so local and
  CI builds match.
- **Xcode** (macOS only, for iOS builds). The project has been built with
  Xcode 27.2 locally. CI pins its own Xcode version on the macOS runner.
- **CocoaPods** — `sudo gem install cocoapods`.
- **Ruby + Bundler** — required for fastlane. Install fastlane dependencies inside
  the `fastlane/` directory:
  ```bash
  cd fastlane
  bundle install
  ```
- **Git** and a GitHub account with access to this repository.

> **Sanity check:** after setup, run `flutter doctor` and confirm the iOS and
> Android toolchains report as ready.

## 2. Local build & run

Android / iOS / desktop / web:

```bash
flutter pub get    # fetch dependencies
flutter run        # run on the connected device or simulator
```

- **iOS simulator**: `open -a Simulator`, then run `flutter run`.
- **Release build check** (framework + pods, without signing):
  ```bash
  flutter build ios --release --no-codesign
  ```

## 3. Environment / config files

- `l10n.yaml`, `.metadata`, `mise.toml`, and `analysis_options.yaml` are committed;
  no manual action is needed.
- `lib/firebase_options.dart` and `ios/Runner/GoogleService-Info.plist` are
  **gitignored**. For a build with Crashlytics/Analytics enabled, place the plist
  in `ios/Runner/` locally, or supply it via the `GOOGLE_SERVICE_INFO` CI secret.

## 4. Running tests

```bash
flutter test
```

---

# Releasing the iOS app to TestFlight

The release pipeline is a **manually-triggered GitHub Actions workflow**. It uses
**fastlane** to build a signed Release `.ipa` and upload it to TestFlight, with
code signing handled by **fastlane match**.

## One-time setup

### 1. Confirm Apple Developer membership

- Go to <https://developer.apple.com/account> → **Membership details**.
- Confirm the **Team ID** is `4F2M6L6HAY`.
- You need an **Account Holder** or **App Manager** role, and the paid
  **Apple Developer Program** membership must be active to create distribution
  certificates and upload to TestFlight.

### 2. Register the bundle ID

- App Store Connect → **Certificates, IDs & Profiles** → **Identifiers** → **+**.
- Choose **App IDs** → **App**, set the bundle ID to exactly **`me.trainlog.ios`**
  (no wildcard), and register the capabilities the app needs.

### 3. Create the app in App Store Connect

- <https://appstoreconnect.apple.com> → **My Apps** → **+** → **New App**.
- Set **Platform** = iOS, a name (e.g. "Trainlog"), primary language,
  **bundle ID** = `me.trainlog.ios`, and a unique **SKU** (e.g. `trainlog-ios`).
- Complete the required **Export Compliance** / **Privacy** details so TestFlight
  builds can be distributed.

### 4. Create an App Store Connect API key (for CI uploads)

- App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API**
  → **Generate API Key**.
- **Key name**: e.g. `trainlog-ci`; **Access**: App Manager.
- Download the `.p8` (only offered once) and record:
  - **Key ID** → `APP_STORE_CONNECT_KEY_ID`
  - **Issuer ID** → `APP_STORE_CONNECT_ISSUER_ID`
  - The `.p8` private key contents → `APP_STORE_CONNECT_KEY`
- Never commit the `.p8`. Store the three values only as GitHub secrets.

### 5. Generate & encrypt the signing certs with fastlane match

- Create a **private** git repo for the certs, e.g. `trainlog-certs`.
- On one Mac, generate and store the Distribution cert + App Store profile:
  ```bash
  cd fastlane
  bundle install
  export MATCH_GIT_URL="git@github.com:YOU/trainlog-certs.git"   # or https + token
  export MATCH_PASSWORD="a-strong-passphrase-you-keep-secret"
  bundle exec fastlane match appstore
  ```
- match will request a **Distribution certificate** from Apple, create an **App Store
  provisioning profile** for `me.trainlog.ios`, **encrypt** both with `MATCH_PASSWORD`,
  and push them to `trainlog-certs`. Every new machine (including CI) imports these in
  `readonly` mode without re-issuing certs.

### 6. (Recommended) Cache the fastlane/Apple session

First uploads may prompt for a 2FA code. Run `fastlane spaceauth` once and export the
resulting env var so CI never hits the interactive prompt, or use an
app-specific password via `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`.

## GitHub secrets

Add these under **repo → Settings → Secrets and variables → Actions**:

| Secret | Purpose | Source |
|--------|---------|--------|
| `MATCH_GIT_URL` | Private certs repo URL | Step 5 |
| `MATCH_PASSWORD` | match encryption passphrase | Step 5 |
| `APP_STORE_CONNECT_KEY_ID` | API key ID | Step 4 |
| `APP_STORE_CONNECT_ISSUER_ID` | API key issuer ID | Step 4 |
| `APP_STORE_CONNECT_KEY` | API key private key (`.p8` contents) | Step 4 |
| `DEVELOPMENT_TEAM_ID` | Apple team `4F2M6L6HAY` | Membership |
| `FIREBASE_OPTIONS_DART` | base64 of `lib/firebase_options.dart` | Required — `main.dart` imports it and the build fails to compile without it. Base64 it with `base64 < lib/firebase_options.dart` |
| `GOOGLE_SERVICE_INFO` | base64 `ios/Runner/GoogleService-Info.plist` | Only needed once Firebase is initialized at runtime (currently `_initFirebase()` is commented out in `main.dart`) |

## Triggering a release

1. Open **Actions** → **Release iOS (TestFlight)**.
2. **Run workflow** (optionally add release notes).
3. Watch the run: it checks out the code, picks up the signing cert, builds the
   `.ipa`, uploads to TestFlight, and reports the build number.
4. TestFlight processes the upload. Once it appears, add testers / a group and let
   them install.

## Workflow internals (for reference)

- `.github/workflows/release-ios.yml` — the GitHub Actions pipeline.
- `fastlane/Fastfile` — the `release_ios` lane (match + gym + pilot).
- `fastlane/Appfile` — bundle id (`me.trainlog.ios`) + team id (`4F2M6L6HAY`).
- `fastlane/Matchfile` — match storage/type/readonly config.
- `fastlane/Gemfile` — pinned fastlane version.