
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

.
