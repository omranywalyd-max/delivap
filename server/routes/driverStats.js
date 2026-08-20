const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Driver = require('../models/Driver');
const User = require('../models/User');
const { tokenIdentities, resolveUserFromReq } = require('../middleware/authorize');

// helper: find driver by _id or uid
async function findDriver(id) {
  let driver;
  if (mongoose.Types.ObjectId.isValid(id)) {
    driver = await Driver.findById(id);
  }
  if (!driver) {
    driver = await Driver.findOne({ uid: id });
  }
  return driver;
}

async function ownIds(req) {
  const ids = [...tokenIdentities(req)];
  const u = await resolveUserFromReq(req, User);
  if (u) {
    if (u.uid) ids.push(u.uid);
    if (u.username) ids.push(u.username);
  }
  return [...new Set(ids.map(String))];
}

async function isDriverSelf(req, driver) {
  if (req.user && req.user.role === 'admin') return true;
  if (!driver) return false;
  const ids = await ownIds(req);
  if (driver.uid && ids.includes(String(driver.uid))) return true;
  return false;
}

// Driver stats - compatibility with dashboard nested endpoint
router.get('/drivers/:id/stats', async (req, res) => {
  try {
    const driver = await findDriver(req.params.id);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    res.json(driver.stats || {});
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/drivers/:id/stats/:key', async (req, res) => {
  try {
    const driver = await findDriver(req.params.id);
    if (!driver) return res.status(404).json({ error: 'Driver not found' });
    if (!(await isDriverSelf(req, driver))) return res.status(403).json({ error: 'Forbidden' });
    if (!driver.stats) driver.stats = {};
    driver.stats[req.params.key] = req.body;
    driver.markModified('stats');
    await driver.save();
    res.json(driver.stats);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
