const mongoose = require('mongoose');
mongoose.connect('mongodb://127.0.0.1:27017/delivery').then(async () => {
  const db = mongoose.connection.db;
  const collections = await db.listCollections().toArray();
  console.log('Collections:', collections.map(c => c.name));
  const count = await db.collection('users').countDocuments();
  console.log('Total users:', count);
  const users = await db.collection('users').find({}).sort({ createdAt: -1 }).limit(50).toArray();
  const nameCount = {};
  users.forEach(u => {
    const name = ((u.firstName || '') + ' ' + (u.lastName || '')).trim();
    const key = name || u.phone || u.email || 'no-name';
    if (!nameCount[key]) nameCount[key] = [];
    nameCount[key].push({ _id: u._id.toString(), uid: u.uid, name, phone: u.phone, role: u.role, email: u.email });
  });
  for (const [key, entries] of Object.entries(nameCount)) {
    if (entries.length > 1) {
      console.log('DUPLICATE:', key);
      entries.forEach(e => console.log('  -', JSON.stringify(e)));
    }
  }
  mongoose.disconnect();
}).catch(e => console.error('Error:', e.message));
