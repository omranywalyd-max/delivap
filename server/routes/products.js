const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Product = require('../models/Product');
const Store = require('../models/Store');
const fs = require('fs');
const path = require('path');

function deleteImageFile(url) {
  if (!url || !url.includes('/uploads/')) return;
  const filename = url.split('/uploads/').pop();
  if (!filename) return;
  const filePath = path.join(__dirname, '..', 'uploads', filename);
  try { if (fs.existsSync(filePath)) fs.unlinkSync(filePath); } catch (_) {}
}

router.get('/products', async (req, res) => {
  try {
    const match = {};
    if (req.query.storeId) match.storeId = req.query.storeId;
    if (req.query.categorieId) match.categorieId = req.query.categorieId;
    if (req.query.search) {
      const s = req.query.search.toLowerCase();
      match.$or = [
        { name: { $regex: s, $options: 'i' } },
        { searchTags: { $regex: s, $options: 'i' } }
      ];
    }
    if (req.query.searchTags) {
      const s = req.query.searchTags.toLowerCase();
      match.searchTags = { $regex: s, $options: 'i' };
    }
    if (req.query.name) {
      match.name = { $regex: req.query.name, $options: 'i' };
    }
    if (req.query.active) match.active = req.query.active === 'true';
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    if (req.query.lastId && mongoose.Types.ObjectId.isValid(req.query.lastId)) {
      match._id = { $lt: new mongoose.Types.ObjectId(req.query.lastId) };
    }

    const projection = { searchTags: 0 };
    const products = await Product.find(match, projection).sort({ _id: -1 }).skip(skip).limit(limit);
    const storeIds = [...new Set(products.map(p => p.storeId).filter(Boolean))];
    const storeMap = {};
    if (storeIds.length > 0) {
      const stores = await Store.find({ _id: { $in: storeIds } }, 'uiStyle nom');
      stores.forEach(s => { storeMap[s._id.toString()] = { uiStyle: s.uiStyle ?? 1, nom: s.nom ?? '' }; });
    }
    const enriched = products.map(p => {
      const pObj = p.toObject();
      const storeInfo = storeMap[p.storeId] || {};
      pObj.uiStyle = storeInfo.uiStyle ?? 1;
      pObj.storeName = storeInfo.nom || pObj.storeName || '';
      return pObj;
    });
    res.json(enriched);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/products/:id', async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    res.json(product);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/products', async (req, res) => {
  try {
    const product = await Product.create(req.body);
    res.status(201).json(product);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/products/:id', async (req, res) => {
  try {
    // حذف الصورة القديمة إذا تغيرت
    if (req.body.image) {
      const old = await Product.findById(req.params.id);
      if (old && old.image && old.image !== req.body.image) {
        deleteImageFile(old.image);
      }
    }
    const product = await Product.findByIdAndUpdate(
      req.params.id,
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    res.json(product);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/products/:id', async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (product) {
      deleteImageFile(product.image);
      if (product.extraImages && Array.isArray(product.extraImages)) {
        for (const img of product.extraImages) {
          if (typeof img === 'string') deleteImageFile(img);
        }
      }
    }
    await Product.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
