const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  uid: { type: String }, // حقول الزبون (Customer)
  firstName: String,
  lastName: String,
  // حقول التاجر (Merchant) - أضفناهم هنا
  username: String, 
  password: String, 
  storeName: String,
  role: { type: String, default: 'user' }, // 'user' أو 'owner' أو 'security'
  isActive: { type: Boolean, default: false }, // حالة التفعيل
  magasinId: String, // رابط المحل الحقيقي
  // حقول مشتركة
  cityName: String,
  phone: String,
  email: String,
  gender: String,
  location: String,
  photoUrl: String,
  isVerified: { type: Boolean, default: false },
  fcmToken: String,
  lastTokenUpdate: Date,
  isBanned: { type: Boolean, default: false },
  bannedIp: String,
  lastIp: String,
  hasFreeDelivery: { type: Boolean, default: false },
  phoneHidden: { type: Boolean, default: false },
  loyaltyCount: { type: Number, default: 0 },
  driverLoyalty: { type: Map, of: Number, default: {} },
  driverFreeDelivery: { type: Map, of: Boolean, default: {} },
  settings: {
    disableSound: { type: Boolean, default: false },
    disablePurchaseNotif: { type: Boolean, default: false },
    enableDriverArrivalRing: { type: Boolean, default: false },
  },
  totalEarnings: { type: Number, default: 0 },
  cash: { type: Number, default: 0 },
  commissionPercent: { type: Number, default: 0 },
  lastCommissionResetEarnings: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now },
});

userSchema.index({ uid: 1 }, { unique: true, sparse: true });
userSchema.index({ role: 1, isActive: 1 });
userSchema.index({ username: 1 });
userSchema.index({ fcmToken: 1 });

module.exports = mongoose.model('User', userSchema, 'users');