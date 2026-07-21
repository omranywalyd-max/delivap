const mongoose = require('mongoose');

const transportOrderSchema = new mongoose.Schema({
  userId: String,
  userName: String,
  userPhone: String,
  fromAddress: String,
  fromLat: Number,
  fromLng: Number,
  fromImage: String,
  toAddress: String,
  toLat: Number,
  toLng: Number,
  toImage: String,
  parcelImageUrl: String,
  note: String,
  price: Number,
  status: { type: String, default: 'pending' },
  driverId: String,
  driverName: String,
  transportType: String,
  cancelledBy: String,
  rejectedBy: [String],
  rejectionReason: String,
  counterOffer: {
    status: String,
    driverId: String,
    proposedPrice: Number,
    driverName: String,
  },
  orderId: String,
  createdAt: { type: Date, default: Date.now },
  updatedAt: Date,
});

module.exports = mongoose.model('TransportOrder', transportOrderSchema, 'transport_orders');
