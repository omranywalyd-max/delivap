const { getAuth } = require('firebase-admin/auth');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');

const isInitialized = admin.getApps().length > 0;

const authMiddleware = async (req, res, next) => {
  if (!isInitialized) {
    console.error('[AUTH] Firebase Admin not initialized');
    return res.status(503).json({ error: 'خدمة المصادقة غير متوفرة' });
  }
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    console.log('[AUTH] No token - %s %s', req.method, req.originalUrl);
    return res.status(401).json({ error: 'No token' });
  }
  try {
    const decoded = await getAuth().verifyIdToken(token);
    req.user = decoded;
    console.log('[AUTH] Firebase OK uid=%s for %s', decoded.uid, req.originalUrl);
    return next();
  } catch (e) {
    console.log('[AUTH] Firebase fail: %s for %s', e.message, req.originalUrl);
  }
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (!decoded.uid && !decoded.user_id) {
      console.log('[AUTH] JWT OK but no uid — rejected for %s', req.originalUrl);
    } else {
      req.user = decoded;
      console.log('[AUTH] JWT OK uid=%s for %s', decoded.uid || decoded.user_id, req.originalUrl);
      return next();
    }
  } catch (e) {
    console.log('[AUTH] JWT fail: %s for %s', e.message, req.originalUrl);
  }
  console.log('[AUTH] Invalid token for %s', req.originalUrl);
  res.status(401).json({ error: 'Invalid token' });
};

module.exports = authMiddleware;
