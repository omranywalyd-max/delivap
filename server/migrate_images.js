const mongoose = require('mongoose');
require('dotenv').config();

const OLD = 'http://192.168.100.50:3000';
const NEW = 'https://api.delivap.com';

async function migrate() {
  await mongoose.connect(process.env.MONGO_URI);
  const db = mongoose.connection.db;

  const updates = [
    { collection: 'magasins',      field: 'image' },
    { collection: 'produits',      field: 'image' },
    { collection: 'produits',      field: 'extraImages', isArray: true },
    { collection: 'users',         field: 'photoUrl' },
    { collection: 'drivers',       field: 'photoUrl' },
    { collection: 'categories',    field: 'image' },
    { collection: 'promotions',    field: 'image' },
  ];

  for (const { collection, field, isArray } of updates) {
    const col = db.collection(collection);
    const filter = isArray
      ? { [field]: { $regex: `^${OLD}` } }
      : { [field]: { $regex: `^${OLD}` } };

    const docs = await col.find(filter).toArray();
    if (docs.length === 0) {
      console.log(`⚠️  ${collection}.${field}: 0 matches`);
      continue;
    }

    let matched = 0;
    for (const doc of docs) {
      if (isArray) {
        const oldArr = doc[field] || [];
        const newArr = oldArr.map(v => v.startsWith(OLD) ? v.replace(OLD, NEW) : v);
        if (JSON.stringify(oldArr) !== JSON.stringify(newArr)) {
          await col.updateOne({ _id: doc._id }, { $set: { [field]: newArr } });
          matched++;
        }
      } else {
        const oldVal = doc[field];
        if (oldVal && oldVal.startsWith(OLD)) {
          await col.updateOne({ _id: doc._id }, { $set: { [field]: oldVal.replace(OLD, NEW) } });
          matched++;
        }
      }
    }
    console.log(`✅ ${collection}.${field}: ${matched}/${docs.length} updated`);
  }

  await mongoose.disconnect();
  console.log('\n🎉 Migration complete!');
}

migrate().catch(err => { console.error(err); process.exit(1); });
