# Push To GitHub From Windows

Use this when the ChatGPT GitHub connector fails with:

```text
Failed to add connector link
```

That error only means ChatGPT could not connect to GitHub. The project can still be uploaded to GitHub normally.

## Option A: GitHub Website

1. Open GitHub.
2. Create a new repository, for example `TivanONTiOS`.
3. Keep it empty. Do not add README, `.gitignore`, or license from GitHub.
4. Extract the latest `TivanONTiOS-v*.zip`.
5. Open the extracted `TivanONTiOS` folder.
6. Drag all contents of that folder into the GitHub upload page.
7. Commit the upload.
8. Go to **Actions**.
9. Run **iOS build**.

Expected result:

- GitHub starts a macOS build.
- If the project compiles, an artifact named `TivanONTiOS-simulator-app` is created.

## Option B: PowerShell With Git

Install Git for Windows first if `git --version` does not work.

From PowerShell:

```powershell
cd "$env:USERPROFILE\Downloads\TivanONTiOS"

git init
git add .
git commit -m "Initial iOS ONT bootstrapper"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/TivanONTiOS.git
git push -u origin main
```

Then open GitHub:

1. Go to the repository.
2. Open **Actions**.
3. Run **iOS build**.

## Important

GitHub Actions can compile the app without a Mac, but it cannot test the real ONT because the runner is not on your local modem network.

For a real iPhone install, the next step is Apple signing:

- Apple Developer account.
- GitHub secrets for certificate/profile or App Store Connect API.
- A second workflow for TestFlight or AdHoc export.
