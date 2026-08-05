const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');
const { v4: uuidv4 } = require('uuid');
const authMiddleware = require('../middleware/auth');

const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${Date.now()}-${uuidv4()}${ext}`);
  }
});

const ALLOWED_TYPES = [
  'image/jpeg', 'image/png', 'image/webp', 'image/gif',
  'video/mp4', 'video/webm', 'video/quicktime', 'video/x-msvideo', 'video/x-matroska'
];
// امتدادات آمنة فقط — يمنع HTML/SVG/JS وكل ما يمكن تنفيذه في المتصفح
const ALLOWED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.mp4', '.webm', '.mov', '.avi', '.mkv'];
const MAX_SIZE = 100 * 1024 * 1024; // 100MB — الفيديو أكبر من الصور

const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  if (!ALLOWED_EXTENSIONS.includes(ext)) {
    return cb(new Error(`امتداد الملف غير مسموح: ${ext}`));
  }
  if (!ALLOWED_TYPES.includes(file.mimetype)) {
    return cb(new Error(`نوع الملف غير مسموح: ${file.mimetype}. الأنواع المسموحة: صور (JPG, PNG, WebP, GIF) أو فيديو (MP4, WebM)`));
  }
  cb(null, true);
};

const upload = multer({ storage, fileFilter, limits: { fileSize: MAX_SIZE } });

const MAX_WIDTH = 1200;
const QUALITY = 80;

router.post('/upload', authMiddleware, upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const base = process.env.BASE_URL || 'http://localhost:3000';
  const origPath = req.file.path;
  const origSize = req.file.size;
  try {
    const ext = path.extname(req.file.filename).toLowerCase();
    const isGif = ext === '.gif';
    const isVideo = req.file.mimetype.startsWith('video/');
    if (!isGif && !isVideo) {
      const webpName = req.file.filename.replace(/\.[^.]+$/, '.webp');
      const webpPath = path.join(req.file.destination, webpName);
      const meta = await sharp(origPath).metadata();
      let pipeline = sharp(origPath).webp({ quality: QUALITY });
      if (meta.width && meta.width > MAX_WIDTH) {
        pipeline = pipeline.resize({ width: MAX_WIDTH, withoutEnlargement: true });
      }
      await pipeline.toFile(webpPath);
      fs.unlinkSync(origPath);
      const newSize = fs.statSync(webpPath).size;
      const ratio = Math.round((1 - newSize / origSize) * 100);
      console.log(`Compressed: ${origSize} -> ${newSize} (${ratio}% smaller)`);
      const url = `${base}/uploads/${webpName}`;
      return res.json({ url, filename: webpName, compressed: true, originalSize: origSize, newSize });
    }
    const url = `${base}/uploads/${req.file.filename}`;
    res.json({ url, filename: req.file.filename, compressed: false, type: isVideo ? 'video' : 'image' });
  } catch (err) {
    console.error('Image compression error:', err.message);
    const url = `${base}/uploads/${req.file.filename}`;
    res.json({ url, filename: req.file.filename, compressed: false });
  }
});

// حذف آمن: نمنع path traversal (../ و %) — ملف داخل مجلد uploads فقط
router.delete('/upload/:filename', authMiddleware, (req, res) => {
  try {
    const name = path.basename(req.params.filename);
    if (name !== req.params.filename) {
      return res.status(400).json({ error: 'Invalid filename' });
    }
    const root = path.resolve(__dirname, '..', 'uploads');
    const filePath = path.resolve(root, name);
    if (!filePath.startsWith(root + path.sep)) {
      return res.status(400).json({ error: 'Invalid filename' });
    }
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      res.json({ deleted: true });
    } else {
      res.status(404).json({ error: 'الملف غير موجود' });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
