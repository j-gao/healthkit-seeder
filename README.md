# healthkit-seeder
An iOS utility app that generates and writes realistic mock HealthKit data into Apple Health to facilitate the testing of HealthKit-powered apps.

## What it does
- Requests HealthKit read/write permissions for various data (sleep, time in daylight, steps, and walking/running distance, etc.).
- Lets you generate realistic mock samples for the chosen day with one tap and displays them.
- Includes a calendar-style date picker to switch days.

## Getting started
1. Open `HealthKitSeeder.xcodeproj` in Xcode .
2. Build and run on either an iOS simulator or a physical device.