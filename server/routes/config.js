const express = require('express');
const router = express.Router();
const Config = require('../models/Config');
const WilayaConfig = require('../models/WilayaConfig');
const authMiddleware = require('../middleware/auth');
const { requireAdmin, requireAdminOrPricingDriver } = require('../middleware/authorize');

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

router.put('/wilaya_configs/:cityName', authMiddleware, requireAdminOrPricingDriver, async (req, res) => {
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

// ── Force update config (public, no auth) ──
// ترجع أدنى رقم build مطلوب + رابط التحديث لكل تطبيق.
// الأولوية لمخزون MongoDB (يعدل من لوحة التحكم) ثم .env كقيمة افتراضية.
router.get('/app/config', async (req, res) => {
  try {
    let versions = {};
    try {
      const doc = await Config.findOne();
      if (doc) versions = doc.get('appVersions') || {};
    } catch (_) {}
    const v = versions.customer || {};
    const d = versions.driver || {};
    res.json({
      customer: {
        minBuild: v.minBuild != null ? parseInt(v.minBuild, 10) : parseInt(process.env.MIN_BUILD_CUSTOMER || '0', 10),
        latestVersion: v.latestVersion ?? process.env.LATEST_VERSION_CUSTOMER ?? '',
        updateUrl: v.updateUrl ?? (process.env.UPDATE_URL_CUSTOMER ||
          'https://play.google.com/store/apps/details?id=com.deliv.customer'),
      },
      driver: {
        minBuild: d.minBuild != null ? parseInt(d.minBuild, 10) : parseInt(process.env.MIN_BUILD_DRIVER || '0', 10),
        latestVersion: d.latestVersion ?? process.env.LATEST_VERSION_DRIVER ?? '',
        updateUrl: d.updateUrl ?? (process.env.UPDATE_URL_DRIVER ||
          'https://play.google.com/store/apps/details?id=com.deliv.driver'),
      },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── تحديث النسخة الإلزامية من لوحة التحكم (admin only) ──
// body: { app: 'customer' | 'driver', minBuild: 25, latestVersion: '1.2.0', updateUrl: '...' }
router.put('/app/config', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { app, minBuild, latestVersion, updateUrl } = req.body;
    if (app !== 'customer' && app !== 'driver') {
      return res.status(400).json({ error: 'app must be customer or driver' });
    }
    let doc = await Config.findOne();
    if (!doc) doc = new Config({});
    const versions = doc.get('appVersions') || {};
    const current = versions[app] || {};
    versions[app] = {
      minBuild: minBuild != null ? parseInt(minBuild, 10) : current.minBuild,
      latestVersion: latestVersion || current.latestVersion,
      updateUrl: updateUrl || current.updateUrl,
    };
    doc.set('appVersions', versions);
    doc.set('updatedAt', new Date());
    await doc.save();
    res.json(versions[app]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
