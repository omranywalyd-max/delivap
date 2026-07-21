const mongoose = require('mongoose');

const projectSchema = new mongoose.Schema({
  name: String,
  phone: String,
  description: String,
  capacite: String,
  location: String,
  userLat: Number,
  userLng: Number,
  storeId: String,
  storeName: String,
  storeLat: Number,
  storeLng: Number,
  userId: String,
  userEmail: String,
  imageUrl: String,
  extraImages: [String],
  productPrice: Number,
  quantity: Number,
  productId: String,
  status: { type: String, default: 'pending' },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Project', projectSchema, 'projects');
