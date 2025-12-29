# Firebase Deployment Guide

This guide explains how to deploy Firebase configurations and Cloud Functions for push notifications.

## Prerequisites

1. Firebase CLI installed (`npm install -g firebase-tools`)
2. Logged into Firebase (`firebase login`)
3. Firebase project initialized in this directory

## Deploy Firestore Security Rules and Indexes

### Deploy Security Rules
```bash
firebase deploy --only firestore:rules
```

### Deploy Firestore Indexes
```bash
firebase deploy --only firestore:indexes
```

### Deploy Both at Once
```bash
firebase deploy --only firestore
```

## Deploy Cloud Functions

### Initial Setup (First Time Only)
1. Navigate to functions directory:
   ```bash
   cd functions
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Go back to root directory:
   ```bash
   cd ..
   ```

### Deploy All Functions
```bash
firebase deploy --only functions
```

### Deploy Specific Function
```bash
firebase deploy --only functions:onServiceRecordCreated
firebase deploy --only functions:onServiceRecordUpdated
firebase deploy --only functions:onOrderCreated
firebase deploy --only functions:onOrderUpdated
firebase deploy --only functions:sendBookingReminders
```

## Cloud Functions Overview

The following Cloud Functions are configured:

1. **onServiceRecordCreated** - Triggers when a new booking is created
   - Sends push notification to customer confirming booking
   - Sends push notification to all admins about new booking
   - Creates in-app notifications

2. **onServiceRecordUpdated** - Triggers when a booking is updated
   - Sends push notification to customer about status changes
   - Sends push notification to admins when user cancels or modifies booking
   - Creates in-app notifications

3. **onOrderCreated** - Triggers when a new order is placed
   - Sends push notification to customer confirming order
   - Sends push notification to admins about new order
   - Creates in-app notifications

4. **onOrderUpdated** - Triggers when order status changes
   - Sends push notification to customer about order status
   - Creates in-app notifications

5. **sendBookingReminders** - Scheduled function (runs every hour)
   - Sends 24-hour reminder push notifications for upcoming bookings
   - Creates in-app notifications

## Testing Push Notifications

### On Mobile Devices (Android/iOS)
1. Deploy all Cloud Functions
2. Ensure FCM token is being saved to user documents (check logs)
3. Create a test booking or order
4. Check device for push notification

### Check Logs
```bash
firebase functions:log
```

### View Function Status
```bash
firebase functions:list
```

## Troubleshooting

### Push Notifications Not Working

1. **Check FCM Token**: Ensure users have FCM tokens saved in Firestore
   ```
   users/{userId} should have "fcmToken" field
   ```

2. **Check Cloud Functions Deployment**: Verify functions are deployed and running
   ```bash
   firebase functions:list
   ```

3. **Check Function Logs**: Look for errors in Cloud Functions logs
   ```bash
   firebase functions:log --limit 50
   ```

4. **Check Android Permissions**: Ensure AndroidManifest.xml has notification permissions
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   ```

5. **Check iOS Permissions**: Ensure Info.plist has required entries and push notifications capability is enabled in Xcode

6. **Test on Physical Device**: Push notifications don't work on emulators/simulators reliably

### Common Issues

1. **"Missing FCM token"** - User needs to log in again to generate and save FCM token
2. **"Invalid registration token"** - Token expired, user needs to log in again
3. **Notifications only work in foreground** - Background handler not properly configured
4. **Web notifications not working** - Need to add VAPID key in fcm_service.dart (line 120)

## Production Checklist

- [ ] Deploy Firestore security rules
- [ ] Deploy Firestore indexes
- [ ] Deploy all Cloud Functions
- [ ] Test push notifications on Android device
- [ ] Test push notifications on iOS device
- [ ] Verify in-app notifications work
- [ ] Check Firebase Console for function execution logs
- [ ] Set up monitoring and alerting in Firebase Console

## Firebase Console Links

- **Functions**: https://console.firebase.google.com/project/YOUR_PROJECT_ID/functions
- **Firestore**: https://console.firebase.google.com/project/YOUR_PROJECT_ID/firestore
- **Cloud Messaging**: https://console.firebase.google.com/project/YOUR_PROJECT_ID/messaging

## Notes

- Cloud Functions run in Node.js environment on Google Cloud
- Free tier includes 125K function invocations per month
- Scheduled functions (sendBookingReminders) count towards quota
- Monitor usage in Firebase Console to avoid unexpected charges
