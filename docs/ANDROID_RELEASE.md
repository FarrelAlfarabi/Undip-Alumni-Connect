# Android release signing and app ID

## App ID
`com.lingkaran.app` (set in `android/app/build.gradle.kts`). Change it only
before the first APK reaches anyone: a different ID is a different app to
Android, so there is no in place update and users lose local data.

## One time: make your release key (you do this, on your own computer)
Keep this file and its passwords safe. If you lose them you can never ship an
update that installs over the old app.

    keytool -genkeypair -v -keystore lingkaran-release.jks -alias lingkaran \
      -keyalg RSA -keysize 2048 -validity 10000

Back it up somewhere other than this repo (password manager, private drive).
Never commit it (`*.jks` is already git ignored).

## Build on GitHub (recommended)
Add four repository secrets (Settings > Secrets and variables > Actions):
- `ANDROID_RELEASE_KEYSTORE_BASE64`: `base64 -w0 lingkaran-release.jks`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS` (`lingkaran` above)
- `ANDROID_KEY_PASSWORD`

The APK job then signs with it and refuses to fall back to the debug key. With
no secrets the job still runs but warns: that APK is not for real users.

## Build on your computer
Create `android/key.properties` (git ignored):

    storeFile=../lingkaran-release.jks
    storePassword=...
    keyAlias=lingkaran
    keyPassword=...

then `flutter build apk --release`. Set `REQUIRE_RELEASE_KEY=true` to make the
build fail instead of falling back to the debug key.
