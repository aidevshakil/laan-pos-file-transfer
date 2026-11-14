# LAAN TECH POS — Background File Transfer & Sync Module

A resilient, enterprise-grade Flutter module built for **LAAN TECH POS SAAS** to handle large file background transfers (product catalogs, sales audits, inventory databases >50MB) under unpredictable network conditions.

---

## 🏗️ 1. Architecture & Key Design Decisions

The application follows **Clean Architecture** combined with the **BLoC (Business Logic Component)** pattern to ensure strict separation of concerns, testability, and deterministic state transitions.

```
lib/
├── core/                        # Cross-cutting concerns & infrastructure
│   ├── constants/               # API endpoints, POS themes, color palette
│   ├── network/                 # Dio client, timeout configs, interceptors
│   ├── theme/                   # Material 3 POS styling
│   └── utils/                   # File utilities & notification service
├── data/                        # Concrete implementations & external sources
│   ├── datasources/             # Remote data sources (Auth & Transfer API)
│   ├── models/                  # Data transfer objects (DTOs) with JSON serialization
│   └── repositories/            # Repository implementations & CancelToken registry
├── domain/                      # Pure business logic & contracts (Framework-agnostic)
│   ├── entities/                # Core entities (TransferTask, RemoteFile, TransferStatus)
│   └── repositories/            # Repository interfaces
└── presentation/                # UI layer
    ├── bloc/                    # State management (AuthBloc, TransferBloc)
    ├── screens/                 # Views (UploadScreen, DownloadScreen, TransferCenter)
    └── widgets/                 # Reusable UI (PersistentTransferBanner, TransferItemTile)
```

### Key Design Decisions:
1. **BLoC as the State Engine:**
   - File transfers are inherently finite state machines: `queued` ➔ `running` ➔ `paused` ➔ `completed` / `failed`.
   - BLoC's unidirectional event-to-state stream guarantees that the UI (Upload screen, Download screen, and Global Floating Banner) stays 100% in sync without race conditions.
2. **Global Root-Level Transfer Provider:**
   - `TransferBloc` is provided above the navigation tree (`MultiBlocProvider`). When a user begins a 100MB catalog upload and navigates to another screen, the transfer continues uninterrupted in memory.
3. **Persistent Floating Transfer Banner:**
   - Implemented at the root navigation scaffold (`main_navigation_screen.dart`), giving real-time visibility into active transfers, aggregate speed, and progress from anywhere in the POS app.
4. **Resilience & Resumability via HTTP Range:**
   - Downloads implement HTTP `Range: bytes=X-` headers (mirroring `curl -C -`). If a network connection drops or the user pauses, downloading resumes exactly where it stopped rather than starting over from byte 0.

---

## ⚡ 2. Android Background Execution Strategy & Platform Limitations

Handling background network transfers on modern Android (API 26+) presents multiple platform constraints:

### Android Platform Limitations:
1. **Doze Mode & App Standby (Android 6.0+):**
   - When the user locks the screen or the device is unplugged and stationary, Android enters Doze Mode, cutting off network access and deferring background jobs to maintenance windows.
2. **Background Execution Limits (Android 8.0+ / API 26):**
   - Standard background services can no longer run when the app is minimized or in the background. The OS aggressively kills non-foreground tasks to conserve RAM.
3. **Aggressive OEM Battery Optimization (Samsung, Xiaomi, Huawei):**
   - Custom Android skins terminate long-running processes after a few minutes in the background unless exempt from battery optimizations.
4. **Android 14 (API 34) Foreground Service Types:**
   - Foreground services now strictly require specific types like `dataSync` (`android:foregroundServiceType="dataSync"`).

### How This Solution Addresses These Limits:
- **System Tray Notification Service:**
  - Employs `flutter_local_notifications` with an ongoing notification (`ongoing: true`, priority `low` during progress, and `high` upon completion).
  - This informs the user in real-time and pairs with Android's notification requirements.
- **Throttled Notification Updates:**
  - Progress updates to the notification tray are throttled to 5% increments to prevent Android system notification rate-limiting / sluggishness.
- **Persistent App Process Continuation:**
  - Network requests run through an active client with long-lived stream sinks (`receiveTimeout: 10m`, `sendTimeout: 15m`).
- **Resumable HTTP Architecture:**
  - If the OS terminates the app while a transfer is in progress, the partial file remains safely on disk. Upon reopening or retrying, the download resumes from the exact disk byte offset.

---

## 🛠️ 3. Features & Resiliency Checklist

| Feature | Requirement | Implementation Details |
| :--- | :---: | :--- |
| **Pick Large Files (>50MB)** |  | Native file picker + Built-in **"Dummy 50MB"** generator for instant testing |
| **Multipart Upload** |  | POST `/upload` with `multipart/form-data` and chunked stream tracking |
| **Real-time Progress & Speed** |  | Live percentage bar, bytes transferred, and instantaneous transfer rate (MB/s) |
| **Navigation & Minimize Continuation** |  | Global Bloc keeps transfers running as user navigates POS screens |
| **System Tray Notification** |  | Ongoing progress notifications + Persistent completion notification with tap action |
| **Resumable Download** |  | GET `/get?file=NAME` using HTTP `Range: bytes=start-` |
| **Sensible Storage Path** |  | Saves directly to device Downloads / Documents directory |
| **Central Transfer Center** |  | Dedicated dashboard with metrics (Active, Completed, Issues) and Pause/Resume All |
| **Persistent Global Widget** |  | Floating banner at screen bottom showing live count, %, and speed |
| **Error Handling & Retry** |  | Network failure alerts, retry buttons, and friendly error feedback |

---

## 🔍 4. Known Limitations & Future Improvements

With more time, the following enhancements could be incorporated:
1. **Native WorkManager / `background_downloader` Integration:**
   - Integrate native Android `WorkManager` / `JobScheduler` for out-of-process transfers that survive even if the OS forces a hard process kill.
2. **Chunked Resumable Uploads (tus.io protocol):**
   - The current mock REST server accepts standard multipart uploads for `/upload`. If the server supported chunked uploads (e.g., TUS or S3 Multipart), upload pauses/resumes could be resumed at the chunk level.
3. **Local SQLite / Hive State Persistence:**
   - Store transfer task metadata in a local SQLite database (`drift` or `hive`) so paused/failed transfer history persists across device restarts.
4. **Adaptive Bandwidth Throttling:**
   - Allow POS operators to throttle upload/download speeds to reserve bandwidth for critical POS checkout operations.

---

## 🚀 5. Setup & Run Instructions

### Prerequisites:
- **Flutter SDK:** `>= 3.13.0`
- **Dart SDK:** `>= 3.1.0`
- **Android Studio / Android SDK** (API 24+)

### Steps to Run:

1. **Clone the repository:**
   ```bash
   git clone <REPO_URL>
   cd laantech_task
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run Unit Tests:**
   ```bash
   flutter test
   ```

4. **Run on Android Device or Emulator:**
   ```bash
   flutter run
   ```

5. **Build Release APK (Split Per ABI):**
   ```bash
   flutter build apk --target-platform android-arm,android-arm64 --split-per-abi
   ```
   *Generated optimized split APKs:*
   - **ARM 64-bit (Modern Android & POS Devices):** `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (17.8 MB)
   - **ARM 32-bit (Legacy POS Devices):** `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (15.4 MB)

### Testing Tips:
- **Login Screen:** Use credentials `admin` / `admin` or tap **"Continue in Demo / Offline Mode"** to test UI flows even without server reachability.
- **Upload Screen:** Tap **"Dummy 50MB"** to create a test catalog file instantly on the device without having to copy files to the emulator.
