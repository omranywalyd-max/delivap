const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost/walyyd').then(async () => {
  // add missing financial fields
  const r1 = await mongoose.connection.collection('categories').updateMany(
    { cash: { $exists: false } },
    { $set: { cash: 0, totalEarnings: 0, lastCommissionResetEarnings: 0, totalCollected: 0 } }
  );
  console.log('Add financial fields:', JSON.stringify(r1));
  // unset commissionPercent for categories that were never explicitly set (old default was 0)
  const r2 = await mongoose.connection.collection('categories').updateMany(
    { commissionPercent: 0 },
    { $unset: { commissionPercent: '' } }
  );
  console.log('Unset commissionPercent:', JSON.stringify(r2));
  process.exit(0);
}).catch(e => { console.error(e); process.exit(1); });
