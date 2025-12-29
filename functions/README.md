# Bimmerwise Cloud Functions

Firebase Cloud Functions for push notifications and backend automation.

## 📦 Functions Overview

### 1. **onOrderCreated**
- Triggers when a new order is created
- Sends confirmation notification to customer
- Alerts admins about new orders
- Creates in-app notification record

### 2. **onOrderUpdated**
- Triggers when order status changes
- Notifies customer about order progress (processing, shipped, delivered, cancelled)
- Creates in-app notification record

### 3. **onServiceRecordCreated**
- Triggers when a new service booking is made
- Sends confirmation to customer
- Alerts admins about new bookings
- Creates in-app notification record

### 4. **onServiceRecordUpdated**
- Triggers when service status changes
- Notifies customer about service progress (confirmed, in progress, completed, cancelled)
- Creates in-app notification record

## 🚀 Deployment

### From Dreamflow:
1. Go to **Firebase panel** (left sidebar)
2. Look for **Cloud Functions** section
3. Click **"Deploy Functions"**

### Manual Deployment:
```bash
# Install dependencies
cd functions
npm install

# Deploy all functions
npm run deploy

# Deploy specific function
firebase deploy --only functions:onOrderCreated

# View logs
npm run logs
```

## 📱 How It Works

1. **User Action** → Order/Service created in Firestore
2. **Cloud Function** → Automatically triggered by Firestore
3. **Fetch FCM Token** → Retrieved from user's profile
4. **Send Notification** → Delivered via Firebase Cloud Messaging
5. **In-App Record** → Created in notifications collection

## 🔧 Configuration

The functions automatically use:
- Firebase Admin SDK (server-side access)
- Firestore database connection
- Firebase Cloud Messaging

**No additional configuration needed!** Firebase handles authentication automatically.

## 📝 Notes

- Functions run on Node.js 18
- Invalid/expired FCM tokens are automatically removed
- All notifications include both push and in-app records
- Admins receive notifications for all new orders and services
- Error handling and logging included
