const { getMessaging } = require('firebase-admin/messaging');

async function clearFcmToken(Model, query) {
  try {
    await Model.updateOne(query, { $unset: { fcmToken: '' } });
    console.log(`✅ Cleared invalid fcmToken for ${Model.modelName}:`, query);
  } catch (e) {
    console.error('Failed to clear fcmToken:', e.message);
  }
}

async function sendToDriver({ driverId, title, body, data = {} }) {
  try {
    const mongoose = require('mongoose');
    const Driver = require('./models/Driver');
    let driver = await Driver.findOne({ uid: driverId });
    if (!driver && mongoose.Types.ObjectId.isValid(driverId)) {
      driver = await Driver.findById(driverId);
    }
    if (!driver || !driver.fcmToken) {
      console.log(`FCM: no fcmToken for driver ${driverId}`);
      return;
    }
    await getMessaging().send({
      token: driver.fcmToken,
      notification: { title, body },
      data: Object.fromEntries(Object.entries({ title, body, recipientId: driverId, ...data }).map(([k, v]) => [k, String(v)])),
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'orders_channel',
          priority: 'max',
          visibility: 'public',
        },
      },
    });
    console.log(`FCM sent to driver ${driverId}: ${title}`);
  } catch (e) {
    if (e.code === 'messaging/registration-token-not-registered' || e.message?.includes('NotRegistered')) {
      const Driver = require('./models/Driver');
      await clearFcmToken(Driver, { uid: driverId });
    } else {
      console.error(`FCM Error for driver ${driverId}:`, e.message);
    }
  }
}

async function sendToUser({ userId, title, body, data = {} }) {
  try {
    const mongoose = require('mongoose');
    const User = require('./models/User');
    let user = await User.findOne({ uid: userId });
    if (!user && mongoose.Types.ObjectId.isValid(userId)) {
      user = await User.findById(userId);
    }
    if (!user || !user.fcmToken) {
      console.log(`FCM: no fcmToken for user ${userId}`);
      return;
    }
    if (user.settings?.disablePurchaseNotif && data?.type?.includes('purchased')) {
      console.log(`FCM: skipped purchase notif for ${userId}`);
      return;
    }

    const isRing = data.sound === 'ring';
    const isOkhrej = data.sound === 'okhrej';
    const isAlternative = data.sound === 'alternative';
    const isDelivered = data.sound === 'delivered';

    const dataFields = Object.fromEntries(
      Object.entries({ title, body, recipientId: userId, ...data }).map(([k, v]) => [k, String(v)])
    );

    if (isRing || isAlternative || isDelivered) {
      await getMessaging().send({
        token: user.fcmToken,
        data: dataFields,
        android: {
          priority: 'high',
        },
      });
      console.log(`FCM sent to ${userId}: ${title} | DATA-ONLY (${isRing ? 'ring' : isAlternative ? 'alternative' : 'delivered'})`);
    } else if (isOkhrej) {
      await getMessaging().send({
        token: user.fcmToken,
        notification: { title, body },
        data: dataFields,
        android: {
          priority: 'high',
          notification: {
            channelId: 'user_channel_okhrej',
            sound: 'okhrej',
            priority: 'max',
            visibility: 'public',
          },
        },
      });
      console.log(`FCM sent to ${userId}: ${title} | okhrej notification`);
    } else {
      await getMessaging().send({
        token: user.fcmToken,
        notification: { title, body },
        data: dataFields,
        android: {
          priority: 'high',
          notification: {
            channelId: 'user_channel',
            sound: 'default',
            priority: 'max',
            visibility: 'public',
          },
        },
      });
      console.log(`FCM sent to ${userId}: ${title} | notification`);
    }
  } catch (e) {
    if (e.code === 'messaging/registration-token-not-registered' || e.message?.includes('NotRegistered')) {
      const User = require('./models/User');
      await clearFcmToken(User, { uid: userId });
    } else {
      console.error(`FCM Error for user ${userId}:`, e.message);
    }
  }
}

module.exports = { sendToUser, sendToDriver };
