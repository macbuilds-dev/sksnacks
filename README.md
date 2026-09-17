# apps/sksnacks

SHSnacks client app inside parent **baithak** (M3).

## First-time platform folders

Agar `android/` / `ios/` missing hon (CLI sandbox):

```bash
cd apps/sksnacks
flutter create --org com.baithak --project-name sksnacks --platforms=android,ios .
```

Phir:

```bash
flutter pub get
flutter run
```

## Brand

- Active brand: `brands/sksnacks/brand.yaml`
- Copy `_template` for next client under `apps/<brand>/`

## Firestore sync

Create a **Native** Firestore database for Firebase project `baithak-macbuilds-dev` before cloud sync works. Local Drift + backup work offline without it.
