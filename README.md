# SHSnacks

Shop counter app for **SHSnacks**.

This is a **separate** app repo (`macbuilds-dev/sksnacks`).  
Daily source of truth stays in the parent monorepo — this remote is the release / CI mirror.

**Powered by [Baithak](https://github.com/macbuilds-dev/baithak)**

---

## APK

→ [Releases](https://github.com/macbuilds-dev/sksnacks/releases) (`latest`)

- **Private repo** → Releases are **not** public (only people with repo access).  
- Download the **`.apk`** only. GitHub always also lists Source code zip/tar (cannot disable) — ignore those.  
- CI builds **release · arm64-v8a** (`--split-per-abi`) so size stays phone-like (~local release), not a fat debug APK.

Every push rebuilds and updates `latest`.


---

## Run locally

```bash
flutter pub get
flutter run
```

Android package: `com.baithak.sksnacks`
