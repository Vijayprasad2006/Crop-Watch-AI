# CropWatch AI (FarmGuard AI) — App Details

## Overview
CropWatch AI (app title: **FarmGuard AI**) is a Flutter mobile app that helps farmers **monitor farm areas using the device camera**, detect suspicious activity, and **trigger alerts** (sound + voice + optional SMS/call actions). It also keeps a simple **threat/event history** using Supabase.

## Problem it solves
- **Farm theft / intrusion monitoring**: Detects humans/intruders and flags suspicious presence.
- **Animal intrusion awareness**: Detects animals and can trigger deterrent actions.
- **Faster response**: Raises immediate alerts (sirens + voice) and captures evidence (screenshot/video).

## Key features
- **Login / Sign Up**
  - User signs up/logs in from `AuthScreen`.
  - Uses Supabase Auth under the hood.
  - Stores basic profile data (phone, name, location) in a Supabase `users` table.

- **Dashboard**
  - Shows farm status, detections today, last event, and an AI-based “theft risk” indicator.
  - Pulls today’s threat events from Supabase `threats` table.

- **Live Camera Monitoring**
  - Opens the device camera feed in `CameraMonitoringScreen`.
  - Runs AI detection logic (currently demo/simulated detections via `MLService`).
  - Draws bounding boxes on detections.
  - “Night mode” overlay + optional torch control.
  - Tracks repeated detections to mark **suspicious activity** and compute a simple theft probability.

- **Evidence capture**
  - Captures a **screenshot** when a threat is detected.
  - Records a short **video clip** (about 3 seconds).
  - Uploads media to Supabase Storage and logs the event in the database.
  - Adds GPS coordinates when available.

- **Alerts**
  - Plays an alarm/siren sound.
  - Speaks a TTS warning (localized via app localization).
  - Can launch the SMS app and dialer to notify the saved farmer phone number.
  - Includes a manual “Repel” action that plays a deterrent sound.

- **Alert History**
  - A screen to view past threat detections (stored in Supabase).

- **Settings & Language**
  - Language selection is persisted via `SharedPreferences`.
  - App supports localization through generated `AppLocalizations`.

## Tech stack
- **Frontend**: Flutter (Material UI, dark theme)
- **State / storage**: `provider`, `shared_preferences`
- **Camera**: `camera`
- **ML**: `tflite_flutter` (model asset included)
- **Media capture**: `screenshot`, camera video recording
- **Location**: `geolocator`
- **Backend**: Supabase (`supabase_flutter`)
  - Auth (sign up / login)
  - Database tables (`users`, `threats`)
  - Storage bucket(s) for threat images/videos
- **Alerts**: `flutter_tts`, `audioplayers`, `url_launcher`, (optional) `flutter_local_notifications`

## App flow (high level)
1. **Language Selection** (first run) → stored in preferences
2. **Auth (Login/Sign Up)** → creates/loads user profile
3. **Dashboard** → stats + shortcuts
4. **Start Monitoring** → camera + AI detection + alerts + evidence capture
5. **Alert History** → review past events

## Data model (Supabase)
These are inferred from app usage:
- **`users` table**
  - `id` (Supabase Auth user id)
  - `phone`
  - `name`
  - `location`
  - `updated_at`

- **`threats` table**
  - `user_id`
  - `detected_class`
  - `image_url`
  - `video_url`
  - `latitude`
  - `longitude`
  - `field_name`
  - `status`
  - `created_at` (queried for “today” stats)

## Assets included
- **TFLite model**: `assets/models/ssd_mobilenet.tflite`
- **Labels**: `assets/models/labels.txt`
- **Alert sound**: `assets/sounds/siren.mp3`

## Permissions used
The app requests (depending on platform support):
- Camera
- Microphone (requested, though audio capture is disabled in camera controller)
- Location
- Notifications

## Notes / current behavior
- The ML pipeline (`MLService`) currently **simulates detections** for demo/UX purposes. It is structured so real camera-frame inference can be added later.
- Supabase email rate-limits can occur if sign-up is triggered repeatedly; the app now handles the common `429 over_email_send_rate_limit` case with a cooldown and friendly message.

