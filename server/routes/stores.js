const express = require('express');
const router = express.Router();
const Store = require('../models/Store');

router.get('/stores', async (req, res) => {
  try {
    const filter = {};
    if (req.query.ownerId === 'null') filter.ownerId = null;
    else if (req.query.ownerId) filter.ownerId = req.query.ownerId;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const stores = await Store.find(filter).sort({ nom: 1 }).skip(skip).limit(limit);
    res.json(stores);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/stores/:id', async (req, res) => {
  try {
    const store = await Store.findById(req.params.id);
    res.json(store);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/stores', async (req, res) => {
  try {
    const store = await Store.create(req.body);
    res.status(201).json(store);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/stores/:id', async (req, res) => {
  try {
    const store = await Store.findByIdAndUpdate(
      req.params.id,
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    res.json(store);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/stores/:id/formulas', async (req, res) => {
  try {
    const { formula } = req.body;
    if (!formula || formula.toString().trim().length === 0) {
      return res.status(400).json({ error: 'Formula cannot be empty' });
    }
    const store = await Store.findByIdAndUpdate(
      req.params.id,
      { $addToSet: { savedFormulas: formula.toString().trim() }, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    res.json(store);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/stores/:id/formulas', async (req, res) => {
  try {
    const formula = req.query.formula;
    if (!formula) return res.status(400).json({ error: 'Formula query param required' });
    const store = await Store.findByIdAndUpdate(
      req.params.id,
      { $pull: { savedFormulas: formula } },
      { returnDocument: 'after' }
    );
    res.json(store);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/stores/:id', async (req, res) => {
  try {
    await Store.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
