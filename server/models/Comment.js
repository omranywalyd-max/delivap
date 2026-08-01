const mongoose = require('mongoose');

const replySchema = new mongoose.Schema({
  userId: String,
  userName: String,
  userPhoto: String,
  userGender: String,
  text: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
});

const commentSchema = new mongoose.Schema({
  driverId: String,
  userId: String,
  userName: String,
  userPhoto: String,
  userGender: String,
  text: String,
  replies: [replySchema],
  createdAt: { type: Date, default: Date.now },
  updatedAt: Date,
});

module.exports = mongoose.model('Comment', commentSchema, 'comments');
