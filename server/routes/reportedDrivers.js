const express = require('express');
const router = express.Router();
const Report = require('../models/Report');
const { getIO } = require('../socket/ioInstance');

// Get all reports
router.get('/users/:uid/reportedDrivers', async (req, res) => {
  try {
    const reports = await Report.find({ userId: req.params.uid }).sort({ createdAt: -1 });
    res.json(reports);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Check if driver already reported by this user
router.get('/users/:uid/reportedDrivers/:driverId', async (req, res) => {
  try {
    const report = await Report.findOne({
      userId: req.params.uid,
      driverId: req.params.driverId
    });
    res.json({ reported: !!report, report });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Report a driver
router.post('/users/:uid/reportedDrivers', async (req, res) => {
  try {
    const report = await Report.create({
      ...req.body,
      userId: req.params.uid
    });
    const io = getIO();
    if (io) io.to('admin_room').emit('new_report', report.toObject());
    res.status(201).json(report);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
