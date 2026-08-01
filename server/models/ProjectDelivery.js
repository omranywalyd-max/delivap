const mongoose = require('mongoose');

const projectDeliverySchema = new mongoose.Schema({
  projectId: String,
  storeId: String,
  storeName: String,
  storeOwnerId: String,
  customerName: String,
  customerPhone: String,
  customerAddress: String,
  customerLat: Number,
  customerLng: Number,
  description: String,
  imageUrl: String,
  userId: String,
  deliveryPrice: Number,
  productPrice: Number,
  totalPrice: Number,
  storeLat: Number,
  storeLng: Number,
  storeAddress: String,
  driverId: String,
  driverName: String,
  status: { type: String, default: 'pending' },
  rejectedBy: [String],
  rejectionReason: String,
  counterOffer: {
    status: String,
    driverId: String,
    proposedPrice: Number,
    driverName: String,
  },
  createdAt: { type: Date, default: Date.now },
  acceptedAt: Date,
});

module.exports = mongoose.model('ProjectDelivery', projectDeliverySchema, 'project_deliveries');
