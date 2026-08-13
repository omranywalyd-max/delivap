const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Message = require('../models/Message');
const { getAuth } = require('firebase-admin/auth');
const { getIO } = require('../socket/ioInstance');
const { emitToUser } = require('../socket');
const authMiddleware = require('../middleware/auth');
const { isSelfOrAdmin } = require('../middleware/authorize');

// تنظيف الحقول الحساسة قبل الرد
const PRIVATE_FIELDS = ['password', 'lastIp', 'bannedIp'];
function toSafeUser(u) {
  if (!u) return u;
  const obj = u.toObject ? u.toObject() : { ...u };
  for (const f of PRIVATE_FIELDS) delete obj[f];
  return obj;
}

// تحقق اختياري بدون فشل (للمسارات العمومية)
async function resolveOptionalUser(req) {
  if (req.user) return req.user;
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return null;
  try { return await getAuth().verifyIdToken(token); } catch (_) {}
  try { return jwt.verify(token, process.env.JWT_SECRET); } catch (_) {}
  return null;
}

// عدد المستخدمين حسب الفلترة (للـ pagination)
router.get('/users/count', async (req, res) => {
  try {
    const filter = {};
    if (req.query.role) filter.role = req.query.role;
    const count = await User.countDocuments(filter);
    res.json({ count });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// جلب مستخدم واحد (للزباين والتجار)
router.get('/users/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    let user = await User.findOne({ uid: id });
    if (!user && mongoose.Types.ObjectId.isValid(id)) {
      user = await User.findById(id);
    }
    if (!user && id.length > 20) {
      if (!isSelfOrAdmin(req, null, id)) {
        return res.status(403).json({ error: 'Forbidden' });
      }
      // تحقق من أن مستخدم Firebase موجود قبل auto-create
      try {
        await getAuth().getUser(id);
      } catch (_) {
        return res.status(404).json({ error: 'الحساب محذوف', deleted: true });
      }
      const bannedExists = await User.findOne({ bannedIp: req.ip, isBanned: true });
      if (bannedExists) {
        return res.status(403).json({ error: 'تم حظر هذا الجهاز. لا يمكنك إنشاء حساب جديد.', ipBanned: true });
      }
      let fbName = '';
      try {
        const fbUser = await getAuth().getUser(id);
        fbName = fbUser.displayName || '';
      } catch (_) {}
      const parts = fbName.split(' ');
      const fbFirst = parts[0] || '';
      const fbLast = parts.slice(1).join(' ');
      user = await User.findOneAndUpdate(
        { uid: id },
        {
          $set: { lastIp: req.ip },
          $setOnInsert: { uid: id, firstName: fbFirst, lastName: fbLast, isActive: true },
        },
        { upsert: true, returnDocument: 'after', setDefaultsOnInsert: true }
      );
    } else if (user && !isSelfOrAdmin(req, user, id)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    if (user) {
      user.lastIp = req.ip;
      await user.save();
    }
    res.json(toSafeUser(user));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// تحديث مستخدم (معدل ليدعم الأدمن والزبون معاً)
router.put('/users/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    let user;
    if (mongoose.Types.ObjectId.isValid(id)) {
      user = await User.findById(id);
    } else {
      user = await User.findOne({ uid: id });
    }
    if (!user) return res.status(404).json({ error: 'المستخدم غير موجود' });
    if (!isSelfOrAdmin(req, user, id)) return res.status(403).json({ error: 'Forbidden' });

    // منع المستخدم العادي من تعديل الحقول الحساسة (الأدمن مخول)
    if (!req.user || req.user.role !== 'admin') {
      const blocked = ['role', 'uid', '_id', 'isActive', 'isBanned', 'isAdmin', 'bannedIp', 'isVerified', 'commissionPercent', 'totalEarnings', 'cash', 'lastCommissionResetEarnings'];
      for (const k of blocked) delete req.body[k];
    }

    // مزامنة cityName من cityNameAr إذا كان后者 متوفر
    if (req.body.cityNameAr && !req.body.cityName && !user.cityName) {
      req.body.cityName = req.body.cityNameAr;
    }
    // مزامنة cityName من location إذا لم يكن两者 متوفر
    if (req.body.location && !req.body.cityName && !user.cityName) {
      req.body.cityName = req.body.location;
    }

    if (req.body.password) {
      req.body.password = await bcrypt.hash(String(req.body.password), 12);
    }

    Object.assign(user, req.body, { updatedAt: new Date() });
    await user.save();
    res.json(toSafeUser(user));
    const io = getIO();
    if (io && user) emitToUser(io, user.uid || user._id, 'user:updated', toSafeUser(user));
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// جلب الكل (للأدمن + نسخة مخففة للعموم)
router.get('/users', async (req, res) => {
  try {
    req.user = req.user || await resolveOptionalUser(req);
    const isAdmin = req.user && req.user.role === 'admin';
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    // فلترة حسب الدور (مثال: ?role=owner يجيب أصحاب المحلات برك)
    const filter = {};
    if (req.query.role) filter.role = req.query.role;
    const users = await User.find(filter)
      .select(isAdmin ? '-password -lastIp -bannedIp' : '_id uid username role storeName firstName lastName createdAt isActive')
      .sort({ createdAt: -1 }).skip(skip).limit(limit);
    res.json(users);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// POST /api/users/owner-login — تسجيل دخول التاجر (آمن)
router.post('/owner-login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: 'username and password required' });
    }

    const user = await User.findOne({
      username,
      role: { $in: ['owner', 'merchant'] }
    });

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Support both hashed and plain text passwords during migration
    let isValid = false;
    if (user.password.startsWith('$2')) {
      isValid = await bcrypt.compare(password, user.password);
    } else {
      isValid = user.password === password;
      if (isValid) {
        user.password = await bcrypt.hash(password, 12);
        await user.save();
      }
    }

    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    user.lastIp = req.ip;
    await user.save();

    const token = jwt.sign(
      { role: 'owner', username: user.username, id: user._id },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );
    res.json({ success: true, token, user });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
// إنشاء مستخدم جديد (يستعمله التاجر)
router.post('/users', async (req, res) => {
  try {
    console.log("📥 طلب تسجيل جديد:", req.body);

    // ✅ إذا كان تاجر وماعندوش UID، نعطوه واحد عشوائي باش المونغو ما تبلوكيش
    if (req.body.role === 'owner' && !req.body.uid) {
      req.body.uid = 'merchant_' + Date.now() + "_" + Math.floor(Math.random() * 1000);
    }

    // ✅ منع التسجيل إذا كان الـ IP محظور
    const bannedExists = await User.findOne({
      isBanned: true,
      $or: [{ bannedIp: req.ip }, { lastIp: req.ip }]
    });
    if (bannedExists) {
      return res.status(403).json({ error: 'لا يمكنك التسجيل. تم حظر هذا الجهاز.', ipBanned: true });
    }

    // منع الاستيلاء على حساب موجود عبر upsert (الزبون ممكن يسجل بلا توكن)
    req.user = req.user || await resolveOptionalUser(req);
    if (req.body.uid) {
      const existing = await User.findOne({ uid: req.body.uid });
      if (existing && !isSelfOrAdmin(req, existing, req.body.uid)) {
        return res.status(403).json({ error: 'هذا الحساب مسجل مسبقاً' });
      }
    }
    if (!req.user || req.user.role !== 'admin') {
      delete req.body.isBanned;
      delete req.body.isAdmin;
      delete req.body.bannedIp;
      delete req.body.isVerified;
      delete req.body.commissionPercent;
      delete req.body.totalEarnings;
      delete req.body.cash;
      if (req.body.role && !['owner', 'merchant', 'customer'].includes(req.body.role)) {
        return res.status(400).json({ error: 'role غير مسموح به' });
      }
    }

    // التاجر (owner) يحتفظ بـ isActive كما أرسله التطبيق (عادة false)
    // الزبون العادي ينشط تلقائياً
    if (req.body.role === 'owner') {
      // نحتفظ بـ isActive كما هو (true/false من التطبيق)
    } else {
      req.body.isActive = true; // الزبون ينشط ديركت
    }
    // Hash password if provided
    if (req.body.password) {
      req.body.password = await bcrypt.hash(req.body.password, 12);
    }

    req.body.lastIp = req.ip;
    req.body.updatedAt = new Date();

    // مزامنة cityName من cityNameAr إذا كان后者 متوفر
    if (req.body.cityNameAr && !req.body.cityName) {
      req.body.cityName = req.body.cityNameAr;
    }
    // مزامنة cityName من location إذا لم يكن两者 متوفر
    if (req.body.location && !req.body.cityName) {
      req.body.cityName = req.body.location;
    }

    // upsert باش ما نخلقوش مستخدم مكرر (ال GET autu-create يمكن يكون سبقنا)
    const user = await User.findOneAndUpdate(
      { uid: req.body.uid },
      { $set: { ...req.body } },
      { upsert: true, returnDocument: 'after', setDefaultsOnInsert: true }
    );

    console.log("✅ تم الحفظ بنجاح في الداتابيز");
    res.status(201).json(user);
  } catch (e) {
    console.error("❌ خطأ أثناء الحفظ:", e.message);
    res.status(500).json({ error: e.message });
  }
});


// جلب جميع رسائل المستخدم (ذهابا وإيابا)
router.get('/users/:id/messages', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const target = mongoose.Types.ObjectId.isValid(id) ? await User.findById(id) : await User.findOne({ uid: id });
    if (!isSelfOrAdmin(req, target, id)) return res.status(403).json({ error: 'Forbidden' });
    const messages = await Message.find({ userId: id }).sort({ createdAt: 1 });
    await Message.updateMany({ userId: id, from: 'admin', read: false }, { $set: { read: true } });
    res.json(messages);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// رد المستخدم على الأدمن
router.post('/users/:id/messages/reply', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { text } = req.body;
    if (!text || !text.trim()) return res.status(400).json({ error: 'text required' });
    const target = mongoose.Types.ObjectId.isValid(id) ? await User.findById(id) : await User.findOne({ uid: id });
    if (!isSelfOrAdmin(req, target, id)) return res.status(403).json({ error: 'Forbidden' });
    const msg = await Message.create({ userId: id, from: 'user', text: text.trim() });
    const io = getIO();
    if (io) {
      const { emitToRoom } = require('../socket');
      emitToRoom(io, 'admin_room', 'new_admin_message', msg.toObject());
    }
    res.json({ sent: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/users/:id', authMiddleware, async (req, res) => {
  try {
    const id = req.params.id;
    let user = null;

    try {
      user = await User.findById(id);
    } catch (e) {}

    if (!user) {
      user = await User.findOne({ uid: id });
    }

    if (user && !isSelfOrAdmin(req, user, id)) return res.status(403).json({ error: 'Forbidden' });
    if (!user && !isSelfOrAdmin(req, null, id)) return res.status(403).json({ error: 'Forbidden' });

    // 1. نحاول نحذف باستعمال الـ ID تاع المونغو ( ObjectId )
    // نستعمل try/catch داخلية باش لو كان الـ ID ماشي ObjectId ما يحبسش السيرفر
    try {
      user = await User.findByIdAndDelete(id);
    } catch (e) {
      // إذا فشل لأنه ليس ObjectId، نكمل للبحث بالـ uid
    }

    // 2. إذا ملقيناش أو المعرف كان نصي (uid)
    if (!user) {
      user = await User.findOneAndDelete({ uid: id });
    }

    if (user) {
      console.log(`✅ تم حذف المستخدم: ${id}`);
      res.json({ deleted: true, message: "User deleted successfully" });
    } else {
      res.status(404).json({ error: "User not found" });
    }
  } catch (e) {
    console.error("❌ خطأ أثناء الحذف:", e.message);
    res.status(500).json({ error: e.message });
  }
});



// زيادة الولاء بعد تأكيد الاستلام (atomic increment)
router.put('/users/:id/loyalty', async (req, res) => {
  try {
    const { id } = req.params;
    const { driverId, orderId } = req.body;
    const filter = mongoose.Types.ObjectId.isValid(id) ? { _id: id } : { uid: id };

    const user = await User.findOne(filter);
    if (!user) return res.status(404).json({ error: 'User not found' });

    if (orderId) {
      const Order = require('../models/Order');
      const order = await Order.findById(orderId);
      if (order && order.customerConfirmed) {
        return res.json({ ...user.toObject(), loyaltySkipped: true });
      }
    }

    const updates = { updatedAt: new Date() };
    if (!user.isVerified) updates.isVerified = true;

    // Per-driver loyalty
    if (driverId) {
      const driverLoyalty = user.driverLoyalty || {};
      const currentDriverCount = (driverLoyalty.get?.(driverId) ?? 0) + 1;
      updates[`driverLoyalty.${driverId}`] = currentDriverCount >= 5 ? 0 : currentDriverCount;
      if (currentDriverCount >= 5) {
        updates[`driverFreeDelivery.${driverId}`] = true;
      }
    }

    const updated = await User.findOneAndUpdate(
      filter,
      { $set: updates },
      { returnDocument: 'after' }
    );

    res.json(updated);
    const io = getIO();
    if (io) emitToUser(io, updated.uid || updated._id, 'user:updated', updated);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

const Settlement = require('../models/Settlement');

// حذف بيانات ولاء سائق محذوف من حساب الزبون
router.delete('/users/:id/loyalty/:driverId', async (req, res) => {
  try {
    const { id, driverId } = req.params;
    const filter = mongoose.Types.ObjectId.isValid(id) ? { _id: id } : { uid: id };
    const updated = await User.findOneAndUpdate(
      filter,
      { $unset: { [`driverLoyalty.${driverId}`]: '', [`driverFreeDelivery.${driverId}`]: '' } },
      { returnDocument: 'after' }
    );
    if (!updated) return res.status(404).json({ error: 'User not found' });
    res.json({ success: true, updated });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/users/:id/settlements', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const target = mongoose.Types.ObjectId.isValid(id) ? await User.findById(id) : await User.findOne({ uid: id });
    if (!isSelfOrAdmin(req, target, id)) return res.status(403).json({ error: 'Forbidden' });
    const list = await Settlement.find({ userId: req.params.id }).sort({ createdAt: -1 });
    res.json(list);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/users/:id/settlements/:settlementId', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const target = mongoose.Types.ObjectId.isValid(id) ? await User.findById(id) : await User.findOne({ uid: id });
    if (!isSelfOrAdmin(req, target, id)) return res.status(403).json({ error: 'Forbidden' });
    await Settlement.findByIdAndDelete(req.params.settlementId);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;