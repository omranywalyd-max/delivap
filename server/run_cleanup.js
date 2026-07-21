const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

async function run() {
  await mongoose.connect('mongodb://127.0.0.1:27017/walyyd');
  const produits = await mongoose.connection.db.collection('produits').find({}, { projection: { image: 1, extraImages: 1 } }).toArray();
  const uploadsDir = '/root/delivery-server/uploads';
  const files = fs.readdirSync(uploadsDir);
  const referenced = new Set();
  for (const p of produits) {
    if (p.image) referenced.add(path.basename(p.image.replace(/\\/g, '/')));
    if (p.extraImages && Array.isArray(p.extraImages)) {
      for (const img of p.extraImages) {
        if (typeof img === 'string') referenced.add(path.basename(img.replace(/\\/g, '/')));
      }
    }
  }
  const deleted = [];
  for (const file of files) {
    const fp = path.join(uploadsDir, file);
    if (fs.statSync(fp).isFile() && !referenced.has(file) && file !== '.gitkeep') {
      fs.unlinkSync(fp);
      deleted.push(file);
    }
  }
  console.log(JSON.stringify({ deleted, count: deleted.length }));
  await mongoose.disconnect();
}
run().catch(e => { console.error(e.message); process.exit(1); });
