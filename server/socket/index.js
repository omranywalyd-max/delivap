const Driver = require('../models/Driver');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');

// ── Resolve identity (optional) from Firebase ID token or app JWT ──
async function resolveSocketUser(socket) {
  const token = (socket.handshake.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  try {
    if (admin.getApps().length > 0) {
      const decoded = await admin.auth().verifyIdToken(token);
      return { uid: decoded.uid, role: decoded.role || 'user' };
    }
  } catch (_) {}
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    return {
      uid: decoded.uid || decoded.user_id || decoded.id,
      username: decoded.username,
      role: decoded.role || 'user'
    };
  } catch (_) {}
  return null;
}

function identityMatches(user, id) {
  if (!user || !id) return false;
  const candidates = [user.uid, user.id, user.user_id, user.username];
  return candidates.filter(Boolean).some((c) => String(c) === String(id));
}

function canJoinRoom(user, room) {
  if (room === 'admin_room') return !!(user && user.role === 'admin');
  // All other rooms require authentication
  if (!user) return false;
  if (room.startsWith('track_driver_')) {
    const id = room.slice('track_driver_'.length);
    return identityMatches(user, id);
  }
  if (room.startsWith('user_')) {
    const id = room.slice('user_'.length);
    return identityMatches(user, id);
  }
  if (room.startsWith('driver_')) {
    const id = room.slice('driver_'.length);
    return identityMatches(user, id);
  }
  return false;
}

const setupSocket = (io) => {
  io.on('connection', (socket) => {
    const userPromise = resolveSocketUser(socket);
    console.log(' Socket connected:', socket.id);

    socket.on('join', async (data) => {
      const room = typeof data === 'string' ? data : data?.room;
      if (!room) return;
      const user = await userPromise;
      if (!canJoinRoom(user, room)) {
        console.log(`   Socket ${socket.id} DENIED join room: ${room}`);
        return;
      }
      socket.join(room);
      if (room.startsWith('driver_')) socket.join('drivers');
      console.log(`   Socket ${socket.id} joined room: ${room}`);
    });

    socket.on('leave', (data) => {
      const room = typeof data === 'string' ? data : data?.room;
      if (room) {
        socket.leave(room);
        console.log(`   Socket ${socket.id} left room: ${room}`);
      }
    });

    // Driver location updates (realtime) — broadcast ONLY to tracking room
    socket.on('driver:location', async (data) => {
      try {
        const { driverId, lat, lng } = data;

        if (!driverId || lat === undefined || lng === undefined) return;

        // Authenticated senders may only push location for their own account
        const user = await userPromise;
        if (user && !identityMatches(user, driverId)) return;

        // Update location in database
        await Driver.findOneAndUpdate(
          { uid: driverId },
          { lat, lng, lastLocationUpdate: new Date() }
        );

        // تحديث موقع السائق في الطلبيات النشطة
        await require('../models/Order').updateMany(
          { driverId, status: { $in: ['accepted', 'purchased', 'onway'] } },
          { driverLat: lat, driverLng: lng }
        );

        // تحديث موقع السائق في توصيليات المشاريع النشطة (بعد قبول السائق)
        await require('../models/ProjectDelivery').updateMany(
          { driverId, status: { $in: ['accepted', 'onway_to_store', 'near_owner', 'picked_up', 'in_transit', 'near_customer'] } },
          { driverLat: lat, driverLng: lng }
        );

        // بث الطلبيات المحدّثة للزبون والسائق (مسار إضافي للتتبع)
        const activeOrders = await require('../models/Order').find(
          { driverId, status: { $in: ['accepted', 'purchased', 'onway'] } }
        );
        for (const o of activeOrders) {
          if (o.userId) io.to(`user_${o.userId}`).emit('order:updated', o);
          io.to(`driver_${driverId}`).emit('order:updated', o);
        }

        // Broadcast ONLY to users tracking this specific driver
        io.to(`track_driver_${driverId}`).emit('driver:location_updated', {
          driverId,
          lat,
          lng,
          timestamp: new Date().toISOString(),
        });
      } catch (err) {
        console.error('driver:location error:', err.message);
      }
    });

    // Driver status changes — broadcast ONLY to admin room
    socket.on('driver:status', async (data) => {
      try {
        const { driverId, status } = data;

        // Authenticated senders may only toggle status for their own account
        const user = await userPromise;
        if (user && !identityMatches(user, driverId)) return;

        await Driver.findOneAndUpdate(
          { uid: driverId },
          { isOnline: status === 'online', updatedAt: new Date() }
        );
        io.to('admin_room').emit('driver:status_changed', { driverId, status, timestamp: new Date() });
      } catch (err) {
        console.error('driver:status error:', err.message);
      }
    });

    socket.on('disconnect', () => {
      console.log(' Socket disconnected:', socket.id);
    });
  });
};

const emitToUser = (io, userId, event, data) => {
  io.to(`user_${userId}`).emit(event, data);
};

const emitToDriver = (io, driverId, event, data) => {
  io.to(`driver_${driverId}`).emit(event, data);
};

const emitToRoom = (io, room, event, data) => {
  io.to(room).emit(event, data);
};

module.exports = { setupSocket, emitToUser, emitToDriver, emitToRoom };
