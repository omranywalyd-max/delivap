const express = require('express');
const router = express.Router();
const Config = require('../models/Config');
const WilayaConfig = require('../models/WilayaConfig');
const authMiddleware = require('../middleware/auth');
const { requireAdmin } = require('../middleware/authorize');

router.get('/config', async (req, res) => {
  try {
    let config = await Config.findOne();
    if (!config) config = {};
    res.json(config);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/config', authMiddleware, requireAdmin, async (req, res) => {
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
    const filter = {};
    if (req.query.vehicleType) filter.vehicleType = req.query.vehicleType;
    const configs = await WilayaConfig.find(filter, 'cityName cityNameAr cityNameFr basePrice cityLat cityLng vehicleType');
    res.json(configs);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Wilaya by city name — matches any of cityName / cityNameAr / cityNameFr
// يدعم ?vehicleType= لإرجاع تسعيرة نوع مركبة معين فقط (كل مركبة ومدينتها وحدها)
router.get('/wilaya-configs/:cityName', async (req, res) => {
  try {
    const name = req.params.cityName.replace(/-/g, '_');
    const regex = new RegExp(name, 'i');
    const cityMatch = {
      $or: [
        { cityName: { $regex: regex } },
        { cityNameAr: { $regex: regex } },
        { cityNameFr: { $regex: regex } },
      ],
    };
    const vehicleType = req.query.vehicleType;
    if (vehicleType) {
      const wilaya = await WilayaConfig.findOne({ ...cityMatch, vehicleType });
      return res.json(wilaya);
    }
    // بدون نوع: نجرب تسعيرة الدراجة أولاً ثم أي تسعيرة (للتوافق مع البيانات القديمة)
    let wilaya = await WilayaConfig.findOne({ ...cityMatch, vehicleType: 'motorcycle' });
    if (!wilaya) wilaya = await WilayaConfig.findOne(cityMatch);
    res.json(wilaya);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/wilaya_configs/:cityName', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const name = req.params.cityName.replace(/-/g, '_');
    const regex = new RegExp(name, 'i');
    const cityMatch = {
      $or: [
        { cityName: { $regex: regex } },
        { cityNameAr: { $regex: regex } },
        { cityNameFr: { $regex: regex } },
      ],
    };
    const vehicleType = req.body.vehicleType || 'motorcycle';
    const wilaya = await WilayaConfig.findOneAndUpdate(
      { ...cityMatch, vehicleType },
      { ...req.body, vehicleType, updatedAt: new Date() },
      { returnDocument: 'after', upsert: true }
    );
    res.json(wilaya);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
