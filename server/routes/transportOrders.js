const express = require('express');
const router = express.Router();
const TransportOrder = require('../models/TransportOrder');
const Driver = require('../models/Driver');
const { getIO } = require('../socket/ioInstance');
const { emitToUser, emitToDriver } = require('../socket');
const { sendToUser, sendToDriver } = require('../fcm');
const authMiddleware = require('../middleware/auth');
const { deleteImageFile } = require('../helpers/fileCleanup');

router.use(authMiddleware);

router.get('/transport-orders', async (req, res) => {
  try {
    const uid = req.user.uid || req.user.user_id;
    const isAdmin = req.user.role === 'admin';
    if (req.query.userId && req.query.userId !== uid && !isAdmin) {
      return res.status(403).json({ error: 'غير مصرح' });
    }
    if (req.query.driverId && req.query.driverId !== uid && !isAdmin) {
      return res.status(403).json({ error: 'غير مصرح' });
    }
    const filter = {};
    if (req.query.userId) filter.userId = req.query.userId;
    if (req.query.driverId) filter.driverId = req.query.driverId;
    if (req.query.status) {
      const statuses = req.query.status.split(',');
      filter.status = { $in: statuses };
    }
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const orders = await TransportOrder.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit);
    res.json(orders);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/transport-orders/:id', async (req, res) => {
  try {
    const uid = req.user.uid || req.user.user_id;
    const order = await TransportOrder.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Transport order not found' });
    if (req.user.role !== 'admin' && order.userId !== uid && order.driverId !== uid) {
      return res.status(403).json({ error: 'غير مصرح' });
    }
    res.json(order);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/transport-orders', async (req, res) => {
  try {
    req.body.userId = req.user.uid || req.user.user_id;
    const order = await TransportOrder.create({ ...req.body, createdAt: new Date() });
    const io = getIO();
    if (io) {
      emitToUser(io, order.userId, 'transport:created', order);
      if (order.driverId) emitToDriver(io, order.driverId, 'transport:created', order);
      io.to('drivers').emit('transport:created', order);
    }
    res.status(201).json(order);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/transport-orders/:id', async (req, res) => {
  try {
    const uid = req.user.uid || req.user.user_id;
    if (req.user.role !== 'admin') {
      const existing = await TransportOrder.findById(req.params.id);
      if (!existing) return res.status(404).json({ error: 'Transport order not found' });
      if (existing.userId !== uid && existing.driverId !== uid) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
    }
    const old = await TransportOrder.findById(req.params.id);
    const updateBody = { ...req.body, updatedAt: new Date() };
    if (updateBody.status === 'accepted' && updateBody.driverId) {
      updateBody.rejectedBy = [];
    }
    const order = await TransportOrder.findByIdAndUpdate(
      req.params.id,
      updateBody,
      { returnDocument: 'after' }
    );
    if (!order) return res.status(404).json({ error: 'Transport order not found' });
    const io = getIO();
    if (io) {
      emitToUser(io, order.userId, 'transport:updated', order);
      if (order.driverId) emitToDriver(io, order.driverId, 'transport:updated', order);
    }
    const oldStatus = old?.status;
    if (order.status === 'accepted' && oldStatus !== 'accepted') {
      sendToUser({ userId: order.userId, title: '✅ تم قبول طلب النقل', body: 'تم قبول طلب النقل، انتظر مكالمة تأكيد.', data: { orderId: order._id.toString(), type: 'transport_accepted' } });
    } else if (order.status === 'onway' && oldStatus !== 'onway') {
      sendToUser({ userId: order.userId, title: '🚚 السائق في الطريق', body: 'السائق متجه إلى موقعك.', data: { orderId: order._id.toString(), type: 'transport_onway' } });
    } else if (order.status === 'delivered' && oldStatus !== 'delivered') {
      sendToUser({ userId: order.userId, title: '✅ تم إتمام النقل', body: 'شكراً لاستخدامك خدمة النقل!', data: { orderId: order._id.toString(), type: 'transport_delivered' } });
      if (order.driverId) {
        try {
          const fee = order.price || 0;
          const driver = await Driver.findOne({ uid: order.driverId });
          if (driver) {
            driver.totalEarnings = (driver.totalEarnings || 0) + fee;
            driver.totalDeliveries = (driver.totalDeliveries || 0) + 1;
            driver.cash = (driver.cash || 0) + fee;
            await driver.save();
            const io = getIO();
            if (io) emitToDriver(io, order.driverId, 'driver:updated', driver);
          }
        } catch (drvErr) {
          console.error('Transport order driver earnings error:', drvErr.message);
        }
      }
      deleteImageFile(order.fromImage);
      deleteImageFile(order.toImage);
      deleteImageFile(order.parcelImageUrl);
    }
    const oldCounterOffer = old?.counterOffer;
    if (order.counterOffer?.status === 'accepted' && oldCounterOffer?.status !== 'accepted' && order.driverId) {
      sendToDriver({ driverId: order.driverId, title: '💰 تم قبول عرض السعر', body: 'الزبون قبل العرض الجديد.', data: { orderId: order._id.toString(), type: 'counter_offer_accepted' } });
    }
    // إذا السائق رفض الطلبية → ننبّه الزبون
    const oldRejectedBy = old?.rejectedBy || [];
    const newReject = req.body.rejectedBy;
    if (newReject && !oldRejectedBy.includes(newReject)) {
      const uid = order.userId;
      if (uid) {
        const reason = req.body.rejectionReason ? `سبب الرفض: ${req.body.rejectionReason}` : '';
        sendToUser({ userId: uid, title: '❌ السائق رفض طلب النقل', body: `السائق رفض طلب النقل.${reason ? ' ' + reason : ''}`, data: { orderId: order._id.toString(), type: 'driver_rejected' } });
      }
    }
    res.json(order);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/transport-orders/:id', async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'غير مصرح' });
    await TransportOrder.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
