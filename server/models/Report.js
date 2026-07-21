const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  type: { type: String, default: 'driver_report' }, // 'driver_report', 'customer_report', 'comment_report'
  driverId: String,
  driverName: String,
  userId: String,
  userName: String,
  ownerId: String,
  ownerName: String,
  orderId: String,
  // حقول البلاغ على تعليق
  commentId: String,
  commentText: String,
  commentAuthorId: String,
  commentAuthorName: String,
  reason: String,
  note: String,
  status: { type: String, default: 'pending' },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Report', reportSchema, 'reports_driver');
