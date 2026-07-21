const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost/walyyd').then(async () => {
  const db = mongoose.connection.db;
  const orders = await db.collection('orders').find({ status: 'delivered' }).toArray();
  let totals = {};

  // Cache products by storeId for matching
  const prodCache = {};

  for (const order of orders) {
    const items = order.items || [];
    for (const item of items) {
      const storeId = item.storeId;
      if (!storeId) continue;

      // Load products for this store
      if (!prodCache[storeId]) {
        prodCache[storeId] = await db.collection('produits').find({ storeId }).toArray();
      }
      const storeProds = prodCache[storeId];

      // Try 1: match by exact name
      let prod = storeProds.find(p => p.name === item.name);
      // Try 2: match by prix + storeId
      if (!prod && item.prix) {
        prod = storeProds.find(p => Number(p.prix) === Number(item.prix));
      }
      if (!prod || !prod.categorieId) continue;

      const itemTotal = ((item.finalPrice ?? item.prix ?? 0)) * (item.quantity ?? 1);
      const catId = prod.categorieId.toString();
      totals[catId] = (totals[catId] || 0) + itemTotal;
    }
  }

  console.log(`Processed ${orders.length} orders, found ${Object.keys(totals).length} categories with earnings.`);

  const catIds = Object.keys(totals).map(id => new mongoose.Types.ObjectId(id));
  const existingCats = await db.collection('categories').find({ _id: { $in: catIds } }).toArray();
  const catMap = {};
  for (const c of existingCats) catMap[c._id.toString()] = c;

  let totalSet = 0;
  for (const [catId, total] of Object.entries(totals)) {
    const existing = catMap[catId];
    if (existing && (existing.totalEarnings || 0) >= total) continue; // skip if already has this or more
    const collected = existing?.totalCollected || 0;
    await db.collection('categories').updateOne(
      { _id: new mongoose.Types.ObjectId(catId) },
      { $set: { totalEarnings: total, cash: Math.max(0, total - collected) } }
    );
    totalSet++;
  }

  console.log(`Updated ${totalSet} categories.`);
  process.exit(0);
}).catch(e => { console.error(e); process.exit(1); });
