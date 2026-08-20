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

// خريطة نوع النقل (من تطبيق الزبون) → أنواع مركبات السائق
const TRANSPORT_TYPE_TO_VEHICLES = {
  car: ['car'],
  transport: ['minibus', 'harbin'],
  truck: ['truck', 'fourgon'],
  motorcycle: ['motorcycle'],
};

// حساب تسعيرة النقل تلقائياً: المسافة بين الموقعين + تسعيرة السائق المسؤول عن المدينة
router.post('/transport-orders/quote', async (req, res) => {
  try {
    const { fromLat, fromLng, toLat, toLng, transportType } = req.body;
    if (!transportType) return res.status(400).json({ error: 'transportType مطلوب' });
    if (
      fromLat == null || fromLng == null || toLat == null || toLng == null ||
      fromLat === 0 || fromLng === 0 || toLat === 0 || toLng === 0
    ) {
      return res.json({ deliveryFee: null, distanceKm: null, cityName: '', cityNameFr: '', basePrice: 0, baseDist: 0, extraDistPrice: 0, extraKm: 0, driverId: null });
    }

    const distanceKm = haversineKm(Number(fromLat), Number(fromLng), Number(toLat), Number(toLng));
    const vehicles = TRANSPORT_TYPE_TO_VEHICLES[transportType] || [transportType];

    // نجيب السائق المسؤول عن تسعيرة هذا النوع في أقرب مدينة لموقع الانطلاق
    const drivers = await Driver.find({
      canSetPricing: true,
      vehicleType: { $in: vehicles },
    }).lean();

    let best = null;
    let bestDist = Infinity;
    for (const d of drivers) {
      if (d.cityLat == null || d.cityLng == null) continue;
      const dist = haversineKm(Number(fromLat), Number(fromLng), Number(d.cityLat), Number(d.cityLng));
      if (dist < bestDist) {
        bestDist = dist;
        best = d;
      }
    }

    let bestCityName = best ? (best.cityNameAr || best.cityName || '') : '';
    let bestCityFr = best ? (best.cityNameFr || '') : '';

    let basePrice = 0;
    let baseDist = 0;
    let extraDistPrice = 0;
    let isDefault = false;
    let driverId = null;
    let driverName = '';

    if (best) {
      let cfg = (best.transportConfig && best.transportConfig[best.vehicleType]) || {};
      // fallback: بعض السائقين نوعهم minibus/truck لكن يحفظون التسعيرة تحت harbin/fourgon
      if (typeof cfg !== 'object' || cfg === null || Object.keys(cfg).length === 0) {
        const mapped = { minibus: 'harbin', truck: 'fourgon' }[best.vehicleType];
        if (mapped && best.transportConfig && best.transportConfig[mapped]) {
          cfg = best.transportConfig[mapped];
        }
      }
      basePrice = Number(cfg.basePrice ?? 0);
      baseDist = Number(cfg.baseDist ?? 0);
      extraDistPrice = Number(cfg.extraDistPrice ?? 0);
      driverId = best.uid || null;
      driverName = [best.firstName, best.lastName].filter(Boolean).join(' ').trim();
    }

    // إن لم توجد تسعيرة سائق: سعر افتراضي 200 لأول كيلومتر + 50 لكل كيلومتر إضافي
    if (!(basePrice > 0)) {
      basePrice = 200;
      baseDist = 1;
      extraDistPrice = 50;
      isDefault = true;
    }

    const extraKm = Math.max(0, Math.ceil(distanceKm - baseDist));
    const deliveryFee = Math.round(basePrice + extraKm * extraDistPrice);

    res.json({
      deliveryFee,
      distanceKm: Math.round(distanceKm * 10) / 10,
      cityName: bestCityName,
      cityNameFr: bestCityFr,
      basePrice,
      baseDist,
      extraDistPrice,
      extraKm,
      driverId,
      driverName,
      isDefault,
    });
  } catch (e) {
    console.error('[SERVER] transport-orders/quote error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

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
    if (order.driverId) {
      const from = order.fromAddress || '';
      const to = order.toAddress || '';
      const price = order.price ?? 0;
      sendToDriver({
        driverId: order.driverId,
        title: '🆕 طلب نقل جديد',
        body: `من: ${from}${to ? ` إلى ${to}` : ''} | السعر: ${price} DZD`,
        data: { orderId: order._id.toString(), type: 'new_transport_order' },
      }).catch(e => console.error('FCM transport created error:', e.message));
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
      sendToUser({ userId: order.userId, title: '🚚 السائق ذاهب لتسليم الطلبية', body: 'تم استلام طلبيتك، السائق ذاهب لتسليمها لك.', data: { orderId: order._id.toString(), type: 'transport_onway' } });
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
