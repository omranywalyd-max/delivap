const mongoose = require('mongoose');

const configSchema = new mongoose.Schema({
  key: String,
  value: mongoose.Schema.Types.Mixed,
}, { strict: false });

module.exports = mongoose.model('Config', configSchema, 'config');
