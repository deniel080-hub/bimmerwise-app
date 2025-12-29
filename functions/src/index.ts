import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Send notification to a user's FCM token
 */
async function sendNotificationToUser(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>
) {
  try {
    // Get user document to retrieve FCM token
    const userDoc = await db.collection("users").doc(userId).get();
    
    if (!userDoc.exists) {
      console.log(`User ${userId} not found`);
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token found for user ${userId}`);
      return;
    }

    // Send notification
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        notification: {
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.send(message);
    console.log(`Successfully sent notification to user ${userId}:`, response);
  } catch (error) {
    console.error(`Error sending notification to user ${userId}:`, error);
    
    // If token is invalid or expired, remove it from user document
    if (error && typeof error === "object" && "code" in error) {
      const errorCode = (error as any).code;
      if (errorCode === "messaging/invalid-registration-token" ||
          errorCode === "messaging/registration-token-not-registered") {
        await db.collection("users").doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        console.log(`Removed invalid FCM token for user ${userId}`);
      }
    }
  }
}

/**
 * Send notification to all admin users
 */
async function sendNotificationToAdmins(
  title: string,
  body: string,
  data?: Record<string, string>
) {
  try {
    // Get all users with isAdmin = true
    const adminsSnapshot = await db.collection("users")
      .where("isAdmin", "==", true)
      .get();

    if (adminsSnapshot.empty) {
      console.log("No admin users found");
      return;
    }

    const promises = adminsSnapshot.docs.map((doc) => 
      sendNotificationToUser(doc.id, title, body, data)
    );

    await Promise.all(promises);
    console.log(`Sent notifications to ${adminsSnapshot.size} admins`);
  } catch (error) {
    console.error("Error sending notifications to admins:", error);
  }
}

/**
 * Trigger: When a new order is created
 * Sends notification to the customer and admins
 */
export const onOrderCreated = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const orderData = snapshot.data();
    const orderId = context.params.orderId;

    console.log(`New order created: ${orderId}`);

    try {
      // Send notification to customer
      if (orderData.userId) {
        await sendNotificationToUser(
          orderData.userId,
          "Order Confirmed! 🎉",
          `Your order #${orderId.substring(0, 8)} has been confirmed. Total: $${orderData.totalAmount.toFixed(2)}`,
          {
            type: "order",
            orderId: orderId,
          }
        );
      }

      // Send notification to admins
      await sendNotificationToAdmins(
        "New Order Received 📦",
        `Order #${orderId.substring(0, 8)} - $${orderData.totalAmount.toFixed(2)} from ${orderData.customerName || "Guest"}`,
        {
          type: "admin_order",
          orderId: orderId,
        }
      );

      // Create in-app notification for customer
      if (orderData.userId) {
        await db.collection("notifications").add({
          userId: orderData.userId,
          title: "Order Confirmed! 🎉",
          message: `Your order #${orderId.substring(0, 8)} has been confirmed.`,
          type: "order",
          orderId: orderId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      console.error("Error handling order creation:", error);
    }
  });

/**
 * Trigger: When an order status is updated
 * Sends notification to the customer
 */
export const onOrderUpdated = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const orderId = context.params.orderId;

    // Check if status changed
    if (beforeData.status === afterData.status) {
      return;
    }

    console.log(`Order ${orderId} status changed: ${beforeData.status} → ${afterData.status}`);

    try {
      let title = "Order Update";
      let body = "";

      switch (afterData.status) {
        case "processing":
          title = "Order Processing 🔄";
          body = `Your order #${orderId.substring(0, 8)} is now being processed.`;
          break;
        case "shipped":
          title = "Order Shipped 🚚";
          body = `Your order #${orderId.substring(0, 8)} has been shipped!`;
          break;
        case "delivered":
          title = "Order Delivered ✅";
          body = `Your order #${orderId.substring(0, 8)} has been delivered. Thank you!`;
          break;
        case "cancelled":
          title = "Order Cancelled ❌";
          body = `Your order #${orderId.substring(0, 8)} has been cancelled.`;
          break;
        default:
          body = `Your order #${orderId.substring(0, 8)} status: ${afterData.status}`;
      }

      // Send notification to customer
      if (afterData.userId) {
        await sendNotificationToUser(
          afterData.userId,
          title,
          body,
          {
            type: "order_update",
            orderId: orderId,
            status: afterData.status,
          }
        );

        // Create in-app notification
        await db.collection("notifications").add({
          userId: afterData.userId,
          title: title,
          message: body,
          type: "order",
          orderId: orderId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      console.error("Error handling order update:", error);
    }
  });

/**
 * Trigger: When a new service record is created
 * Sends notification to the customer and admins
 */
export const onServiceRecordCreated = functions.firestore
  .document("service_records/{recordId}")
  .onCreate(async (snapshot, context) => {
    const recordData = snapshot.data();
    const recordId = context.params.recordId;

    console.log(`New service record created: ${recordId}`);

    try {
      let serviceType = "Service";
      if (recordData.serviceType === "carplay") {
        serviceType = "CarPlay";
      } else if (recordData.serviceType === "gearbox") {
        serviceType = "Gearbox";
      } else if (recordData.serviceType === "regular") {
        serviceType = "Regular Service";
      }

      // Send notification to customer
      if (recordData.userId) {
        await sendNotificationToUser(
          recordData.userId,
          "Booking Confirmed! 🔧",
          `Your ${serviceType} booking for ${recordData.serviceDate} has been confirmed.`,
          {
            type: "service",
            recordId: recordId,
          }
        );

        // Create in-app notification
        await db.collection("notifications").add({
          userId: recordData.userId,
          title: "Booking Confirmed! 🔧",
          message: `Your ${serviceType} booking has been confirmed.`,
          type: "service",
          recordId: recordId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Send notification to admins
      const customerName = recordData.customerName || "Customer";
      await sendNotificationToAdmins(
        "New Service Booking 🔧",
        `${serviceType} booking from ${customerName} on ${recordData.serviceDate}`,
        {
          type: "admin_service",
          recordId: recordId,
        }
      );
    } catch (error) {
      console.error("Error handling service record creation:", error);
    }
  });

/**
 * Trigger: When a service record status is updated
 * Sends notification to the customer and admins (for cancellations/modifications by users)
 */
export const onServiceRecordUpdated = functions.firestore
  .document("service_records/{recordId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const recordId = context.params.recordId;

    console.log(`Service record ${recordId} updated`);
    console.log(`Before status: ${beforeData.status}, After status: ${afterData.status}`);
    console.log(`Modified by admin: ${afterData.modifiedByAdmin}`);

    try {
      // Check if modification was by admin
      const isAdminModification = afterData.modifiedByAdmin === true;
      
      let title = "Service Update";
      let body = "";
      let notifyAdmins = false;
      let notifyUser = false;
      let adminTitle = "";
      let adminBody = "";

      // Get service type name
      let serviceTypeName = afterData.serviceType || "Service";

      // Get customer name if available
      let customerName = "Customer";
      if (afterData.userId) {
        try {
          const userDoc = await db.collection("users").doc(afterData.userId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            customerName = userData?.name || customerName;
          }
        } catch (error) {
          console.log("Could not fetch customer name:", error);
        }
      }

      // Check if status changed
      if (beforeData.status !== afterData.status) {
        console.log(`Status changed: ${beforeData.status} → ${afterData.status}`);

        if (isAdminModification) {
          // Admin modified the booking
          console.log("Admin-initiated status change");
          
          switch (afterData.status) {
            case "Booking Confirmed":
              title = "Booking Confirmed ✅";
              body = `Your ${serviceTypeName} booking has been confirmed by admin.`;
              notifyUser = true;
              break;
            case "Completed":
              title = "Service Completed ✅";
              body = `Your ${serviceTypeName} has been completed. Ready to collect!`;
              notifyUser = true;
              break;
            case "Booking Canceled":
              title = "Booking Canceled ❌";
              body = `Your ${serviceTypeName} booking has been canceled by admin. Please contact us.`;
              notifyUser = true;
              break;
            default:
              title = "Booking Updated 🔄";
              body = `Your ${serviceTypeName} booking status: ${afterData.status}`;
              notifyUser = true;
          }
        } else {
          // User modified their own booking
          console.log("User-initiated status change");
          
          switch (afterData.status) {
            case "Booking Confirmed":
              title = "Booking Confirmed ✅";
              body = `Your ${serviceTypeName} booking has been confirmed.`;
              notifyUser = true;
              break;
            case "Completed":
              title = "Service Completed ✅";
              body = `Your ${serviceTypeName} has been completed. Ready to collect!`;
              notifyUser = true;
              break;
            case "Booking Canceled":
              title = "Booking Cancelled ❌";
              body = `Your ${serviceTypeName} booking has been cancelled.`;
              notifyUser = true;
              // Notify admins when user cancels
              notifyAdmins = true;
              adminTitle = "Booking Cancelled by User 🚫";
              adminBody = `${customerName} cancelled their ${serviceTypeName} booking`;
              break;
            default:
              body = `${serviceTypeName} status: ${afterData.status}`;
              notifyUser = true;
          }
        }

        // Send notification to customer
        if (notifyUser && afterData.userId) {
          await sendNotificationToUser(
            afterData.userId,
            title,
            body,
            {
              type: "service_update",
              recordId: recordId,
              status: afterData.status,
            }
          );

          // Create in-app notification for customer
          await db.collection("notifications").add({
            userId: afterData.userId,
            title: title,
            message: body,
            type: isAdminModification ? "adminModified" : "service",
            bookingId: recordId,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Status didn't change, check if other fields changed (modification)
        const hasChanges = 
          beforeData.serviceDate?.seconds !== afterData.serviceDate?.seconds ||
          beforeData.description !== afterData.description ||
          beforeData.cost !== afterData.cost;

        if (hasChanges) {
          console.log("Booking details modified");
          
          if (isAdminModification) {
            // Admin modified booking details
            console.log("Admin modified booking details");
            title = "Booking Updated by Admin 🔄";
            body = `Your ${serviceTypeName} booking has been updated by admin.`;
            notifyUser = true;
          } else {
            // User modified their booking
            console.log("User modified booking details");
            notifyAdmins = true;
            adminTitle = "Booking Modified by User 📝";
            adminBody = `${customerName} modified their ${serviceTypeName} booking`;
            
            // Notify customer about modification
            title = "Booking Updated 📝";
            body = `Your ${serviceTypeName} booking has been updated.`;
            notifyUser = true;
          }
          
          // Send notification to customer if needed
          if (notifyUser && afterData.userId) {
            await sendNotificationToUser(
              afterData.userId,
              title,
              body,
              {
                type: "service_update",
                recordId: recordId,
                status: afterData.status,
              }
            );

            // Create in-app notification for customer
            await db.collection("notifications").add({
              userId: afterData.userId,
              title: title,
              message: body,
              type: isAdminModification ? "adminModified" : "service",
              bookingId: recordId,
              isRead: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // Send notification to admins if needed (only for user-initiated changes)
      if (notifyAdmins) {
        await sendNotificationToAdmins(
          adminTitle,
          adminBody,
          {
            type: "admin_booking_update",
            recordId: recordId,
          }
        );

        // Create in-app notifications for all admins
        const adminsSnapshot = await db.collection("users")
          .where("isAdmin", "==", true)
          .get();
        
        const adminNotifications = adminsSnapshot.docs.map((doc) => 
          db.collection("notifications").add({
            userId: doc.id,
            title: adminTitle,
            message: adminBody,
            type: afterData.status === "Booking Canceled" ? "bookingCanceled" : "bookingModified",
            bookingId: recordId,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          })
        );

        await Promise.all(adminNotifications);
      }

      // Reset modifiedByAdmin flag after processing
      if (isAdminModification) {
        await db.collection("service_records").doc(recordId).update({
          modifiedByAdmin: false,
        });
      }
    } catch (error) {
      console.error("Error handling service record update:", error);
    }
  });

/**
 * Scheduled Function: Runs every hour to send 24-hour booking reminders
 * Checks for bookings that are 23-25 hours away and sends reminders
 */
export const sendBookingReminders = functions.pubsub
  .schedule("every 1 hours")
  .timeZone("America/New_York") // Change to your timezone
  .onRun(async (context) => {
    console.log("Running scheduled booking reminders check...");

    try {
      const now = admin.firestore.Timestamp.now();
      const nowDate = now.toDate();
      
      // Calculate 23 and 25 hours from now (to catch the 24-hour window)
      const after23Hours = new Date(nowDate.getTime() + 23 * 60 * 60 * 1000);
      const after25Hours = new Date(nowDate.getTime() + 25 * 60 * 60 * 1000);
      
      console.log(`Checking bookings between ${after23Hours.toISOString()} and ${after25Hours.toISOString()}`);

      // Query service records that need reminders
      const recordsSnapshot = await db.collection("service_records")
        .where("serviceDate", ">=", admin.firestore.Timestamp.fromDate(after23Hours))
        .where("serviceDate", "<=", admin.firestore.Timestamp.fromDate(after25Hours))
        .where("reminderSent", "==", false)
        .get();

      if (recordsSnapshot.empty) {
        console.log("No bookings found that need reminders");
        return null;
      }

      console.log(`Found ${recordsSnapshot.size} bookings that need reminders`);

      // Send reminders for each booking
      const promises = recordsSnapshot.docs.map(async (doc) => {
        const recordData = doc.data();
        const recordId = doc.id;

        // Skip completed or cancelled bookings
        if (recordData.status === "completed" || recordData.status === "cancelled") {
          console.log(`Skipping ${recordId} - status: ${recordData.status}`);
          return;
        }

        try {
          // Get user details
          let userName = "Customer";
          let userId = recordData.userId;

          if (userId) {
            const userDoc = await db.collection("users").doc(userId).get();
            if (userDoc.exists) {
              const userData = userDoc.data();
              userName = userData?.name || userName;
            }
          } else if (recordData.customerName) {
            userName = recordData.customerName;
          }

          // Get vehicle details to show in reminder
          let vehicleInfo = "";
          if (recordData.vehicleId) {
            const vehicleDoc = await db.collection("vehicles").doc(recordData.vehicleId).get();
            if (vehicleDoc.exists) {
              const vehicleData = vehicleDoc.data();
              vehicleInfo = `${vehicleData?.make || ""} ${vehicleData?.model || ""}`.trim();
            }
          } else if (recordData.vehicleMake && recordData.vehicleModel) {
            vehicleInfo = `${recordData.vehicleMake} ${recordData.vehicleModel}`;
          }

          // Format service date
          const serviceDate = (recordData.serviceDate as admin.firestore.Timestamp).toDate();
          const dateStr = serviceDate.toLocaleDateString("en-US", {
            weekday: "long",
            month: "long",
            day: "numeric",
            year: "numeric",
          });
          const timeStr = serviceDate.toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            hour12: true,
          });

          // Determine service type name
          let serviceTypeName = "Service";
          switch (recordData.serviceType) {
            case "carplay":
              serviceTypeName = "CarPlay Installation";
              break;
            case "gearbox":
              serviceTypeName = "Gearbox Service";
              break;
            case "xhp_remap":
              serviceTypeName = "BMW XHP Gearbox Remap";
              break;
            case "regular":
              serviceTypeName = "Regular Service";
              break;
            default:
              serviceTypeName = recordData.serviceType || "Service";
          }

          // Send push notification to user
          if (userId) {
            const title = "Booking Reminder 🔔";
            const body = `Your ${serviceTypeName} appointment is tomorrow at ${timeStr}${vehicleInfo ? ` for your ${vehicleInfo}` : ""}`;
            
            await sendNotificationToUser(
              userId,
              title,
              body,
              {
                type: "reminder",
                recordId: recordId,
              }
            );

            // Create in-app notification
            await db.collection("notifications").add({
              userId: userId,
              title: title,
              message: `Your ${serviceTypeName} appointment is scheduled for ${dateStr} at ${timeStr}.${vehicleInfo ? ` Vehicle: ${vehicleInfo}` : ""}`,
              type: "service",
              recordId: recordId,
              isRead: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`Sent reminder for booking ${recordId} to user ${userId}`);
          } else {
            console.log(`No userId found for booking ${recordId} - cannot send reminder`);
          }

          // Mark reminder as sent
          await db.collection("service_records").doc(recordId).update({
            reminderSent: true,
          });

        } catch (error) {
          console.error(`Error sending reminder for booking ${recordId}:`, error);
        }
      });

      await Promise.all(promises);
      console.log("Finished sending booking reminders");
      return null;

    } catch (error) {
      console.error("Error in sendBookingReminders function:", error);
      return null;
    }
  });
