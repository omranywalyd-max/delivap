const mongoose = require('mongoose');

const savedTemplateSchema = new mongoose.Schema({
  userId: String,
  templateName: String,
  items: [mongoose.Schema.Types.Mixed],
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('SavedTemplate', savedTemplateSchema, 'saved_templates');
