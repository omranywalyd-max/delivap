const mongoose = require('mongoose');

const projectMessageSchema = new mongoose.Schema({
  projectId: { type: String, required: true, index: true },
  fromId: String,
  fromRole: { type: String, enum: ['customer', 'owner'], default: 'customer' },
  text: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('ProjectMessage', projectMessageSchema, 'project_messages');
