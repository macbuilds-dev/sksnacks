Component: Dart SDK not configured + no device picker

## Cause
1. IDE opened **monorepo root** `baithak` — Flutter module is nested at `apps/sksnacks`.
2. Dart/Flutter SDK path not set in IDE settings.
3. Run config missing → "Add Configuration" only.

Flutter SDK on this machine: `/Users/mac/flutter`  
Dart SDK: `/Users/mac/flutter/bin/cache/dart-sdk`

## Fix A — Cursor / VS Code (recommended)
1. Install extensions: **Dart** + **Flutter** (Dart Code).
2. Repo already has `.vscode/settings.json` + `launch.json`.
3. Cmd+Shift+P → **Developer: Reload Window**.
4. Bottom-right / status: pick device (iPhone simulator).
5. Run config **sksnacks** from Run and Debug.

Or terminal:
```bash
open -a Simulator
cd /Users/mac/mac/baithak/apps/sksnacks
flutter devices
flutter run
```

## Fix B — Android Studio / IntelliJ
1. Preferences → Languages & Frameworks → **Flutter**
   - Flutter SDK path: `/Users/mac/flutter`
2. Languages & Frameworks → **Dart**
   - Dart SDK: `/Users/mac/flutter/bin/cache/dart-sdk` (usually auto from Flutter)
3. **File → Open** → open folder `apps/sksnacks` (not only monorepo root), OR
   File → Project Structure → Modules → add Flutter module pointing at `apps/sksnacks`.
4. Wait for indexing; device dropdown appears.
5. Start simulator: Xcode → Open Developer Tool → Simulator, or `open -a Simulator`.

## Fix C — if device still missing
```bash
flutter doctor
xcrun simctl list devices booted
flutter emulators
open -a Simulator
flutter run -d booted
```

iPhone 17 Pro Max must show in `flutter devices` before IDE can list it.
