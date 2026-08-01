const mongoose = require('mongoose');

const settlementSchema = new mongoose.Schema({
  driverId: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver' },
  driverName: { type: String, default: '' },
  vehicleType: { type: String, default: '' },
  userId: { type: String, default: '' },
  storeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Store', default: null },
  targetType: { type: String, default: 'driver' },
  targetName: { type: String, default: '' },
  earningsBefore: { type: Number, default: 0 },
  earningsAfter: { type: Number, default: 0 },
  commissionPercent: { type: Number, default: 0 },
  commissionAmount: { type: Number, default: 0 },
  discount: { type: Number, default: 0 },
  cashAtSettlement: { type: Number, default: 0 },
  amountCollected: { type: Number, default: 0 },
  paymentMethod: { type: String, default: 'cash' },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Settlement', settlementSchema, 'settlements');
