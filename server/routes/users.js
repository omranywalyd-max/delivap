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

// جلب مستخدم واحد (للزباين والتجار)
router.get('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    let user = await User.findOne({ uid: id });
    if (!user && mongoose.Types.ObjectId.isValid(id)) {
      user = await User.findById(id);
    }
    if (!user && id.length > 20) {
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
      user = await User.create({ uid: id, firstName: fbFirst, lastName: fbLast, lastIp: req.ip, isActive: true });
    }
    if (user) {
      user.lastIp = req.ip;
      await user.save();
    }
    res.json(user);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// تحديث مستخدم (معدل ليدعم الأدمن والزبون معاً)
router.put('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    let user;
    if (mongoose.Types.ObjectId.isValid(id)) {
      user = await User.findById(id);
    } else {
      user = await User.findOne({ uid: id });
    }
    if (!user) return res.status(404).json({ error: 'المستخدم غير موجود' });

    // مزامنة cityName من cityNameAr إذا كان后者 متوفر
    if (req.body.cityNameAr && !req.body.cityName && !user.cityName) {
      req.body.cityName = req.body.cityNameAr;
    }
    // مزامنة cityName من location إذا لم يكن两者 متوفر
    if (req.body.location && !req.body.cityName && !user.cityName) {
      req.body.cityName = req.body.location;
    }

    Object.assign(user, req.body, { updatedAt: new Date() });
    await user.save();
    res.json(user);
    const io = getIO();
    if (io && user) emitToUser(io, user.uid || user._id, 'user:updated', user);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// جلب الكل (للأدمن)
router.get('/users', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const users = await User.find().sort({ createdAt: -1 }).skip(skip).limit(limit);
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
router.get('/users/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;
    const messages = await Message.find({ userId: id }).sort({ createdAt: 1 });
    await Message.updateMany({ userId: id, from: 'admin', read: false }, { $set: { read: true } });
    res.json(messages);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// رد المستخدم على الأدمن
router.post('/users/:id/messages/reply', async (req, res) => {
  try {
    const { id } = req.params;
    const { text } = req.body;
    if (!text || !text.trim()) return res.status(400).json({ error: 'text required' });
    const msg = await Message.create({ userId: id, from: 'user', text: text.trim() });
    const io = getIO();
    if (io) {
      const { emitToRoom } = require('../socket');
      emitToRoom(io, 'admin_room', 'new_admin_message', msg.toObject());
    }
    res.json({ sent: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/users/:id', async (req, res) => {
  try {
    const id = req.params.id;
    let user = null;

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
    const { driverId } = req.body;
    const filter = mongoose.Types.ObjectId.isValid(id) ? { _id: id } : { uid: id };

    const user = await User.findOne(filter);
    if (!user) return res.status(404).json({ error: 'User not found' });

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

router.get('/users/:id/settlements', async (req, res) => {
  try {
    const list = await Settlement.find({ userId: req.params.id }).sort({ createdAt: -1 });
    res.json(list);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/users/:id/settlements/:settlementId', async (req, res) => {
  try {
    await Settlement.findByIdAndDelete(req.params.settlementId);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;