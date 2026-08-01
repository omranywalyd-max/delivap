const mongoose = require('mongoose');

const drinkSchema = new mongoose.Schema({
  storeId: String,
  name: String,
  flavors: [mongoose.Schema.Types.Mixed],
});

module.exports = mongoose.model('Drink', drinkSchema, 'drinks');
