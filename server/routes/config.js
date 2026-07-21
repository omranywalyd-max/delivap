const express = require('express');
const router = express.Router();
const Config = require('../models/Config');
const WilayaConfig = require('../models/WilayaConfig');

router.get('/config', async (req, res) => {
  try {
    let config = await Config.findOne();
    if (!config) config = {};
    res.json(config);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/config', async (req, res) => {
  try {
    const config = await Config.findOneAndUpdate(
      {},
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after', upsert: true }
    );
    res.json(config);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Wilaya
router.get('/wilaya', async (req, res) => {
  try {
    const wilaya = await WilayaConfig.find();
    res.json(wilaya);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Wilaya list (for city picker in customer app)
router.get('/wilaya-configs', async (req, res) => {
  try {
    const configs = await WilayaConfig.find({}, 'cityName cityNameAr cityNameFr basePrice cityLat cityLng');
    res.json(configs);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Wilaya by city name — matches any of cityName / cityNameAr / cityNameFr
router.get('/wilaya-configs/:cityName', async (req, res) => {
  try {
    const name = req.params.cityName.replace(/-/g, '_');
    const regex = new RegExp(name, 'i');
    const wilaya = await WilayaConfig.findOne({
      $or: [
        { cityName: { $regex: regex } },
        { cityNameAr: { $regex: regex } },
        { cityNameFr: { $regex: regex } },
      ],
    });
    res.json(wilaya);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/wilaya_configs/:cityName', async (req, res) => {
  try {
    const name = req.params.cityName.replace(/-/g, '_');
    const regex = new RegExp(name, 'i');
    const wilaya = await WilayaConfig.findOneAndUpdate(
      {
        $or: [
          { cityName: { $regex: regex } },
          { cityNameAr: { $regex: regex } },
          { cityNameFr: { $regex: regex } },
        ],
      },
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after', upsert: true }
    );
    res.json(wilaya);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
