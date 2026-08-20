const express = require('express');
const router = express.Router();
const Project = require('../models/Project');
const ProjectMessage = require('../models/ProjectMessage');
const User = require('../models/User');
const { getIO } = require('../socket/ioInstance');
const { sendToUser } = require('../fcm');
const { tokenIdentities, resolveUserFromReq } = require('../middleware/authorize');

// هل الطالب يملك المشروع (زبونه، تاجر المحل، أو أدمن)؟
async function canManageProject(req, project, User) {
  if (req.user && req.user.role === 'admin') return true;
  const ids = tokenIdentities(req);
  if (ids.length && project.userId && ids.includes(String(project.userId))) return true;
  const u = await resolveUserFromReq(req, User);
  if (!u) return false;
  if (project.userId && u.uid === project.userId) return true;
  if ((u.role === 'owner' || u.role === 'merchant') && project.storeId && u.magasinId === project.storeId) return true;
  return false;
}

router.get('/projects', async (req, res) => {
  try {
    const filter = {};
    if (req.query.userId) filter.userId = req.query.userId;
    if (req.query.storeId) filter.storeId = req.query.storeId;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const skip = parseInt(req.query.skip) || 0;
    const projects = await Project.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit);
    res.json(projects);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// عدد الرسائل غير المقروءة لكل مشاريع الطالب (زبون أو صاحب مشروع)
router.get('/projects/unread-count', async (req, res) => {
  try {
    const u = await resolveUserFromReq(req, User);
    if (!u) return res.status(401).json({ error: 'Unauthorized' });
    const isOwner = (u.role === 'owner' || u.role === 'merchant') && !!u.magasinId;
    const filter = isOwner ? { storeId: u.magasinId } : { userId: u.uid };
    const projects = await Project.find(filter)
      .select('_id unreadCustomer unreadOwner')
      .lean();
    const items = projects
      .map((p) => ({
        projectId: String(p._id),
        unread: isOwner ? (p.unreadOwner || 0) : (p.unreadCustomer || 0),
      }))
      .filter((x) => x.unread > 0);
    const total = items.reduce((a, b) => a + b.unread, 0);
    res.json({ total, items });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.get('/projects/:id', async (req, res) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ error: 'Project not found' });
    res.json(project);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.post('/projects', async (req, res) => {
  try {
    // منع تزوير الملكية: الزبون يسجل مشروعه باسمه هو فقط (الأدمن مخول)
    if (req.user && req.user.role !== 'admin') {
      const ids = tokenIdentities(req);
      const udoc = await resolveUserFromReq(req, User);
      if (req.body.userId) {
        const allowed = ids.includes(String(req.body.userId)) ||
          (udoc && (udoc.uid === req.body.userId || udoc.username === req.body.userId));
        if (!allowed) return res.status(403).json({ error: 'Forbidden' });
      } else if (udoc && udoc.uid) {
        req.body.userId = udoc.uid;
      }
    }
    const project = await Project.create(req.body);
    const storeId = req.body.storeId || project.storeId;
    if (storeId) {
      const owner = await User.findOne({ role: 'owner', magasinId: storeId });
      if (owner && owner.uid) {
        const io = getIO();
        if (io) io.to(`user_${owner.uid}`).emit('project:created', project.toObject());
        if (owner.fcmToken) {
          await sendToUser({
            userId: owner.uid,
            title: '📦 طلب مشروع جديد',
            body: `لديك طلب مشروع جديد من ${req.body.name || 'زبون'}`,
            data: { projectId: project._id.toString(), type: 'project_created' },
          });
        }
      }
    }
    res.status(201).json(project);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.put('/projects/:id', async (req, res) => {
  try {
    const existing = await Project.findById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Project not found' });
    if (!(await canManageProject(req, existing, User))) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    const project = await Project.findByIdAndUpdate(
      req.params.id,
      { ...req.body, updatedAt: new Date() },
      { returnDocument: 'after' }
    );
    if (!project) return res.status(404).json({ error: 'Project not found' });
    const io = getIO();
    if (req.body.status === 'rejected') {
      const userId = project.userId;
      if (userId) {
        if (io) io.to(`user_${userId}`).emit('project:updated', project.toObject());
        const reason = req.body.rejectReason || '';
        await sendToUser({
          userId,
          title: '❌ تم رفض طلب المشروع',
          body: reason ? `سبب الرفض: ${reason}` : 'تم رفض طلب مشروعك من قبل التاجر.',
          data: { projectId: project._id.toString(), type: 'project_rejected' },
        });
      }
    } else if (project && req.body.status === 'processing') {
      const userId = project.userId;
      if (userId) {
        if (io) io.to(`user_${userId}`).emit('project:updated', project.toObject());
      }
    }
    res.json(project);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

router.delete('/projects/:id', async (req, res) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ error: 'Project not found' });
    if (!(await canManageProject(req, project, User))) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    await Project.findByIdAndDelete(req.params.id);
    res.json({ deleted: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── محادثة صاحب المشروع ↔ الزبون ────────────────────────────────
const CLOSED_STATUSES = ['completed', 'cancelled', 'delivered'];

// هل الطالب طرف في هذه المحادثة؟ (الزبون، صاحب المحل، أو أدمن)
async function canChat(req, project) {
  if (await canManageProject(req, project, User)) return true;
  const u = await resolveUserFromReq(req, User);
  if (!u) return false;
  if (project.storeId && u.magasinId === project.storeId) return true;
  return false;
}

// يعيد كائن { customerId, ownerId } لطرفي المحادثة
async function chatParticipants(project) {
  let customerId = project.userId || null;
  let ownerId = null;
  if (project.storeId) {
    const owner = await User.findOne({ role: 'owner', magasinId: project.storeId });
    if (owner && owner.uid) ownerId = owner.uid;
  }
  return { customerId, ownerId };
}

// دور الطالب في هذه المحادثة: 'owner' | 'customer' | null
async function requesterRole(req, project) {
  const u = await resolveUserFromReq(req, User);
  if (!u) return null;
  if ((u.role === 'owner' || u.role === 'merchant') && project.storeId && u.magasinId === project.storeId) return 'owner';
  if (project.userId && (u.uid === project.userId || String(u._id) === String(project.userId))) return 'customer';
  return null;
}

// جلب رسائل المشروع (فقط للطرفين أو الأدمن) — يصفّر العداد غير المقروء للطالب
router.get('/projects/:id/messages', async (req, res) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ error: 'Project not found' });
    if (!(await canChat(req, project))) return res.status(403).json({ error: 'Forbidden' });
    const role = await requesterRole(req, project);
    if (role === 'owner') {
      await Project.findByIdAndUpdate(req.params.id, { $set: { unreadOwner: 0 } });
    } else if (role === 'customer') {
      await Project.findByIdAndUpdate(req.params.id, { $set: { unreadCustomer: 0 } });
    }
    const messages = await ProjectMessage.find({ projectId: req.params.id }).sort({ createdAt: 1 });
    res.json(messages);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// إرسال رسالة في المشروع
router.post('/projects/:id/messages', async (req, res) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ error: 'Project not found' });
    if (!(await canChat(req, project))) return res.status(403).json({ error: 'Forbidden' });
    if (CLOSED_STATUSES.includes(project.status || '')) {
      return res.status(403).json({ error: 'المحادثة مغلقة بعد اكتمال الطلبية' });
    }
    const text = (req.body.text || '').toString().trim();
    if (!text) return res.status(400).json({ error: 'text required' });

    const ids = tokenIdentities(req);
    const u = await resolveUserFromReq(req, User);
    let fromId = ids[0] || (u && u.uid) || (u && u._id ? String(u._id) : '');
    let fromRole = 'customer';
    if (u && (u.role === 'owner' || u.role === 'merchant') && project.storeId && u.magasinId === project.storeId) {
      fromRole = 'owner';
    }

    const msg = await ProjectMessage.create({
      projectId: req.params.id,
      fromId,
      fromRole,
      text,
      createdAt: new Date(),
    });

    // عدّاد الرسائل غير المقروءة للطرف الآخر
    if (fromRole === 'owner') {
      await Project.findByIdAndUpdate(req.params.id, { $inc: { unreadCustomer: 1 } });
    } else {
      await Project.findByIdAndUpdate(req.params.id, { $inc: { unreadOwner: 1 } });
    }

    const io = getIO();
    const { customerId, ownerId } = await chatParticipants(project);
    const otherId = fromRole === 'owner' ? customerId : ownerId;
    if (io && otherId) io.to(`user_${otherId}`).emit('project:message', msg.toObject());

    // إشعار للطرف الآخر مع اسم المرسل
    const senderName = fromRole === 'owner'
      ? (u && (u.name || u.username)) || project.storeName || 'صاحب المشروع'
      : (u && (u.name || u.username)) || 'الزبون';
    if (otherId && otherId !== fromId) {
      await sendToUser({
        userId: otherId,
        title: `رسالة من ${senderName}`,
        body: text,
        data: { projectId: req.params.id, type: 'project_message' },
      });
    }

    res.status(201).json(msg);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
