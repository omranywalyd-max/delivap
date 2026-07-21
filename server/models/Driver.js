const mongoose = require('mongoose');

const driverSchema = new mongoose.Schema({
  uid: { type: String, unique: true },
  firstName: String,
  lastName: String,
  phone: String,
  email: String,
  photoUrl: { type: String, default: '' },
  gender: String,
  fcmToken: String,
  isOnline: { type: Boolean, default: false },
  isActive: { type: Boolean, default: true },
  isVerified: { type: Boolean, default: false },
  canSetPricing: { type: Boolean, default: false },
  hasSetPricing: { type: Boolean, default: false },
  canUploadPhoto: { type: Boolean, default: false },
  vehicleType: String,
  cityNameAr: String,
  cityNameFr: String,
  cityName: String,
  cityLat: Number,
  cityLng: Number,
  lat: Number,
  lng: Number,
  lastLocationUpdate: Date,
  deliveryConfig: mongoose.Schema.Types.Mixed,
  totalEarnings: { type: Number, default: 0 },
  totalDeliveries: { type: Number, default: 0 },
  cancelledDeliveries: { type: Number, default: 0 },
  cash: { type: Number, default: 0 },
  hold: { type: Number, default: 0 },
  commission: { type: Number, default: 0 },
  discount: { type: Number, default: 0 },
  lastCommissionResetEarnings: { type: Number, default: 0 },
  commissionPercent: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

driverSchema.index({ isOnline: 1, isActive: 1 });
driverSchema.index({ fcmToken: 1 });

module.exports = mongoose.model('Driver', driverSchema, 'drivers');
