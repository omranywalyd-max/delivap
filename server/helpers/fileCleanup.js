const fs = require('fs');
const path = require('path');

function deleteImageFile(url) {
  if (!url || typeof url !== 'string' || !url.includes('/uploads/')) return;
  const filename = url.split('/uploads/').pop();
  if (!filename) return;
  const filePath = path.join(__dirname, '..', 'uploads', filename);
  try { if (fs.existsSync(filePath)) fs.unlinkSync(filePath); } catch (_) {}
}

function deleteImageFiles(urls) {
  if (!Array.isArray(urls)) return;
  for (const url of urls) deleteImageFile(url);
}

module.exports = { deleteImageFile, deleteImageFiles };
