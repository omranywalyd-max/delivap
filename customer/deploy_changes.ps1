# 1. رفع ملفات السيرفر
scp C:\server\models\Store.js root@89.167.84.221:/root/delivery-server/models/Store.js

# 2. إعادة تشغيل السيرفر
ssh root@89.167.84.221 "pm2 restart delivery-server || systemctl restart delivery-server || cd /root/delivery-server && node index.js &"

Write-Host "تم التحديث بنجاح"
