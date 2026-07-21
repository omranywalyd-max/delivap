const express = require('express');
const router = express.Router();
const Category = require('../models/Category');

router.get('/categories', async (req, res) => {
  try {
    const filter = {};
    const andCond = [];
    if (req.query.storeId) andCond.push({ storeId: req.query.storeId });
    if (req.query.templateId) andCond.push({ templateId: req.query.templateId });
    if (req.query.ownerId) andCond.push({ ownerId: req.query.ownerId });
    if (andCond.length) filter.$and = andCond;
    // دعم البحث أيضاً by storeId كـ templateId (لأن الزبون يبعث نفس القيمة للزوج)
    if (req.query.storeId && req.query.templateId && req.query.storeId === req.query.templateId) {
      delete filter.$and;
      filter.$or = [
        { storeId: req.query.storeId },
        { templateId: req.query.templateId },
      ];
      if (req.query.ownerId) {
        filter.$and = [
          { $or: [
            { storeId: req.query.storeId },
            { templateId: req.query.templateId },
          ]},
          { ownerId: req.query.ownerId },
        ];
        delete filter.$or;
      }
    }
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const cats = await Category.find(filter).sort({ order: 1, nom: 1 }).skip(skip).limit(limit);
    res.json(cats);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/categories/:id', async (req, res) => {
  try {
    const cat = await Category.findById(req.params.id);
    if (!cat) return res.status(404).json({ error: 'Category not found' });
    res.json(cat);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/categories', async (req, res) => {
  try {
    const cat = await Category.create(req.body);
    res.status(201).json(cat);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/categories/reorder', async (req, res) => {
  try {
    const { orders } = req.body;
    if (!Array.isArray(orders)) return res.status(400).json({ error: 'orders must be array' });
    const ops = orders.map(o => ({
      updateOne: { filter: { _id: o.id }, update: { $set: { order: o.order } } }
    }));
    await Category.bulkWrite(ops);
    res.json({ updated: orders.length });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/categories/:id', async (req, res) => {
  try {
    const cat = await Category.findByIdAndUpdate(
      req.params.id,
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    res.json(cat);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/categories/:id', async (req, res) => {
  try {
    await Category.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── إصلاح الأقسام القديمة (ownerId: null) ──
router.post('/categories/fix-orphans', async (req, res) => {
  try {
    const { ownerId, storeId } = req.body;
    if (!ownerId || !storeId) return res.status(400).json({ error: 'ownerId and storeId required' });
    const result = await Category.updateMany(
      { storeId, $or: [{ ownerId: null }, { ownerId: { $exists: false } }] },
      { $set: { ownerId } }
    );
    res.json({ fixed: result.modifiedCount });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
