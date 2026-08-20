const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Driver = require('../models/Driver');
const User = require('../models/User');
const Order = require('../models/Order');
const Comment = require('../models/Comment');
const Report = require('../models/Report');
const { getIO } = require('../socket/ioInstance');
const { emitToDriver } = require('../socket');
const authMiddleware = require('../middleware/auth');
const { requireAdmin, isSelfOrAdmin, tokenIdentities, resolveUserFromReq } = require('../middleware/authorize');

// helper: find driver by _id or uid
async function findDriver(id) {
  let driver;
  if (mongoose.Types.ObjectId.isValid(id)) {
    driver = await Driver.findById(id);
  }
  if (!driver) {
    driver = await Driver.findOne({ uid: id });
  }
  return driver;
}

function toSafeDriver(driver, isAdmin) {
  if (!driver) return driver;
  const obj = driver.toObject ? driver.toObject() : { ...driver };
  if (!isAdmin) {
    delete obj.fcmToken;
    delete obj.lastIp;
    delete obj.bannedIp;
  }
  return obj;
}

async function ownIds(req) {
  const ids = [...tokenIdentities(req)];
  const u = await resolveUserFromReq(req, User);
  if (u) {
    if (u.uid) ids.push(u.uid);
    if (u.username) ids.push(u.username);
  }
  return [...new Set(ids.map(String))];
}

// هل الطالب صاحب التعليق أو أدمن؟
async function isCommentOwner(req, comment) {
  if (req.user && req.user.role === 'admin') return true;
  if (!comment) return false;
  if (comment.userId && (await ownIds(req)).includes(String(comment.userId))) return true;
  return false;
}

// هل الطالب هو السائق نفسه أو أدمن؟
async function isDriverSelf(req, driver) {
  if (req.user && req.user.role === 'admin') return true;
  if (!driver) return false;
  const ids = await ownIds(req);
  if (driver.uid && ids.includes(String(driver.uid))) return true;
  return false;
}

router.get('/drivers', async (req, res) => {
  try {
    const filter = {};
    if (req.query.isOnline === 'true') filter.isOnline = true;
    if (req.query.isActive === 'true') filter.isActive = true;
    if (req.query.storeId) filter.storeId = req.query.storeId;
    if (req.query.vehicleType) filter.vehicleType = req.query.vehicleType;
    if (req.query.cityName) filter.cityName = req.query.cityName;
    // نحيد السائقين اللي عندهم طلبيات نشيطة (مشغولين) غير الدراجة النارية
    const busyDriverIds = await Order.distinct('driverId', {
      status: { $nin: ['delivered', 'cancelled', 'archived'] },
      driverId: { $exists: true, $ne: null },
    });
    const busyDrivers = await Driver.find({ uid: { $in: busyDriverIds } }, { vehicleType: 1, uid: 1 });
    const excludeUids = busyDrivers
      .filter(d => {
        const vt = (d.vehicleType || '').toLowerCase();
        return !vt.includes('motorcycle');
      })
      .map(d => d.uid);
    if (excludeUids.length > 0) filter.uid = { $nin: excludeUids };
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const drivers = await Driver.find(filter).sort({ totalEarnings: -1 }).skip(skip).limit(limit);
    const isAdmin = req.user && req.user.role === 'admin';
    res.json(drivers.map(d => toSafeDriver(d, isAdmin)));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── جميع السائقين مع الأرباح (للأدمن فقط) ──
router.get('/drivers/earnings', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const drivers = await Driver.find(
      {},
      'uid firstName lastName phone totalEarnings totalDeliveries cash hold commission discount isOnline isActive cityName'
    ).sort({ totalEarnings: -1 }).skip(skip).limit(limit);
    res.json(drivers);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── قائمة المدن المتاحة من السائقين ──
router.get('/drivers/cities', async (req, res) => {
  try {
    const filter = { $or: [
      { cityName: { $exists: true, $ne: '', $ne: null } },
      { cityNameAr: { $exists: true, $ne: '', $ne: null } },
    ]};
    if (req.query.isOnline === 'true') filter.isOnline = true;
    if (req.query.vehicleType) filter.vehicleType = req.query.vehicleType;
    const citiesAr = await Driver.distinct('cityNameAr', filter);
    const all = [...citiesAr].filter(Boolean);
    const unique = [...new Set(all.map(c => c.trim()))];
    res.json(unique);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── التحقق مما إذا كانت المدينة لديها سائق مسؤول عن التسعيرة ──
router.get('/drivers/city-has-pricing', async (req, res) => {
  try {
    const { cityName } = req.query;
    if (!cityName) return res.json({ hasPricingDriver: false });
    const existing = await Driver.findOne({
      $or: [
        { cityName: cityName },
        { cityNameAr: cityName },
        { cityNameFr: cityName },
      ],
      canSetPricing: true,
    });
    res.json({ hasPricingDriver: !!existing, driverName: existing ? ([existing.firstName, existing.lastName].filter(Boolean).join(' ').trim() || 'سائق') : null });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/drivers/:id', async (req, res) => {
  try {
    const driver = await findDriver(req.params.id);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    if (!driver.commissionPercent) {
      try {
        const Config = require('../models/Config');
        const config = await Config.findOne();
        if (config && driver.vehicleType) {
          const vehicleKey = `commission_${driver.vehicleType.replace(/ /g, '_')}`;
          driver.commissionPercent = config[vehicleKey] || config.defaultCommissionPercent || 0;
        }
      } catch (_) {}
    }
    res.json(toSafeDriver(driver, req.user && req.user.role === 'admin'));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/comments', async (req, res) => {
  try {
    const filter = {};
    if (req.query.driverId) filter.driverId = req.query.driverId;
    const comments = await Comment.find(filter).sort({ createdAt: -1 });
    res.json(comments);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/comments', async (req, res) => {
  try {
    // منع انتحال هوية كاتب التعليق
    if (req.user && req.user.role !== 'admin') {
      const ids = await ownIds(req);
      if (ids.length) req.body.userId = ids[0];
    }
    const comment = await Comment.create(req.body);
    res.status(201).json(comment);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/comments/:id', async (req, res) => {
  try {
    const existing = await Comment.findById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Comment not found' });
    if (!(await isCommentOwner(req, existing))) return res.status(403).json({ error: 'Forbidden' });
    const comment = await Comment.findByIdAndUpdate(
      req.params.id,
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    res.json(comment);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Driver Stats ──
router.get('/drivers/:id/stats', async (req, res) => {
  try {
    const driver = await findDriver(req.params.id);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    res.json(driver.stats || {});
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/drivers/:id/stats/:key', async (req, res) => {
  try {
    const driver = await findDriver(req.params.id);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    if (!(await isDriverSelf(req, driver))) return res.status(403).json({ error: 'Forbidden' });
    if (!driver.stats) driver.stats = {};
    driver.stats[req.params.key] = req.body;
    driver.markModified('stats');
    await driver.save();
    res.json(driver.stats);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Nested Comments (compatibility) ──
router.get('/drivers/:id/comments', async (req, res) => {
  try {
    const comments = await Comment.find({ driverId: req.params.id }).sort({ createdAt: -1 });
    res.json(comments);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/drivers/:id/comments', async (req, res) => {
  try {
    // منع انتحال هوية كاتب التعليق
    if (req.user && req.user.role !== 'admin') {
      const ids = await ownIds(req);
      if (ids.length) req.body.userId = ids[0];
    }
    const comment = await Comment.create({ ...req.body, driverId: req.params.id });
    res.status(201).json(comment);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/drivers/:id/comments/:commentId', async (req, res) => {
  try {
    const existing = await Comment.findById(req.params.commentId);
    if (!existing) return res.status(404).json({ error: 'Comment not found' });
    if (!(await isCommentOwner(req, existing))) return res.status(403).json({ error: 'Forbidden' });
    const comment = await Comment.findByIdAndUpdate(
      req.params.commentId,
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    res.json(comment);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/drivers/:id/comments/:commentId', async (req, res) => {
  try {
    const existing = await Comment.findById(req.params.commentId);
    if (!existing) return res.status(404).json({ error: 'Comment not found' });
    if (!(await isCommentOwner(req, existing))) return res.status(403).json({ error: 'Forbidden' });
    await Comment.findByIdAndDelete(req.params.commentId);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── الرد على تعليق ──
router.post('/comments/:commentId/reply', async (req, res) => {
  try {
    const reply = { ...req.body, createdAt: new Date() };
    // منع انتحال هوية صاحب الرد
    if (req.user && req.user.role !== 'admin') {
      const ids = await ownIds(req);
      if (ids.length) reply.userId = ids[0];
    }
    const comment = await Comment.findByIdAndUpdate(
      req.params.commentId,
      { $push: { replies: reply } },
      { returnDocument: 'after' }
    );
    if (!comment) return res.status(404).json({ error: 'Comment not found' });
    const io = getIO();
    if (io) io.emit('comment:updated', { driverId: comment.driverId, commentId: comment._id });
    res.json(comment);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── تعديل رد ──
router.put('/comments/:commentId/reply/:replyId', async (req, res) => {
  try {
    const { text } = req.body;
    if (!text) return res.status(400).json({ error: 'text is required' });
    const comment = await Comment.findOne({
      _id: req.params.commentId,
      'replies._id': req.params.replyId
    });
    if (!comment) return res.status(404).json({ error: 'Comment or reply not found' });
    const target = (comment.replies || []).find(r => String(r._id) === String(req.params.replyId));
    if (req.user && req.user.role !== 'admin') {
      const ids = await ownIds(req);
      if (!target || !target.userId || !ids.includes(String(target.userId))) {
        return res.status(403).json({ error: 'Forbidden' });
      }
    }
    const updated = await Comment.findOneAndUpdate(
      { _id: req.params.commentId, 'replies._id': req.params.replyId },
      { $set: { 'replies.$.text': text, 'replies.$.createdAt': new Date() } },
      { returnDocument: 'after' }
    );
    const io = getIO();
    if (io) io.emit('comment:updated', { driverId: updated.driverId, commentId: updated._id });
    res.json(updated);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── حذف رد ──
router.delete('/comments/:commentId/reply/:replyId', async (req, res) => {
  try {
    const comment = await Comment.findOne({
      _id: req.params.commentId,
      'replies._id': req.params.replyId
    });
    if (!comment) return res.status(404).json({ error: 'Comment or reply not found' });
    const target = (comment.replies || []).find(r => String(r._id) === String(req.params.replyId));
    if (req.user && req.user.role !== 'admin') {
      const ids = await ownIds(req);
      if (!target || !target.userId || !ids.includes(String(target.userId))) {
        return res.status(403).json({ error: 'Forbidden' });
      }
    }
    const updated = await Comment.findByIdAndUpdate(
      req.params.commentId,
      { $pull: { replies: { _id: req.params.replyId } } },
      { returnDocument: 'after' }
    );
    const io = getIO();
    if (io) io.emit('comment:updated', { driverId: updated.driverId, commentId: updated._id });
    res.json(updated);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── الإبلاغ على تعليق ──
router.post('/comments/:commentId/report', async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.commentId);
    if (!comment) return res.status(404).json({ error: 'Comment not found' });
    let reporterId = req.body.userId;
    let reporterName = req.body.userName;
    // منع انتحال هوية المبلّغ
    if (req.user && req.user.role !== 'admin') {
      const ids = await ownIds(req);
      if (ids.length) reporterId = ids[0];
    }
    const report = await Report.create({
      type: 'comment_report',
      driverId: comment.driverId,
      commentId: comment._id,
      commentText: comment.text,
      commentAuthorId: comment.userId,
      commentAuthorName: comment.userName,
      userId: reporterId,
      userName: reporterName,
      reason: req.body.reason,
      note: req.body.note,
    });
    const io = getIO();
    if (io) io.to('admin_room').emit('new_report', report.toObject());
    res.status(201).json(report);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── PUT / DELETE drivers (self-edit أو للأدمن) ──
router.put('/drivers/:id', async (req, res) => {
  try {
    const id = req.params.id;
    let driver = await findDriver(id);

    // ملكية: غير الأدمن يعدّل سجل نفسو فقط
    if (req.user && req.user.role !== 'admin' &&
        !isSelfOrAdmin(req, driver ? { uid: driver.uid, _id: driver._id } : null, id)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    if (req.user && req.user.role !== 'admin') {
      const blocked = ['cash', 'hold', 'commissionPercent', 'canSetPricing', 'lastCommissionResetEarnings', 'commissionDiscount'];
      for (const k of blocked) delete req.body[k];
    }

    // 🔒 مركبة وحدة (نوع واحد) من مدينة فقط: يمنع منح صلاحية التسعير
    // لأكثر من سائق لنفس نوع المركبة في نفس المدينة — كامل السائقين
    // من نفس النوع والمدينة ياخدو بهاديك التسعيرة
    if (req.body.canSetPricing === true && driver) {
      const cityName = req.body.cityName || req.body.cityNameAr || req.body.cityNameFr || driver.cityName || driver.cityNameAr || driver.cityNameFr;
      const vehicleType = req.body.vehicleType || driver.vehicleType;
      if (cityName && vehicleType) {
        const existing = await Driver.findOne({
          _id: { $ne: driver._id },
          $or: [
            { cityName: cityName },
            { cityNameAr: cityName },
            { cityNameFr: cityName },
          ],
          vehicleType: vehicleType,
          canSetPricing: true,
        });
        if (existing) {
          const existingName = [existing.firstName, existing.lastName].filter(Boolean).join(' ').trim() || 'سائق آخر';
          return res.status(409).json({
            error: `هذه المدينة لديها سائق مسؤول عن تسعيرة هذا النوع بالفعل (${existingName})`,
          });
        }
      }
    }

    if (driver) {
      Object.assign(driver, req.body, { updatedAt: new Date() });

      // منع الاختلاط: deliveryConfig مخصص للدراجة النارية فقط (تسعيرة الإحضار/التوصيل)
      if (req.body.deliveryConfig != null && driver.vehicleType !== 'motorcycle') {
        delete driver.deliveryConfig;
      }
      // منع الاختلاط: transportConfig مخصص لمركبات النقل فقط
      if (req.body.transportConfig != null && driver.vehicleType === 'motorcycle') {
        delete driver.transportConfig;
      }
      if (!driver.commissionPercent && req.body.vehicleType) {
        try {
          const Config = require('../models/Config');
          const config = await Config.findOne();
          if (config) {
            const vehicleKey = `commission_${req.body.vehicleType.replace(/ /g, '_')}`;
            driver.commissionPercent = config[vehicleKey] || config.defaultCommissionPercent || 0;
          }
        } catch (_) {}
      }
      await driver.save();
    } else {
      const body = { ...req.body };
      if (!body.commissionPercent) {
        try {
          const Config = require('../models/Config');
          const config = await Config.findOne();
          if (config) {
            const vehicleKey = body.vehicleType ? `commission_${body.vehicleType.replace(/ /g, '_')}` : null;
            const pct = vehicleKey && config[vehicleKey] ? config[vehicleKey] : (config.defaultCommissionPercent || 0);
            body.commissionPercent = pct;
          }
        } catch (_) {}
      }
      driver = await Driver.create({ ...body, uid: id, updatedAt: new Date() });
    }
    const io = getIO();
    if (io && driver) emitToDriver(io, driver.uid || driver._id, 'driver:updated', driver);
    res.json(driver);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/drivers/:id', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const driver = await findDriver(req.params.id);
    if (driver) await driver.deleteOne();
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

const Settlement = require('../models/Settlement');

router.get('/drivers/:id/settlements', authMiddleware, async (req, res) => {
  try {
    const driver = await findDriver(req.params.id);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    const isAdmin = req.user && req.user.role === 'admin';
    const ids = tokenIdentities(req);
    const isSelf = ids.length && driver.uid && ids.includes(String(driver.uid));
    if (!isAdmin && !isSelf) return res.status(403).json({ error: 'Forbidden' });
    const list = await Settlement.find({ driverId: driver._id })
      .sort({ createdAt: -1 });
    res.json(list);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/drivers/:id/settlements/:settlementId', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const driver = await findDriver(req.params.id);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    await Settlement.findByIdAndDelete(req.params.settlementId);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
