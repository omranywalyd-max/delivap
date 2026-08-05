const express = require('express');
const router = express.Router();
const Project = require('../models/Project');
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

module.exports = router;
