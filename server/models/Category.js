const mongoose = require('mongoose');

const categorySchema = new mongoose.Schema({
  templateId: String,
  storeId: String,
  ownerId: String,
  nom: String,
  image: String,
  order: { type: Number, default: 0 },
  lat: Number,
  lng: Number,
  cash: { type: Number, default: 0 },
  totalEarnings: { type: Number, default: 0 },
  commissionPercent: { type: Number },
  lastCommissionResetEarnings: { type: Number, default: 0 },
  totalCollected: { type: Number, default: 0 },
});

module.exports = mongoose.model('Category', categorySchema, 'categories');
