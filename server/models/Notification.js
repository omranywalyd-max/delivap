const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  toId: String,
  orderId: String,
  title: String,
  body: String,
  type: String,
  isRead: { type: Boolean, default: false },
  hiddenFor: [String],
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Notification', notificationSchema, 'notifications');
