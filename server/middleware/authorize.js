// صلاحيات إضافية: فحص الأدمن + ملكية السجل
function requireAdmin(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'No token' });
  if (req.user.role === 'admin') return next();
  return res.status(403).json({ error: 'admin_only' });
}

// يسمح للأدمن أو لسائق لديه صلاحية التسعير (canSetPricing) بتحديث تسعيرة المدن
async function requireAdminOrPricingDriver(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'No token' });
  if (req.user.role === 'admin') return next();
  try {
    const Driver = require('../models/Driver');
    const driver = await Driver.findOne({ uid: req.user.uid || req.user.user_id });
    if (driver && driver.canSetPricing === true) return next();
  } catch (_) {}
  return res.status(403).json({ error: 'admin_only' });
}

// الـ UID الخاص بالطالب (Firebase uid أو JWT id)
function callerUid(req) {
  const u = req.user || {};
  return u.uid || u.user_id || u.id || null;
}

// كل الهويات المحتملة للطالب من التوكن: uid / user_id / id / username
function tokenIdentities(req) {
  const u = req.user || {};
  return [...new Set([u.uid, u.user_id, u.id, u.username].filter(v => v != null && v !== ''))].map(String);
}

// استرجاع وثيقة المستخدم الحقيقية من التوكن (بحث بـ uid / id / username)
async function resolveUserFromReq(req, User) {
  if (!req.user) return null;
  if (req.user.role === 'admin') return null;
  const ids = tokenIdentities(req);
  const or = [];
  if (ids.length) or.push({ uid: { $in: ids } });
  if (ids.length) or.push({ _id: { $in: ids.filter(x => /^[0-9a-fA-F]{24}$/.test(x)) } });
  if (req.user.username) or.push({ username: req.user.username });
  if (!or.length) return null;
  return User.findOne({ $or: or });
}

// هل الطالب هو صاحب السجل نفسه أو أدمن؟
function isSelfOrAdmin(req, user, rawId) {
  if (req.user && req.user.role === 'admin') return true;
  if (!req.user) return false;
  const uid = req.user.uid || req.user.user_id;
  if (rawId && uid && String(rawId) === String(uid)) return true;
  if (user) {
    if (uid && user.uid === uid) return true;
    if (req.user.id && user._id && String(user._id) === String(req.user.id)) return true;
    if (rawId && req.user.id && String(rawId) === String(req.user.id)) return true;
    if (req.user.username && user.username && user.username === req.user.username) return true;
  }
  return false;
}

module.exports = { requireAdmin, requireAdminOrPricingDriver, isSelfOrAdmin, callerUid, tokenIdentities, resolveUserFromReq };
