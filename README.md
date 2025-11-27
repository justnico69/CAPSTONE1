# SPOTATO - Smart Potato Disease Detection (Drone-Powered)


SPOTATO is a Flutter-based mobile application designed to help farmers quickly and accurately detect common potato diseases, specifically **Early Blight** and **Late Blight**. It integrates with the **Ryze Tello drone** to automate image capture in the field and uses an on-device **TensorFlow Lite (TFLite)** model for real-time analysis, even without an internet connection.

---

## Features

* **Real-time Disease Detection:** Utilizes a pre-trained TFLite model to classify potato leaves as **Healthy**, **Early Blight**, or **Late Blight**.
* **Tello Drone Integration:** Seamlessly launches the Tello app to fly and capture images. Automatically imports, compresses, and analyzes new images upon returning to SPOTATO.
* **Image Handling & Compression:** Compresses all imported images (from gallery or drone) to a maximum of 1080p and 85% quality, and converts them to JPEG for consistent, efficient processing.
* **Local Data Persistence:** Stores all analysis results, including the image file path, prediction, confidence, and row-tag metadata, in a local **SQLite database**.
* **Album and Location Tagging:** Allows users to save a "Current Scan" session as a persistent **Album**, providing the ability to tag the results with a specific **Row Tag** (e.g., 'Row 5', 'North Field') for easy location tracking.
* **Intuitive UI/UX:** Uses a clean, Poppins-based design with distinct color-coding (Dark Brown, Orange) and a **`RowDetailPage`** for managing active scan sessions.

---

## System Requirements

### Mobile Device
* **OS:** Android (The Tello app and file system access features, particularly `/storage/emulated/0/Pictures/TelloPhoto`, suggest a focus on the Android platform).
* **Required Apps:** The official **Ryze Tello** application must be installed on the device for drone connectivity.

### Development
* **Flutter:** Stable Channel (The project uses modern Flutter features like `WidgetStateProperty` and TFLite for Flutter).
* **TFLite Model:** The model asset `assets/models/model.tflite` must be present.

---

## Installation Guide

### Prerequisites
1.  **Install Flutter:** Follow the official Flutter installation guide.
2.  **Clone the Repository:**
    ```bash
    git clone https://github.com/justnico69/CAPSTONE1.git
    cd spotato
    ```
3.  **Add Model Assets:** Ensure your TFLite model is placed in the correct location:
    ```
    assets/models/model.tflite
    ```

### Setup and Running
1.  **Get Dependencies:**
    ```bash
    flutter pub get
    ```
2.  **Run the App:**
    ```bash
    flutter run
    ```
    *Note: The app performs essential asynchronous setup (loading the TFLite model and initializing notifications) on startup before running the UI*.

---

## Folder Structure Explanation

The core logic of the application is organized within the `lib/` directory:

| File/Folder | Purpose | Key Files |
| :--- | :--- | :--- |
| `lib/main.dart` | Application entry point. Loads the TFLite model and initializes the root `SPOTATOApp`. | `main()` |
| `lib/config.dart` | Global constants, TFLite configuration, and the core **`DetectionResult`** data class. | `kModelAssetPath`, `DetectionResult` |
| `lib/database_helper.dart` | Manages the **SQLite database**. Includes functions for inserting analysis results and querying albums. | `tableAnalyses`, `getAllAlbums()` |
| `lib/analysis.dart` | Contains the logic for running the TFLite inference. **Crucially, it includes the fix to remove normalization for raw pixel values**. | `_imageToTensor()`, `runModelAnalysis()` |
| `lib/row_detail.dart` | The **Current Scan** session manager. Handles image picking, Tello import logic, and the Save Album dialog. | `_importFromTelloFolder()`, `_saveCurrentScan()` |
| `lib/album_page.dart` | Displays the list of all saved albums and manages the multi-select/delete functionality. | `_deleteSelected()`, `build()` |
| `lib/image_handler.dart` | Utility class for all image-related file operations: picking, importing from Tello directory, and compression. | `importFromTello()`, `compressImage()` |

---

## 🚦 Usage Workflow

The primary user workflow is initiated from the Home Page:

1. **Detect Disease:** Tap the **'Detect Disease'** button.
2.  **Start Scan Session:** The user is taken to the **'Current Scan'** page (`RowDetailPage`).
3.  **Add Images:** Use the **Floating Action Button (`+`)** to:
    * **Launch Tello:** Opens the Tello app. Upon returning, new photos will be automatically imported, compressed, and analyzed.
    * **Add from Gallery:** Imports a single image from the device's gallery.
4.  **Analysis:** The image is immediately processed by the local TFLite model. Notifications are sent when analysis is complete.
5.  **Save Album:** Tap the **'Save as Album'** icon, select or enter a **Row Tag**, and save the entire scan session to a new album.
6.  **View Results:** Access saved scans via the **'Albums'** tab.

---------

## API Overview

SPOTato system does NOT expose any public API, REST endpoints, or network-based services.

This is a 100% offline-first, standalone Android mobile application designed for potato blight detection using a DJI Tello drone and on-device TensorFlow Lite inference. There is no backend server, no cloud sync, no internet requirement, and no external API.

### Purpose:  
To enable farmers in remote and low-connectivity areas (especially in Manolo Fortich, Bukidnon, Philippines) to perform real-time, accurate detection of Early Blight and Late Blight in potato crops using only a low-cost drone and an Android smartphone — entirely offline.

### Target Users:  
- Potato farmers in rural and off-grid areas  
- Agricultural extension officers  
- Researchers and students in precision agriculture  
- Developers studying offline AI + drone + mobile integration

All data (images, analysis results, albums) is stored locally using SQLite (`sqflite`) and the Android file system.

---

## Authentication Details

Not applicable — No authentication system exists.

The app has no login, no user accounts, no tokens, no API keys, and no OAuth.

All features are available immediately upon opening the app. Data privacy is ensured by design: everything stays on the user's device.

---

## Endpoint Documentation

No HTTP endpoints are available.

This is a pure client-side Flutter application with zero network calls.

For developers interested in internal "services" (local function-level APIs), here are the core reusable components:

| Component                 | Purpose                                                         | File / Key Methods                                                               |
| :------------------------ | :-------------------------------------------------------------- | :------------------------------------------------------------------------------- |
| `DatabaseHelper.instance` | Full CRUD for albums and detection results using SQLite         | `lib/helpers/database_helper.dart` — `insertAnalysis()`, `getAnalysesForAlbum()` |
| `ImageHandler`            | Imports, compresses, and processes images from Tello or gallery | `lib/helpers/image_handler.dart` — `importFromTello()`, `compressImage()`        |
| `Analysis.runInference()` | Runs on-device EfficientNetB3 TFLite model                      | `lib/analysis.dart` — `runInference()`, `_imageToTensor()`                       |
| `getAnalysesForAlbum()`   | Retrieves all results for a saved scan session                  | `DatabaseHelper` class                                                           |

These are internal Dart classes/methods, not network-accessible APIs.

---

## Error Handling

Since there is no server, all errors are handled gracefully within the Flutter app:
- Missing/deleted images → Shows broken image icon with grey placeholder
- No new Tello photos found → User-friendly message: "No new photos taken in the last 10 minutes"
- Model loading failure → Disables analysis and shows error dialog
- Database errors → Caught silently with fallback to empty state
- Storage permission denied → Prompts user to grant permission

All user-facing errors use `SnackBar`, `AlertDialog`, or fallback UI elements. No JSON error responses exist.

---

## Version Information

| Item                       | Details                                                                          |
| :------------------------- | :------------------------------------------------------------------------------- |
| Latest Code Update         | November 19, 2025                                                                |
| App Version                | 1.0.0+1                                  |
| AI Model                   | EfficientNetB3, converted to `.tflite`, trained on 2,714 custom/augmented images |
| Flutter SDK                | 3.x (stable channel)                                                             |
| Supported Android Versions | Android 10+ recommended                                                          |
| API Versioning             | Not applicable — no public API                                                   |


Future versions may introduce optional cloud sync, but as of November 2025, the system remains fully offline by design.

---

## License & Credits

### License:  
Copyright © 2025 – All Rights Reserved  
University of Science and Technology of Southern Philippines (USTP)  
No license file is currently provided. This is an academic capstone project. Redistribution or commercial use requires explicit permission from the authors and USTP.

### Authors / Developers:
- Nicole Kabiling Camara  
- Andreanne Monique Doloquin Gorres  
- Aljo Nicolo Macasa Andina  
- Jimboy Obial Pacanut  
- Lenielyn Dalore Ponteras

### Capstone Adviser:  
Mrs. Jocelyn Garrido

### Panel Members:  
- Mrs. Ma. Esther Chio  
- Mrs. Rhea Suzette M. Haguisan  
- Mr. Jomar C. Llevado

With special thanks to the farmers of Bukidnon:  
Mr. Rolan Daman, Mrs. Irene Daman, Mr. Lowel Escaba, Mrs. Mayolina Escaba, Ms. Chona Binaliw

### Technologies Used:
- Flutter & Dart
- TensorFlow Lite (EfficientNetB3)
- DJI Tello Drone (via official Ryze Tello app)
- `tflite_flutter`, `sqflite`, `path_provider`, `image_picker`, `google_fonts`
- PlantVillage Dataset (base) + custom field-collected images

### Institution:  
University of Science and Technology of Southern Philippines, Cagayan De Oro   
College of Information Technology and Computing  
Department of Information Technology  
November 2025

