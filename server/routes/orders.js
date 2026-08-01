const express = require('express');
const router = express.Router();
const Order = require('../models/Order');
const Driver = require('../models/Driver');
const User = require('../models/User');
const Store = require('../models/Store');
const Category = require('../models/Category');
const Product = require('../models/Product');
const { getIO } = require('../socket/ioInstance');
const { emitToUser, emitToDriver } = require('../socket');
const { sendToUser, sendToDriver } = require('../fcm');
const authMiddleware = require('../middleware/auth');

// ─── Public route: جلب طلبيات التاجر عبر المحلات (يقبل ownerId و storeId كـ query params) ───
router.get('/orders/by-store-owner', async (req, res) => {
  try {
    const uid = req.user?.uid || req.user?.user_id;
    const isAdmin = req.user?.role === 'admin';
    const ownerId = req.query.ownerId || req.query.uid || uid;
    const storeIdQ = req.query.storeId;

    if (!storeIdQ && !ownerId) {
      return res.status(400).json({ error: 'storeId or ownerId required' });
    }

    let storeIds = [];
    if (storeIdQ) {
      storeIds = [storeIdQ];
    } else {
      let stores = await Store.find({ ownerId }).select('_id');
      if (stores.length === 0 && ownerId !== uid) {
        const user = await User.findOne({ uid: ownerId });
        if (user) stores = await Store.find({ ownerId: user._id.toString() }).select('_id');
      }
      storeIds = stores.map(s => s._id.toString());
    }
    if (storeIds.length === 0) return res.json([]);

    let ownerCategoryIds = null;
    if (ownerId) {
      const ownerCats = await Category.find({ storeId: { $in: storeIds }, ownerId: ownerId }).select('_id');
      ownerCategoryIds = ownerCats.map(c => c._id.toString());
      if (ownerCategoryIds.length === 0) {
        const orphans = await Category.find({ storeId: { $in: storeIds }, $or: [{ ownerId: null }, { ownerId: { $exists: false } }] });
        if (orphans.length > 0) {
          await Category.updateMany({ _id: { $in: orphans.map(c => c._id) } }, { $set: { ownerId } });
          ownerCategoryIds = orphans.map(c => c._id.toString());
        }
      }
    }

    const filter = { $or: [
      { storeIds: { $in: storeIds } },
      { 'items.storeId': { $in: storeIds } },
    ] };

    if (ownerCategoryIds && ownerCategoryIds.length > 0) {
      filter.$and = [
        { 'items.categorieId': { $in: ownerCategoryIds } }
      ];
    }

    const statusFilter = req.query.status;
    if (statusFilter) {
      const statuses = statusFilter.split(',');
      filter.status = { $in: statuses };
    }
    const limit = Math.min(parseInt(req.query.limit) || 100, 200);
    const skip = parseInt(req.query.skip) || 0;
    const orders = await Order.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit);
    res.json(orders);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.use(authMiddleware);

router.post('/orders', async (req, res) => {
  try {
    req.body.userId = req.user.uid || req.user.user_id;
    const User = require('../models/User');
    const userDoc = await User.findOne({ uid: req.body.userId });
    if (!userDoc) return res.status(404).json({ error: 'User not found' });
    req.body.userPhoneHidden = userDoc?.phoneHidden === true;
    req.body.phoneHidden = userDoc?.phoneHidden === true;

    // ربط كل منتج بالـ categorieId بتاعه
    if (req.body.items && req.body.items.length > 0) {
      const Category = require('../models/Category');
      const catById = {};
      const catIds = [...new Set((req.body.items || []).map(i => i.categorieId).filter(Boolean))];
      if (catIds.length > 0) {
        const cats = await Category.find({ _id: { $in: catIds } }, 'nom lat lng address');
        cats.forEach(c => { catById[c._id.toString()] = c; });
      }
      for (const item of req.body.items) {
        if (item.productId) {
          try {
            const parts = item.productId.split('_');
            let baseId = parts[0];
            // المشروبات: drink_<drinkId>_<flavor>_<timestamp>
            if (baseId === 'drink' && parts.length >= 3) {
              baseId = parts[1];
            }
            // فقط إذا الـ baseId يشبه ObjectId صالح
            if (/^[0-9a-fA-F]{24}$/.test(baseId)) {
              const prod = await Product.findById(baseId);
              if (prod && prod.categorieId) {
                item.categorieId = prod.categorieId.toString();
                if (baseId !== item.productId) item.productId = baseId;
              }
              if (prod) {
                item.categoryName = prod.categorieNom || item.categoryName || '';
              }
            }
          } catch (_) {}
        } else if (item.name && item.storeId) {
          try {
            const prod = await Product.findOne({ name: item.name, storeId: item.storeId });
            if (prod) {
              item.productId = prod._id.toString();
              item.categorieId = prod.categorieId ? prod.categorieId.toString() : undefined;
              item.categoryName = prod.categorieNom || item.categoryName || '';
            }
          } catch (_) {}
        }
        // تعبئة اسم القسم وموقعه من قسم الزبون إذا كان ناقصاً
        if (item.categorieId) {
          const c = catById[item.categorieId.toString()];
          if (c) {
            if (!item.categoryName) item.categoryName = c.nom || '';
            if (!item.storeName) item.storeName = c.nom || '';
            if (!item.storeLat) item.storeLat = c.lat ?? undefined;
            if (!item.storeLng) item.storeLng = c.lng ?? undefined;
          }
        }
      }
    }

    // استخراج storeIds من الأصناف
    if (!req.body.storeIds || req.body.storeIds.length === 0) {
      const ids = [...new Set((req.body.items || []).map(i => i.storeId).filter(Boolean))];
      if (ids.length > 0) req.body.storeIds = ids;
    }

    const deleteAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const order = await Order.create({ ...req.body, createdAt: new Date(), deleteAt });
    const io = getIO();
    if (io) {
      emitToUser(io, order.userId, 'order:created', order);
      if (order.driverId) {
        emitToDriver(io, order.driverId, 'order:created', order);
        const customerName = order.userName || 'زبون';
        const productTotal = (order.items || []).reduce((sum, item) => {
          const price = item.finalPrice ?? item.price ?? item.prix ?? 0;
          const qty = item.quantity ?? 1;
          return sum + (price * qty);
        }, 0);
        const deliveryFee = order.deliveryFee || 0;
        sendToDriver({
          driverId: order.driverId,
          title: '📦 طلبية جديدة',
          body: `${customerName} — ${productTotal} DA + ${deliveryFee} DA توصيل`,
          data: { orderId: order._id.toString(), type: 'new_order' },
        }).catch(e => console.error('FCM order created error:', e.message));
      } else {
        // طلبية جديدة بدون سائق — نبثثها لكل السائقين المتصلين
        io.to('drivers').emit('order:created', order);
      }

    }
    res.status(201).json(order);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/orders', async (req, res) => {
  try {
    const uid = req.user.uid || req.user.user_id;
    const isAdmin = req.user.role === 'admin';
    console.log('[GET /orders] uid=%s query=%j isAdmin=%s', uid, { driverId: req.query.driverId, userId: req.query.userId, status: req.query.status }, isAdmin);
    if (req.query.userId && req.query.userId !== uid && !isAdmin) {
      return res.status(403).json({ error: 'غير مصرح' });
    }
    if (req.query.driverId && req.query.driverId !== uid && !isAdmin) {
      console.log('[GET /orders] FORBIDDEN: query.driverId=%s !== uid=%s', req.query.driverId, uid);
      return res.status(403).json({ error: 'غير مصرح' });
    }
    const filter = {};
    if (req.query.userId) filter.userId = req.query.userId;
    if (req.query.driverId) filter.driverId = req.query.driverId;
    if (req.query.status) {
      const statuses = req.query.status.split(',');
      filter.status = { $in: statuses };
    }
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const orders = await Order.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit);
    console.log('[GET /orders] filter=%j found=%d', filter, orders.length);
    res.json(orders);
  } catch (e) { console.error('[GET /orders] ERROR:', e.message); res.status(500).json({ error: e.message }); }
});

router.put('/orders/:id/alternative-response', async (req, res) => {
  try {
    const { itemName, accepted } = req.body;
    if (!itemName) return res.status(400).json({ error: 'itemName required' });
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    const item = order.items.find(i => i.name === itemName && i.purchaseStatus === 'unavailable');
    if (!item) return res.status(404).json({ error: 'Item not found' });
    if (accepted) {
      item.alternativeStatus = 'accepted';
      item.purchaseStatus = 'purchased';
      if (item.alternativePrice) item.finalPrice = item.alternativePrice;
      if (item.alternativeName) {
        item.name = item.alternativeName;
        if (item.alternativePrice) item.prix = item.alternativePrice;
      }
    } else {
      item.alternativeStatus = 'rejected';
    }
    let newSubtotal = 0;
    for (const i of order.items) {
      if (i.purchaseStatus === 'unavailable') continue;
      const p = i.finalPrice || i.price || i.prix || 0;
      newSubtotal += p * (i.quantity || 1);
    }
    order.subtotal = newSubtotal;
    order.total = newSubtotal + (order.deliveryFee || 0);
    order.updatedAt = new Date();
    await order.save();
    const io = getIO();
    if (io) {
      emitToUser(io, order.userId, 'order:updated', order);
      if (order.driverId) emitToDriver(io, order.driverId, 'order:updated', order);
    }
    res.json(order);
  } catch (e) { console.error('[ALT RESPONSE] ERROR:', e.message); res.status(500).json({ error: e.message }); }
});

router.get('/orders/:id', async (req, res) => {
  try {
    const uid = req.user.uid || req.user.user_id;
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    if (req.user.role !== 'admin' && order.userId !== uid && order.driverId !== uid) {
      return res.status(403).json({ error: 'غير مصرح' });
    }
    res.json(order);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/orders/:id', async (req, res) => {
  try {
    console.log('[PUT ORDER] id=' + req.params.id + ' body.items count=' + (req.body.items ? req.body.items.length : 'none') + ' body.items=' + JSON.stringify(req.body.items?.map(i => ({name:i.name, purchaseStatus:i.purchaseStatus, alternativeStatus:i.alternativeStatus, finalPrice:i.finalPrice, price:i.price, prix:i.prix}))));
    const uid = req.user.uid || req.user.user_id;
    if (req.user.role !== 'admin') {
      const existing = await Order.findById(req.params.id);
      if (!existing) return res.status(404).json({ error: 'Order not found' });
      if (existing.userId !== uid && existing.driverId !== uid) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
    }
    const old = await Order.findById(req.params.id);
    // If updating items, merge with existing items to preserve fields
    // like storeLat/storeLng/note that may not be sent by the driver
    if (req.body.items && old && old.items) {
      const oldByName = {};
      for (const item of old.items) {
        const key = item.name || `__idx_${old.items.indexOf(item)}`;
        oldByName[key] = item.toObject();
      }
      const clientUpdatesByName = {};
      const unnamedUpdates = [];
      for (const updatedItem of req.body.items) {
        if (updatedItem.name) {
          clientUpdatesByName[updatedItem.name] = updatedItem;
        } else {
          unnamedUpdates.push(updatedItem);
        }
      }
      for (const nu of unnamedUpdates) {
        for (const [k, v] of Object.entries(oldByName)) {
          if (v.purchaseStatus === 'unavailable' && v.alternativeStatus === 'pending' && !clientUpdatesByName[k]) {
            if (nu.alternativeStatus === 'accepted') {
              nu.purchaseStatus = 'purchased';
              nu.finalPrice = v.alternativePrice || v.prix || v.price || 0;
              nu.name = v.alternativeName || v.name;
              nu.prix = v.alternativePrice || v.prix || v.price || 0;
            }
            clientUpdatesByName[k] = nu;
            break;
          }
        }
      }
      const mergedItems = Object.entries(oldByName)
        .filter(([key]) => key in clientUpdatesByName)
        .map(([key, existingItem]) => {
          const update = clientUpdatesByName[key];
          return { ...existingItem, ...update };
        });
      // إضافة المنتجات الجديدة اللي زادها الزبون (غير موجودة في الطلبية القديمة)
      for (const [name, update] of Object.entries(clientUpdatesByName)) {
        if (!(name in oldByName)) {
          mergedItems.push(update);
        }
      }
      req.body.items = mergedItems;
    }
    // تعبئة اسم القسم (categoryName) وموقع القسم (storeLat/storeLng) للناقص
    if (req.body.items && req.body.items.length > 0) {
      const Category = require('../models/Category');
      const needCat = req.body.items.filter(i => (!i.categoryName || !i.storeLat || !i.storeLng) && (i.categorieId || i.storeId));
      const catIds = [...new Set(needCat.map(i => (i.categorieId || i.storeId).toString()))];
      if (catIds.length > 0) {
        const cats = await Category.find({ _id: { $in: catIds } }, 'nom lat lng address');
        const catMap = {};
        cats.forEach(c => { catMap[c._id.toString()] = c; });
        for (const item of needCat) {
          const c = catMap[(item.categorieId || item.storeId).toString()];
          if (!c) continue;
          if (!item.categoryName) item.categoryName = c.nom || '';
          if (!item.storeName) item.storeName = c.nom || '';
          if (!item.storeLat) item.storeLat = c.lat ?? undefined;
          if (!item.storeLng) item.storeLng = c.lng ?? undefined;
        }
      }
    }
    console.log('[PUT ORDER] AFTER MERGE items=' + JSON.stringify(req.body.items?.map(i => ({name:i.name, categoryName:i.categoryName, purchaseStatus:i.purchaseStatus, alternativeStatus:i.alternativeStatus, finalPrice:i.finalPrice}))));
    // Handle hiddenFor with $addToSet instead of overwrite
    const updateData = { ...req.body, updatedAt: new Date() };
    let hiddenForUser = null;
    if (req.body.hiddenFor && Array.isArray(req.body.hiddenFor)) {
      hiddenForUser = req.body.hiddenFor;
      delete updateData.hiddenFor;
    }
    const updateOps = { $set: updateData };
    if (hiddenForUser && hiddenForUser.length > 0) {
      updateOps.$addToSet = { hiddenFor: { $each: hiddenForUser } };
    }
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      updateOps,
      { returnDocument: 'after' }
    );
    if (!order) return res.status(404).json({ error: 'Order not found' });
    const io = getIO();
    if (io) {
      emitToUser(io, order.userId, 'order:updated', order);
      if (order.driverId) emitToDriver(io, order.driverId, 'order:updated', order);
    }
    const oldStatus = old?.status;
    if (order.status === 'accepted' && oldStatus !== 'accepted') {
      // حفظ موقع السائق الحالي في الطلبية عند القبول
      if (order.driverId) {
        try {
          const Driver = require('../models/Driver');
          const drv = await Driver.findOne({ uid: order.driverId });
          if (drv && drv.lat != null && drv.lng != null) {
            await Order.findByIdAndUpdate(order._id, { driverLat: drv.lat, driverLng: drv.lng });
            order.driverLat = drv.lat;
            order.driverLng = drv.lng;
          }
        } catch (_) {}
      }
      sendToUser({ userId: order.userId, title: '📦 تم قبول طلبك', body: 'سائق يقبل طلبيتك وهو في الطريق للمتجر.', data: { orderId: order._id.toString(), type: 'accepted' } });
      // إشعار للتاجر (جميع الإستايلات عدا 6 — المشاريع عندها نظامها الخاص)
      _notifyStoreOwners(order, '📦 تم قبول الطلبية', `السائق قبل الطلبية وهو في الطريق للمتجر.`, 'accepted', order.driverId);
      // استهلاك هدية التوصيل عند قبول السائق
      if (order.isFreeDelivery && order.userId && order.driverId) {
        try {
          const User = require('../models/User');
          await User.updateOne(
            { uid: order.userId },
            { $set: { [`driverFreeDelivery.${order.driverId}`]: false } }
          );
        } catch (giftErr) {
          console.error('Gift consumption error:', giftErr.message);
        }
      }
    } else if (order.status === 'onway' && oldStatus !== 'onway') {
      sendToUser({ userId: order.userId, title: '🚚 الطلبية في الطريق', body: 'السائق انطلق وهو متجه إلى موقعك.', data: { orderId: order._id.toString(), type: 'onway' } });
    } else if (order.status === 'cancelled' && oldStatus !== 'cancelled') {
      // تم إلغاء الطلبية — لا أرباح للسائق ولا للزبون ولا للمحل
      sendToUser({ userId: order.userId, title: '❌ تم إلغاء الطلبية', body: req.body.cancelledByName ? 'تم إلغاء الطلبية من السائق.' : 'تم إلغاء الطلبية.', data: { orderId: order._id.toString(), type: 'order_cancelled' } });
      // إشعار للسائق إذا الإلغاء من الزبون
      if (order.driverId && req.body.cancelledBy && req.body.cancelledBy !== order.driverId) {
        sendToDriver({ driverId: order.driverId, title: '❌ تم إلغاء الطلبية', body: 'الزبون ألغى الطلبية.', data: { orderId: order._id.toString(), type: 'order_cancelled' } });
      }
      // إشعار للتاجر
      _notifyStoreOwners(order, '❌ تم إلغاء الطلبية', 'تم إلغاء الطلبية.', 'cancelled');
    }
    // إشعار للسائق عند موافقة أو رفض الزبون على البديل
    if (order.driverId && old && old.items && req.body.items) {
      for (let i = 0; i < old.items.length; i++) {
        const oldAltStatus = old.items[i]?.alternativeStatus;
        const newItem = req.body.items[i];
        if (!newItem) continue;
        if (oldAltStatus !== 'pending' && newItem.alternativeStatus === 'pending' && newItem.alternativeName) {
          let driverPhotoUrl = '';
          try {
            const driverDoc = await Driver.findOne({ uid: order.driverId });
            if (driverDoc && driverDoc.photoUrl) driverPhotoUrl = driverDoc.photoUrl;
          } catch (_) {}
          sendToUser({ userId: order.userId, title: '🔄 منتج بديل', body: `السائق لم يجد "${newItem.name}" وأرسل منتجاً بديلاً: "${newItem.alternativeName}" بسعر ${newItem.alternativePrice || 0} DZD`, data: { orderId: order._id.toString(), type: 'alternative_pending', sound: 'alternative', productName: newItem.name || '', productPrice: String(newItem.price || newItem.prix || 0), alternativeName: newItem.alternativeName || '', alternativePrice: String(newItem.alternativePrice || 0), driverName: order.driverName || 'السائق', driverPhoto: driverPhotoUrl } });
        } else if (oldAltStatus === 'pending' && newItem.alternativeStatus === 'accepted') {
          sendToDriver({ driverId: order.driverId, title: '✅ الزبون وافق على البديل', body: `الزبون وافق على المنتج البديل "${newItem.alternativeName || ''}" بسعر ${newItem.alternativePrice || 0} DZD`, data: { orderId: order._id.toString(), type: 'alternative_accepted' } });
        } else if (oldAltStatus === 'pending' && newItem.alternativeStatus === 'rejected') {
          sendToDriver({ driverId: order.driverId, title: '❌ الزبون رفض البديل', body: `الزبون رفض المنتج البديل "${newItem.alternativeName || ''}"`, data: { orderId: order._id.toString(), type: 'alternative_rejected' } });
        }
      }
    }
    if (order.status === 'delivered' && oldStatus !== 'delivered') {
      // إشعار عادي + overlay للتأكيد
      let driverPhotoUrl = '';
      try {
        const drv = await Driver.findOne({ uid: order.driverId });
        if (drv && drv.photoUrl) driverPhotoUrl = drv.photoUrl;
      } catch (_) {}
      sendToUser({ userId: order.userId, title: '🎉 تم توصيل طلبك بنجاح', body: 'شكراً لتعاملك معنا، نتمنى أن تكون الخدمة قد أعجبتك!', data: { orderId: order._id.toString(), type: 'delivered', sound: 'delivered', driverName: order.driverName || 'السائق', driverPhoto: driverPhotoUrl, driverId: order.driverId || '', itemCount: String((order.items || []).length) } });
      // إشعار للتاجر باكتمال التوصيل
      _notifyStoreOwners(order, '✅ تم توصيل الطلبية', 'السائق سلم الطلبية للزبون بنجاح.', 'delivered');
      // تجميع أرباح السائق
      if (order.driverId) {
        try {
          const fee = order.deliveryFee || 0;
          const driver = await Driver.findOne({ uid: order.driverId });
          if (driver) {
            driver.totalEarnings = (driver.totalEarnings || 0) + fee;
            driver.totalDeliveries = (driver.totalDeliveries || 0) + 1;
            driver.cash = (driver.cash || 0) + fee;
            await driver.save();
            const io = getIO();
            if (io) emitToDriver(io, order.driverId, 'driver:updated', driver);
          }
        } catch (drvErr) {
          console.error('Driver earnings update error:', drvErr.message);
        }
      }
      // تجميع أرباح صاحب المحل / الستايل + الزبون
      try {
        const items = order.items || [];
        const productTotal = items.reduce((sum, item) => {
          const price = (item.finalPrice ?? item.price ?? item.prix ?? 0);
          const qty = (item.quantity ?? 1);
          return sum + (price * qty);
        }, 0);
        if (productTotal > 0) {
          // 1. الزبون: سعر المنتجات يتجمع في حسابو
          const customer = await User.findOne({ uid: order.userId });
          if (customer) {
            customer.totalEarnings = (customer.totalEarnings || 0) + productTotal;
            customer.cash = (customer.cash || 0) + productTotal;
            await customer.save();
          }
          // 2. المحل: نلقاو صاحب المحل ولا الستايل
          const storeIds = order.storeIds && order.storeIds.length > 0
            ? order.storeIds
            : [...new Set((items || []).map(i => i.storeId).filter(Boolean))];
          for (const sId of storeIds) {
            const store = await Store.findById(sId);
            if (store) {
              const storeItems = items.filter(i => i.storeId == sId);
              const storeTotal = storeItems.reduce((sum, item) => {
                const price = (item.finalPrice ?? item.price ?? item.prix ?? 0);
                const qty = (item.quantity ?? 1);
                return sum + (price * qty);
              }, 0);
              if (storeTotal > 0) {
                store.totalEarnings = (store.totalEarnings || 0) + storeTotal;
                store.cash = (store.cash || 0) + storeTotal;
                await store.save();
                if (store.ownerId) {
                  const owner = await User.findById(store.ownerId);
                  if (owner) {
                    owner.totalEarnings = (owner.totalEarnings || 0) + storeTotal;
                    owner.cash = (owner.cash || 0) + storeTotal;
                    await owner.save();
                  }
                }
                // تجميع أرباح كل قسم على حدة
                for (const item of storeItems) {
                  let catId = item.categorieId;
                  if (!catId && item.productId) {
                    try {
                      const parts = item.productId.split('_');
                      let baseId = parts[0];
                      if (baseId === 'drink' && parts.length >= 3) {
                        baseId = parts[1];
                      }
                      if (/^[0-9a-fA-F]{24}$/.test(baseId)) {
                        const prod = await Product.findById(baseId);
                        if (prod) catId = prod.categorieId;
                      }
                    } catch (_) {}
                  }
                  if (catId) {
                    try {
                      const itemTotal = ((item.finalPrice ?? item.price ?? item.prix ?? 0)) * (item.quantity ?? 1);
                      const cat = await Category.findById(catId);
                      if (cat) {
                        cat.totalEarnings = (cat.totalEarnings || 0) + itemTotal;
                        cat.cash = (cat.cash || 0) + itemTotal;
                        await cat.save();
                      }
                    } catch (_) {}
                  }
                }
              }
            }
          }
        }
      } catch (earnErr) {
        console.error('Customer/store earnings update error:', earnErr.message);
      }
    }
    // إشعار للسائق عند قبول الزبون لعرض السعر
    const oldCounterOffer = old?.counterOffer;
    if (order.counterOffer?.status === 'accepted' && oldCounterOffer?.status !== 'accepted' && order.driverId) {
      sendToDriver({ driverId: order.driverId, title: '💰 تم قبول عرض السعر', body: 'الزبون قبل العرض الجديد.', data: { orderId: order._id.toString(), type: 'counter_offer_accepted' } });
    }
    // Driver app handles item-level FCM for purchased/unavailable
    res.json(order);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/orders/:id', async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'غير مصرح' });
    await Order.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Hide order for user
router.put('/orders/:id/hide', async (req, res) => {
  try {
    const uid = req.user.uid || req.user.user_id;
    if (req.user.role !== 'admin' && req.body.userId !== uid) {
      return res.status(403).json({ error: 'غير مصرح' });
    }
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { $addToSet: { hiddenFor: req.body.userId }, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    res.json(order);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ─── Helper: إشعار أصحاب المحلات ───
async function _notifyStoreOwners(order, title, body, type, skipDriverId) {
  try {
    const storeIds = order.storeIds && order.storeIds.length > 0
      ? order.storeIds
      : [...new Set((order.items || []).map(i => i.storeId).filter(Boolean))];
    if (storeIds.length === 0) return;
    const stores = await Store.find({ _id: { $in: storeIds } });
    for (const store of stores) {
      if (!store.ownerId) continue;
      // نحيد uiStyle 6 (المشاريع) لأن عندهم نظام خاص في projectDeliveries
      if ((store.uiStyle || 1) === 6) continue;
      const owner = await User.findById(store.ownerId);
      if (!owner || !owner.fcmToken) continue;
      // نحيد الإشعار لصاحب المتجر إلا كان هو را نفس السيك (كيقبل订单)
      if (skipDriverId && owner.uid === skipDriverId) continue;
      sendToUser({
        userId: owner.uid,
        title: title,
        body: body,
        data: { orderId: order._id.toString(), type, storeId: store._id.toString() },
      }).catch(e => console.error('FCM store owner notif error:', e.message));
      const io = getIO();
      if (io) {
        const roomId = owner.uid || owner._id.toString();
        io.to(`user_${roomId}`).emit('order:updated', order);
      }
    }
  } catch (e) {
    console.error('Store owner notification error:', e.message);
  }
}

module.exports = router;
