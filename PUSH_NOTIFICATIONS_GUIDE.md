# Push Notifications Setup Guide

## ✅ Current Implementation Status

Your BIMMERWISE app has **full push notification support** configured for:
- ✅ **Real-time in-app notifications** (via Firestore streams)
- ✅ **Push notifications** (via Firebase Cloud Messaging)
- ✅ **Samsung device optimization**
- ✅ **iOS and Android support**

---

## 📱 Samsung Device Compatibility

### What's Been Optimized:
1. **Battery Optimization Handling**
   - Added `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission
   - Notifications will work even with aggressive battery management

2. **Enhanced Notification Priority**
   - Using `Importance.max` and `Priority.max` for Android
   - Notifications show on lock screen (`visibility: public`)

3. **FCM Token Management**
   - Retry logic for token retrieval (Samsung devices sometimes delay token generation)
   - Token refresh listener to handle Samsung's periodic token refreshes

4. **Direct Boot Support**
   - FCM service enabled for `directBootAware` mode
   - Notifications work even before device unlock

---

## 🧪 Testing Push Notifications on Samsung Devices

### Step 1: Grant Permissions
When you first open the app on a Samsung device:
1. Allow notification permissions when prompted
2. Go to **Settings → Apps → BIMMERWISE → Notifications**
3. Enable **All notification categories**
4. Ensure **Allow notifications** is ON

### Step 2: Disable Battery Optimization
Samsung's aggressive battery management can block notifications:
1. Go to **Settings → Apps → BIMMERWISE → Battery**
2. Select **Unrestricted** or **Optimized** (avoid "Restricted")
3. Some Samsung devices: **Settings → Device care → Battery → App power management**
4. Add BIMMERWISE to **Apps that won't be put to sleep**

### Step 3: Check Samsung Notification Settings
Samsung has additional notification layers:
1. **Settings → Notifications → Advanced settings**
2. Enable **Show notification icons**
3. Enable **Notification pop-ups**
4. Set **Notification reminder** if desired

### Step 4: Test Different Scenarios

#### Scenario A: App Open (Foreground)
1. Open the app
2. Have another user create a booking
3. You should see a **local notification banner** at the top
4. The notification also appears in the **notification bell icon**

#### Scenario B: App in Background
1. Press the Home button (app minimized)
2. Have another user create a booking
3. You should receive a **push notification**
4. Tap the notification → app opens to the relevant screen

#### Scenario C: App Completely Closed
1. Swipe away the app from Recent Apps
2. Have another user create a booking
3. You should receive a **push notification**
4. Tap the notification → app opens to the relevant screen

#### Scenario D: Device Locked
1. Lock your Samsung device
2. Have another user create a booking
3. Notification should appear on **lock screen**

---

## 🔔 Real-Time Notifications

### How It Works:
1. **Firestore Streams**: Real-time updates without page refresh
2. **Push Notifications**: Background/foreground alerts via FCM
3. **Cloud Functions**: Automatically triggered when bookings are created/modified

### What Triggers Notifications:
- **For Admin Users:**
  - ✅ New booking created by customer
  - ✅ Booking modified by customer
  - ✅ Booking canceled by customer
  
- **For Customers:**
  - ✅ Booking confirmed by admin
  - ✅ Booking modified by admin
  - ✅ Booking canceled by admin
  - ✅ Service completed
  - ✅ 24-hour booking reminders (automated)

---

## 🐛 Troubleshooting Samsung Devices

### Notifications Not Showing?

1. **Check Debug Console Logs:**
   - Look for `✅ FCM Service initialized successfully`
   - Look for `📱 FCM Token obtained`
   - Look for `📨 Foreground message received` or `📨 Background message received`

2. **Verify FCM Token is Saved:**
   - After login, check Debug Console for: `✅ FCM token saved to user document`
   - If missing, the user won't receive push notifications

3. **Verify Cloud Functions are Deployed:**
   - Cloud Functions must be deployed to Firebase to send push notifications
   - Check Firebase Console → Functions to ensure they're active

4. **Check Firestore Security Rules:**
   - Ensure users can write to `notifications` collection
   - Ensure Cloud Functions have admin privileges

5. **Samsung-Specific Issues:**
   - **Problem**: Notifications stop after device restart
     - **Solution**: User needs to open the app once after restart
   
   - **Problem**: Notifications delayed by 5-10 minutes
     - **Solution**: Disable battery optimization for BIMMERWISE
   
   - **Problem**: No sound/vibration
     - **Solution**: Check Samsung's notification sound settings
   
   - **Problem**: Notifications disappear immediately
     - **Solution**: Enable "Show notification content" in Samsung settings

---

## 📊 Monitoring Notifications

### Debug Console Logs:
- `🔔 Requesting FCM permissions...` → Permission request started
- `✅ FCM Permission status: authorized` → Permissions granted
- `📱 FCM Token obtained` → Device ready to receive push
- `✅ FCM token saved to user document` → Token stored in Firestore
- `📨 Foreground message received` → Notification received while app open
- `📨 Background message tapped` → User tapped notification
- `✅ Local notification shown` → Notification displayed

### Firebase Console:
- **Cloud Functions logs**: Check if functions are executing
- **FCM logs**: Verify messages are being sent
- **Firestore**: Verify notifications collection is being updated

---

## 🚀 Deployment Checklist

Before deploying to production:
- [ ] Deploy Cloud Functions to Firebase
- [ ] Test on multiple Samsung devices (S21, S22, S23, etc.)
- [ ] Test with different Android versions (11, 12, 13, 14)
- [ ] Verify battery optimization settings
- [ ] Test notification tap navigation
- [ ] Test 24-hour booking reminders
- [ ] Test admin-to-customer notifications
- [ ] Test customer-to-admin notifications

---

## 📝 Notes

### Known Samsung Behaviors:
- Samsung devices may show a "Swipe to open app" notification style
- One UI 5+ has enhanced notification grouping
- Samsung's "Smart Pop-up View" may affect notification behavior
- Battery optimization is more aggressive than stock Android

### Web Preview Limitations:
- Push notifications don't work in web preview (browser restriction)
- You'll see: `⚠️ FCM notifications not available on web preview`
- This is **normal** - notifications work on real devices

### Next Steps:
1. Deploy Cloud Functions: `firebase deploy --only functions`
2. Test on a physical Samsung device
3. Monitor Debug Console for any errors
4. Check Firebase Console for Cloud Function execution logs

---

## 🆘 Support

If notifications still don't work after following this guide:
1. Check Debug Console logs (share with support)
2. Check Firebase Console → Functions → Logs
3. Verify Samsung device settings
4. Test on a different Samsung device to isolate the issue
