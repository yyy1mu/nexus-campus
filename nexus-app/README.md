# Nexus Campus Android

Native Android client for the Nexus Campus Spring Boot REST API.

## Stack

- Kotlin and Jetpack Compose
- ViewModel, StateFlow, coroutines and unidirectional data flow
- Navigation Compose
- Hilt with KSP
- Retrofit, OkHttp and Gson
- Gradle Kotlin DSL and Compose BOM

The app is organized into `core/network`, `data`, `feature` and `ui` packages. Compose screens do
not access HTTP clients directly; they render `MainUiState` exposed by `MainViewModel`.

## Build

```bash
./gradlew lintDebug testDebugUnitTest assembleDebug
```

The APK is written to `app/build/outputs/apk/debug/app-debug.apk`.

## Physical device testing on the same network

Start the Docker Compose stack from the repository root. The Android device and development Mac
must use the same LAN. Build with the Mac LAN address:

```bash
./gradlew assembleDebug -PNEXUS_BASE_URL=http://192.168.66.73/
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.novus.nexus/.MainActivity
```

The current debug default is `http://192.168.66.73/`. Override it whenever the Mac address changes.
No `adb reverse` mapping is required. Release builds reject cleartext HTTP and should use an HTTPS
deployment URL.
