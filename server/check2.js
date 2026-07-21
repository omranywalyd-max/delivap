const { Client } = require('ssh2');
const conn = new Client();
conn.on('ready', () => {
  const script = `const mongoose = require('mongoose');
mongoose.connect('mongodb://127.0.0.1:27017/walyyd').then(async () => {
  const db = mongoose.connection.db;
  const stores = await db.collection('stores').countDocuments();
  const products = await db.collection('produits').countDocuments();
  const templates = await db.collection('templates').countDocuments();
  const fs = require('fs');
  const files = fs.readdirSync('/root/delivery-server/uploads').filter(f => f !== '.gitkeep');
  console.log('stores=' + stores + ' products=' + products + ' templates=' + templates + ' uploads=' + files.length);
  if (products > 0) {
    const prods = await db.collection('produits').find({}).limit(3).toArray();
    console.log('prods:', JSON.stringify(prods.map(p => ({name:p.name, image:p.image, storeId:p.storeId}))));
  }
  await mongoose.disconnect();
}).catch(e => console.error(e.message));`;
  const b64 = Buffer.from(script).toString('base64');
  conn.exec(`echo '${b64}' | base64 -d | NODE_PATH=/root/delivery-server/node_modules node`, (err, stream) => {
    if (err) { console.error(err); conn.end(); return; }
    let out = '';
    stream.on('data', d => out += d.toString());
    stream.stderr.on('data', d => out += d.toString());
    stream.on('close', () => { console.log(out); conn.end(); });
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
