# Deliv - دليل المشروع السريع

## المسارات على الويندوز

| المكون | المسار | Package Name |
|--------|--------|-------------|
| تطبيق الزبون | `C:\flutter_application_1` | `com.deliv.customer` |
| تطبيق السائق + التاجر + الادمن | `C:\D\dashbord` | `com.deliv.driver` |
| السيرفر (Node.js) | `C:\server` | — |

---

## VPS
- **IP:** `89.167.84.221`
- **User:** `root`
- **Pass:** `ddeelliivv`

### مسارات الـ VPS
| المكون | المسار على VPS |
|--------|---------------|
| كود السيرفر | `/root/delivery-server/` |
| كونفيغ `.env` | `/root/delivery-server/.env` |
| الصور المرفوعة | `/root/delivery-server/uploads/` |
| لوحة التحكم | `/root/delivery-server/admin/` |
| serviceAccountKey | `/root/delivery-server/serviceAccountKey.json` |

---

## الدومين
- **التطبيق:** `delivap.com`
- **API:** `https://api.delivap.com`
- **لوحة التحكم:** `https://api.delivap.com/admin`
- **DNS:** Cloudflare → A record `api` و `@` → `89.167.84.221` (Proxied)

---

## السيرفر
- **Port:** `3000`
- **PM2 Name:** `delivery-api`
- **MongoDB:** `mongodb://127.0.0.1:27017/walyyd`
- **Auto-restart:** inotifywait يراقب التعديلات + Cron watchdog كل 5 دقايق

### أوامر PM2
```bash
pm2 status                    # الحالة
pm2 logs delivery-api         # اللوقات
pm2 restart delivery-api      # إعادة التشغيل
```

---

## Firebase
- **Project:** `delive-667f5`
- **Android (زبون):** `com.deliv.customer`
- **Client ID:** `432689533764-6qh35mbtn6l3v7t1su6rde0psluhp15k.apps.googleusercontent.com`

---

## طريقة رفع السيرفر للـ VPS

### SCP (الأسهل)
```powershell
# رفع ملف واحد
scp C:\server\routes\products.js root@89.167.84.221:/root/delivery-server/routes/products.js

# رفع كل المجلد
scp -r C:\server\* root@89.167.84.221:/root/delivery-server/
```

### Posh-SSH (بوويرشيل)
```powershell
$secpass = ConvertTo-SecureString "ddeelliivv" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("root", $secpass)
$session = New-SSHSession -ComputerName "89.167.84.221" -Credential $cred -AcceptKey

Set-SCPItem -ComputerName "89.167.84.221" -Credential $cred `
  -Path "C:\server\index.js" -Destination "/root/delivery-server/" -NewName "index.js" -AcceptKey -Force

Invoke-SSHCommand -SessionId $session.SessionId -Command "pm2 restart delivery-api"
Remove-SSHSession -SessionId $session.SessionId
```

---

## بناء APK

### تطبيق الزبون
```powershell
$env:KEYSTORE_PASSWORD="wwaalliidd"
$env:KEY_ALIAS="key"
$env:KEY_PASSWORD="wwaalliidd"
flutter build appbundle --release
```

### تطبيق السائق
```powershell
cd C:\D\dashbord
flutter build appbundle --release
```

---

## كيفاش يخدم النظام
```
الزبون (Flutter App)
    ↓
Cloudflare (https://api.delivap.com)
    ↓ SSL Flexible
VPS (89.167.84.221:3000)
    ├── Express.js (index.js + routes/)
    ├── Socket.IO (شات + تحديثات مباشرة)
    ├── MongoDB (walyyd)
    ├── Firebase Admin (إشعارات)
    └── لوحة التحكم (/admin)
```

---

## الملفات المهمة

### تطبيق الزبون (`C:\flutter_application_1`)
- `lib/main.dart` → نقطة البداية
- `lib/env_config.dart` → baseUrl及其他 الإعدادات
- `lib/Services/api_client.dart` → كل الـ API calls
- `lib/Services/socket_client.dart` → Socket.IO
- `keystore.jks` → توقيع APK
- `android/app/google-services.json` → Firebase

### تطبيق السائق (`C:\D\dashbord`)
- `lib/main.dart` → نقطة البداية
- `lib/env_config.dart` → baseUrl
- `lib/services/api_client.dart` → كل الـ API calls
- `lib/services/socket_client.dart` → Socket.IO
- `keystore.jks` → توقيع APK

### السيرفر (`C:\server`)
- `index.js` → نقطة البداية
- `.env` → المتغيرات البيئية
- `routes/` → كل الـ API endpoints
- `models/` → MongoDB schemas
- `socket/` → أحداث Socket.IO
- `admin/` → لوحة التحكم
- `serviceAccountKey.json` → Firebase Admin
