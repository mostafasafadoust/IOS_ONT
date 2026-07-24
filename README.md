# Tivan ONT iOS Bootstrapper

SwiftUI iPhone version of the Windows Huawei ONT Bootstrapper logic.

## What it does

- Opens the Huawei ONT web UI on `192.168.100.1`.
- Logs in to the ONT panel.
- Creates/configures the WAN as PPPoE, VLAN `800`, service `TR069_VOIP_INTERNET`.
- Sets ACS to `https://yaraacs.tci.ir` with inform interval `30`.
- Tries to enable local Telnet/SSH from the web UI.
- Uses Telnet to copy `hw_ctree.xml` to `hw_default_ctree.xml`, chmod it, sync it, and compare both files.

The Windows network-card/IP switching stage is intentionally removed because the iPhone path assumes L3 access to the ONT is already active.

## GitHub path without a Mac

This repository includes `.github/workflows/ios-build.yml`.

1. Push this folder to a GitHub repository.
2. Open the repository on GitHub.
3. Go to **Actions**.
4. Run **iOS build** manually, or push to `main`.
5. GitHub builds the app on a hosted macOS runner and uploads a simulator `.app` artifact.

This proves the Xcode project compiles without needing a local Mac.

If ChatGPT shows `Failed to add connector link`, ignore the connector path and use the manual Windows path in `Docs/Push-To-GitHub-Windows.md`.

## Installing on a real iPhone

GitHub Actions can build the source, but installing on a real iPhone still needs Apple signing.

Recommended next step:

- Add an Apple Developer account.
- Add App Store Connect API secrets to GitHub.
- Add a second GitHub workflow for TestFlight or AdHoc export.

Until signing is configured, the workflow only produces a simulator build artifact.

## Local ONT test notes

The GitHub runner cannot reach the ONT on your local network. Real ONT testing must happen on an iPhone connected to the ONT network.

Required iOS permission:

- Local Network permission must be accepted when iOS asks.

Default ONT target:

- Host: `192.168.100.1`
- Web user: `admin`
- Web password: `adminHW`
- Telnet user: `root`
- Telnet password fallback list: `adminHW`, then `admin`
