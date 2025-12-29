# 🚀 Firebase Cloud Functions Deployment Guide

## ✅ What's Already Set Up

Your Cloud Functions are **fully configured and ready to deploy**. They will handle:

1. **📱 Real-time Push Notifications** to all devices (Android, iOS, Web)
2. **🔔 Booking Notifications** - Admins get notified when users create, modify, or cancel bookings
3. **✅ Service Completion Notifications** - Users get notified when their service is completed
4. **📦 Order Notifications** - Customers and admins get notified about orders
5. **⏰ Automated Booking Reminders** - 24-hour reminders sent automatically

---

## 📋 Prerequisites

Before deploying, make sure you have:

1. **Node.js** installed (version 18 or higher)
2. **Firebase CLI** installed globally:
   ```bash
   npm install -g firebase-tools
   ```
3. **Firebase Project** connected (you already have this)
4. **Admin access** to your Firebase project

---

## 🛠️ Deployment Steps

### 1️⃣ Login to Firebase CLI

Open your terminal and login:
```bash
firebase login
```

### 2️⃣ Navigate to Your Project Directory

```bash
cd /path/to/your/bimmerwise/project
```

### 3️⃣ Install Cloud Functions Dependencies

```bash
cd functions
npm install
cd ..
```

### 4️⃣ Deploy Cloud Functions

Deploy all functions:
```bash
firebase deploy --only functions
```

**OR** deploy specific functions:
```bash
# Deploy only notification functions
firebase deploy --only functions:onServiceRecordCreated,functions:onServiceRecordUpdated

# Deploy only order functions
firebase deploy --only functions:onOrderCreated,functions:onOrderUpdated

# Deploy reminder scheduler
firebase deploy --only functions:sendBookingReminders
```

### 5️⃣ Wait for Deployment

The deployment will take 2-5 minutes. You'll see output like:
```
✔  functions[onServiceRecordCreated(us-central1)] Successful create operation.
✔  functions[onServiceRecordUpdated(us-central1)] Successful update operation.
✔  Deploy complete!
```

---

## 🎯 What Happens After Deployment

Once deployed, the following will happen **automatically**:

### For Users:
- ✅ Get push notifications when:
  - Booking is confirmed
  - Service status changes
  - Service is completed
  - Admin modifies their booking
  - 24 hours before their appointment

### For Admins:
- ✅ Get push notifications when:
  - New bookings are created
  - Users modify bookings
  - Users cancel bookings
  - New orders are placed

---

## 🔍 Verify Deployment

### Check in Firebase Console:

1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Functions** in the left sidebar
4. You should see these functions listed:
   - `onServiceRecordCreated`
   - `onServiceRecordUpdated`
   - `onOrderCreated`
   - `onOrderUpdated`
   - `sendBookingReminders`

### Test Push Notifications:

1. **Create a test booking** on your device
2. **Check admin device** - should receive push notification instantly
3. **Mark service as completed** in admin panel
4. **Check user device** - should receive completion notification

---

## 📊 Monitor Function Logs

View real-time logs to debug issues:

```bash
# View all function logs
firebase functions:log

# View logs for specific function
firebase functions:log --only onServiceRecordCreated

# Follow logs in real-time
firebase functions:log --only onServiceRecordCreated --follow
```

---

## ⚙️ Configure Booking Reminders (Optional)

The `sendBookingReminders` function runs **every hour** and checks for bookings 24 hours away.

**To change the timezone:**
1. Open `functions/src/index.ts`
2. Find the `sendBookingReminders` function (around line 463)
3. Change `.timeZone("America/New_York")` to your timezone
4. Redeploy: `firebase deploy --only functions:sendBookingReminders`

**Available timezones:**
- `"America/New_York"` - Eastern Time
- `"America/Los_Angeles"` - Pacific Time
- `"America/Chicago"` - Central Time
- `"Europe/London"` - UK Time
- `"Asia/Dubai"` - UAE Time
- [Full list of timezones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

---

## 🚨 Troubleshooting

### Issue: "Functions deployment failed"

**Solution:** Check that your Firebase project has the **Blaze (pay-as-you-go) plan** enabled. Cloud Functions require this plan.

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click on **Upgrade** in the left sidebar
4. Choose **Blaze Plan** (only pay for what you use)

---

### Issue: "No push notifications received"

**Solution 1: Check FCM Token**
```bash
# View function logs to see if token exists
firebase functions:log --only onServiceRecordCreated
```

Look for log entries like:
- ✅ `"Successfully sent notification to user XYZ"` - Working!
- ⚠️ `"No FCM token found for user XYZ"` - User needs to login again

**Solution 2: Ask users to logout and login again**
This will refresh their FCM tokens.

**Solution 3: Check device permissions**
Make sure users have enabled notifications in device settings.

---

### Issue: "Scheduled reminders not working"

**Solution:** The scheduler function may need manual first trigger:

```bash
# Manually trigger the reminder function
firebase functions:shell
sendBookingReminders()
```

Then check logs:
```bash
firebase functions:log --only sendBookingReminders
```

---

## 💰 Cost Estimate

Cloud Functions on the **Blaze Plan** includes:
- **2 million invocations/month FREE**
- **400,000 GB-seconds of compute time FREE**
- **200,000 CPU-seconds of compute time FREE**

For a typical small business with **100 bookings/month**:
- **Estimated cost: $0 - $1/month** (well within free tier)

Your current setup is very efficient and should stay within the free tier! 🎉

---

## 📱 Next Steps

1. **Deploy the functions** using the commands above
2. **Test notifications** by creating a booking
3. **Monitor logs** for any errors
4. **Enjoy real-time notifications!** 🚀

---

## 📞 Need Help?

If you encounter any issues:

1. Check the Firebase Console logs
2. Run `firebase functions:log` to see detailed errors
3. Make sure all devices are logged in (to get FCM tokens)
4. Verify Firestore security rules allow Cloud Functions to read/write

---

## ✨ Summary

Your Cloud Functions are **production-ready** and will provide:
- ✅ Real-time push notifications on all devices
- ✅ Automatic booking reminders
- ✅ Admin notifications for all booking changes
- ✅ Service completion notifications

Just deploy and you're done! 🎊
