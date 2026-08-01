const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  storeId: String,
  name: String,
  prix: Number,
  price: Number,
  image: String,
  capacite: String,
  description: String,
  models: [mongoose.Schema.Types.Mixed],
  toppings: [mongoose.Schema.Types.Mixed],
  categorieNom: String,
  categorieId: String,
  sizes: [mongoose.Schema.Types.Mixed],
  extraImages: [String],
  variants: [mongoose.Schema.Types.Mixed],
  searchTags: [String],
  flavors: [mongoose.Schema.Types.Mixed],
   uiStyle: { type: Number, default: 1 },
   hasPiecePrice: { type: Boolean, default: false },
   pricePerPiece: { type: Number, default: 0 },
   order: { type: Number, default: 0 },
});

productSchema.index({ storeId: 1 });
productSchema.index({ storeId: 1, categorieId: 1 });

module.exports = mongoose.model('Product', productSchema, 'produits');
