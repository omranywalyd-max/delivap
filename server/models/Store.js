const mongoose = require('mongoose');

const storeSchema = new mongoose.Schema({
  nom: String,
  image: String,
  lat: Number,
  lng: Number,
  primaryColor: { type: String, default: '#5B0094' },
  showDistance: { type: Boolean, default: false },
  uiStyle: { type: Number, default: 1 },
  stylePizza: { type: Boolean, default: false },
  allowMultipleCategories: { type: Boolean, default: false },
  ville: String,
  templateId: String,
  ownerId: String,
  nm: { type: Number, default: 1 },
  savedFormulas: [String],
  totalEarnings: { type: Number, default: 0 },
  cash: { type: Number, default: 0 },
  commissionPercent: { type: Number, default: 0 },
  lastCommissionResetEarnings: { type: Number, default: 0 },
  totalCollected: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now },
  updatedAt: Date,
});

storeSchema.index({ ownerId: 1 });
storeSchema.index({ isActive: 1 });

module.exports = mongoose.model('Store', storeSchema, 'magasins');