const mongoose = require('mongoose');

const favoriteSchema = new mongoose.Schema({
  userId: String,
  storeId: String,
  name: String,
  productIds: [String],
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Favorite', favoriteSchema, 'favorites');
