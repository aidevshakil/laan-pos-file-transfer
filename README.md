# LAAN POS — Background Upload / Download Module

A Flutter feature module for a POS SaaS that moves large files (product catalog imports, audit report exports) between the device and a REST server. Transfers survive screen changes, app minimisation and flaky networks.

Server: `http://108.136.142.112:90` (`/register`, `/token`, `/get`, `/upload`, `/delete`).

---

## 1. Features

| Requirement | Implementation |
| --- | --- |
| Pick a large file (>50 MB) | `file_picker` (any type). A **Create 50 MB test CSV** button builds a realistic catalog on-device for quick testing. Empty or unreadable files are rejected before upload. |
| Multipart upload | `POST /upload` with `multipart/form-data` (`file` field) via Dio, with a Bearer token. |
| Real-time progress | Percentage, progress bar, bytes, speed and ETA on the Upload screen, the Transfers dashboard and the global banner. |
| Continues in background | Transfers live in a root-level `TransferBloc`. While any transfer runs, an Android **`dataSync` foreground service** keeps the process alive (see §3). |
| Persistent completion notification | Result notification on a high-importance channel that stays in the tray until tapped. Tapping it opens the relevant screen: Upload screen (upload done), a *Download Complete* page with **Open File** (download done) or Transfers (failure). This also works when the app was killed (cold start via `getNotificationAppLaunchDetails`). |
| Download a previously uploaded file | Every completed upload stores the file name and URL returned by `/upload`. Its tile has a **Download** button that fetches that exact URL. If the server returns only a name, the app falls back to `/get?file=NAME`. The separate **Download** screen also lists everything on the server (`/get`). |
| Download progress + own notification | Each transfer has its own progress notification and its own result notification. |
| Global transfer list | **Transfers** tab (in-progress summary, All / Ongoing / Completed / Failed filters, Pause all / Resume all / Clear finished) plus a docked banner on every other screen. A badge on the nav item shows the active count. |
| State management | `flutter_bloc` (`TransferBloc`, `AuthBloc`). |
| Pause / resume | Downloads resume from the exact byte with `Range: bytes=N-` (like `curl -C -`). Uploads restart from zero, because the server has no resumable-upload protocol. The UI says so. |
| Poor network | Connection loss, timeouts and 5xx errors are retried automatically with exponential back-off (2 s → 4 s → 8 s → 16 s → 30 s, 5 attempts) in a visible **Reconnecting** state. After that, the transfer is marked **Failed** and has a Retry button. |
| Error handling | Every failure becomes a typed `TransferException` with a message a cashier can understand (no connection, timeout, session expired, file not found, file too large, server rejected the file, storage error). |
| Sensible save location | `Download/LAAN POS/` on Android, so files show up in the Files app. Falls back to app-specific external storage if the public folder can't be written. Name clashes become `report (1).csv`. Data is written to `*.part` and renamed only when complete. |
| History survives restarts | Tasks and the auth token are saved in `shared_preferences`. A transfer interrupted by a process kill comes back as **Paused**, and a download resumes from its `.part` file. |

## 2. Architecture

```
lib/
├── core/
│   ├── constants/      API endpoints, colours
│   ├── errors/         TransferException – typed, user-friendly failures
│   ├── services/       BackgroundTransferService (foreground service), AppNavigation (tab routing)
│   ├── theme/          Material 3 theme
│   └── utils/          FileUtils (paths, formatting), NotificationService
├── data/
│   ├── datasources/    Dio remote sources (auth, transfer) + LocalStorage (prefs)
│   ├── models/         RemoteFileModel
│   └── repositories/   Repository impls; CancelToken registry for pause/cancel
├── domain/
│   ├── entities/       TransferTask (JSON-serialisable), RemoteFile, UploadResult
│   └── repositories/   Contracts
└── presentation/
    ├── bloc/           TransferBloc (transfer engine), AuthBloc
    ├── screens/        Splash, Login, Home, Upload, Download (+ Download Complete), Transfers, Settings, app shell
    └── widgets/        TransferItemTile, PersistentTransferBanner, decorations, shared UI
```

### Key design decisions
- **The Bloc is the transfer engine.** `TransferBloc` owns a small scheduler: at most 2 transfers run at once, and the rest wait as *Waiting*. Each attempt gets a `runId`, and callbacks from a stale attempt (one that was paused or superseded) are ignored, so a late error can't overwrite a newer state.
- **Pause = cancel the HTTP request.** A `CancelToken` per task is cancelled. On resume, downloads re-request with `Range` from the size of the `.part` file. The data source checks for `206 Partial Content`. If the server answers `200` instead, it rewrites from byte 0 rather than appending, which would corrupt the file.
- **Throttled progress.** Byte callbacks are sampled, with UI updates every 250 ms and notifications every 1 s. A 500 MB file therefore doesn't flood the event queue. Speed is an exponential moving average.
- **Single navigation controller.** `AppNavigation` (a `ValueNotifier<AppTab>`) lets notification taps and the banner switch tabs without a `BuildContext`.
- **Screens.** Splash → Login/Register → **Home** dashboard (overall progress ring, upload/download counts, quick actions, recent transfers) → **Upload** / **Download** pages → **Transfers** → **Settings** (account, battery-optimisation shortcut, download folder, clear history, logout). Tapping a "Download complete" notification opens a full-screen completion page with *Open File*.
- **Responsive shell.** Phones get a bottom `NavigationBar` (Home / Transfers / Settings). Screens ≥ 840 dp wide (tablets, landscape POS terminals) get a `NavigationRail`. Upload and Download share the same `IndexedStack`, so their state and the global banner persist. Content width is capped at 760 dp.
- **Errors don't block the UI.** A full-page "No Internet Connection" view appears only when the server file list can't be loaded. Transfers themselves retry inline in a *Reconnecting* state.

## 3. Background execution strategy & Android limits

**What the app does**
1. Network work runs in the main isolate (Dio + Bloc). That keeps one source of truth for UI state and makes pause, resume and progress simple.
2. When the first transfer starts, which is always a user action and so always from the foreground, `BackgroundTransferService` starts a **foreground service** with `foregroundServiceType="dataSync"` (`flutter_foreground_task`). It stops when the queue is idle. Its notification shows the combined progress ("2 transfers in progress • 45%").
3. The foreground service raises the process to foreground priority. That stops Android from freezing the cached app (Android 12+ app freezer) or killing it shortly after it is backgrounded. A wake lock and a Wi-Fi lock keep the network up with the screen off.
4. If the process is still killed, the persisted state plus `.part` files let downloads resume from the same byte after relaunch.

**Platform limits involved**
- **Background execution limits (API 26+):** a backgrounded app can't keep doing work without a foreground service. That is why the service exists.
- **Foreground service types (API 34+):** the type must be declared (`dataSync`) together with the `FOREGROUND_SERVICE_DATA_SYNC` permission. Both are in the manifest.
- **`dataSync` time limit (API 35+ targets):** at most about **6 hours per 24 h** in the background. After that the system stops the service, the process loses its foreground priority and may be killed. A killed transfer comes back as *Paused* on the next launch. This is fine for 50–500 MB files, but not for unlimited bulk sync.
- **Starting a foreground service from the background is blocked (API 31+).** Auto-retries reuse the service that is already running. A transfer resumed after a cold start needs the user to open the app.
- **Doze / App Standby:** network access is deferred when the device is idle. The foreground service is exempt while it runs, but OEM battery managers (Xiaomi, Samsung, Huawei, etc.) can still kill it. Ask users to set the app to *Unrestricted* battery use.
- **Notification permission (API 33+):** requested at start-up. If it is denied, transfers still run, but progress and result notifications are hidden.
- **Swiping the app away from Recents** destroys the Flutter engine, which also ends the in-process transfer. The persisted state then lets it resume on the next launch.
- **iOS** (not the target here) gives roughly 30 s of background time. Real background transfers there need `URLSession` background configuration (see §5).

## 4. Assumptions

The brief leaves some details open. These are the assumptions the app is built on:

- **Server response format.** `/get` and `/upload` have no documented JSON schema. The app accepts a plain list or `{files|data|items: [...]}` for listings, with each entry being a name string or `{name|filename, size, url, modified}`. For uploads it reads `{name|filename|file, url|download_url}`, optionally nested under `data`. If no name comes back, the local file name is used.
- **Registration.** `POST /register` takes the same form fields as `/token` (`username`, `password`). The username rule shown in the UI (3–32 characters: letters, numbers, `_ . -`) mirrors the server's validation message. After a successful registration the app logs in automatically.
- **Token lifetime.** The server does not document expiry or refresh, so the token is kept until logout. A 401/403 is shown as "session expired".
- **Uploads are not resumable.** `/upload` is a single multipart request, so pausing an upload cancels it and resuming starts over. Downloads are resumable, since the brief shows `curl -C -`.
- **Concurrency.** At most 2 transfers run at the same time so POS checkout traffic keeps some bandwidth. Others wait in a queue.
- **"Large file".** Any size is accepted. A 50 MB test CSV can be generated inside the app because emulators rarely have big files.
- **Target platform.** Android (the role is Android POS). iOS builds but has no real background-transfer support (see §3).
- **Download location.** Public `Download/LAAN POS/` is treated as the "sensible location" because operators can find exported reports there with the Files app.

## 5. Known limitations / what I'd improve
- **Out-of-process transfers.** Move the transfer itself into native `WorkManager` (Android) and background `URLSession` (iOS), for example with `background_downloader`. Transfers would then survive swipe-to-close and the 6 h `dataSync` limit. The trade-off is a more complex progress and pause model.
- **Resumable uploads.** The mock server accepts only single-shot multipart uploads, so a paused upload restarts. With tus or S3-style multipart uploads, chunks could be resumed.
- **Connectivity awareness.** Resume as soon as `connectivity_plus` reports a network instead of waiting for the next back-off tick, and optionally allow "Wi-Fi only" for large files.
- **Integrity check.** Verify a server-provided checksum or `Content-Length` after a download.
- **Token expiry.** On HTTP 401, the transfer is marked failed with "session expired". A refresh-token flow, or an automatic redirect to login, would be smoother.
- **Undocumented server response shapes.** The `/get` and `/upload` parsers accept several common JSON shapes. They should be locked down once the API contract is published.
- **Secure storage.** The token is kept in `shared_preferences`. `flutter_secure_storage` would be better in production.

## 6. Run instructions

**Prerequisites:** Flutter 3.47+ (Dart 3.13+, per `pubspec.yaml`), Android SDK 36, JDK 17. The project uses AGP 9.1, Kotlin 2.4 and Gradle 9.3.

```bash
flutter pub get
flutter test            # unit, bloc, download-resume (local HTTP server) and layout tests
flutter run             # device or emulator
flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

**APK:** download from the [latest release](https://github.com/aidevshakil/laan-pos-file-transfer/releases/latest).

| File | Use it for |
| --- | --- |
| `LAAN-POS-File-Transfer-v1.0.0-arm64-v8a.apk` | Most phones and POS terminals (recommended) |
| `LAAN-POS-File-Transfer-v1.0.0-armeabi-v7a.apk` | Older 32-bit devices |
| `LAAN-POS-File-Transfer-v1.0.0-x86_64.apk` | Android emulators |

Release builds are signed with the debug key.

**Tests** (27): unit tests (formatting, entities, error mapping, upload-response parsing), bloc tests (upload, auto-retry, give-up then manual retry, pause/resume, concurrency limit), download tests against a local HTTP server (fresh, `Range` resume, server ignoring `Range`, cancel mid-stream, 404, direct URL) and layout tests at 320 / 360 / 1280 px.

**Using the app**
1. Open the app and choose **Register** to create an account on the mock server. You are logged in automatically after registering.
2. **Home → Upload File** → *Choose File* (or *Create a 50 MB test CSV*) → *Start Upload*. Switch tabs or press Home: the upload keeps going, and a completion notification appears when it finishes. Tap **Download** on the finished upload to fetch it back via the returned URL.
3. **Home → Download File** → tap *Download* on a server file. Try *Pause* / *Resume* or airplane mode to see resume and reconnect. Files are saved to `Download/LAAN POS/`.
4. **Transfers** tab → see everything, filter it, and pause, resume or retry.
5. **Settings** → allow *Unrestricted* battery use on phones that kill background apps.
