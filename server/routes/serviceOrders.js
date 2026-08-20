const express = require('express');
const router = express.Router();
const ServiceOrder = require('../models/ServiceOrder');
const Driver = require('../models/Driver');
const WilayaConfig = require('../models/WilayaConfig');
const { getIO } = require('../socket/ioInstance');
const { emitToUser, emitToDriver } = require('../socket');
const { sendToUser, sendToDriver } = require('../fcm');
const authMiddleware = require('../middleware/auth');
const { deleteImageFile } = require('../helpers/fileCleanup');

router.use(authMiddleware);

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371.0;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// حساب التسعيرة تلقائياً: المسافة بين الموقعين + تسعيرة المدينة (بالكيلومتر)
router.post('/service-orders/quote', async (req, res) => {
  try {
    const { fromLat, fromLng, toLat, toLng } = req.body;
    if (
      fromLat == null || fromLng == null || toLat == null || toLng == null ||
      fromLat === 0 || fromLng === 0 || toLat === 0 || toLng === 0
    ) {
      return res.json({ deliveryFee: null, distanceKm: null, cityName: '', cityNameFr: '', basePrice: 0, baseDist: 5, extraDistPrice: 0, extraKm: 0 });
    }

    const distanceKm = haversineKm(Number(fromLat), Number(fromLng), Number(toLat), Number(toLng));

    // نجيب أقرب تسعيرة مدينة لموقع الانطلاق — تسعيرة الدراجة فقط (الإحضار/التوصيل)
    // لا نستعمل أبداً تسعيرة مركبات أخرى (لا خلط)
    const configs = await WilayaConfig.find({ vehicleType: 'motorcycle' }).lean();
    let best = null;
    let bestDist = Infinity;
    for (const cfg of configs) {
      if (cfg.cityLat == null || cfg.cityLng == null) continue;
      const d = haversineKm(Number(fromLat), Number(fromLng), Number(cfg.cityLat), Number(cfg.cityLng));
      if (d < bestDist) {
        bestDist = d;
        best = cfg;
      }
    }
    if (!best) {
      // احتياط: سائق دراجة مسؤول عن تسعيرة المدينة (deliveryConfig) — دراجة فقط
      const motoDrivers = await Driver.find({
        canSetPricing: true,
        vehicleType: 'motorcycle',
        deliveryConfig: { $ne: null },
      }).lean();
      let bDriver = null;
      let bDist = Infinity;
      for (const d of motoDrivers) {
        if (d.cityLat == null || d.cityLng == null) continue;
        const dist = haversineKm(Number(fromLat), Number(fromLng), Number(d.cityLat), Number(d.cityLng));
        if (dist < bDist) { bDist = dist; bDriver = d; }
      }
      if (bDriver) {
        const cfg = bDriver.deliveryConfig || {};
        const basePrice = Number(cfg.basePrice ?? 150);
        const baseDist = Number(cfg.baseDist ?? 5);
        const extraDistPrice = Number(cfg.extraDistPrice ?? 15);
        const extraKm = Math.max(0, Math.ceil(distanceKm - baseDist));
        const deliveryFee = Math.round(basePrice + extraKm * extraDistPrice);
        return res.json({
          deliveryFee,
          distanceKm: Math.round(distanceKm * 10) / 10,
          cityName: bDriver.cityNameAr || bDriver.cityName || '',
          cityNameFr: bDriver.cityNameFr || '',
          basePrice,
          baseDist,
          extraDistPrice,
          extraKm,
        });
      }
      return res.json({ deliveryFee: null, distanceKm: Math.round(distanceKm * 10) / 10, cityName: '', cityNameFr: '', basePrice: 0, baseDist: 5, extraDistPrice: 0, extraKm: 0 });
    }

    const basePrice = Number(best.basePrice ?? 150);
    const baseDist = Number(best.baseDist ?? 5);
    const extraDistPrice = Number(best.extraDistPrice ?? 15);
    const extraKm = Math.max(0, Math.ceil(distanceKm - baseDist));
    const deliveryFee = Math.round(basePrice + extraKm * extraDistPrice);

    res.json({
      deliveryFee,
      distanceKm: Math.round(distanceKm * 10) / 10,
      cityName: best.cityNameAr || best.cityName || '',
      cityNameFr: best.cityNameFr || '',
      basePrice,
      baseDist,
      extraDistPrice,
      extraKm,
    });
  } catch (e) {
    console.error('[SERVER] service-orders/quote error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

router.get('/service-orders', async (req, res) => {
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
    const orders = await ServiceOrder.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit);
    res.json(orders);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/service-orders/:id', async (req, res) => {
  try {
    const uid = req.user.uid || req.user.user_id;
    const order = await ServiceOrder.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Service order not found' });
    if (req.user.role !== 'admin' && order.userId !== uid && order.driverId !== uid) {
      return res.status(403).json({ error: 'غير مصرح' });
    }
    res.json(order);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/service-orders', async (req, res) => {
  try {
    req.body.userId = req.user.uid || req.user.user_id;
    const order = await ServiceOrder.create({ ...req.body, createdAt: new Date() });
    const io = getIO();
    if (io) {
      emitToUser(io, order.userId, 'service:created', order);
      if (order.driverId) emitToDriver(io, order.driverId, 'service:created', order);
      io.to('drivers').emit('service:created', order);
    }
    if (order.driverId) {
      sendToDriver({
        driverId: order.driverId,
        title: '🆕 طلب خدمة جديد',
        body: order.description || order.address || 'طلب خدمة جديد',
        data: { orderId: order._id.toString(), type: 'new_service_order' },
      }).catch(e => console.error('FCM service created error:', e.message));
    }
    res.status(201).json(order);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/service-orders/:id', async (req, res) => {
  try {
    const uid = req.user.uid || req.user.user_id;
    if (req.user.role !== 'admin') {
      const existing = await ServiceOrder.findById(req.params.id);
      if (!existing) return res.status(404).json({ error: 'Service order not found' });
      if (existing.userId !== uid && existing.driverId !== uid) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
    }
    const old = await ServiceOrder.findById(req.params.id);
    const updateBody = { ...req.body, updatedAt: new Date() };
    if (updateBody.status === 'accepted' && updateBody.driverId) {
      updateBody.rejectedBy = [];
    }
    const order = await ServiceOrder.findByIdAndUpdate(
      req.params.id,
      updateBody,
      { returnDocument: 'after' }
    );
    if (!order) return res.status(404).json({ error: 'Service order not found' });
    console.log(`[SERVER] service-order ${req.params.id} updated, counterOffer:`, req.body.counterOffer);
    const io = getIO();
    if (io) {
      console.log(`[SERVER] emitting service:updated to user_${order.userId}`);
      emitToUser(io, order.userId, 'service:updated', order);
      if (order.driverId) {
        console.log(`[SERVER] emitting service:updated to driver_${order.driverId}`);
        emitToDriver(io, order.driverId, 'service:updated', order);
      }
    }
    const oldStatus = old?.status;
    if (order.status === 'accepted' && oldStatus !== 'accepted') {
      sendToUser({ userId: order.userId, title: '✅ تم قبول طلب الخدمة', body: 'تم قبول طلب الخدمة، انتظر مكالمة تأكيد.', data: { orderId: order._id.toString(), type: 'service_accepted' } });
    } else if (order.status === 'onway' && oldStatus !== 'onway') {
      sendToUser({ userId: order.userId, title: '🚚 السائق ذاهب لتسليم الطلبية', body: 'تم استلام طلبيتك، السائق ذاهب لتسليمها لك.', data: { orderId: order._id.toString(), type: 'service_onway' } });
    } else if (order.status === 'delivered' && oldStatus !== 'delivered') {
      sendToUser({ userId: order.userId, title: '✅ تم إكمال الخدمة', body: 'شكراً لاستخدامك خدماتنا!', data: { orderId: order._id.toString(), type: 'service_delivered' } });
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
          console.error('Service order driver earnings error:', drvErr.message);
        }
      }
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
        sendToUser({ userId: uid, title: '❌ السائق رفض طلب الخدمة', body: `السائق رفض طلب الخدمة.${reason ? ' ' + reason : ''}`, data: { orderId: order._id.toString(), type: 'driver_rejected' } });
      }
    }
    res.json(order);
  } catch (e) {
    console.error('[SERVER] PUT service-orders error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

router.delete('/service-orders/:id', async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'غير مصرح' });
    await ServiceOrder.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
