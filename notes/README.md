1. To export apk/appbundle
   flutter build apk --release --analyze-size --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols --no-tree-shake-icons

2. Never rely on client-side trust.
3. Do not lose your keystore and symbol files (Important for crash reports) — store them securely and maintain reliable backups elsewhere.
