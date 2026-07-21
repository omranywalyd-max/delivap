const express = require('express');
const router = express.Router();
const Driver = require('../models/Driver');

// Driver stats - compatibility with dashboard nested endpoint
router.get('/drivers/:id/stats', async (req, res) => {
  try {
    const driver = await Driver.findById(req.params.id);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    res.json(driver.stats || {});
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/drivers/:id/stats/:key', async (req, res) => {
  try {
    const driver = await Driver.findById(req.params.id);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    if (!driver.stats) driver.stats = {};
    driver.stats[req.params.key] = req.body;
    driver.markModified('stats');
    await driver.save();
    res.json(driver.stats);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
