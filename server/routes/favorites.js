const express = require('express');
const router = express.Router();
const Favorite = require('../models/Favorite');
const authMiddleware = require('../middleware/auth');
const { tokenIdentities, resolveUserFromReq } = require('../middleware/authorize');
const User = require('../models/User');
const { getAuth } = require('firebase-admin/auth');
const jwt = require('jsonwebtoken');

// auth اختياري: يملأ req.user لو فيه توكن صالح، بدون ما يمنع الطلب
async function optionalAuth(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return next();
  try {
    req.user = await getAuth().verifyIdToken(token);
    return next();
  } catch (_) {
    try {
      req.user = jwt.verify(token, process.env.JWT_SECRET);
      return next();
    } catch (_) {
      return next();
    }
  }
}

const MERCHANT_ROLES = ['owner', 'merchant'];

async function ownIds(req) {
  const ids = [...tokenIdentities(req)];
  const u = await resolveUserFromReq(req, User);
  if (u) {
    if (u.uid) ids.push(u.uid);
    if (u.username) ids.push(u.username);
    if (u._id) ids.push(String(u._id));
  }
  return [...new Set(ids.map(String))];
}

function matches(ids, value) {
  return value != null && ids.includes(String(value));
}

async function isOwner(req, value) {
  if (req.user && req.user.role === 'admin') return true;
  return matches(await ownIds(req), value);
}

// ✅ GET: عام للقراءة — الزبون (حتى مش مسجل) يشوف فافوريت المتجر
//    التاجر (owner/merchant) يشوف فافوريتو هو فقط داخل المتجر
//    أولوية: storeId ثم userId ثم فافوريت المستخدم الحالي
router.get('/favorites', optionalAuth, async (req, res) => {
  try {
    const filter = {};
    if (req.query.storeId) {
      filter.storeId = req.query.storeId;
      if (req.user && MERCHANT_ROLES.includes(req.user.role)) {
        const ids = await ownIds(req);
        if (!ids.length) return res.json([]);
        filter.userId = { $in: ids };
      }
    } else if (req.query.userId) {
      filter.userId = req.query.userId;
    } else {
      const ids = await ownIds(req);
      if (!ids.length) return res.json([]);
      filter.userId = { $in: ids };
    }
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const faves = await Favorite.find(filter).skip(skip).limit(limit);
    res.json(faves);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/favorites', authMiddleware, async (req, res) => {
  try {
    if (req.user && req.user.role !== 'admin') {
      const ids = await ownIds(req);
      if (ids.length) req.body.userId = ids[0];
    }
    const fave = await Favorite.create(req.body);
    res.status(201).json(fave);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/favorites/:id', authMiddleware, async (req, res) => {
  try {
    const fave = await Favorite.findById(req.params.id);
    if (!fave) return res.status(404).json({ error: 'Not found' });
    if (!(await isOwner(req, fave.userId))) return res.status(403).json({ error: 'Forbidden' });
    const updated = await Favorite.findByIdAndUpdate(req.params.id, req.body, { returnDocument: 'after' });
    res.json(updated);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/favorites/:id', authMiddleware, async (req, res) => {
  try {
    const fave = await Favorite.findById(req.params.id);
    if (!fave) return res.status(404).json({ error: 'Not found' });
    if (!(await isOwner(req, fave.userId))) return res.status(403).json({ error: 'Forbidden' });
    await Favorite.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
