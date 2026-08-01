const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const ProjectDelivery = require('../models/ProjectDelivery');
const Driver = require('../models/Driver');
const { getIO } = require('../socket/ioInstance');
const { emitToUser, emitToDriver } = require('../socket');
const { sendToUser, sendToDriver } = require('../fcm');
const User = require('../models/User');
const Project = require('../models/Project');
const { deleteImageFile, deleteImageFiles } = require('../helpers/fileCleanup');

async function resolveDriverId(driverId) {
  if (mongoose.Types.ObjectId.isValid(driverId)) {
    const driver = await Driver.findById(driverId);
    if (driver && driver.uid) return driver.uid;
  }
  return driverId;
}

router.get('/project-deliveries', async (req, res) => {
  try {
    const filter = {};
    if (req.query.userId) filter.userId = req.query.userId;
    if (req.query.projectId) filter.projectId = req.query.projectId;
    if (req.query.driverId) filter.driverId = req.query.driverId;
    if (req.query.storeOwnerId) filter.storeOwnerId = req.query.storeOwnerId;
    if (req.query.status) {
      const statuses = req.query.status.split(',');
      filter.status = { $in: statuses };
    }
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const deliveries = await ProjectDelivery.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit);
    res.json(deliveries);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/project-deliveries/:id', async (req, res) => {
  try {
    const delivery = await ProjectDelivery.findById(req.params.id);
    if (!delivery) return res.status(404).json({ error: 'Delivery not found' });
    res.json(delivery);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/project-deliveries', async (req, res) => {
  try {
    const delivery = await ProjectDelivery.create({ ...req.body, status: 'pending' });
    const uid = delivery.driverId ? await resolveDriverId(delivery.driverId) : null;
    const io = getIO();
    if (io) {
      emitToUser(io, delivery.userId, 'delivery:created', delivery);
      emitToUser(io, delivery.userId, 'project_delivery:created', delivery);
      if (delivery.storeOwnerId) {
        io.to(`user_${delivery.storeOwnerId}`).emit('delivery:created', delivery.toObject());
        io.to(`user_${delivery.storeOwnerId}`).emit('project_delivery:created', delivery.toObject());
      }
      if (uid) {
        emitToDriver(io, uid, 'delivery:created', delivery);
        emitToDriver(io, uid, 'project_delivery:created', delivery);
      }
    }
    if (delivery.userId) {
      sendToUser({ userId: delivery.userId, title: '📦 تم إنشاء توصيلية مشروع', body: 'تم إنشاء طلب توصيل لمشروعك، يرجى انتظار السائق.', data: { deliveryId: delivery._id.toString(), type: 'delivery_created' } });
    }
    if (uid) {
      sendToDriver({ driverId: uid, title: '🚚 توصيلية مشروع جديدة', body: `توصيلية من ${delivery.storeName || ''} إلى ${delivery.customerName || ''} — ${delivery.deliveryPrice || 0} DA`, data: { deliveryId: delivery._id.toString(), type: 'delivery_assigned' } });
    }
    res.status(201).json(delivery);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// استجابة السائق: قبول / رفض / عرض سعر
router.put('/project-deliveries/:id/driver-response', async (req, res) => {
  try {
    const { action, reason, proposedPrice } = req.body;
    const delivery = await ProjectDelivery.findById(req.params.id);
    if (!delivery) return res.status(404).json({ error: 'Delivery not found' });
    const uid = delivery.driverId ? await resolveDriverId(delivery.driverId) : null;
    const io = getIO();

    if (action === 'accept') {
      delivery.status = 'accepted';
      delivery.acceptedAt = new Date();
      delivery.rejectedBy = [];
      await delivery.save();
      if (io) {
        emitToUser(io, delivery.userId, 'project_delivery:updated', delivery);
        if (delivery.storeOwnerId) io.to(`user_${delivery.storeOwnerId}`).emit('project_delivery:updated', delivery.toObject());
        if (uid) { emitToDriver(io, uid, 'project_delivery:updated', delivery); }
      }
      sendToUser({ userId: delivery.storeOwnerId, title: '✅ السائق قبل التوصيلية', body: `السائق ${delivery.driverName || ''} قبل توصيلية المشروع.`, data: { deliveryId: delivery._id.toString(), type: 'driver_accepted' } });
      if (delivery.userId) {
        sendToUser({ userId: delivery.userId, title: '✅ تم قبول توصيل مشروعك', body: `السائق ${delivery.driverName || ''} قبل توصيل مشروعك.`, data: { deliveryId: delivery._id.toString(), type: 'driver_accepted' } });
      }
    } else if (action === 'reject') {
      delivery.status = 'pending';
      delivery.driverId = undefined;
      delivery.driverName = undefined;
      delivery.rejectionReason = reason || '';
      await delivery.save();
      if (delivery.storeOwnerId) {
        const ownerUid = delivery.storeOwnerId;
        if (io) io.to(`user_${ownerUid}`).emit('project_delivery:updated', delivery.toObject());
        sendToUser({ userId: ownerUid, title: '❌ السائق رفض التوصيلية', body: `السائق رفض التوصيلية.${reason ? ' سبب: ' + reason : ''}`, data: { deliveryId: delivery._id.toString(), type: 'driver_rejected' } });
      }
      if (delivery.userId) {
        if (io) emitToUser(io, delivery.userId, 'project_delivery:updated', delivery);
      }
      // رجع المشروع للحالة الأولى
      if (delivery.projectId) {
        await Project.findByIdAndUpdate(delivery.projectId, { status: 'pending' });
        const project = await Project.findById(delivery.projectId);
        if (io && project && delivery.storeOwnerId) io.to(`user_${delivery.storeOwnerId}`).emit('project:updated', project.toObject());
      }
    } else if (action === 'counter') {
      delivery.counterOffer = {
        status: 'pending',
        driverId: delivery.driverId,
        driverName: delivery.driverName,
        proposedPrice: proposedPrice || delivery.deliveryPrice,
      };
      await delivery.save();
      if (delivery.storeOwnerId) {
        if (io) io.to(`user_${delivery.storeOwnerId}`).emit('project_delivery:updated', delivery.toObject());
        sendToUser({ userId: delivery.storeOwnerId, title: '💰 السائق اقترح سعر جديد', body: `${delivery.driverName || ''} اقترح ${proposedPrice || delivery.deliveryPrice} DA بدلاً من ${delivery.deliveryPrice} DA`, data: { deliveryId: delivery._id.toString(), type: 'counter_offer' } });
      }
    }
    res.json(delivery);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// رد صاحبة المشروع على عرض السعر
router.put('/project-deliveries/:id/owner-price-response', async (req, res) => {
  try {
    const { action } = req.body;
    const delivery = await ProjectDelivery.findById(req.params.id);
    if (!delivery) return res.status(404).json({ error: 'Delivery not found' });
    const uid = delivery.driverId ? await resolveDriverId(delivery.driverId) : null;
    const io = getIO();

    if (action === 'accept') {
      delivery.deliveryPrice = delivery.counterOffer?.proposedPrice || delivery.deliveryPrice;
      delivery.totalPrice = delivery.deliveryPrice + (delivery.productPrice || 0);
      delivery.counterOffer.status = 'accepted';
      delivery.status = 'accepted';
      delivery.acceptedAt = new Date();
      await delivery.save();
      if (uid) {
        if (io) emitToDriver(io, uid, 'project_delivery:updated', delivery);
        sendToDriver({ driverId: uid, title: '💰 صاحبة المشروع قبلت عرض السعر', body: 'قبلت السعر الجديد، تقدر تبدا التوصيل.', data: { deliveryId: delivery._id.toString(), type: 'counter_offer_accepted' } });
      }
      if (delivery.storeOwnerId && io) io.to(`user_${delivery.storeOwnerId}`).emit('project_delivery:updated', delivery.toObject());
    } else if (action === 'reject') {
      delivery.counterOffer.status = 'rejected';
      delivery.driverId = undefined;
      delivery.driverName = undefined;
      await delivery.save();
      if (uid) {
        sendToDriver({ driverId: uid, title: '❌ تم رفض عرض السعر', body: 'صاحبة المشروع رفضت عرض السعر.', data: { deliveryId: delivery._id.toString(), type: 'counter_offer_rejected' } });
      }
      if (delivery.storeOwnerId && io) io.to(`user_${delivery.storeOwnerId}`).emit('project_delivery:updated', delivery.toObject());
      if (delivery.projectId) {
        await Project.findByIdAndUpdate(delivery.projectId, { status: 'pending' });
        const project = await Project.findById(delivery.projectId);
        if (io && project && delivery.storeOwnerId) io.to(`user_${delivery.storeOwnerId}`).emit('project:updated', project.toObject());
      }
    }
    res.json(delivery);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/project-deliveries/:id', async (req, res) => {
  try {
    const old = await ProjectDelivery.findById(req.params.id);
    const updateBody = { ...req.body, updatedAt: new Date() };
    if (updateBody.status === 'accepted' && updateBody.driverId) {
      updateBody.rejectedBy = [];
    }
    const delivery = await ProjectDelivery.findByIdAndUpdate(
      req.params.id,
      updateBody,
      { returnDocument: 'after' }
    );
    if (!delivery) return res.status(404).json({ error: 'Delivery not found' });
    const uid = delivery.driverId ? await resolveDriverId(delivery.driverId) : null;
    const io = getIO();
    if (io) {
      emitToUser(io, delivery.userId, 'delivery:updated', delivery);
      emitToUser(io, delivery.userId, 'project_delivery:updated', delivery);
      if (delivery.storeOwnerId) {
        io.to(`user_${delivery.storeOwnerId}`).emit('delivery:updated', delivery.toObject());
        io.to(`user_${delivery.storeOwnerId}`).emit('project_delivery:updated', delivery.toObject());
      }
      if (uid) {
        emitToDriver(io, uid, 'delivery:updated', delivery);
        emitToDriver(io, uid, 'project_delivery:updated', delivery);
      }
    }
    const oldStatus = old?.status;
    if (delivery.status === 'near_owner' && oldStatus !== 'near_owner') {
      if (delivery.storeOwnerId) sendToUser({ userId: delivery.storeOwnerId, title: '🛵 السائق وصل قريب', body: `${delivery.driverName || ''} قريب منك، اخرج لاستلام الطلبية.`, data: { deliveryId: delivery._id.toString(), type: 'driver_near_owner' } });
    } else if (delivery.status === 'picked_up' && oldStatus !== 'picked_up') {
      sendToUser({ userId: delivery.userId, title: '📦 تم استلام الطلبية', body: 'السائق استلم الطلبية من صاحبة المشروع وهو في الطريق إليك.', data: { deliveryId: delivery._id.toString(), type: 'project_picked_up' } });
      if (delivery.storeOwnerId) sendToUser({ userId: delivery.storeOwnerId, title: '📦 تم استلام الطلبية', body: `${delivery.driverName || ''} استلم الطلبية منك.`, data: { deliveryId: delivery._id.toString(), type: 'project_picked_up_owner' } });
    } else if (delivery.status === 'in_transit' && oldStatus !== 'in_transit') {
      sendToUser({ userId: delivery.userId, title: '🚚 التوصيلية في الطريق', body: 'السائق انطلق وهو متجه إلى موقعك.', data: { deliveryId: delivery._id.toString(), type: 'delivery_onway' } });
    } else if (delivery.status === 'near_customer' && oldStatus !== 'near_customer') {
      sendToUser({ userId: delivery.userId, title: '🛵 السائق قريب منك', body: `${delivery.driverName || ''} قريب من موقعك، اخرج لاستلام طلبك.`, data: { deliveryId: delivery._id.toString(), type: 'driver_near_customer' } });
    } else if (delivery.status === 'delivered' && oldStatus !== 'delivered') {
      sendToUser({ userId: delivery.userId, title: '✅ تم توصيل مشروعك', body: 'السائق سلم مشروعك بنجاح. شكراً لتعاملك معنا!', data: { deliveryId: delivery._id.toString(), type: 'delivery_delivered' } });
      if (delivery.storeOwnerId) sendToUser({ userId: delivery.storeOwnerId, title: '✅ تم توصيل المشروع للزبون', body: `السائق ${delivery.driverName || ''} سلم المشروع للزبون بنجاح.`, data: { deliveryId: delivery._id.toString(), type: 'delivery_delivered_owner' } });
      if (delivery.driverId) {
        try {
          const fee = delivery.deliveryPrice || 0;
          let driver = await Driver.findOne({ uid: delivery.driverId });
          if (!driver && mongoose.Types.ObjectId.isValid(delivery.driverId)) {
            driver = await Driver.findById(delivery.driverId);
          }
          if (driver) {
            driver.totalEarnings = (driver.totalEarnings || 0) + fee;
            driver.totalDeliveries = (driver.totalDeliveries || 0) + 1;
            driver.cash = (driver.cash || 0) + fee;
            await driver.save();
            const io = getIO();
            const uid = driver.uid || delivery.driverId;
            if (io) emitToDriver(io, uid, 'driver:updated', driver);
          }
        } catch (drvErr) {
          console.error('Project delivery driver earnings error:', drvErr.message);
        }
      }
      deleteImageFile(delivery.imageUrl);
    } else if (delivery.status === 'rejected' && oldStatus !== 'rejected') {
      sendToUser({ userId: delivery.userId, title: '❌ تم رفض توصيلية المشروع', body: 'تم رفض توصيلية مشروعك، يرجى التواصل مع الدعم.', data: { deliveryId: delivery._id.toString(), type: 'delivery_rejected' } });
      if (uid) sendToDriver({ driverId: uid, title: '❌ تم رفض التوصيلية', body: 'تم رفض توصيلية المشروع.', data: { deliveryId: delivery._id.toString(), type: 'delivery_rejected' } });
      if (delivery.storeOwnerId) sendToUser({ userId: delivery.storeOwnerId, title: '❌ تم رفض التوصيلية', body: 'تم رفض توصيلية المشروع.', data: { deliveryId: delivery._id.toString(), type: 'delivery_rejected_owner' } });
    }
    const oldCounterOffer = old?.counterOffer;
    if (delivery.counterOffer?.status === 'accepted' && oldCounterOffer?.status !== 'accepted' && uid) {
      sendToDriver({ driverId: uid, title: '💰 تم قبول عرض السعر', body: 'الزبون قبل العرض الجديد.', data: { deliveryId: delivery._id.toString(), type: 'counter_offer_accepted' } });
    }
    // إذا السائق رفض التوصيلية → نمسح driverId ونرجع project لـ pending باش صاحب المتجر يشوفها من novo
    const oldRejectedBy = old?.rejectedBy || [];
    const newReject = req.body.rejectedBy;
    if (newReject && !oldRejectedBy.includes(newReject)) {
      await ProjectDelivery.findByIdAndUpdate(req.params.id, {
        $unset: { driverId: '', driverName: '' }
      });
      const ownerUid = delivery.storeOwnerId;
      if (ownerUid) {
        const reason = req.body.rejectionReason ? `سبب الرفض: ${req.body.rejectionReason}` : '';
        sendToUser({ userId: ownerUid, title: '❌ السائق رفض التوصيلية', body: `السائق رفض توصيلية المشروع.${reason ? ' ' + reason : ''}`, data: { deliveryId: delivery._id.toString(), type: 'driver_rejected' } });
      }
      if (delivery.projectId && ownerUid) {
        await Project.findByIdAndUpdate(delivery.projectId, { status: 'pending' });
        const project = await Project.findById(delivery.projectId);
        const io = getIO();
        if (io && project) io.to(`user_${ownerUid}`).emit('project:updated', project.toObject());
      }
    }
    // إذا رفض صاحب المتجر السعر → نمسح driverId ونرجع project لـ pending
    if (delivery.counterOffer?.status === 'rejected' && oldCounterOffer?.status === 'pending') {
      await ProjectDelivery.findByIdAndUpdate(req.params.id, { $unset: { driverId: '', driverName: '' } });
      if (uid) sendToDriver({ driverId: uid, title: '❌ تم رفض عرض السعر', body: 'صاحب المتجر رفض عرض السعر المقترح.', data: { deliveryId: delivery._id.toString(), type: 'counter_offer_rejected' } });
      if (delivery.projectId && delivery.storeOwnerId) {
        await Project.findByIdAndUpdate(delivery.projectId, { status: 'pending' });
        const project = await Project.findById(delivery.projectId);
        const io = getIO();
        if (io && project) io.to(`user_${delivery.storeOwnerId}`).emit('project:updated', project.toObject());
      }
    }
    // إعادة تحميل التوصيلية بعد أي تعديلات
    const updated = await ProjectDelivery.findById(req.params.id);
    res.json(updated);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/project-deliveries/:id', async (req, res) => {
  try {
    await ProjectDelivery.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
