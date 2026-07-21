const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost/walyyd').then(async () => {
  const db = mongoose.connection.db;

  // 1. حذف كل الأوردرات
  const delOrders = await db.collection('orders').deleteMany({});
  console.log('Orders deleted:', delOrders.deletedCount);

  // 2. حذف كل service_orders
  try { const r = await db.collection('service_orders').deleteMany({}); console.log('Service orders deleted:', r.deletedCount); } catch (_) {}

  // 3. حذف كل transport_orders
  try { const r = await db.collection('transport_orders').deleteMany({}); console.log('Transport orders deleted:', r.deletedCount); } catch (_) {}

  // 4. حذف كل project_deliveries
  try { const r = await db.collection('project_deliveries').deleteMany({}); console.log('Project deliveries deleted:', r.deletedCount); } catch (_) {}

  // 5. حذف كل settlements
  try { const r = await db.collection('settlements').deleteMany({}); console.log('Settlements deleted:', r.deletedCount); } catch (_) {}

  // 6. تصفير أرصدة السائقين
  try { const r = await db.collection('drivers').updateMany({}, { $set: { cash: 0, totalEarnings: 0 } }); console.log('Drivers reset:', r.modifiedCount); } catch (_) {}

  // 7. تصفير أرصدة التجار (stores)
  try { const r = await db.collection('magasins').updateMany({}, { $set: { cash: 0, totalEarnings: 0, totalCollected: 0 } }); console.log('Stores reset:', r.modifiedCount); } catch (_) {}

  // 8. تصفير أرصدة الأقسام
  try { const r = await db.collection('categories').updateMany({}, { $set: { cash: 0, totalEarnings: 0, totalCollected: 0, lastCommissionResetEarnings: 0 } }); console.log('Categories reset:', r.modifiedCount); } catch (_) {}

  // 9. تصفير أرصدة المستخدمين (التجار والزبائن)
  try { const r = await db.collection('users').updateMany({}, { $set: { cash: 0, totalEarnings: 0 } }); console.log('Users reset:', r.modifiedCount); } catch (_) {}

  // 10. تصفير أرصدة الزبائن (customers) إن وجدت
  try { const r = await db.collection('customers').updateMany({}, { $set: { cash: 0, totalEarnings: 0 } }); console.log('Customers reset:', r.modifiedCount); } catch (_) {}

  // 11. إنشاء TTL index للحذف التلقائي بعد أسبوع
  try {
    await db.collection('orders').createIndex(
      { deleteAt: 1 },
      { expireAfterSeconds: 0 }
    );
    console.log('TTL index created on orders.deleteAt');
  } catch (e) {
    console.error('TTL index error:', e.message);
  }

  console.log('Cleanup complete.');
  process.exit(0);
}).catch(e => { console.error(e); process.exit(1); });
