const mongoose = require('mongoose');

const serviceOrderSchema = new mongoose.Schema({
  userId: String,
  userName: String,
  userPhone: String,
  serviceType: String,
  fromAddress: String,
  fromLat: Number,
  fromLng: Number,
  toAddress: String,
  toLat: Number,
  toLng: Number,
  orderName: String,
  note: String,
  price: Number,
  parcelImageUrl: String,
  status: { type: String, default: 'pending' },
  driverId: String,
  driverName: String,
  cancelledBy: String,
  rejectedBy: [String],
  rejectionReason: String,
  orderId: String,
  counterOffer: {
    status: String,
    driverId: String,
    proposedPrice: Number,
    driverName: String,
  },
  createdAt: { type: Date, default: Date.now },
  updatedAt: Date,
});

module.exports = mongoose.model('ServiceOrder', serviceOrderSchema, 'service_orders');
