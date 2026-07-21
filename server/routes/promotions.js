const express = require('express');
const router = express.Router();
const Promotion = require('../models/Promotion');

router.get('/promotions', async (req, res) => {
  try {
    const filter = {};
    if (req.query.storeId) filter.storeId = req.query.storeId;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;

    // حذف تلقائي للعروض المحذوفة بعد 72 ساعة
    const cutoff = new Date(Date.now() - 72 * 60 * 60 * 1000);
    await Promotion.deleteMany({ isDeleted: true, deletedAt: { $lte: cutoff } });

    const promos = await Promotion.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit);
    res.json(promos);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/promotions', async (req, res) => {
  try {
    const promo = await Promotion.create(req.body);
    res.status(201).json(promo);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/promotions/:id', async (req, res) => {
  try {
    const promo = await Promotion.findByIdAndUpdate(req.params.id, req.body, { returnDocument: 'after' });
    res.json(promo);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/promotions/:id', async (req, res) => {
  try {
    await Promotion.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
