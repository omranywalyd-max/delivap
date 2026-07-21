const mongoose = require('mongoose');

const promotionSchema = new mongoose.Schema({
  storeId: String,
  storeName: String,
  templateName: String,
  title: String,        // ✅ رجعناها title كما Flutter
  description: String,
  image: String,
  price: Number,        // ✅ رجعناها price كما Flutter
  storeLat: Number,
  storeLng: Number,
  categorieId: String,
  categoryName: String,
  isActive: { type: Boolean, default: true }, // ✅ رجعناها isActive كما Flutter
  isDeleted: { type: Boolean, default: false },
  deletedAt: Date,
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Promotion', promotionSchema, 'promotions');