process.env.DOTENV_CONFIG_QUIET = 'true';
require('dotenv').config({ path: require('path').join(__dirname, '.env') });
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection:', reason);
});
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
});
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const path = require('path');
const connectDB = require('./db');
const { setIO } = require('./socket/ioInstance');

// ── Firebase Admin (مركزي باش كل الملفات تستفيد) ──
const admin = require('firebase-admin');
try {
  const serviceAccount = require('./serviceAccountKey.json');
  if (admin.getApps().length === 0) {
    admin.initializeApp({ credential: admin.cert(serviceAccount) });
  }
} catch (e) {
  console.warn('⚠️ No serviceAccountKey.json found — Firebase Admin disabled');
}

const app = express();
const server = http.createServer(app);

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',')
  : ['https://api.delivap.com', 'https://delivap.com'];

const io = new Server(server, {
  cors: {
    origin: allowedOrigins,
    methods: ['GET', 'POST', 'PUT', 'DELETE']
  }
});

let _io = null;
const getIO = () => _io;

// ── Middleware ──
app.set('trust proxy', 1);
app.use(cors({ origin: allowedOrigins }));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads'), { maxAge: '365d' }));
app.use('/admin', express.static(path.join(__dirname, 'admin')));

// Rate limiting
const rateLimit = require('express-rate-limit');
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 20, message: { error: 'طلبات كثيرة. حاول بعد 15 دقيقة.' } });
const generalLimiter = rateLimit({ windowMs: 60 * 1000, max: 200, message: { error: 'طلبات كثيرة. حاول بعد دقيقة.' } });
app.use('/api/admin/login', authLimiter);
app.use('/api/owner-login', authLimiter);
app.use('/api/users', generalLimiter);
app.use('/api/orders', generalLimiter);

// ── Route Aliases (French/English compatibility) ──
app.use((req, res, next) => {
  if (req.path.startsWith('/api/produits')) {
    req.url = req.url.replace('/api/produits', '/api/products');
  } else if (req.path.startsWith('/api/magasins')) {
    req.url = req.url.replace('/api/magasins', '/api/stores');
  }
  next();
});

// ── Routes (wrapped with fallback) ──
function safeRoute(path, mount) {
  try {
    const router = require(path);
    if (typeof router === 'function') return app.use(mount, router);
    console.warn(`⚠️ ${path} did not export a router`);
  } catch (e) {
    console.error(`❌ Failed to load ${path}:`, e.message);
  }
  const fallback = require('express').Router();
  fallback.all('/{*splat}', (req, res) => res.status(503).json({ error: `Route ${mount} unavailable` }));
  app.use(mount, fallback);
}
// ── Public routes (registered before auth so GET passes without token) ──
safeRoute('./routes/promotions', '/api');
safeRoute('./routes/config', '/api');
safeRoute('./routes/contact', '/api');
// ── Debug arrival log (before auth) ──
app.post('/api/debug/arrival-log', (req, res) => {
  const { userId, sound, isEnabled, hasContext, source, timestamp } = req.body;
  console.log(`🔔 [ARRIVAL DEBUG] userId=${userId} sound=${sound} isEnabled=${isEnabled} hasContext=${hasContext} source=${source} time=${timestamp}`);
  res.json({ ok: true });
});

// ── Auth middleware لجميع عمليات الكتابة + قراءة الطلبيات ──
const authMiddleware = require('./middleware/auth');
app.use('/api', (req, res, next) => {
  const publicPaths = ['/admin/login', '/owner-login', '/notify-token', '/clear-token', '/upload', '/debug/arrival-log'];
  const publicUserWrites = ['/users'];
  const isWrite = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method);
  const isReadOrders = req.method === 'GET' && (req.path === '/orders' || req.path.startsWith('/orders/'));
  if ((isWrite || isReadOrders) && !publicPaths.includes(req.path) && !req.path.startsWith('/admin/')) {
    if ((req.method === 'POST' && publicUserWrites.includes(req.path)) ||
        (req.method === 'PUT' && req.path.startsWith('/users/'))) return next();
    return authMiddleware(req, res, next);
  }
  next();
});
safeRoute('./routes/admin', '/api/admin');
safeRoute('./routes/upload', '/api');
safeRoute('./routes/users', '/api');
safeRoute('./routes/categories', '/api');
safeRoute('./routes/stores', '/api');
safeRoute('./routes/products', '/api');
safeRoute('./routes/drivers', '/api');
safeRoute('./routes/orders', '/api');
safeRoute('./routes/transportOrders', '/api');
safeRoute('./routes/serviceOrders', '/api');
safeRoute('./routes/projects', '/api');
safeRoute('./routes/projectDeliveries', '/api');
safeRoute('./routes/drinks', '/api');
safeRoute('./routes/favorites', '/api');
safeRoute('./routes/misc', '/api');
safeRoute('./routes/reportedDrivers', '/api');
safeRoute('./routes/driverStats', '/api');

// ── Error handler ──
app.use((err, req, res, next) => {
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    console.error('❌ JSON parse error from', req.method, req.path, '- body:', req.body);
    return res.status(400).json({ error: 'JSON غير صحيح في الطلب' });
  }
  console.error('❌', err.stack || err.message);
  res.status(err.status || 500).json({ error: 'حدث خطأ داخلي في الخادم' });
});

// ── Socket ──
const { setupSocket } = require('./socket');
setupSocket(io);
setIO(io);

// ── Start ──
const PORT = process.env.PORT || 3000;
const net = require('net');

function startServer() {
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
    console.log(`📁 Uploads served at /uploads`);
    console.log(`🔌 Socket.IO listening`);
  });
  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.warn(`⚠️ Port ${PORT} in use, killing old process...`);
      const spawn = require('child_process').spawn;
      const killer = spawn('fuser', ['-k', `${PORT}/tcp`]);
      killer.on('exit', () => {
        setTimeout(startServer, 1000);
      });
    } else {
      console.error('❌ Server error:', err.message);
      process.exit(1);
    }
  });
}

connectDB().then(startServer);


