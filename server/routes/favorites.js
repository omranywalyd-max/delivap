const express = require('express');
const router = express.Router();
const Favorite = require('../models/Favorite');

router.get('/favorites', async (req, res) => {
  try {
    const filter = {};
    if (req.query.userId) filter.userId = req.query.userId;
    if (req.query.storeId) filter.storeId = req.query.storeId;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const faves = await Favorite.find(filter).skip(skip).limit(limit);
    res.json(faves);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/favorites', async (req, res) => {
  try {
    const fave = await Favorite.create(req.body);
    res.status(201).json(fave);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/favorites/:id', async (req, res) => {
  try {
    const fave = await Favorite.findByIdAndUpdate(req.params.id, req.body, { returnDocument: 'after' });
    res.json(fave);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/favorites/:id', async (req, res) => {
  try {
    await Favorite.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
