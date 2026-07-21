const mongoose = require('mongoose');

const savedLocationSchema = new mongoose.Schema({
  userId: String,
  label: String,
  address: String,
  lat: Number,
  lng: Number,
  cityNameAr: String,
  cityNameFr: String,
  type: { type: String, default: 'other' },
  housingType: { type: String, default: 'منزل' },
  floor: { type: String, default: 'أرضي' },
  doorColor: String,
  doorNumber: String,
  locationImage: String,
  createdAt: { type: Date, default: Date.now },
  updatedAt: Date,
});

module.exports = mongoose.model('SavedLocation', savedLocationSchema, 'savedLocations');
