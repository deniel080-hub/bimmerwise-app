# iOS Push Notifications Setup Guide 📱

## ✅ What's Already Configured

Your BIMMERWISE app now has complete iOS push notification support with:

1. **AppDelegate.swift** - Registers for remote notifications and handles APNs tokens
2. **Info.plist** - Background modes enabled for remote notifications
3. **Runner.entitlements** - Push notification capabilities configured
4. **FCM Service** - iOS-specific token handling with APNs integration
5. **iOS 13.0+** - Minimum deployment target set in Podfile

---

## 🔑 Apple Developer Account Setup

### 1. Enable Push Notifications in Apple Developer Portal

1. Go to [Apple Developer](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select your app's **Bundle ID** (`com.bimmerwise.bimmerwiseconnect`)
4. Enable **Push Notifications** capability
5. Generate **APNs Certificate** or use **APNs Key** (recommended)

### 2. Upload APNs Key to Firebase Console

**Option A: APNs Authentication Key (Recommended)**
1. In Apple Developer Portal:
   - Go to **Keys** → **Create a new key**
   - Enable **Apple Push Notifications service (APNs)**
   - Download the `.p8` key file
   - Note your **Key ID** and **Team ID**

2. In Firebase Console:
   - Go to **Project Settings** → **Cloud Messaging** → **iOS app configuration**
   - Upload your APNs Authentication Key (`.p8` file)
   - Enter **Key ID** and **Team ID**

**Option B: APNs Certificate (Legacy)**
1. Generate a Certificate Signing Request (CSR) from Keychain Access
2. Create APNs SSL Certificate in Apple Developer Portal
3. Download and install the certificate
4. Export as `.p12` file
5. Upload to Firebase Console

---

## 🔧 Xcode Configuration

### 1. Open Project in Xcode

```bash
cd ios
open Runner.xcworkspace
```

⚠️ **Important:** Always open `.xcworkspace`, NOT `.xcodeproj`!

### 2. Configure Signing & Capabilities

1. Select **Runner** target
2. Go to **Signing & Capabilities** tab
3. Enable **Automatic Signing** or configure manual signing
4. Select your **Team**
5. Verify **Push Notifications** capability is enabled
6. Verify **Background Modes** includes:
   - ✅ Remote notifications
   - ✅ Background fetch

### 3. Update Bundle ID (if needed)

Make sure your Bundle Identifier matches:
- **Bundle ID:** `com.bimmerwise.bimmerwiseconnect`
- Matches the one in Apple Developer Portal
- Matches the one in Firebase Console

---

## 📱 Testing iOS Push Notifications

### Method 1: Test on Real iOS Device (Recommended)

1. **Connect your iPhone/iPad** to your Mac via USB

2. **Select your device** in Xcode (top bar)

3. **Build and Run:**
   ```bash
   flutter build ios
   flutter run --release
   ```

4. **Grant notification permission** when prompted

5. **Check logs** for FCM token:
   ```
   ✅ APNs Token obtained: abc123...
   ✅ FCM Token obtained: fGcR8v...
   ```

6. **Test notification:**
   - Log in as admin on another device
   - Create a booking
   - iOS device should receive push notification

### Method 2: Firebase Console Test Message

1. Go to **Firebase Console** → **Cloud Messaging**
2. Click **Send test message**
3. Enter your device's **FCM token** (from logs)
4. Send test notification
5. Check if notification appears on iOS device

### Method 3: Using Cloud Functions

Your Cloud Functions will automatically send notifications:
- `sendBookingNotification` - Booking confirmations
- `sendBookingReminder` - 24-hour reminders
- `checkUpcomingBookings` - Daily scheduled checks

---

## 🧪 Debugging iOS Push Notifications

### Enable Verbose Logging

Add to `main.dart` before `runApp()`:

```dart
debugPrint('🚀 Starting BIMMERWISE app with FCM logging');
```

### Check APNs Token Registration

Watch for these logs when app launches:
```
✅ iOS Notification Permission Granted
✅ APNs Device Token Registered: abc123...
🍎 APNs Token obtained: abc123...
📱 FCM Token obtained: fGcR8v...
```

### Common Issues & Solutions

#### ❌ "Failed to register for remote notifications"
**Solution:** Check:
- Push Notifications capability is enabled in Xcode
- APNs certificate/key uploaded to Firebase
- Running on real device (simulator doesn't support APNs)

#### ❌ "APNs token is null"
**Solution:**
- User denied notification permission - check Settings → Notifications
- App not signed with valid provisioning profile
- Push capability not enabled in Apple Developer Portal

#### ❌ "Notifications not appearing"
**Solution:**
- Check notification settings in iOS Settings → Notifications → BIMMERWISE
- Ensure "Allow Notifications" is ON
- Check "Lock Screen", "Notification Center", and "Banners" are enabled

#### ❌ "Token not saved to Firestore"
**Solution:**
- Check internet connection
- Verify Firestore rules allow writing to `users` collection
- Check logs for timeout errors

---

## 🎯 iOS App Icon Setup

### Current Configuration

Your `pubspec.yaml` already has icon configuration:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: assets/images/bimmerwise2.png
  remove_alpha_ios: true  # Required for iOS
```

### Regenerate Icons

If you need to update the app icon:

1. **Prepare your icon image:**
   - Size: 1024x1024 pixels
   - Format: PNG
   - No transparency (iOS requirement)
   - Place in `assets/images/bimmerwise2.png`

2. **Run icon generator:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

3. **Verify in Xcode:**
   - Open `ios/Runner.xcworkspace`
   - Check `Runner/Assets.xcassets/AppIcon.appiconset`
   - All icon sizes should be populated

---

## 🚀 Publishing to App Store

### Before Submission

1. ✅ Test push notifications on real device
2. ✅ Verify app icon displays correctly
3. ✅ Update version in `pubspec.yaml`
4. ✅ Build release version:
   ```bash
   flutter build ios --release
   ```

### Required Configurations

- **Privacy - User Notifications Usage Description** (already in Info.plist)
- **Push Notifications** capability enabled
- **APNs certificate/key** uploaded to Firebase
- **Bundle ID** matches Apple Developer Portal

### Using Dreamflow Publish

1. Click **Publish** button (top right)
2. Select **iOS** platform
3. Follow the wizard to:
   - Generate IPA file
   - Upload to App Store Connect
   - Submit for review

---

## 📋 Checklist for iOS Push Notifications

- ✅ AppDelegate.swift registers for remote notifications
- ✅ Info.plist has background modes enabled
- ✅ Runner.entitlements file created with push capability
- ✅ Podfile sets iOS 13.0 minimum version
- ✅ FCM service handles iOS APNs tokens
- ✅ Push Notifications enabled in Apple Developer Portal
- ✅ APNs key/certificate uploaded to Firebase Console
- ✅ App signed with valid provisioning profile
- ✅ Tested on real iOS device

---

## 🔔 Real-Time Notifications

Your app supports:

1. **Foreground Notifications** - Shown when app is open
2. **Background Notifications** - Delivered when app is in background
3. **Terminated State** - Notifications wake up the app
4. **Interactive Notifications** - Tap to open relevant screen

### Notification Channels

- **Booking Created** → Admin receives when user books
- **Service Complete** → User receives when service done
- **Booking Reminder** → 24 hours before appointment
- **Admin Actions** → Status updates, cancellations

---

## 🆘 Support

If you encounter issues:

1. Check logs in Xcode console
2. Verify Firebase Console setup
3. Test with Firebase test message first
4. Contact Dreamflow support (Submit Feedback button)

---

## 📱 Samsung Device Compatibility

Your app already has Samsung device optimizations:
- High priority notifications (`Importance.max`)
- Retry logic for FCM token retrieval
- Battery optimization handling
- Lock screen notification visibility

---

**Last Updated:** January 2025  
**iOS Version:** 13.0+  
**Firebase Messaging:** 16.0.0
