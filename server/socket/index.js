const Driver = require('../models/Driver');

const setupSocket = (io) => {
  io.on('connection', (socket) => {
    console.log(' Socket connected:', socket.id);

    socket.on('join', (data) => {
      const room = typeof data === 'string' ? data : data?.room;
      if (room) {
        socket.join(room);
        if (room.startsWith('driver_')) socket.join('drivers');
        console.log(`   Socket ${socket.id} joined room: ${room}`);
      }
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

        // Update location in database
        await Driver.findOneAndUpdate(
          { uid: driverId },
          { lat, lng, lastLocationUpdate: new Date() }
        );

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
