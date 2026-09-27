# Windows development

Windows can edit, test pure text tooling, commit, push, inspect Actions, and download artifacts. It cannot run Xcode, an iOS simulator, archive an iOS app, or sign an IPA.

## Setup

Install Git and an editor such as Visual Studio Code. GitHub CLI is optional.

```powershell
git clone https://github.com/cuonqisme/MiMaps.git
cd MiMaps
git switch -c feature/my-change
```

Edit files, then:

```powershell
git add -A
git commit -m "feat: describe the change"
git push -u origin feature/my-change
```

Open the repository on GitHub and inspect **Actions → iOS CI**. For release artifacts, manually trigger **iOS Release**. Download the artifact zip from the completed run. A signed IPA appears only when Apple signing secrets are configured and `signed` is selected.
