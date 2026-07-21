# Delivery - دليل التحديث والعمل

## كيفاش التحديث يخدم (سريع)
```
تعدل في C:\server\*.js -> scp إلى VPS -> PM2 auto-restart
```

السيرفر عندو inotifywait يراقب `/root/delivery-server/`. إلا تحط ملف جديد، السيرفر يعاود التشغيل لحالو خلال 1-2 ثواني.

---

## طريقة تحديث VPS

```
C:\server\                        <- عندك على ويندوز
   ├── index.js
   ├── routes/
   ├── models/
   ├── middleware/
   ├── socket/
   ├── helpers/
   ├── admin/
   ├── data/
   ├── db.js, fcm.js, logs.js
   ├── package.json
   └── .env
```

### الخيار 1: scp (يدوي)
```bash
# نقل كل الملفات
scp -r C:\server\* root@89.167.84.221:/root/delivery-server/

# أو ملف واحد
scp C:\server\routes\products.js root@89.167.84.221:/root/delivery-server/routes/products.js

# السيرفر يعاود التشغيل لحالو بعدها
```

### الخيار 2: Posh-SSH بوويرشيل
```powershell
$secpass = ConvertTo-SecureString "ddeelliivv" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("root", $secpass)
$session = New-SSHSession -ComputerName "89.167.84.221" -Credential $cred -AcceptKey

# رفع ملف
Set-SCPItem -ComputerName "89.167.84.221" -Credential $cred ` 
  -Path "C:\server\index.js" -Destination "/root/delivery-server/" -NewName "index.js" -AcceptKey -Force

# تشغيل أمر
Invoke-SSHCommand -SessionId $session.SessionId -Command "pm2 restart delivery-api"

Remove-SSHSession -SessionId $session.SessionId
```

### الخيار 3: deploy_all.js (قديم)
```bash
node C:\server\deploy_all.js
# يستعمل ssh2 via SFTP عشان يرفع الملفات من ويندوز لـ VPS مباشر
```

---

## طريقة العمل

```
مستخدم (Flutter App)
    │
    ▼
Cloudflare (https://api.delivap.com)
    │
    ▼ (Proxied, SSL Flexible)
VPS (89.167.84.221:3000)
    │
    ├── Express (index.js + routes/)
    ├── Socket.IO (chat, realtime)
    ├── MongoDB (127.0.0.1:27017/walyyd)
    ├── Firebase Admin (notifications)
    └── Admin Panel (/admin)
```

### المسار الكامل لريكويست:
1. المستخدم يضغط على زر في التطبيق
2. التطبيق يرسل HTTP request إلى `https://api.delivap.com/api/...`
3. Cloudflare يوصل الطلب إلى VPS على port 3000 (HTTP داخلي)
4. Express يعالج الطلب ويختار الـ route المناسب
5. الـ route يتعامل مع MongoDB (قراءة/كتابة)
6. إذا كان فيه إشعار، Firebase يرسله
7. إذا كان فيه realtime، Socket.IO يبث للمستخدمين
8. الـ response يرجع للمستخدم

---

## VPS
- IP: `89.167.84.221` | user: `root` | pass: `ddeelliivv`
- المسارات: الكود `/root/delivery-server/` | الكونفيغ `.env` | الصور `uploads/` | لوحة التحكم `admin/`
- SSL: Cloudflare Flexible (HTTP على port 80 داخل السيرفر)

### أوامر PM2
| الأمر | الوظيفة |
|-------|---------|
| `pm2 status` | الحالة |
| `pm2 logs delivery-api` | اللوقات |
| `pm2 restart delivery-api` | إعادة التشغيل |
| `pm2 stop delivery-api` | إيقاف |
| `pm2 start delivery-api` | تشغيل |

---

## الدومين
- `delivap.com` | API: `https://api.delivap.com`
- DNS: A records `api` و `@` -> `89.167.84.221` (Cloudflare Proxied)

## MongoDB
- `mongodb://127.0.0.1:27017/walyyd` (محلي على VPS)

## Firebase
- Project: `delive-667f5` | Android app: `com.deliv.customer`
- Server key: `serviceAccountKey.json` في `/root/delivery-server/`
- Client ID: `432689533764-6qh35mbtn6l3v7t1su6rde0psluhp15k.apps.googleusercontent.com`

## Flutter App
- المسار: `C:\flutter_application_1` | package: `com.deliv.customer`
- `baseUrl`: `https://api.delivap.com`
- Google Maps Key: `AIzaSyCp2VwwSQSY2vvyCot-oq7UFvlO61xpo2s`
- بناء APK: `flutter build appbundle --release`
- التوقيع: قبل البناء دير `$env:KEYSTORE_PASSWORD="wwaalliidd"` و `$env:KEY_ALIAS="key"` و `$env:KEY_PASSWORD="wwaalliidd"`
- ملفات مهمة: `google-services.json` | `keystore.jks` (alias: key) | `env_config.dart` | `build.gradle.kts`

## السيرفر
- Port: `3000` | PM2 name: `delivery-api`
- Auto-restart على التعديل (inotifywait) + Cron watchdog كل 5 دقايق
- لوحة التحكم: `https://api.delivap.com/admin`

---
تم الإنشاء: 25 يونيو 2026 | آخر تحديث: 7 يوليو 2026 - 10:45
