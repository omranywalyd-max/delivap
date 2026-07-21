# ملخص تحسينات الأداء — تطبيق التوصيل

## التغييرات المُطبقة

### 🔴 P0 (تأثير عالي على السرعة المحسوسة)

| # | الملفات | المشكلة | الحل |
|---|---------|---------|------|
| 1 | `stores_view.dart` + `dashboard_screen.dart` | `/api/stores` يُستدعى **مرتين** — مرة في DashboardScreen ومرة في StoresView | تمرير `stores` عبر constructor; `_checkDistanceAndLoad()` تستعمل `widget.stores.firstWhere` بدل `getList` جديد |
| 2 | `stores_view.dart` | `_CatCache` موجود لكنه غير مُفعّل — كل switch محل = إعادة fetch كاملة | تفعيل الـ cache مع TTL (5 دقائق): يعرض instant إن وُجد، fetch في الخلفية، clear عند تغير templateId أو pull-to-refresh |
| 3 | `Services/api_client.dart` | `upload()` يرفع الصور بحجمها الأصلي (4000×3000+) بدون resize | إضافة `img.copyResize()` إلى حد أقصى 1200px (يحافظ على aspect ratio) + JPEG quality 85 |

### 🟡 P1

| # | الملفات | المشكلة | الحل |
|---|---------|---------|------|
| 4 | `stores_view.dart` (CategoryCardWidget) | `CachedNetworkImage` بلا `memCacheWidth` → فك كامل للصورة عالية الدقة | إضافة `memCacheWidth` ديناميكي بقيمة `(screenWidth/2 * dpr)` |

### 🟢 P2

| # | الملفات | المشكلة | الحل |
|---|---------|---------|------|
| 5 | `profile_screen.dart` | صورة البروفايل تستعمل `Image.network` بدون caching | استبدال بـ `CachedNetworkImage` مع `memCacheWidth` + placeholder + errorWidget |
| 6 | `app_cached_image.dart` | `precacheImages()` كانت تسلسلية (تنتظر كل صورة على حدة) | تحويلها إلى `Future.wait` لتحميل كل الصور بالتوازي |

---

## تغييرات إضافية

- `didUpdateWidget` في `StoresView`: أصبح يتحقق كمان من تغير `stores` وليس فقط `templateId`
- `_CatCache`: إضافة `clear()` مع TTL لمنع stale data
- الـ cache يُمسح تلقائياً عند pull-to-refresh

---

## الخطوات القادمة

1. تشغيل `flutter analyze` للتأكد من عدم وجود أخطاء
2. بناء APK (تطبيق الزبون + تطبيق السائق)
3. اختبار تحديث البروفيل التلقائي عند استلام طلبية (loyalty)
4. (خيار إضافي) إضافة pagination لـ `/api/promotions` في السيرفر
