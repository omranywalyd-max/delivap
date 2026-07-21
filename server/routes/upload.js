const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');
const { v4: uuidv4 } = require('uuid');

const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}-${uuidv4()}${ext}`);
  }
});

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MAX_SIZE = 25 * 1024 * 1024;

const fileFilter = (req, file, cb) => {
  if (ALLOWED_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`نوع الملف غير مسموح: ${file.mimetype}. الأنواع المسموحة: JPG, PNG, WebP, GIF`));
  }
};

const upload = multer({ storage, fileFilter, limits: { fileSize: MAX_SIZE } });

const MAX_WIDTH = 1200;
const QUALITY = 80;

router.post('/upload', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const base = process.env.BASE_URL || 'http://localhost:3000';
  const origPath = req.file.path;
  const origSize = req.file.size;
  try {
    const ext = path.extname(req.file.filename).toLowerCase();
    const isGif = ext === '.gif';
    if (!isGif) {
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
    res.json({ url, filename: req.file.filename, compressed: false });
  } catch (err) {
    console.error('Image compression error:', err.message);
    const url = `${base}/uploads/${req.file.filename}`;
    res.json({ url, filename: req.file.filename, compressed: false });
  }
});

router.delete('/upload/:filename', (req, res) => {
  try {
    const filePath = path.join(__dirname, '..', 'uploads', req.params.filename);
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
