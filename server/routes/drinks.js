const express = require('express');
const router = express.Router();
const Drink = require('../models/Drink');

router.get('/drinks', async (req, res) => {
  try {
    const filter = {};
    if (req.query.storeId) filter.storeId = req.query.storeId;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const drinks = await Drink.find(filter).skip(skip).limit(limit);
    res.json(drinks);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/drinks', async (req, res) => {
  try {
    const drink = await Drink.create(req.body);
    res.status(201).json(drink);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/drinks/:id', async (req, res) => {
  try {
    const drink = await Drink.findByIdAndUpdate(req.params.id, req.body, { returnDocument: 'after' });
    res.json(drink);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/drinks/:id', async (req, res) => {
  try {
    await Drink.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
