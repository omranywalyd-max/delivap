const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { getAuth } = require('firebase-admin/auth');
const { getIO } = require('../socket/ioInstance');
const { emitToUser, emitToDriver } = require('../socket');
const User = require('../models/User');
const Order = require('../models/Order');
const Favorite = require('../models/Favorite');
const Comment = require('../models/Comment');
const Notification = require('../models/Notification');
const Project = require('../models/Project');
const ProjectDelivery = require('../models/ProjectDelivery');
const Report = require('../models/Report');
const SavedLocation = require('../models/SavedLocation');
const SavedTemplate = require('../models/SavedTemplate');
const ServiceOrder = require('../models/ServiceOrder');
const TransportOrder = require('../models/TransportOrder');
const Store = require('../models/Store');
const Product = require('../models/Product');
const Promotion = require('../models/Promotion');
const Category = require('../models/Category');
const Message = require('../models/Message');
const Driver = require('../models/Driver');
const Config = require('../models/Config');
const WilayaConfig = require('../models/WilayaConfig');
const Settlement = require('../models/Settlement');
const Drink = require('../models/Drink');
const authMiddleware = require('../middleware/auth');
const fs = require('fs');
const path = require('path');

function deleteImageFile(url) {
  if (!url || !url.includes('/uploads/')) return;
  const filename = url.split('/uploads/').pop();
  if (!filename) return;
  const filePath = path.join(__dirname, '..', 'uploads', filename);
  try { if (fs.existsSync(filePath)) fs.unlinkSync(filePath); } catch (_) {}
}

// ─── تسجيل دخول الأدمن ──────────────────────────────────────────────
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    const adminUsername = process.env.ADMIN_USERNAME || 'admin';
    const adminPasswordHash = process.env.ADMIN_PASSWORD_HASH;

    if (username !== adminUsername) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    if (!adminPasswordHash) {
      return res.status(500).json({ error: 'ADMIN_PASSWORD_HASH غير مضبوط في الخادم' });
    }
    const valid = await bcrypt.compare(password, adminPasswordHash);
    if (!valid) return res.status(401).json({ error: 'Invalid credentials' });

    if (!process.env.JWT_SECRET) {
      return res.status(500).json({ error: 'JWT_SECRET غير مضبوط في الخادم' });
    }
    const token = jwt.sign(
      { role: 'admin', username },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({ success: true, token, role: 'admin' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── المستخدمين ─────────────────────────────────────────────────────

router.use(authMiddleware);

router.get('/users', async (req, res) => {
  try {
    const users = await User.find().sort({ createdAt: -1 });
    res.json(users);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/users/:uid/toggle-verify', async (req, res) => {
  try {
    const user = await User.findOne({ uid: req.params.uid });
    if (!user) return res.status(404).json({ error: 'User not found' });
    user.isVerified = !user.isVerified;
    await user.save();
    res.json(user);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/users/:uid/toggle-phone', async (req, res) => {
  try {
    const user = await User.findOne({ uid: req.params.uid });
    if (!user) return res.status(404).json({ error: 'User not found' });
    user.phoneHidden = !user.phoneHidden;
    await user.save();
    const Order = require('../models/Order');
    await Order.updateMany(
      { userId: req.params.uid, status: { $nin: ['delivered', 'cancelled', 'archived'] } },
      { $set: { userPhoneHidden: user.phoneHidden } }
    );
    res.json(user);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/users/toggle-active/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    user.isActive = !user.isActive;
    await user.save();
    res.json(user);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── حظر / إلغاء حظر المستخدم ───
router.put('/users/toggle-ban/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    user.isBanned = !user.isBanned;
    if (user.isBanned) {
      user.isActive = false;
      user.bannedIp = user.lastIp || req.ip;
    }
    await user.save();
    res.json(user);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── إرسال رسالة من الأدمن إلى مستخدم ───
router.post('/users/send-message', async (req, res) => {
  try {
    const { userId, title, body } = req.body;
    if (!userId || !title || !body) return res.status(400).json({ error: 'userId, title, body required' });
    await Message.create({ userId, from: 'admin', text: body });
    const { sendToUser } = require('../fcm');
    await sendToUser({ userId, title, body, data: { type: 'admin_message' } });
    res.json({ sent: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── جلب رسائل جميع المستخدمين للأدمن ───
router.get('/users/messages', async (req, res) => {
  try {
    const messages = await Message.find({ from: 'user' }).sort({ createdAt: -1 }).limit(200);
    const users = await User.find().select('uid firstName lastName phone');
    const userMap = {};
    for (const u of users) {
      userMap[u._id.toString()] = u;
      if (u.uid) userMap[u.uid] = u;
    }
    const enriched = messages.map(m => {
      const u = userMap[m.userId] || {};
      return {
        ...m.toObject(),
        userName: `${u.firstName || ''} ${u.lastName || ''}`.trim() || u.phone || m.userId,
      };
    });
    res.json(enriched);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── جلب جميع رسائل مستخدم معين (للأدمن) ───
router.get('/users/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;
    const messages = await Message.find({ userId: id }).sort({ createdAt: 1 });
    await Message.updateMany({ userId: id, from: 'user', read: false }, { $set: { read: true } });
    res.json(messages);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── إرسال رسالة من الأدمن إلى مستخدم معين (مع socket) ───
router.post('/users/:id/send-message', async (req, res) => {
  try {
    const { id } = req.params;
    const { text } = req.body;
    if (!text || !text.trim()) return res.status(400).json({ error: 'text required' });
    const msg = await Message.create({ userId: id, from: 'admin', text: text.trim() });
    const { emitToRoom } = require('../socket');
    const io = getIO();
    if (io) emitToRoom(io, `user_${id}`, 'new_message', msg.toObject());
    res.json(msg);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/users/:uid', async (req, res) => {
  try {
    const uid = req.params.uid;

    // جلب المستخدم لمعرفة الـ uid الحقيقي (قد يكون id أو uid)
    let user = await User.findOne({ uid });
    if (!user && mongoose.Types.ObjectId.isValid(uid)) {
      user = await User.findById(uid);
    }
    const targetUid = user ? (user.uid || user._id.toString()) : uid;

    // إرسال إشعار للعميل لتسجيل الخروج قبل الحذف
    const io = getIO();
    if (io) {
      emitToUser(io, targetUid, 'user:deleted', { reason: 'تم حذف حسابك من قبل الإدارة' });
    }

    // إلغاء جميع توكنات Firebase عشان الجلسة تنتهي فوراً
    try {
      await getAuth().revokeRefreshTokens(targetUid);
    } catch (_) {} // لو ما كانش موجود نكمل

    // نحذف مستخدم Firebase Auth أولاً قبل البيانات
    // باش الـ GET auto-create ما يقدرش يعاود ينشئ المستخدم
    try {
      await getAuth().deleteUser(targetUid);
    } catch (fe) {
      // لو Firebase مش موجود نكمل عادي
    }

    const models = [
      { m: Order, f: 'userId' },
      { m: Favorite, f: 'userId' },
      { m: Comment, f: 'userId' },
      { m: Notification, f: 'toId' },
      { m: Message, f: 'userId' },
      { m: Project, f: 'userId' },
      { m: ProjectDelivery, f: 'userId' },
      { m: Report, f: 'userId' },
      { m: SavedLocation, f: 'userId' },
      { m: SavedTemplate, f: 'userId' },
      { m: ServiceOrder, f: 'userId' },
      { m: TransportOrder, f: 'userId' },
      { m: Store, f: 'ownerId' },
    ];
    const deleted = {};
    for (const { m, f } of models) {
      const result = await m.deleteMany({ [f]: targetUid });
      if (result.deletedCount > 0) deleted[m.modelName] = result.deletedCount;
    }
    if (user) await User.deleteOne({ _id: user._id });
    else await User.deleteOne({ uid });
    deleted.firebase = 1;
    res.json({ deleted: true, details: deleted });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── المتاجر ────────────────────────────────────────────────────────

router.get('/stores', async (req, res) => {
  try {
    const stores = await Store.find().sort({ name: 1 });
    res.json(stores);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/stores', async (req, res) => {
  try {
    const store = await Store.create(req.body);
    res.status(201).json(store);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/stores/:id', async (req, res) => {
  try {
    const store = await Store.findByIdAndUpdate(req.params.id, req.body, { returnDocument: 'after' });
    res.json(store);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/stores/:id', async (req, res) => {
  try {
    const storeId = req.params.id;
    const store = await Store.findById(storeId);
    if (store) deleteImageFile(store.image);
    const products = await Product.find({ storeId });
    for (const p of products) {
      deleteImageFile(p.image);
      if (p.extraImages && Array.isArray(p.extraImages)) {
        for (const img of p.extraImages) {
          if (typeof img === 'string') deleteImageFile(img);
        }
      }
    }
    const prodDel = await Product.deleteMany({ storeId });
    await Promotion.deleteMany({ storeId });
    await Store.findByIdAndDelete(storeId);
    res.json({ deleted: true, productsRemoved: prodDel.deletedCount });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── الفئات ─────────────────────────────────────────────────────────

router.get('/categories', async (req, res) => {
  try {
    const cats = await Category.find().sort({ name: 1 });
    res.json(cats);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/categories', async (req, res) => {
  try {
    const cat = await Category.create(req.body);
    res.status(201).json(cat);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/categories/:id', async (req, res) => {
  try {
    await Category.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── المنتجات ───────────────────────────────────────────────────────

router.get('/products', async (req, res) => {
  try {
    const filter = req.query.storeId ? { storeId: req.query.storeId } : {};
    const products = await Product.find(filter).sort({ name: 1 });
    res.json(products);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/products', async (req, res) => {
  try {
    const product = await Product.create(req.body);
    res.status(201).json(product);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/products/:id', async (req, res) => {
  try {
    const product = await Product.findByIdAndUpdate(req.params.id, req.body, { returnDocument: 'after' });
    res.json(product);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/products/:id', async (req, res) => {
  try {
    await Product.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── الطلبات ────────────────────────────────────────────────────────

router.get('/orders', async (req, res) => {
  try {
    const filter = {};
    if (req.query.userId) filter.userId = req.query.userId;
    if (req.query.status) filter.status = req.query.status;
    if (req.query.orderId) filter.orderId = req.query.orderId;
    const orders = await Order.find(filter).sort({ createdAt: -1 }).limit(200);
    res.json(orders);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/orders/:id', async (req, res) => {
  try {
    await Order.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── التقارير / البلاغات ────────────────────────────────────────────

router.get('/reports', async (req, res) => {
  try {
    const filter = {};
    if (req.query.status) filter.status = req.query.status;
    if (req.query.type) filter.type = req.query.type;
    let reports = await Report.find(filter).sort({ createdAt: -1 }).lean();
    const Driver = require('../models/Driver');
    const driverIds = [...new Set(reports.map(r => r.driverId).filter(Boolean))];
    const drivers = await Driver.find({ uid: { $in: driverIds } }).lean();
    const driverMap = {};
    for (const d of drivers) {
      const name = [d.firstName, d.lastName].filter(Boolean).join(' ').trim();
      if (name) driverMap[d.uid] = name;
    }
    reports = reports.map(r => ({
      ...r,
      driverName: driverMap[r.driverId] || r.driverName || 'سائق',
    }));
    res.json(reports);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/reports/count', async (req, res) => {
  try {
    const count = await Report.countDocuments({ status: 'pending' });
    res.json({ count });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/reports/:id/status', async (req, res) => {
  try {
    const report = await Report.findByIdAndUpdate(
      req.params.id,
      { status: req.body.status },
      { returnDocument: 'after' }
    );
    if (report && req.body.status === 'resolved') {
      const { sendToUser } = require('../fcm');

      let targetId, targetName;
      if (report.type === 'driver_report') {
        targetId = report.driverId;
        targetName = report.driverName || 'السائق';
      } else if (report.type === 'customer_report_owner') {
        targetId = report.userId;
        targetName = report.userName || 'الزبون';
      } else if (report.type === 'comment_report') {
        targetId = report.commentAuthorId;
        targetName = report.commentAuthorName || 'المستخدم';
      } else {
        targetId = report.userId || report.driverId;
        targetName = report.userName || report.driverName || 'المستخدم';
      }

      if (targetId) {
        const title = 'تم استلام بلاغك';
        const body = 'تم استلام بلاغك بنجاح، سنقوم بمراجعته في أقرب وقت.';
        try { await sendToUser({ userId: targetId, title, body, data: { type: 'admin_message' } }); } catch (_) {}
      }
    }
    res.json(report);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── الإعدادات ─────────────────────────────────────────────────────────

router.get('/config', async (req, res) => {
  try {
    const Config = require('../models/Config');
    let config = await Config.findOne();
    if (!config) config = {};
    res.json(config);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/config', async (req, res) => {
  try {
    const Config = require('../models/Config');
    const config = await Config.findOneAndUpdate(
      {},
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after', upsert: true }
    );

    // مزامنة نسب العمولة حسب نوع المركبة مع جميع السائقين
    for (const [key, val] of Object.entries(req.body)) {
      const match = key.match(/^commission_(.+)$/);
      if (match && val > 0) {
        const vehicleType = match[1].replace(/_/g, ' ');
        await Driver.updateMany(
          { vehicleType },
          { $set: { commissionPercent: val } }
        );
      }
    }

    res.json(config);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── السائقون ─────────────────────────────────────────────────────────

router.get('/drivers', async (req, res) => {
  try {
    const filter = {};
    if (req.query.isActive === 'true') filter.isActive = true;
    const drivers = await Driver.find(filter)
      .sort({ totalEarnings: -1 })
      .limit(200);
    res.json(drivers);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/drivers/:id', async (req, res) => {
  try {
    const { id } = req.params;
    let driver = await Driver.findById(id);
    if (!driver) driver = await Driver.findOne({ uid: id });

    // 🔒 منع منح صلاحية التسعير لأكثر من سائق في نفس المدينة
    if (req.body.canSetPricing === true && driver) {
      const cityName = driver.cityName || driver.cityNameAr;
      if (cityName) {
        const existing = await Driver.findOne({
          _id: { $ne: driver._id },
          $or: [
            { cityName: cityName },
            { cityNameAr: cityName },
          ],
          canSetPricing: true,
        });
        if (existing) {
          const existingName = [existing.firstName, existing.lastName].filter(Boolean).join(' ').trim() || 'سائق آخر';
          return res.status(409).json({
            error: `هذه المدينة لديها سائق مسؤول عن التسعيرة بالفعل (${existingName})`,
          });
        }
      }
    }

    if (driver) {
      Object.assign(driver, req.body, { updatedAt: new Date() });
      await driver.save();
      const io = getIO();
      if (io && driver.uid) emitToDriver(io, driver.uid, 'driver:updated', driver.toObject());
    } else {
      driver = await Driver.create({ ...req.body, uid: id });
    }
    res.json(driver);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/drivers/:id', async (req, res) => {
  try {
    const { id } = req.params;
    let driver = await Driver.findById(id);
    if (!driver) driver = await Driver.findOne({ uid: id });
    if (driver) await driver.deleteOne();
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── التسويات المالية (تحصيل العمولة) ─────────────────────────────

router.get('/settlements', async (req, res) => {
  try {
    const list = await Settlement.find().sort({ createdAt: -1 }).limit(200);
    res.json(list);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/settlements/:driverId', async (req, res) => {
  try {
    const list = await Settlement.find({ driverId: req.params.driverId })
      .sort({ createdAt: -1 });
    res.json(list);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/settlements', async (req, res) => {
  try {
    const { driverId, amountCollected, paymentMethod } = req.body;
    const driver = await Driver.findById(driverId);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });

    let commissionPercent = driver.commissionPercent || 0;
    if (commissionPercent <= 0) {
      const config = await Config.findOne();
      if (config) {
        const vType = (driver.vehicleType || '').replace(/ /g, '_');
        const key = `commission_${vType}`;
        commissionPercent = (config[key] || config.defaultCommissionPercent || 0);
      }
    }
    const cash = driver.cash || 0;
    const commissionAmount = cash * commissionPercent / 100;
    const discount = driver.discount || 0;
    const totalDue = commissionAmount + discount;

    const settlement = await Settlement.create({
      driverId: driver._id,
      driverName: `${driver.firstName || ''} ${driver.lastName || ''}`.trim(),
      vehicleType: driver.vehicleType || '',
      earningsBefore: driver.lastCommissionResetEarnings || 0,
      earningsAfter: driver.totalEarnings || 0,
      commissionPercent,
      commissionAmount,
      discount,
      cashAtSettlement: cash,
      amountCollected: amountCollected ?? totalDue,
      paymentMethod: paymentMethod || 'cash',
    });

    driver.lastCommissionResetEarnings = driver.totalEarnings || 0;
    driver.cash = 0;
    await driver.save();

    res.json(settlement);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── تسوية حسابات المستخدمين (اصحاب المحلات + الزبون) ────────────
router.get('/user-settlements/:userId', async (req, res) => {
  try {
    const list = await Settlement.find({ userId: req.params.userId, targetType: { $in: ['owner', 'customer'] } })
      .sort({ createdAt: -1 });
    res.json(list);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/user-settlements', async (req, res) => {
  try {
    const { userId, amountCollected, targetType } = req.body;
    const user = await User.findOne({ uid: userId });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const commissionPercent = user.commissionPercent || 0;
    const earnings = user.totalEarnings || 0;
    const lastReset = user.lastCommissionResetEarnings || 0;
    const commissionAmount = ((earnings - lastReset) * commissionPercent / 100);
    const totalDue = commissionAmount;

    const settlement = await Settlement.create({
      userId: user.uid,
      targetType: targetType || 'owner',
      targetName: user.storeName || `${user.firstName || ''} ${user.lastName || ''}`.trim(),
      earningsBefore: lastReset,
      earningsAfter: earnings,
      commissionPercent,
      commissionAmount,
      amountCollected: amountCollected ?? totalDue,
      paymentMethod: 'cash',
    });

    user.lastCommissionResetEarnings = earnings;
    user.cash = 0;
    await user.save();

    res.json(settlement);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── تسوية حسابات الستايلات (templates) ──────────────────────────
router.get('/store-settlements/:storeId', async (req, res) => {
  try {
    const list = await Settlement.find({ storeId: req.params.storeId, targetType: { $in: ['template', 'category'] } })
      .sort({ createdAt: -1 });
    res.json(list);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/settlements/:settlementId', async (req, res) => {
  try {
    await Settlement.findByIdAndDelete(req.params.settlementId);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/store-settlements', async (req, res) => {
  try {
    const { storeId, amountCollected } = req.body;
    const store = await Store.findById(storeId);
    if (!store) return res.status(404).json({ error: 'Store not found' });

    let commissionPercent = store.commissionPercent || 0;
    if (!commissionPercent && store.templateId) {
      const template = await Store.findById(store.templateId);
      if (template) commissionPercent = template.commissionPercent || 0;
    }
    const earnings = store.totalEarnings || 0;
    const lastReset = store.lastCommissionResetEarnings || 0;
    const commissionAmount = ((earnings - lastReset) * commissionPercent / 100);
    const totalDue = commissionAmount;

    const settlement = await Settlement.create({
      storeId: store._id,
      targetType: 'template',
      targetName: store.nom || '',
      earningsBefore: lastReset,
      earningsAfter: earnings,
      commissionPercent,
      commissionAmount,
      amountCollected: amountCollected ?? totalDue,
      paymentMethod: 'cash',
    });

    store.totalCollected = (store.totalCollected || 0) + (amountCollected ?? totalDue);
    store.lastCommissionResetEarnings = earnings;
    store.cash = 0;
    await store.save();

    res.json(settlement);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// تسوية مالية لقسم
router.post('/category-settlements', async (req, res) => {
  try {
    const { categoryId, storeId, amountCollected } = req.body;
    const cat = await Category.findById(categoryId);
    if (!cat) return res.status(404).json({ error: 'Category not found' });

    let commissionPercent = cat.commissionPercent || 0;
    if (!commissionPercent) {
      const store = await Store.findById(storeId || cat.storeId);
      if (store) {
        commissionPercent = store.commissionPercent || 0;
        if (!commissionPercent && store.templateId) {
          const template = await Store.findById(store.templateId);
          if (template) commissionPercent = template.commissionPercent || 0;
        }
      }
    }
    const earnings = cat.totalEarnings || 0;
    const lastReset = cat.lastCommissionResetEarnings || 0;
    const commissionAmount = ((earnings - lastReset) * commissionPercent / 100);
    const totalDue = commissionAmount;

    const settlement = await Settlement.create({
      storeId: storeId || cat.storeId,
      targetType: 'category',
      targetName: cat.nom || '',
      earningsBefore: lastReset,
      earningsAfter: earnings,
      commissionPercent,
      commissionAmount,
      amountCollected: amountCollected ?? totalDue,
      paymentMethod: 'cash',
    });

    cat.totalCollected = (cat.totalCollected || 0) + (amountCollected ?? totalDue);
    cat.lastCommissionResetEarnings = earnings;
    cat.cash = 0;
    await cat.save();

    res.json(settlement);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── مسح البيانات ──────────────────────────────────────────────────
const deleteModels = [Order, ServiceOrder, TransportOrder, ProjectDelivery, User, Driver, Store, Product, Category, Promotion, Message, Comment, Notification, Favorite, Project, Report, SavedLocation, SavedTemplate, Config, WilayaConfig, Settlement, Drink];

router.post('/delete/orders', async (req, res) => {
  try {
    const r = await Order.deleteMany({});
    const s = await ServiceOrder.deleteMany({});
    const t = await TransportOrder.deleteMany({});
    const p = await ProjectDelivery.deleteMany({});
    res.json({ deleted: r.deletedCount + s.deletedCount + t.deletedCount + p.deletedCount });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/delete/customers', async (req, res) => {
  try {
    const r = await User.deleteMany({ role: { $ne: 'admin' } });
    res.json({ deleted: r.deletedCount });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/delete/drivers', async (req, res) => {
  try {
    const r = await Driver.deleteMany({});
    res.json({ deleted: r.deletedCount });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/delete/stores', async (req, res) => {
  try {
    const stores = await Store.find({}, { _id: 1 });
    const storeIds = stores.map(s => s._id.toString());
    const prodDel = await Product.deleteMany({ storeId: { $in: storeIds } });
    const catDel = await Category.deleteMany({ storeId: { $in: storeIds } });
    const promDel = await Promotion.deleteMany({ storeId: { $in: storeIds } });
    const storeDel = await Store.deleteMany({});
    const projectDel = await Project.deleteMany({});
    const userDel = await User.deleteMany({ role: { $ne: 'admin' } });
    const templDel = await SavedTemplate.deleteMany({});
    const msgDel = await Message.deleteMany({});
    const commentDel = await Comment.deleteMany({});
    const notifDel = await Notification.deleteMany({});
    // حذف الصور
    const allProducts = await Product.find({}, { image: 1, extraImages: 1, models: 1 });
    for (const p of allProducts) {
      deleteImageFile(p.image);
      if (p.extraImages) p.extraImages.forEach(img => deleteImageFile(img));
      if (p.models) p.models.forEach(m => deleteImageFile(m.image));
    }
    res.json({ stores: storeDel.deletedCount, products: prodDel.deletedCount, categories: catDel.deletedCount, promotions: promDel.deletedCount, projects: projectDel.deletedCount, users: userDel.deletedCount });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/delete/all', async (req, res) => {
  try {
    let total = 0;
    for (const Model of deleteModels) {
      const r = await Model.deleteMany({});
      total += r.deletedCount;
    }
    // حذف كل الملفات من مجلد uploads
    const uploadsDir = path.join(__dirname, '..', 'uploads');
    if (fs.existsSync(uploadsDir)) {
      const files = fs.readdirSync(uploadsDir);
      for (const file of files) {
        const fp = path.join(uploadsDir, file);
        try { if (fs.statSync(fp).isFile()) fs.unlinkSync(fp); } catch (_) {}
      }
    }
    res.json({ deleted: total });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── الصور اليتيمة (غير المرتبطة بالداتابيز) ─────────────────────────
const uploadDir = path.join(__dirname, '..', 'uploads');

async function _collectImageRefs() {
  const refs = new Set();
  const db = require('mongoose').connection.db;
  const add = (url) => { if (url && typeof url === 'string') refs.add(url.split('/').pop()); };
  const addArr = (arr) => { if (Array.isArray(arr)) arr.forEach(u => add(u)); };

  // ── المجموعات الأساسية (image / photo / photoUrl + extraImages / models / flavors / variants / toppings / sizes) ──
  const collections = ['magasins', 'produits', 'categories', 'promotions', 'drinks', 'drivers', 'users'];
  for (const col of collections) {
    const docs = await db.collection(col).find({}).toArray();
    for (const doc of docs) {
      add(doc.image); add(doc.photo); add(doc.photoUrl); add(doc.banner); add(doc.logo); add(doc.cover);
      addArr(doc.extraImages);
      if (doc.models) doc.models.forEach(m => { add(m.image); addArr(m.extraImages); });
      if (doc.flavors) doc.flavors.forEach(f => add(f.image));
      if (doc.variants) doc.variants.forEach(v => { add(v.image); addArr(v.extraImages); });
      if (doc.toppings) doc.toppings.forEach(t => { add(t.image); addArr(t.extraImages); });
      if (doc.sizes) doc.sizes.forEach(s => { add(s.image); addArr(s.extraImages); });
    }
  }

  // ── الطلبيات ──
  try {
    const orders = await db.collection('orders').find({}).toArray();
    for (const o of orders) {
      add(o.userPhotoUrl); add(o.locationImage);
      if (o.items) o.items.forEach(item => {
        add(item.image); add(item.imageUrl); addArr(item.extraImages);
        if (item.sizes) item.sizes.forEach(s => add(s.image));
        if (item.variants) item.variants.forEach(v => add(v.image));
      });
    }
  } catch (_) {}

  // ── طلبيات الخدمة ──
  try {
    const sos = await db.collection('serviceorders').find({}).toArray();
    for (const so of sos) {
      add(so.parcelImageUrl);
      if (so.items) so.items.forEach(item => { add(item.image); add(item.imageUrl); addArr(item.extraImages); });
    }
  } catch (_) {}

  // ── طلبيات النقل ──
  try {
    const tos = await db.collection('transportorders').find({}).toArray();
    for (const to of tos) {
      add(to.fromImage); add(to.toImage); add(to.parcelImageUrl);
      if (to.items) to.items.forEach(item => { add(item.image); add(item.imageUrl); addArr(item.extraImages); });
    }
  } catch (_) {}

  // ── توصيل المشاريع ──
  try {
    const pds = await db.collection('projectdeliveries').find({}).toArray();
    for (const pd of pds) {
      add(pd.imageUrl);
      if (pd.items) pd.items.forEach(item => { add(item.image); add(item.imageUrl); addArr(item.extraImages); });
    }
  } catch (_) {}

  // ── المشاريع ──
  try {
    const projects = await db.collection('projects').find({}).toArray();
    for (const p of projects) {
      add(p.imageUrl); addArr(p.extraImages);
    }
  } catch (_) {}

  // ── المواقع المحفوظة ──
  try {
    const sls = await db.collection('savedlocations').find({}).toArray();
    for (const sl of sls) add(sl.locationImage);
  } catch (_) {}

  // ── التعليقات ──
  try {
    const comments = await db.collection('comments').find({}).toArray();
    for (const c of comments) {
      add(c.userPhoto);
      if (c.replies) c.replies.forEach(r => add(r.userPhoto));
    }
  } catch (_) {}

  return refs;
}

router.get('/orphan-images', async (req, res) => {
  try {
    const files = fs.readdirSync(uploadDir).filter(f => fs.statSync(path.join(uploadDir, f)).isFile());
    const refs = await _collectImageRefs();
    const orphans = files.filter(f => !refs.has(f));
    res.json({ total: files.length, referenced: refs.size, orphanCount: orphans.length, orphans });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/orphan-images', async (req, res) => {
  try {
    const files = fs.readdirSync(uploadDir).filter(f => fs.statSync(path.join(uploadDir, f)).isFile());
    const refs = await _collectImageRefs();
    let deleted = 0;
    for (const f of files) {
      if (!refs.has(f)) {
        try { fs.unlinkSync(path.join(uploadDir, f)); deleted++; } catch (_) {}
      }
    }
    const remaining = fs.readdirSync(uploadDir).filter(f => fs.statSync(path.join(uploadDir, f)).isFile()).length;
    res.json({ deleted, remaining });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
