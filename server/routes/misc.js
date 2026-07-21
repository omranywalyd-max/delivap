const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const SavedLocation = require('../models/SavedLocation');
const SavedTemplate = require('../models/SavedTemplate');
const Report = require('../models/Report');
const Notification = require('../models/Notification');
const User = require('../models/User');
const Driver = require('../models/Driver');

router.use(authMiddleware);

// ── Saved Locations ──
router.get('/saved-locations', async (req, res) => {
  try {
    const filter = {};
    if (req.query.userId) filter.userId = req.query.userId;
    const locs = await SavedLocation.find(filter).sort({ createdAt: 1 });
    res.json(locs);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/saved-locations', async (req, res) => {
  try {
    const loc = await SavedLocation.create(req.body);
    res.status(201).json(loc);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/saved-locations/:id', async (req, res) => {
  try {
    const loc = await SavedLocation.findByIdAndUpdate(
      req.params.id,
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    res.json(loc);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/saved-locations/:id', async (req, res) => {
  try {
    await SavedLocation.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Nested saved-locations under /users/:uid (compatibility) ──
router.get('/users/:uid/saved-locations', async (req, res) => {
  try {
    const locs = await SavedLocation.find({ userId: req.params.uid }).sort({ createdAt: 1 });
    res.json(locs);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/users/:uid/saved-locations', async (req, res) => {
  try {
    const loc = await SavedLocation.create({ ...req.body, userId: req.params.uid });
    res.status(201).json(loc);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Saved Templates ──
router.get('/saved-templates', async (req, res) => {
  try {
    const filter = {};
    if (req.query.userId) filter.userId = req.query.userId;
    const tmpl = await SavedTemplate.find(filter).sort({ createdAt: -1 });
    res.json(tmpl);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/saved-templates', async (req, res) => {
  try {
    const tmpl = await SavedTemplate.create(req.body);
    res.status(201).json(tmpl);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/saved-templates/:id', async (req, res) => {
  try {
    await SavedTemplate.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Nested saved-templates under /users/:uid (compatibility) ──
router.post('/users/:uid/saved-templates', async (req, res) => {
  try {
    const tmpl = await SavedTemplate.create({ ...req.body, userId: req.params.uid });
    res.status(201).json(tmpl);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// PUT for saved-templates
router.put('/saved-templates/:id', async (req, res) => {
  try {
    const tmpl = await SavedTemplate.findByIdAndUpdate(
      req.params.id,
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    res.json(tmpl);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Reports ──
router.post('/reports', async (req, res) => {
  try {
    const report = await Report.create(req.body);
    const io = getIO();
    if (io) io.to('admin_room').emit('new_report', report.toObject());
    res.status(201).json(report);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/reports', async (req, res) => {
  try {
    const filter = {};
    if (req.query.status) filter.status = req.query.status;
    if (req.query.type) filter.type = req.query.type;
    const reports = await Report.find(filter).sort({ createdAt: -1 });
    res.json(reports);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Notifications ──
const { sendToDriver, sendToUser } = require('../fcm');
const { getIO } = require('../socket/ioInstance');

router.post('/notify-driver', async (req, res) => {
  try {
    const { driverId, title, body, data = {} } = req.body;
    if (!driverId || !title) return res.status(400).json({ error: 'driverId and title required' });

    // resolve MongoDB _id → Firebase uid
    const mongoose = require('mongoose');
    const Driver = require('../models/Driver');
    let uid = driverId;
    if (mongoose.Types.ObjectId.isValid(driverId)) {
      const driver = await Driver.findById(driverId);
      if (driver && driver.uid) uid = driver.uid;
    }

    const notif = await Notification.create({ toId: uid, title, body, type: data['type'] || 'customer', orderId: data['orderId'] || '', createdAt: new Date() });
    sendToDriver({ driverId: uid, title, body, data });
    const io = getIO();
    if (io) {
      io.to('driver_' + uid).emit('notification', notif);
    }
    res.status(201).json(notif);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/notify-user', async (req, res) => {
  try {
    const { userId, title: originalTitle, body, data = {} } = req.body;
    console.log(`[notify-user] userId=${userId} title=${originalTitle} data=${JSON.stringify(data)}`);
    if (!userId || !originalTitle) return res.status(400).json({ error: 'userId and title required' });
    const title = originalTitle.replace('📍 السائق في موقع التوصيل', 'اخرج اخرج اخررررج راني عندك');
    sendToUser({ userId, title, body, data });
    res.status(201).json({ sent: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/notifications', async (req, res) => {
  try {
    const notif = await Notification.create(req.body);
    res.status(201).json(notif);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/notifications', async (req, res) => {
  try {
    const filter = {};
    if (req.query.toId) filter.toId = req.query.toId;
    const notifs = await Notification.find(filter).sort({ createdAt: -1 });
    res.json(notifs);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/notifications/:id', async (req, res) => {
  try {
    const notif = await Notification.findByIdAndUpdate(req.params.id, req.body, { returnDocument: 'after' });
    res.json(notif);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── All Orders (موحّد) ──
const Order = require('../models/Order');
const TransportOrder = require('../models/TransportOrder');
const ServiceOrder = require('../models/ServiceOrder');
const Project = require('../models/Project');
const ProjectDelivery = require('../models/ProjectDelivery');

router.get('/all-orders', async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'غير مصرح' });
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const skip = parseInt(req.query.skip) || 0;
    const [orders, transport, services, projects, deliveries] = await Promise.all([
      Order.find().sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      TransportOrder.find().sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      ServiceOrder.find().sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      Project.find().sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      ProjectDelivery.find().sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    ]);
    const tagged = [
      ...orders.map(o => ({ ...o, _orderType: 'درجة' })),
      ...transport.map(t => ({ ...t, _orderType: 'هاربين' })),
      ...services.map(s => ({ ...s, _orderType: 'خدمة' })),
      ...projects.map(p => ({ ...p, _orderType: 'مشروع' })),
      ...deliveries.map(d => ({ ...d, _orderType: 'توصيل مشروع' })),
    ];
    tagged.sort((a, b) => {
      const da = a.createdAt || a._id?.toString();
      const db = b.createdAt || b._id?.toString();
      return da < db ? 1 : da > db ? -1 : 0;
    });
    res.json(tagged);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/all-orders/:id/:type', async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'غير مصرح' });
    const { id, type } = req.params;
    const map = {
      'درجة': Order,
      'هاربين': TransportOrder,
      'خدمة': ServiceOrder,
      'مشروع': Project,
      'توصيل مشروع': ProjectDelivery,
    };
    const Model = map[type];
    if (!Model) return res.status(400).json({ error: 'نوع غير معروف' });
    await Model.findByIdAndDelete(id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── FCM Token ──
router.post('/notify-token', async (req, res) => {
  try {
    const { uid, fcmToken, role } = req.body;

    if (!uid || !fcmToken) {
      return res.status(400).json({ error: 'uid and fcmToken are required' });
    }

    let updated;
    if (role === 'driver') {
      updated = await Driver.findOneAndUpdate(
        { uid },
        { fcmToken, fcmUpdatedAt: new Date() },
        { returnDocument: 'after' }
      );
    } else {
      updated = await User.findOneAndUpdate(
        { uid },
        { fcmToken, fcmUpdatedAt: new Date() },
        { returnDocument: 'after' }
      );
    }

    if (!updated) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ success: true, message: 'FCM token updated' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/clear-token', async (req, res) => {
  try {
    const { uid, role } = req.body;
    if (!uid) return res.status(400).json({ error: 'uid is required' });
    if (role === 'driver') {
      await Driver.findOneAndUpdate({ uid }, { fcmToken: null, fcmUpdatedAt: new Date() });
    } else {
      await User.findOneAndUpdate({ uid }, { fcmToken: null, fcmUpdatedAt: new Date() });
    }
    res.json({ success: true, message: 'FCM token cleared' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
