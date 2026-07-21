const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost/walyyd').then(async () => {
  const db = mongoose.connection.db;
  try {
    await db.collection('orders').createIndex(
      { deleteAt: 1 },
      { expireAfterSeconds: 0 }
    );
    console.log('TTL index on orders.deleteAt created.');
  } catch (e) {
    console.error('TTL index error:', e.message);
  }
  process.exit(0);
}).catch(e => { console.error(e); process.exit(1); });
