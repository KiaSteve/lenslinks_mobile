# LensLinks Mobile

Android app for **LensLinks** (version 1.0.0, "Model One"). It sends the phone's
camera and microphone over Wi-Fi to the LensLinks Windows app, which turns them
into a virtual webcam and can record them. See the `lenslinks` project for the
Windows side and full instructions.

## Use

1. Put the phone and the PC on the same Wi-Fi network.
2. Open LensLinks Mobile and allow the camera and microphone permissions.
3. The phone screen shows a 16-character **pairing key**. In the Windows app
   press **Scan**, pick the phone and type that key once; the PC remembers it.
   Tap **Make a new key** if the key ever leaks (the Windows app then needs the
   new key).

## Network ports

| Port | Protocol | Purpose |
| --- | --- | --- |
| 5000 | UDP | Discovery (`LENSLINKS_DISCOVER` / `LENSLINKS_RESPONSE`) |
| 5001 | TCP | Video (4-byte length + JPEG per frame) |
| 5002 | TCP | Audio (16-bit mono PCM, 44.1 kHz) |

Ports 5001 and 5002 require the pairing key and are **encrypted** (ChaCha20 with
HMAC-SHA256 integrity checks, new session keys for every connection; the key is
never sent). A PC that tries a wrong key 5 times is blocked for a minute. The key
is stored in the app's private storage. See the `lenslinks` README for the
full description and its limits (no forward secrecy, no independent audit).

## Build and run

```powershell
flutter devices
flutter run -d <device-id> --release
```

For a release APK: `flutter build apk --release`.

The application ID is `com.KiaSteve.lenslink`. Release builds are signed with
your own key when `android\key.properties` exists (it points to a keystore kept
outside the project; both are ignored by Git). Without it they fall back to the
debug key, which is fine for testing but not for publishing. Create the key once:

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\lenslinks-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lenslinks
```

then create `android\key.properties` with `storePassword`, `keyPassword` (the same
password), `keyAlias=lenslinks` and `storeFile=C:/Users/<you>/lenslinks-release.jks`.
**Back up the keystore file and its password**: without them you cannot publish
updates that install over earlier versions.
