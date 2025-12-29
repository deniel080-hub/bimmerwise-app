# 🚀 Firebase Cloud Functions Deployment Guide

## Overview
Your app has **Cloud Functions** that send push notifications to users and admins. These functions are currently written but **NOT deployed** to Firebase. This is why push notifications aren't working on devices.

## ⚠️ Current Status
- ✅ Cloud Functions code is ready (`/functions/src/index.ts`)
- ✅ In-app notifications work (stored in Firestore)
- ❌ **Push notifications DON'T work** (Cloud Functions not deployed)
- ❌ **Admins don't receive push notifications** for new bookings

## 📱 What the Cloud Functions Do

### 1. **onServiceRecordCreated**
Triggers when a user books a service:
- Sends **push notification** to the customer
- Sends **push notification** to ALL admin users
- Creates in-app notifications in Firestore

### 2. **onServiceRecordUpdated**
Triggers when a service status changes:
- Notifies customer when service is completed/confirmed
- Notifies admins when user cancels or modifies a booking
- Creates in-app notifications in Firestore

### 3. **onOrderCreated** & **onOrderUpdated**
Handles product orders:
- Notifies customers about order confirmations
- Alerts admins about new orders
- Updates customers on order status changes

### 4. **sendBookingReminders**
Scheduled function that runs every hour:
- Sends reminders 24 hours before appointments
- Automatically marks reminders as sent

## 🔧 How to Deploy Cloud Functions

### Option 1: Deploy via Firebase Console (Recommended for Web Preview)

Since Dreamflow runs in the browser and doesn't have terminal access, you'll need to:

1. **Download your project code**
   - Click the menu in the top-left corner
   - Select **"Download Code"**
   - Extract the ZIP file to your computer

2. **Install Firebase CLI**
   ```bash
   npm install -g firebase-tools
   ```

3. **Navigate to your project folder**
   ```bash
   cd /path/to/bimmerwise-connect
   ```

4. **Login to Firebase**
   ```bash
   firebase login
   ```

5. **Select your Firebase project**
   ```bash
   firebase use --add
   # Select your project from the list
   ```

6. **Install Cloud Functions dependencies**
   ```bash
   cd functions
   npm install
   cd ..
   ```

7. **Deploy all Cloud Functions**
   ```bash
   firebase deploy --only functions
   ```

   Or deploy specific functions:
   ```bash
   firebase deploy --only functions:onServiceRecordCreated,onServiceRecordUpdated
   ```

8. **View deployment status**
   After deployment, you'll see output like:
   ```
   ✔  functions[onServiceRecordCreated] Successful create operation.
   ✔  functions[onServiceRecordUpdated] Successful create operation.
   ✔  functions[onOrderCreated] Successful create operation.
   ✔  functions[onOrderUpdated] Successful create operation.
   ✔  functions[sendBookingReminders] Successful create operation.
   ```

### Option 2: Enable Cloud Functions via Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **BIMMERWISE** project
3. Navigate to **Build** → **Functions**
4. If prompted, upgrade to **Blaze (Pay as you go)** plan
   - Don't worry: The free tier includes 2 million invocations/month
   - Your usage will likely stay within the free tier
5. Click **"Get Started"** and follow the setup wizard

## ✅ How to Verify Cloud Functions Are Working

### 1. Check Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Build** → **Functions**
4. You should see these functions listed:
   - `onServiceRecordCreated`
   - `onServiceRecordUpdated`
   - `onOrderCreated`
   - `onOrderUpdated`
   - `sendBookingReminders`

### 2. Test Push Notifications
1. **On a device (Android/iOS):**
   - Login as a regular user
   - Create a new booking
   - Check if admin receives a push notification

2. **Login as admin:**
   - Mark a booking as "Completed"
   - Check if the customer receives a push notification

### 3. View Cloud Function Logs
To see if functions are executing:

```bash
firebase functions:log
```

Or in Firebase Console:
- Go to **Functions** → Select a function → **Logs** tab

## 📊 Expected Behavior After Deployment

### When a user books a service:
1. ✅ Service record created in Firestore
2. ✅ Cloud Function `onServiceRecordCreated` triggers
3. ✅ Push notification sent to customer's device
4. ✅ Push notification sent to ALL admin devices
5. ✅ In-app notifications created in Firestore

### When admin marks service as complete:
1. ✅ Service record updated in Firestore
2. ✅ Cloud Function `onServiceRecordUpdated` triggers
3. ✅ Push notification sent to customer's device
4. ✅ In-app notification created

### When user cancels booking:
1. ✅ Service record status changed to "Booking Canceled"
2. ✅ Cloud Function `onServiceRecordUpdated` triggers
3. ✅ Push notifications sent to ALL admin devices
4. ✅ In-app notifications created for all admins

## 🔍 Troubleshooting

### Push notifications still not working?

1. **Check FCM tokens are being saved**
   - Go to Firestore → `users` collection
   - Check if `fcmToken` field exists for your test users

2. **Check notification permissions**
   - Android: Settings → Apps → BIMMERWISE → Notifications
   - iOS: Settings → BIMMERWISE → Notifications

3. **Check Cloud Function execution**
   ```bash
   firebase functions:log --only onServiceRecordCreated
   ```

4. **Verify Cloud Functions are deployed**
   - In Firebase Console, go to Functions
   - Check if functions show "Healthy" status

5. **Check for errors in logs**
   - Firebase Console → Functions → Click function name → Logs tab
   - Look for red error messages

### Common Issues

**Issue:** "Cloud Functions requires billing account"
- **Solution:** Upgrade to Blaze plan (free tier available)

**Issue:** "Permission denied to deploy functions"
- **Solution:** Make sure you're logged in: `firebase login --reauth`

**Issue:** "FCM token not found"
- **Solution:** Make sure users are logged in and FCM permissions are granted

**Issue:** "Notification sent but not received"
- **Solution:** 
  - Check if app is in foreground (will show as local notification)
  - Check if app has notification permissions
  - Verify FCM token is valid in Firestore

## 💡 Tips

- Cloud Functions have a **cold start** delay (first invocation after idle time may take 5-10 seconds)
- Test in **production mode** on real devices, not just the web preview
- Monitor your Cloud Functions usage in Firebase Console to stay within free tier
- Keep your Firebase CLI updated: `npm install -g firebase-tools@latest`

## 📝 Notes

- **Web preview (Dreamflow)**: FCM may show warnings on web, but will work correctly on mobile devices
- **Development**: Cloud Functions only run in production environment (not on local Firestore emulator)
- **Billing**: Free tier includes 2M invocations/month, 400K GB-seconds/month, 200K CPU-seconds/month

## 🆘 Need Help?

If you're still having issues after deployment:
1. Check the Firebase Console logs for error messages
2. Verify your Firebase project is on the Blaze plan
3. Ensure all users have valid FCM tokens in Firestore
4. Test with both Android and iOS devices (not just web preview)

---

**Ready to deploy?** Follow the steps in "How to Deploy Cloud Functions" above and your push notifications will start working! 🎉
