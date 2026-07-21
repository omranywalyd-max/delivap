const express = require('express');
const router = express.Router();
const nodemailer = require('nodemailer');

const TELEGRAM_BOT_TOKEN = '8863390254:AAHLoEw-8dxTPVtjSJo5THZ0UQr2vxCruF8';
const TELEGRAM_CHAT_ID = '8934590264';
const EMAIL_TO = 'omranywalyd@gmail.com';

router.post('/contact', async (req, res) => {
  try {
    const { name, email, message } = req.body;
    if (!name || !email || !message) {
      return res.status(400).json({ error: 'جميع الحقول مطلوبة' });
    }

    const results = { email: false, telegram: false };

    // Telegram
    try {
      const text = `📩 *رسالة جديدة من الموقع*\n\n👤 الاسم: ${name}\n📧 الإيميل: ${email}\n💬 الرسالة:\n${message}`;
      await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text, parse_mode: 'Markdown' })
      });
      results.telegram = true;
    } catch (e) {
      console.error('Telegram error:', e.message);
    }

    // Email
    try {
      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: EMAIL_TO,
          pass: process.env.GMAIL_APP_PASSWORD || ''
        }
      });
      if (process.env.GMAIL_APP_PASSWORD) {
        await transporter.sendMail({
          from: `"Delivap Website" <${EMAIL_TO}>`,
          to: EMAIL_TO,
          subject: `📩 رسالة جديدة من الموقع - ${name}`,
          html: `<div dir="rtl" style="font-family:sans-serif;max-width:600px;margin:auto;padding:20px;border:1px solid #ddd;border-radius:12px;">
            <h2 style="color:#7D29C6;">📩 رسالة جديدة من موقع Delivap</h2>
            <p><strong>👤 الاسم:</strong> ${name}</p>
            <p><strong>📧 الإيميل:</strong> <a href="mailto:${email}">${email}</a></p>
            <p><strong>💬 الرسالة:</strong></p>
            <div style="background:#f5f5f5;padding:15px;border-radius:8px;margin-top:8px;">${message}</div>
            <hr style="margin-top:20px;border-color:#eee;">
            <p style="color:#999;font-size:12px;">مرسل من نموذج التواصل في موقع Delivap</p>
          </div>`
        });
        results.email = true;
      }
    } catch (e) {
      console.error('Email error:', e.message);
    }

    res.json({ ok: true, results });
  } catch (e) {
    console.error('Contact error:', e);
    res.status(500).json({ error: 'حدث خطأ' });
  }
});

module.exports = router;
