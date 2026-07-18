# Install ABS Trainer on iPhone via Xcode and free Apple ID

## Goal
Install the personal MVP build on the user's iPhone without TestFlight, Ad Hoc, or paid Apple Developer Program.

## Requirements
```text
Mac with current macOS
Xcode from Mac App Store
iPhone + cable
Apple ID
Internet connection
```

## Steps
1. Install Xcode from Mac App Store and open it once.
2. Add Apple ID: `Xcode → Settings → Accounts → + → Apple ID`.
3. Create Xcode project: `File → New → Project → iOS → App`; Product Name `AbsTrainer`; Interface `SwiftUI`; Language `Swift`.
4. Copy files from `ios/AbsTrainer/Sources/AbsTrainer/` into the Xcode project target.
5. Configure signing: Team = your Apple ID; Bundle Identifier = `com.ezaretskiy.abstrainer`; Automatically manage signing = enabled.
6. Connect iPhone by cable and select it as the run destination.
7. If prompted, enable Developer Mode: `Settings → Privacy & Security → Developer Mode → On`.
8. Click `Run ▶` in Xcode.

## Free Apple ID limitation
Apps installed with a free Apple ID can expire, often around 7 days. Re-run from Xcode to reinstall.

## Troubleshooting
```text
No signing certificate       → Check Xcode Accounts and select Team.
Bundle identifier unavailable → Change Bundle Identifier suffix.
Developer Mode disabled      → Enable Developer Mode on iPhone and restart.
Trust developer              → iPhone Settings → General → VPN & Device Management.
Build errors after copy      → Ensure all .swift files are included in target membership.
```

## Artifact links
- Source skeleton: `ios/AbsTrainer/`
- Build notes: `ios/AbsTrainer/BUILD_NOTES.md`
