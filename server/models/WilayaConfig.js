const mongoose = require('mongoose');

const wilayaConfigSchema = new mongoose.Schema({
  wilayaId: Number,
  cityName: String,
  cityNameAr: String,
  cityNameFr: String,
  basePrice: Number,
  baseDist: Number,
  extraDistPrice: Number,
  baseCats: Number,
  extraCatPrice: Number,
  updatedAt: Date,
}, { strict: false });

module.exports = mongoose.model('WilayaConfig', wilayaConfigSchema, 'wilaya_configs');
