
///WALA PANI
SPOTato: Drone-based Potato Blight Detection

1. Project Overview

SPOTato is a drone-based potato blight disease detection system built as a Capstone Project for the University of Science and Technology of Southern Philippines.

This project addresses the challenges of traditional manual crop inspection, which is time-consuming, labor-intensive, and prone to human error, often leading to late disease detection and significant crop loss 

$$cite: 528-531$$

.

Our solution is a standalone, offline-first mobile application for Android, built with Flutter. The system uses a DJI Tello drone to capture aerial images of potato leaves. These images are then processed by an on-device EfficientNetB3 AI model (trained on a dataset of 2,714 images 

$$cite: 147-151$$

) to provide immediate, real-time classification of "Early Blight," "Late Blight," or "Healthy" 

$$cite: 1125-1127$$

. The app allows farmers to analyze crops, save the results into organized albums, and manage their field data without requiring an internet connection.

2. System Requirements

Hardware

Android Smartphone (Android 10 or higher recommended)

DJI Tello Drone

Software (for Users)

The official DJI Tello App (com.ryzerobotics.tello) must be installed from the Google Play Store. The SPOTato app launches this external app for drone control 

$$cite: 3281-3286$$

.

Platform: Android only. iOS is not supported due to Android-specific file system paths (/storage/emulated/0/Pictures/TelloPhoto 

$$cite: 3053$$

) and app-launching logic.

Software (for Developers)

Flutter SDK (version 3.x)

Dart SDK (version 3.x)

Android SDK (Android Studio or command-line tools)

3. Installation Guide

Follow these steps to get a local copy of the project up and running for development.

Clone the repository

git clone [https://github.com/your-username/spotato.git](https://github.com/your-username/spotato.git)


Navigate to the project directory

cd spotato


Install dependencies

flutter pub get


Connect an Android Device
Enable Developer Mode and USB Debugging on your Android device and connect it to your computer.

Run the application

flutter run


4. Folder Structure Explanation

A brief overview of the key directories and files in this project:

spotato/
├── assets/
│   ├── images/         # All logos, icons, and UI graphics
│   └── models/         # Contains the trained model.tflite file [cite: 2186]
│
├── lib/
│   ├── pages/          # UI/Screen files (e.g., home_page.dart, album_page.dart, row_detail.dart)
│   ├── helpers/        # Core logic modules
│   │   ├── database_helper.dart  # Manages the local Sqflite database [cite: 2284]
│   │   └── image_handler.dart    # Handles gallery/Tello image import and compression [cite: 3033]
│   │
│   ├── analysis.dart     # Handles AI model preprocessing and TFLite inference [cite: 1815]
│   ├── config.dart       # App-wide constants (model labels, colors, etc.)
│   ├── main.dart         # The main entry point for the application
│   └── ...
│
└── pubspec.yaml        # Flutter project configuration and list of all dependencies


5. Running the Application (User Guide)

Onboarding: The app opens with a 5-second splash screen, followed by a "Get Started" page. Tap "Get Started" to enter the app 

$$cite: 3113-3128, 2601-2603$$

.

Home Screen: You will land on the Home tab, which shows your most recent analyses. Tap the "Detect Disease" button to begin a new scan 

$$cite: 2970-2796$$

.

Start Scanning: You are now on the "Current Scan" page. You have two options:

Tap "Use Tello": This will launch the DJI Tello app. Connect to your drone, fly, and take pictures of your crops. When finished, manually return to the SPOTato app. It will automatically find and import all photos taken in the last 10 minutes 

$$cite: 3340-3356, 3051-3059$$

.

Tap "Add Image": This opens your phone's gallery to import and analyze existing photos 

$$cite: 3314-3317$$

.

Review Results: As images are imported, they are automatically analyzed and will appear in the grid, tagged with a result ("Healthy," "Early Blight," or "Late Blight").

Save Session: When you are done, tap the Save (folder) icon in the top-right corner. This will save all the images from your "Current Scan" into a new, permanent album (e.g., "Scan_11-01-2025_19-30") 

$$cite: 3396-3405$$

.

View History: Tap the "Albums" tab at the bottom of the screen to view, browse, and manage all your past saved albums 

$$cite: 3024-3029$$



(INITIAL PUD NI BY JIMBOY)
6. **API Overview**

SPOTato system does NOT expose any public API, REST endpoints, or network-based services.

This is a 100% offline-first, standalone Android mobile application designed for potato blight detection using a DJI Tello drone and on-device TensorFlow Lite inference. There is no backend server, no cloud sync, no internet requirement, and no external API.

**Purpose:**  
To enable farmers in remote and low-connectivity areas (especially in Manolo Fortich, Bukidnon, Philippines) to perform real-time, accurate detection of Early Blight and Late Blight in potato crops using only a low-cost drone and an Android smartphone — entirely offline.

**Target Users:**  
- Potato farmers in rural and off-grid areas  
- Agricultural extension officers  
- Researchers and students in precision agriculture  
- Developers studying offline AI + drone + mobile integration

All data (images, analysis results, albums) is stored locally using SQLite (`sqflite`) and the Android file system.


7. **Authentication Details**

Not applicable — No authentication system exists.

The app has no login, no user accounts, no tokens, no API keys, and no OAuth.

All features are available immediately upon opening the app. Data privacy is ensured by design: everything stays on the user's device.


8. **Endpoint Documentation**

No HTTP endpoints are available.

This is a pure client-side Flutter application with zero network calls.

For developers interested in internal "services" (local function-level APIs), here are the core reusable components:
Component                    | File                               | Description
-----------------------------------------------------------------------------------------------
DatabaseHelper.instance      | lib/helpers/database_helper.dart   | Full CRUD for albums and detection results using SQLite
ImageHandler                 | lib/helpers/image_handler.dart     | Imports, compresses, and processes images from Tello or gallery
Analysis.runInference()      | lib/analysis.dart                  | Runs on-device EfficientNetB3 TFLite model
getAnalysesForAlbum()        | DatabaseHelper                     | Retrieves all results for a saved scan session

These are internal Dart classes/methods, not network-accessible APIs.


9. **Error Handling**

Since there is no server, all errors are handled gracefully within the Flutter app:
- Missing/deleted images → Shows broken image icon with grey placeholder
- No new Tello photos found → User-friendly message: "No new photos taken in the last 10 minutes"
- Model loading failure → Disables analysis and shows error dialog
- Database errors → Caught silently with fallback to empty state
- Storage permission denied → Prompts user to grant permission

All user-facing errors use `SnackBar`, `AlertDialog`, or fallback UI elements. No JSON error responses exist.


10. **Version Information**

Item                         | Details
----------------------------------------------------------------------------------------------
Latest Code Update           | November 19, 2025 
App Version                  | Defined in pubspec.yaml (typically 1.0.0+1)
AI Model                     | EfficientNetB3, converted to .tflite, trained on 2,714 custom/augmented images
Flutter SDK                  | 3.x (stable channel)
Supported Android Versions   | Android 10+ recommended
API Versioning               | Not applicable — no public API

Future versions may introduce optional cloud sync, but as of November 2025, the system remains fully offline by design.


11. **License & Credits**

License:  
Copyright © 2025 – All Rights Reserved  
University of Science and Technology of Southern Philippines (USTP)  
No license file is currently provided. This is an academic capstone project. Redistribution or commercial use requires explicit permission from the authors and USTP.

Authors / Developers:
- Nicole Kabiling Camara  
- Andreanne Monique Doloquin Gorres  
- Aljo Nicolo Macasa Andina  
- Jimboy Obial Pacanut  
- Lenielyn Dalore Ponteras

Capstone Adviser:  
Mrs. Jocelyn Garrido

Panel Members:  
- Mrs. Ma. Esther Chio  
- Mrs. Rhea Suzette M. Haguisan  
- Mr. Jomar C. Llevado

With special thanks to the farmers of Bukidnon:  
Mr. Rolan Daman, Mrs. Irene Daman, Mr. Lowel Escaba, Mrs. Mayolina Escaba, Ms. Chona Binaliw

Technologies Used:
- Flutter & Dart
- TensorFlow Lite (EfficientNetB3)
- DJI Tello Drone (via official Ryze Tello app)
- `tflite_flutter`, `sqflite`, `path_provider`, `image_picker`, `google_fonts`
- PlantVillage Dataset (base) + custom field-collected images

Institution:  
University of Science and Technology of Southern Philippines, Cagayan De Oro   
College of Information Technology and Computing  
Department of Information Technology  
November 2025

