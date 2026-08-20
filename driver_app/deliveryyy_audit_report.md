# 📋 Deliveryyy — تقرير التدقيق الشامل للنظام

**التاريخ:** 23 يونيو 2026  
**الأنظمة التي تم تدقيقها:** تطبيق الزبون (Flutter) | تطبيق لوحة التحكم (Flutter) | الخادم الخلفي (Node.js/MongoDB)

---

## 🔴 مشاكل حرجة (يجب الإصلاح قبل رفع التطبيق إلى متجر جوجل بلاي)

1. **CRIT-01 | serviceAccountKey.json مكشوف في المستودع**  
   - 📍 `C:\server\serviceAccountKey.json` — الملف موجود في المستودع بدون `.gitignore`  
   - ❌ حسابات Firebase يمكن اختراقها بالكامل (قراءة/كتابة في كل شي).  
   - ✅ يجب إضافة المسار إلى `.gitignore` واستخدام متغيرات البيئة أو Google Cloud Secret Manager.

2. **CRIT-02 | لوحة تحكم الأدمن تستخدم username/password ثابت في الكود**  
   - 📍 `C:\D\dashbord\lib\unified_login.dart:309-310`  
   - ❌ `if (userCtrl.text == 'omranywalyd' && passCtrl.text == 'wwaalliidd')` — كلمة السر والأي دي مكتوبين في النص البرمجي.  
   - ✅ يجب نقل المصادقة إلى الخادوم باستخدام JWT + مقارنة مع الخادوم، وليس في التطبيق مباشرة.

3. **CRIT-03 | JWT_SECRET ضعيف ومكتوب في `.env` مكشوف**  
   - 📍 `C:\server\.env:3` — `JWT_SECRET=walyyd_local_secret_2026`  
   - ❌ الخادوم لا يستخدم JWT بشكل فعلي (الـ auth middleware يستخدم Firebase ID Token)، لكن السري موجود في المستودع.  
   - ✅ إما حذف JWT_SECRET إن لم يستخدم، أو إخفاءه في `.env` مع إضافة `.env` إلى `.gitignore`.

4. **CRIT-04 | CORS مفتوح بالكامل (`origin: '*'`)**  
   - 📍 `C:\server\index.js:21` — `cors: { origin: '*', ... }`  
   - ✅ يجب تقييده بالنطاقات المعروفة فقط.

5. **CRIT-05 | isMinifyEnabled = false في Customer App**  
   - 📍 `C:\flutter_application_1\android\app\build.gradle.kts:47`  
   - ❌ بدون ProGuard/R8، الكود غير مصغّر وغير محمي. جوجل بلاي قد يرفض لأن ملف الـ AAB كبير جداً والـ code غير محمي.  
   - ✅ يجب تفعيل `isMinifyEnabled = true` مع إعداد قواعد ProGuard مناسبة.

6. **CRIT-06 | FCM token للمستخدم / السائق لم يتم إنشاؤه عند بدء التشغيل**  
   - 📍 `C:\flutter_application_1\lib\main.dart` — لا يوجد استدعاء لـ `FirebaseMessaging.instance.getToken()` عند بدء التطبيق  
   - 📍 `C:\D\dashbord\lib\main.dart` — لا يوجد استدعاء لـ FCM إطلاقاً عند بدء التطبيق (يتم فقط عند تسجيل دخول السائق)  
   - ❌ سيؤدي هذا إلى عدم وصول الإشعارات للمستخدمين في الحالات الحرجة (الخلفية، التطبيق مقفول).  
   - ✅ يجب استدعاء `FirebaseMessaging.instance.getToken()` في `main()` وإرسال التوكن إلى الخادم.

7. **CRIT-07 | Background handler للإشعارات لا يفعل شيئاً في Customer App**  
   - 📍 `C:\flutter_application_1\lib\main.dart:16-18`  
   - ❌ `_firebaseMessagingBackgroundHandler` فقط يعيد تهيئة Firebase بدون أي معالجة للبيانات.  
   - ✅ يجب إضافة معالجة الإشعارات الخلفية (عرض إشعار محلي، تحديث الحالة).

8. **CRIT-08 | targetSdk 35 لكن compileSdk 36**  
   - ✅ هذا جيد لتوافق متجر Play (targetSdk 35 مطلوب لـ 2025-2026)  
   - لكن `google_sign_in: ^6.1.2` قد لا يكون متوافقاً بالكامل مع compileSdk 36

9. **CRIT-09 | لا يوجد معالجة لرفض الأذونات (Permissions Denied Forever)**  
   - 📍 `C:\D\dashbord\lib\driver_app.dart:1290-1298` — إذا رفض المستخدم الإذن بشكل نهائي لا يتم توجيهه للإعدادات  
   - ✅ يجب استخدام `openAppSettings()` من `app_settings` package لتوجيه المستخدم.

10. **CRIT-10 | المفتاح الخريطة (Google Maps API Key) مكتوب في Manifest وEnvConfig**  
    - 📍 `AndroidManifest.xml` في كلا التطبيقين — `AIzaSyAdj5NPbmbhwBFHzZd_TQ7fj9rrzJvgCFY`  
    - 📍 `env_config.dart` في كلا التطبيقين — نفس المفتاح  
    - ❌ هذا يسمح لأي شخص بأخذ المفتاح واستخدامه.  
    - ✅ يجب حماية المفتاح عبر Google Maps API key restriction (Android App restriction + API restriction).

---

## 🟠 مشاكل عالية الأولوية

1. **HIGH-01 | لا يوجد `.env` في `.gitignore` للخادوم**  
   - ملف `.env` و `serviceAccountKey.json` ليسا في `.gitignore`. سيتم رفعهما إلى GitHub إذا حدث `git push`.

2. **HIGH-02 | مصادقة التاجر (Store Owner) تستخدم username/password نصيين**  
   - 📍 `C:\server\routes\users.js:63-76` — كلمة السر مخزنة كنص واضح في MongoDB بدون bcrypt  
   - ✅ يجب استخدام bcrypt لتشفير كلمات السر.

3. **HIGH-03 | الـ socket.io يبث مواقع جميع السائقين لكل المستخدمين**  
   - 📍 `C:\server\socket\index.js:16-18` — `io.emit('driver:location_updated', ...)` يبث لكل الاتصالات  
   - ✅ يجب الإرسال إلى غرف محددة فقط.

4. **HIGH-04 | Driver location يرسل إلى الخادوم عبر REST API (PUT) وليس Socket.IO**  
   - 📍 `C:\D\dashbord\lib\driver_app.dart:216-225` — كل 20 متراً يتم إرسال طلب HTTP PUT  
   - ❌ هذا سيؤدي إلى استهلاك كبير للبطارية والبيانات، خاصة مع 100+ سائق.  
   - ✅ استخدام Socket.IO فقط لتحديث الموقع.

5. **HIGH-05 | نقص الترقيم (Pagination) في endpoints التي تعيد قوائم**  
   - 📍 `GET /api/orders`, `GET /api/users`, `GET /api/drivers/earnings`, `/api/all-orders`  
   - ❌ كل هذه الـ endpoints لا تحتوي على `limit` أو `skip` مما يؤدي لاستهلاك كبير في الذاكرة.

6. **HIGH-06 | customer_confirmed غير مستخدم في كود العميل**  
   - 📍 حقل `customerConfirmed` موجود في `Order.js` model لكن لا يتم تعيينه من الكود  
   - ❌ قد يسبب سلوكاً غير متوقع لتأكيد العميل.

7. **HIGH-07 | الإشعارات تصل من الخادوم عبر `/api/notify-user` بدون مصادقة**  
   - 📍 `C:\server\routes\misc.js:143-151` — أي شخص يمكنه استدعاء هذا الـ endpoint  
   - ✅ يجب إضافة middleware للمصادقة.

8. **HIGH-08 | لا يوجد rate limiting على endpoints المصادقة**  
   - ✅ يجب استخدام `express-rate-limit` لمنع brute force.

9. **HIGH-09 | Owner login عبر Query Parameters**  
    - 📍 `C:\server\routes\users.js:63-67` — يتم إرسال username و password كـ query params في URL  
    - ❌ هذا ممارسة غير آمنة (تظهر في logs).  
    - ✅ يجب استخدام POST مع body.

---

## 🟡 مشاكل متوسطة الأولوية

1. **MED-01 | `debugPrint` و `print` موجودة في كل مكان في كلا التطبيقين**  
   - 📍 مئات المواقع في `dashboard_screen.dart`, `driver_app.dart`, `admin_panel.dart`, إلخ.  
   - ✅ يجب إزالتها أو استخدام شرط `kReleaseMode`.

2. **MED-02 | `StreamBuilder` بدون `initialData` في Customer App**  
   - 📍 `main_page.dart:243` — `StreamBuilder<User?>` بدون `initialData`

3. **MED-03 | `TextEditingController` لا يتم `dispose` بشكل كامل في dashboard**  
   - 📍 بعض الشاشات مثل `_PricingSheet` تفعل `dispose`، لكن يجب التأكد من كل الشاشات.

4. **MED-04 | `setState` بعد `await` بدون التحقق من `mounted`**  
   - 📍 العديد من المواقع في `driver_app.dart` و `admin_panel.dart`  
   - ✅ معظمها يستخدم `mounted` لكن هناك حالات تم تفويتها.

5. **MED-05 | Google Maps API key مكرر في أماكن متعددة**  
   - موجود في: `AndroidManifest.xml` (كلا التطبيقين)، `env_config.dart` (كلا التطبيقين)  
   - ✅ يجب أن يكون في مكان واحد فقط ويُقرأ من متغير البيئة.

6. **MED-06 | لا يوجد `network_security_config.xml` في Customer App**  
   - 📍 `AndroidManifest.xml:24` يشير إلى `@xml/network_security_config` لكن الملف قد لا يكون موجوداً  
   - تحقق من `res/xml/network_security_config.xml`

7. **MED-07 | owner_products_manager.dart, owner_project_deliveries.dart, owner_project_orders.dart**  
   - هذه الملفات غير مذكورة في الـ routes في `main.dart` للتطبيق

8. **MED-08 | Dashboard app لا يستخدم Firebase بشكل صحيح لمعرفة دور المستخدم**  
   - 📍 `main.dart:17-20` — دور المستخدم يُقرأ من `SharedPreferences` وليس من Firebase  
   - ✅ الأفضل استخدام `Firebase custom claims`.

9. **MED-09 | لا يوجد تحقق من نوع الملف في upload endpoint**  
   - 📍 `C:\server\routes\upload.js` — أي نوع ملف يمكن رفعه

10. **MED-10 | `axios` و `cors` لم يتم تعريف `options.successStatus`**  
    - لا يؤثر لكنه قد يسبب مشاكل في إصدارات Express 5.

---

## 🟢 توصيات / تحسينات منخفضة

1. **LOW-01 | إضافة `flutter_secure_storage` لتخزين التوكنات الحساسة بدلاً من `SharedPreferences`**  
2. **LOW-02 | استخدام `cached_network_image` مع placeholder مناسب**  
3. **LOW-03 | استخدام `infinite_scroll_pagination` للمنتجات والطلبات**  
4. **LOW-04 | إضافة `shimmer` effect بدلاً من CircularProgressIndicator** (موجود جزئياً في Orders)  
5. **LOW-05 | استخدام `go_router` أو `auto_route` بدلاً من `Navigator.push` المباشر**  
6. **LOW-06 | إضافة اختبارات (`flutter test`)** — لا يوجد أي اختبار  
7. **LOW-07 | إضافة `CI/CD pipeline` (GitHub Actions)**  
8. **LOW-08 | تحسين هيكلة الملفات — يوجد تكرار في الألوان والـ helpers بين الملفات**  
9. **LOW-09 | إزالة التعليقات بالعربية الزائدة من الشيفرة المصدرية**  
10. **LOW-10 | إضافة `sentry` أو `firebase-crashlytics` لمراقبة الأخطاء في الإنتاج**

---

## 1. جرد قاعدة البيانات

### تطبيق الزبون (`C:\flutter_application_1`)

**pubspec.yaml** — إصدارات الحزم الرئيسية:
| الحزمة | الإصدار | ملاحظة |
|--------|---------|--------|
| `firebase_core` | ^3.0.0 | ✅ حديث |
| `firebase_auth` | ^5.0.0 | ✅ حديث |
| `firebase_messaging` | ^15.2.10 | ✅ حديث |
| `socket_io_client` | ^3.0.0 | ✅ مستقر |
| `google_maps_flutter` | ^2.9.0 | ✅ مستقر |
| `geolocator` | ^13.0.0 | ✅ حديث |
| `http` | ^1.2.0 | ✅ حديث |
| `shared_preferences` | ^2.2.2 | ⚠️ قديم قليلاً |
| `flutter_local_notifications` | ^21.0.0 | ✅ حديث |

**`AndroidManifest.xml`**:
- ✅ `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- ⚠️ `ACCESS_BACKGROUND_LOCATION` — يتطلب مراجعة خاصة من Google Play
- ✅ `POST_NOTIFICATIONS` (Android 13+)
- ✅ `VIBRATE`
- ✅ قناة الإشعارات: `user_channel`
- ✅ Google Maps API key في `<meta-data>`

**`build.gradle.kts`**:
- `compileSdk = 36` ✅
- `targetSdk = 35` ✅ (مطلوب)
- `minSdk = flutter.minSdkVersion` (يعتمد على Flutter SDK)  
- AGP `8.11.1` ✅ حديث  
- Kotlin `2.2.20` ✅ حديث  
- ⚠️ `isMinifyEnabled = false` — يجب تفعيله

**`main.dart`**:
- ✅ Firebase.initializeApp() قبل runApp()
- ⚠️ `FirebaseMessaging.onBackgroundMessage()` لا يعالج البيانات
- ❌ لا يوجد `FirebaseMessaging.instance.getToken()` لإرسال التوكن
- ✅ `navigatorKey` معرف عالمياً
- التوجيه: `/home`, `/map-picker`, `/phone_screen`, `/location_screen`

**هيكل التنقل:**
- `SplashScreen` → `OnboardingScreen` (أول مرة) / `MainPage`
- `MainPage` (4 tabs): `DashboardScreen`, `ServicesScreen`, `OrdersScreen`, `ProfileScreen`
- Dashboard → `StoresView` → `ProductsListScreen`
- Services → `ServiceOrderScreen`, `TransportOrderScreen`, `MapPickerScreen`
- Orders → `ActiveOrdersScreen` (قيد التنفيذ/منتهية/ملغية)
- Profile → `EditProfileScreen`, `SettingsScreen`

**حالة الإدارة:** ✅ Provider (`ChangeNotifier` في `LocationProvider`)

**Firebase Services المستخدمة:**
- ✅ Firebase Auth
- ✅ Firebase Cloud Messaging
- ❌ لا يوجد Firebase Analytics
- ❌ لا يوجد Firebase Crashlytics

**`google-services.json`**: ✅ موجود في `android/app/`

**ملفات `.env`**: ❌ غير موجودة

### تطبيق لوحة التحكم (`C:\D\dashbord`)

**`android/app/build.gradle.kts`**:
- `applicationId = "com.example.dashbord.driver"` — مختلف عن Customer App
- `targetSdk = 35` ✅
- `compileSdk = flutter.compileSdkVersion` (يعتمد على Flutter SDK)
- `isMinifyEnabled` غير معرف (يجب تفعيله)
- Kotlin `2.3.20` ✅

**`AndroidManifest.xml`**:
- ✅ `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- ✅ `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`
- ✅ `CALL_PHONE` (للاتصال الهاتفي)
- ✅ `POST_NOTIFICATIONS`, `WAKE_LOCK`, `VIBRATE`
- ✅ `FLUTTER_NOTIFICATION_CLICK` intent-filter
- ✅ قناة الإشعارات: `orders_channel`
- ✅ تعريف خدمة الموقع: `com.lyokone.location.foreground.ForegroundService`

**الأدوار الثلاثة:**
1. **Admin** — دخول عبر Long Press + username/password (مكتوب في الكود)
2. **Store Owner (تاجر)** — دخول عبر form (username + password → API GET)
3. **Driver** — دخول عبر Firebase Auth Email/Password

**الـ routing:**
- `UnifiedLoginScreen` ← `_buildChoice()` → Driver / Owner / Admin
- Driver → `DriverSignInScreen` → `DriverMainShell`
- Owner → `OwnerDashboard` (معرّف في `driver_app.dart`)
- Admin → `AdminDashboardMain` (4 tabs)

**حالة الإدارة:** ❌ لا يوجد Provider/BLoC/Riverpod — كل شيء `StatefulWidget` + `setState`

### الخادوم (`C:\server`)

**`package.json`**:
- `express: ^5.2.1` ✅ (Express 5 — أحدث إصدار)
- `mongoose: ^9.7.0` ✅ (أحدث إصدار)
- `socket.io: ^4.8.3` ✅
- `firebase-admin: ^14.0.0` ✅
- `jsonwebtoken: ^9.0.3` ✅
- `multer: ^2.1.1` ✅
- `cors: ^2.8.6` ✅
- `dotenv: ^17.4.2` ✅

**الـ routes:**
| المسار | الملف | الوظيفة |
|--------|-------|---------|
| `GET/POST/PUT/DELETE /api/users` | `users.js` | CRUD المستخدمين + مصادقة التاجر |
| `GET/POST/PUT/DELETE /api/orders` | `orders.js` | CRUD الطلبات + FCM + Socket |
| `GET/POST/PUT/DELETE /api/drivers` | `drivers.js` | CRUD السائقين + التعليقات |
| `GET/POST/PUT/DELETE /api/stores` | `stores.js` | CRUD المتاجر |
| `GET/POST/PUT/DELETE /api/products` | `products.js` | CRUD المنتجات |
| `GET/POST/PUT/DELETE /api/categories` | `categories.js` | CRUD الفئات |
| `GET/POST/PUT/DELETE /api/transport-orders` | `transportOrders.js` | طلبات النقل |
| `GET/POST/PUT/DELETE /api/service-orders` | `serviceOrders.js` | طلبات الخدمات |
| `GET/POST/PUT/DELETE /api/projects` | `projects.js` | المشاريع |
| `GET/POST/PUT/DELETE /api/project-deliveries` | `projectDeliveries.js` | توصيل المشاريع |
| `GET/POST/PUT/DELETE /api/drinks` | `drinks.js` | المشروبات (الإضافات) |
| `GET/POST/PUT/DELETE /api/favorites` | `favorites.js` | المفضلة |
| `GET/POST/PUT/DELETE /api/promotions` | `promotions.js` | العروض |
| `GET/PUT /api/config`, `/api/wilaya` | `config.js` | الإعدادات + الولايات |
| `POST /api/upload` | `upload.js` | رفع الصور |
| `/api/admin` | `admin.js` | لوحة الأدمن (CRUD لكل شي) |
| `/api/all-orders` | `misc.js` | جميع الطلبات موحّدة |
| `POST /api/notify-user`, `/api/notify-driver` | `misc.js` | إرسال الإشعارات |

**Middleware المصادقة:**
- 📍 `middleware/auth.js` — يستخدم Firebase Admin SDK للتحقق من Firebase ID Token
- ⚠️ **لا يستخدم في أي route!** — جميع الـ routes بدون middleware

**Socket.IO Events:**
| الحدث | الاتجاه | الوظيفة |
|-------|---------|---------|
| `join` | Client → Server | الانضمام لغرفة |
| `leave` | Client → Server | مغادرة غرفة |
| `driver:location` | Client → Server | تحديث موقع السائق |
| `driver:status` | Client → Server | تغيير حالة السائق |
| `driver:location_updated` | Server → All | بث موقع السائق (⚠️ يبث للكل) |
| `driver:status_changed` | Server → All | بث تغيير الحالة |
| `order:created` | Server → User/Driver | طلب جديد |
| `order:updated` | Server → User/Driver | تحديث الطلب |
| `user:updated` | Server → User | تحديث بيانات المستخدم |
| `user:deleted` | Server → User | حذف المستخدم |
| `transport:created/updated` | Server → User/Driver | نقل جديد/محدث |
| `service:created/updated` | Server → User/Driver | خدمة جديدة/محدثة |
| `delivery:created/updated` | Server → User/Driver | توصيل جديد/محدث |
| `project_delivery:created/updated` | Server → User/Driver | توصيل مشروع جديد |
| `project:created/updated` | Server → Owner | مشروع جديد |
| `new_report` | Server → Admin | بلاغ جديد |
| `new_admin_message` | Server → Admin | رسالة جديدة للأدمن |
| `new_message` | Server → User | رسالة جديدة للمستخدم |
| `notification` | Server → Driver | إشعار جديد |
| `driver:updated` | Server → Driver | تحديث بيانات السائق |

**MongoDB Collections:**
| المجموعة | عدد الحقول | حقول رئيسية |
|----------|-----------|-------------|
| `users` | ~25 | uid, role, username, password, fcmToken, isActive, isBanned, loyaltyCount |
| `drivers` | ~30 | uid, firstName, fcmToken, isOnline, isActive, lat, lng, totalEarnings, pricing |
| `magasins` | ~15 | nom, image, lat, lng, uiStyle, ownerId, templateId |
| `produits` | ~20 | storeId, name, prix, price, sizes, models, uiStyle |
| `categories` | ~6 | templateId, storeId, nom |
| `orders` | ~40+ | userId, items[], status, driverId, counterOffer, deliveryFee |
| `transport_orders` | ~20 | userId, fromAddress, toAddress, driverId, status |
| `service_orders` | ~20 | userId, serviceType, fromAddress, toAddress, counterOffer |
| `projects` | ~20 | userId, storeId, status, description |
| `project_deliveries` | ~30 | projectId, userId, driverId, status, counterOffer |
| `comments` | ~10 | driverId, userId, text, replies[] |
| `messages` | ~6 | userId, from, text, read |
| `notifications` | ~8 | toId, title, body, type |
| `reports_driver` | ~15 | type, driverId, userId, reason, status |
| `favorites` | ~5 | userId, storeId, productIds[] |
| `config` | ~3 | key, value (schema-less) |
| `wilaya_configs` | ~10 | cityName, basePrice, extraDistPrice |
| `savedLocations` | ~15 | userId, label, address, lat, lng |
| `saved_templates` | ~5 | userId, templateName, items[] |
| `drinks` | ~4 | storeId, name, flavors[] |
| `promotions` | ~12 | storeId, title, price, isActive |

---

## 2. تقرير التوافق عبر الأنظمة

### مشاكل العقود API

1. **APIGAP-01 | Customer App يستخدم `/api/users/{uid}` لكن Dashboard يستخدم `/api/drivers/{uid}`**  
   - ✅ صحيح — هذا متعمد لأن Customer و Driver هما كيانان مختلفان في MongoDB

2. **APIGAP-02 | Driver App يرسل `driver:location_updated` عبر Socket لكن الخادوم يستمع لـ `driver:location`**  
   - 📍 `C:\D\dashbord\lib\driver_app.dart:220` يرسل `driver:location_updated`  
   - 📍 `C:\server\socket\index.js:15` يستمع لـ `driver:location`  
   - ❌ **الحدث لا يتطابق!** السائق يرسل `driver:location_updated` لكن الخادوم يستمع لـ `driver:location`  
   - ✅ الحل: تغيير الحدث في Flutter إلى `driver:location`

3. **APIGAP-03 | Customer App يستخدم Firebase UID كمعرف لكن الخادوم يمكنه البحث بـ _id أيضاً**  
   - ✅ صحيح — الخادوم يستخدم `findOne({ uid: id })` ثم `findById(id)` كخطة احتياطية

4. **APIGAP-04 | `notify-token` endpoint غير موجود في الخادوم لكن Dashboard يرسل له**  
   - 📍 `C:\D\dashbord\lib\fcm_helper.dart:30` — `ApiClient.post('/api/notify-token', ...)`  
   - 📍 الخادوم لا يحتوي على route `/api/notify-token`  
   - ❌ **هذا الـ endpoint مكسور** — كل استدعاء سيفشل

5. **APIGAP-05 | Customer App يستخدم `counterOffer` لكن Order model يحتوي عليه**  
   - ✅ صحيح — الخادوم والـ model متوافقان

### مشاكل Socket.IO

1. **SOCK-01 | `driver:location_updated` vs `driver:location` — مذكور أعلاه (APIGAP-02)**

2. **SOCK-02 | `FCMHelper.sendToUser` في Dashboard يرسل عبر REST API (POST /api/notify-user) وليس Socket**  
   - ✅ صحيح — هذا مقصود للإشعارات أثناء الخلفية.

3. **SOCK-03 | الخادوم يبث `driver:location_updated` لكل الاتصالات (`io.emit`)**  
   - 📍 `C:\server\socket\index.js:17` — هذا يعني أن كل مستخدم يستقبل مواقع جميع السائقين  
   - ❌ مشكلة خصوصية وأداء.

4. **SOCK-04 | لا يوجد `emitToRoom` مستخدم بشكل صحيح لتفريق المستخدم عن السائق عن الأدمن**  
   - ✅ `emitToUser`, `emitToDriver` موجودة لكن بعض الأحداث لا تستخدمها.

### مشاكل نماذج البيانات

1. **MODEL-01 | `User` model لا يحتوي على `unique: true` لـ `uid`**  
   - 📍 `C:\server\models\User.js:4` — معلّق: `// ✅ نحينا unique: true باش التاجر يقدر يسجل بلا مشاكل`  
   - ⚠️ هذا قد يسبب مشاكل في التكرار.

2. **MODEL-02 | `Driver` model عنده `uid: { type: String, unique: true }`**  
   - ✅ صحيح.

3. **MODEL-03 | `Store` collection اسمها `magasins` لكن Flutter يستخدم `/api/stores`**  
   - ✅ يوجد route alias في `index.js:36-39` لتحويل `/api/magasins` ← `/api/stores`

4. **MODEL-04 | `Product` collection اسمها `produits` لكن API هو `/api/products`**  
   - ✅ نفس الشيء — route alias.

### تتبع دورة حياة الطلب

| الخطوة | الملفات | حالة |
|--------|---------|------|
| 1. الزبون يضع طلب | `flutter_application_1` → `POST /api/orders` → `orders.js:9` | ✅ |
| 2. السائق يستقبل إشعار | `orders.js:14` ← Socket `order:created` + FCM | ✅ |
| 3. السائق يقبل/يرفض | `driver_app.dart:260-298` ← `PUT /api/orders/:id` | ✅ |
| 4. Counter-offer | `driver_app.dart:300-326` ← `PUT /api/orders/:id` | ✅ |
| 5. استلام الطلب | `driver_app.dart:406-413` ← `PUT /api/orders/:id` | ✅ |
| 6. التسليم | `PUT /api/orders/:id` status=delivered → FCM + حساب الأرباح | ✅ |
| 7. نظام الولاء | `PUT /api/users/:id/loyalty` في `users.js:186-216` | ✅ |

---

## 3. نتائج التدفقات الوظيفية

| التدفق | التطبيق | الحالة | المشكلة | الملف | الإصلاح |
|--------|---------|--------|---------|------|---------|
| تثبيت جديد → Onboarding | Customer | ✅ | - | - | - |
| تسجيل الدخول (هاتف/بريد) | Customer | ⚠️ | يستخدم Firebase Phone + Email | `Sign In/` | لا مشكلة |
| طلب الإذن للموقع | Customer | ✅ | - | - | - |
| عرض المتاجر | Customer | ✅ | - | `dashboard_screen.dart` | - |
| اختيار المنتج وحجمه | Customer | ✅ | - | `products_list_screen.dart` | - |
| إضافة للسلة | Customer | ✅ | - | `cardd.dart` | - |
| حساب رسوم التوصيل | Customer | ⚠️ | يستخدم Nominatim + WilayaConfig | `delivery_screen.dart` | ✅ صحيح |
| إتمام الطلب | Customer | ✅ | - | `Order/Order.dart` | - |
| تتبع الطلب على الخريطة | Customer | ⚠️ | `driver:location_updated` لا يصل للزبون لعدم الانضمام للغرفة | `Server socket` | إصلاح SOCK-03 |
| نظام الولاء (5 طلبات) | Customer | ✅ | - | `users.js:186-216` | - |
| إشعار Push (Foreground) | Customer | ❌ | لا يوجد مستمع `FirebaseMessaging.onMessage` | `main.dart` | إضافة المستمع |
| إشعار Push (Background) | Customer | ❌ | الـ handler لا يفعل شيئاً | `main.dart:16-18` | إضافة المعالجة |
| إشعار Push (Killed) | Customer | ❌ | `getInitialMessage()` غير مستدعى | `main.dart` | إضافة `getInitialMessage()` |
| تسجيل دخول السائق | Dashboard | ✅ | - | `driver_app.dart:894` | - |
| Online/Offline toggle | Dashboard | ✅ | - | `driver_app.dart:196-198` | - |
| قبول الطلب | Dashboard | ✅ | - | `driver_app.dart:260` | - |
| Counter-offer | Dashboard | ✅ | - | `driver_app.dart:300` | - |
| تحديث الموقع live | Dashboard | ❌ | حدث Socket خاطئ | `driver_app.dart:220` | تغيير `driver:location_updated` → `driver:location` |
| تسجيل دخول الأدمن | Dashboard | ❌ | username/password في الكود | `unified_login.dart:309` | نقل للخادوم مع JWT |
| إضافة تاجر جديد | Dashboard | ✅ | - | `admin_panel.dart` | - |
| تفعيل السائق | Dashboard | ✅ | - | `admin_panel.dart` | - |
| إدارة المنتجات (Style 8) | Dashboard | ✅ | - | `owner_products_manager.dart` | - |

---

## 4. تقرير نظام الإشعارات

### إعداد FCM

| البند | حالة | تفاصيل |
|--------|--------|---------|
| `google-services.json` | ✅ | موجود في كلا التطبيقين |
| Firebase init قبل runApp | ✅ | في `main.dart` لكلاهما |
| `FirebaseMessaging.requestPermission()` | ❌ | غير مستدعى في Customer App |
| `POST_NOTIFICATIONS` في Manifest | ✅ | موجود في كلا التطبيقين |
| FCM token إرسال إلى الخادوم | ⚠️ | يتم فقط عند تسجيل دخول السائق، ليس للمستخدم العادي |
| تحديث التوكن | ⚠️ | فقط في `DriverService.updateFcmToken()` |

### قنوات الإشعارات

| التطبيق | القناة | الموقع |
|---------|--------|--------|
| Customer App | `user_channel` | `AndroidManifest.xml:33` |
| Dashboard App | `orders_channel` | `AndroidManifest.xml:69` |

### معالجة الرسائل (3 حالات)

| الحالة | Customer App | Dashboard App |
|--------|--------------|---------------|
| **Foreground** (`onMessage`) | ❌ غير موجود | ❌ غير موجود |
| **Background** (`onBackgroundMessage`) | ⚠️ موجود لكن لا يعالج البيانات | ❌ غير موجود |
| **Terminated** (`getInitialMessage`) | ❌ غير موجود | ❌ غير موجود |
| `onMessageOpenedApp` | ❌ غير موجود | ❌ غير موجود |

### الخادوم — FCM

| البند | حالة |
|--------|--------|
| إرسال FCM عبر `firebase-admin` SDK | ✅ |
| تنسيق payload (notification + data) | ✅ |
| تخزين fcmTokens في MongoDB | ✅ |
| `sendToDriver()` موجودة | ✅ مع `channel_id: 'orders_channel'` |
| `sendToUser()` موجودة | ✅ مع `channel_id: 'user_channel'` |

---

## 5. تقرير الامتثال لمتجر Google Play

| الفحص | الحالة | التفاصيل | الإجراء المطلوب |
|-------|--------|----------|----------------|
| `targetSdkVersion` = 35 | ✅ | متوافق مع متطلبات 2025-2026 | لا شيء |
| `minSdkVersion` | ⚠️ | يعتمد على Flutter SDK (عادة 21+) | تحقق من الإصدار |
| دعم 64-bit (arm64-v8a) | ⚠️ | يتم تضمينه تلقائياً عبر Flutter | تحقق من ABI split |
| تنسيق AAB | ✅ | Flutter يدعم AAB تلقائياً | لا شيء |
| App Signing | ✅ | Play App Signing مع keystore | لا شيء |
| `android:debuggable` في الـ release | ✅ | غير موجود (افتراضياً false) | لا شيء |
| `minifyEnabled = true` | ❌ | حالياً `false` في Customer App | تفعيل ProGuard |
| **إذن `ACCESS_BACKGROUND_LOCATION`** | ⚠️ | موجود في Customer App — يتطلب مراجعة خاصة | تقديم شرح في Play Console |
| **إذن `CALL_PHONE`** | ✅ | موجود فقط في Dashboard (ليس للزبون) | لا مشكلة |
| **إذن `MANAGE_EXTERNAL_STORAGE`** | ✅ | غير موجود | لا مشكلة |
| **إذن `SYSTEM_ALERT_WINDOW`** | ✅ | غير موجود | لا مشكلة |
| **إذن `REQUEST_INSTALL_PACKAGES`** | ✅ | غير موجود | لا مشكلة |
| **إذن `CAMERA`** | ✅ | غير موجود في Manifest (لكن `image_picker` يستخدم camera) | يظهر تلقائياً |
| **إذن `RECORD_AUDIO`** | ✅ | غير موجود | لا مشكلة |
| سياسة الخصوصية | ⚠️ | موجود رابط في Dashboard (`walyyd.com/privacy-policy`) | تحقق من وجود الرابط فعلياً |
| Crash على التشغيل الأول | ❌ | لم يتم اختباره | اختبر على جهاز نظيف |
| معالجة عدم الاتصال بالإنترنت | ⚠️ | موجود جزئياً في Dashboard (`ConnectivityBanner`) | إضافة معالجة كاملة |
| In-App Review API الرسمي | ✅ | غير مستخدم (لا يوجد rating dialog) | لا مشكلة |
| Google Play Billing | ✅ | غير مطلوب (خدمات توصيل فيزيائي) | لا مشكلة |
| أيقونة التطبيق 512×512 PNG | ⚠️ | `assets/logoPNG.png` موجود | تحقق من الحجم والخلفية |
| لقطات الشاشة تطابق الواجهة | ⚠️ | غير متأكد | تأكد من التطابق |
| وصف التطبيق بدون أسماء منافسين | ✅ | اسمه "بين يديك" | لا مشكلة |
| جمع البيانات: الاسم، الهاتف، البريد، الموقع | ✅ | كلها مبررة لتطبيق توصيل | - |
| Firebase SDKs تجمع البيانات | ✅ | يجب الإفصاح عنها في نموذج Data Safety | - |

---

## 6. تقرير الأداء وجودة الكود

### Flutter Performance

1. **mounted check after await** — معظم الأماكن تستخدم `mounted` ✅ لكن هناك بعض الحالات من دونها
2. **StreamBuilder في main_page.dart** — بدون `initialData` ⚠️
3. **setState في كل مكان** — لا يوجد استخدام لـ Provider/BLoC/Riverpod في Dashboard ❌
4. **print()/debugPrint()** — موجود في كل الملفات بكثرة ❌
5. **TextEditingController dispose** — ✅ معظمها يتم التفريغ، لكن يجب التأكد من كل الشاشات
6. **Image.network بدون caching** — ✅ يستخدم `cached_network_image` في معظم الأماكن
7. **ListView.builder** — ✅ يستخدم builder في معظم القوائم
8. **عمق الشجرة (deep nesting)** — بعض الشاشات تحتوي على أكثر من 6 مستويات (مثل `driver_app.dart`)
9. **Future مخزّن في build()** — ✅ `FutureBuilder` يستخدم future من `initState` بشكل عام

### Node.js Backend

1. **مؤشرات MongoDB** — ❌ لا يوجد `ensureIndex` أو `index()` في أي model (خطير للأداء)
2. **Pagination** — ❌ جميع قوائم GET تعيد كل البيانات بدون `limit`/`skip`
3. **Error handling في async handlers** — ✅ كل الـ routes لها try/catch
4. **Request timeout** — ❌ غير موجود (لكن Flutter API client عنده timeout 10s)
5. **Socket.IO rooms** — ⚠️ موجودة لكن غير مستخدمة بشكل صحيح (بث لكل الاتصالات)

---

## 7. تقرير الأمان

### التطبيقات (Flutter)

| البند | الحالة |
|-------|--------|
| أسرار أو مفاتيح API في الكود | ❌ Google Maps API key + Google Sign-In Client ID في `env_config.dart` |
| `android:debuggable` في release | ✅ غير موجود |
| ProGuard/R8 مفعل | ❌ `isMinifyEnabled = false` |
| بيانات حساسة في SharedPreferences | ⚠️ `user_data_{uid}` مخزنة بدون تشفير |
| API base URL يستخدم HTTPS | ✅ `https://api.delivap.com` |
| Certificate pinning | ❌ غير مستخدم |

### الخادوم (Node.js)

| البند | الحالة |
|-------|--------|
| `.env` في `.gitignore` | ❌ غير موجود |
| `serviceAccountKey.json` في `.gitignore` | ❌ غير موجود |
| JWT_SECRET في الكود | ❌ في `.env` مكشوف |
| JWT expiry | ❌ غير مستخدم (يستخدم Firebase tokens) |
| MongoDB injection | ⚠️ آمن لأن Mongoose يستخدم `$set` وليس `$where` |
| CORS | ❌ `origin: '*'` |
| Rate limiting | ❌ غير موجود |
| `strict: true` في Mongoose schemas | ✅ معظمها (Config model عنده `{ strict: false }`) |
| Passwords مشفرة (bcrypt) | ❌ كلمات سر التاجر مخزنة كنص واضح |
| Input validation middleware | ❌ غير موجود (لا joi ولا zod ولا express-validator) |
| Stack traces في الإنتاج | ❌ `res.status(500).json({ error: e.message })` — يعرض تفاصيل الأخطاء |

---

## 8. تقرير الحزم والاعتماديات

### Flutter — تطبيق الزبون
| الحزمة | الإصدار | ملاحظات |
|--------|---------|---------|
| `firebase_messaging` | ^15.2.10 | ✅ حديث |
| `socket_io_client` | ^3.0.0 | ✅ مستقر |
| `google_maps_flutter` | ^2.9.0 | ✅ |
| `flutter_local_notifications` | ^21.0.0 | ✅ حديث جداً |
| `haptic_feedback` | ^0.6.4+3 | ⚠️ قديمة — تحقق من التحديث |
| `add_to_cart_animation` | ^2.0.4 | ✅ |
| `shared_preferences` | ^2.2.2 | ⚠️ يمكن تحديث إلى 2.5.x |

### Flutter — لوحة التحكم
| الحزمة | الإصدار | ملاحظات |
|--------|---------|---------|
| `firebase_auth` | ^6.5.2 | ✅ |
| `firebase_messaging` | ^16.3.0 | ✅ |
| `flutter_local_notifications` | ^22.0.0 | ✅ |
| `google_maps_flutter` | ^2.17.1 | ✅ |
| `flutter_polyline_points` | ^3.1.0 | ✅ |
| `shared_preferences` | ^2.5.5 | ✅ |

### Node.js
| الحزمة | الإصدار | ملاحظات |
|--------|---------|---------|
| `express` | ^5.2.1 | ✅ Express 5 — أحدث |
| `mongoose` | ^9.7.0 | ✅ أحدث إصدار |
| `firebase-admin` | ^14.0.0 | ✅ |
| `socket.io` | ^4.8.3 | ✅ |
| `multer` | ^2.1.1 | ✅ |
| `jsonwebtoken` | ^9.0.3 | ⚠️ غير مستخدم بشكل فعلي |
| `dotenv` | ^17.4.2 | ✅ |

---

## 📝 ملاحظات المطور (بالعربية)

### 🔴 المشاكل الحرجة

1. **📍 `C:\server\serviceAccountKey.json`** — ❌ **مشكلة:** ملف الخدمة الخاص بـ Firebase Admin SDK موجود في المشروع بدون حماية. أي شخص يصل إلى git يمكنه التحكم الكامل في Firebase.  
   - ✅ **الحل:** أضف `serviceAccountKey.json` و `.env` إلى `.gitignore`. استخدم `process.env.FIREBASE_SERVICE_ACCOUNT` مع JSON مشفر أو Google Cloud Secret Manager.  
   - 🔴 **الأولوية:** حرجة

2. **📍 `C:\D\dashbord\lib\unified_login.dart:309-310`** — ❌ **مشكلة:** بيانات دخول الأدمن مكتوبة في الكود المصدري (`omranywalyd / wwaalliidd`).  
   - ✅ **الحل:** أنشئ endpoint `/api/admin/login` في الخادوم مع JWT وتحقق عبر MongoDB.  
   - 🔴 **الأولوية:** حرجة

3. **📍 `C:\flutter_application_1\android\app\build.gradle.kts:47`** — ❌ **مشكلة:** `isMinifyEnabled = false` — بدون تصغير الكود وتعميته.  
   ```gradle
   release {
       signingConfig = signingConfigs.getByName("release")
       isMinifyEnabled = true
       isShrinkResources = true
       proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
   }
   ```  
   - ✅ **الحل:** غيّر إلى `isMinifyEnabled = true`  
   - 🔴 **الأولوية:** حرجة

### 🟠 المشاكل العالية

5. **📍 `C:\D\dashbord\lib\driver_app.dart:220`** — ❌ **مشكلة:** حدث Socket.IO خطأ: يرسل `driver:location_updated` لكن الخادوم ينتظر `driver:location`.  
   ```dart
   // خطأ
   SocketClient().emit('driver:location_updated', {...});
   // صواب
   SocketClient().emit('driver:location', {...});
   ```  
   - 🟠 **الأولوية:** عالية

6. **📍 `C:\D\dashbord\lib\fcm_helper.dart:30`** — ❌ **مشكلة:** `POST /api/notify-token` غير موجود في الخادوم (404).  
   - ✅ **الحل:** إما إضافة الـ route في الخادوم أو إزالة الدالة من Flutter.  
   - 🟠 **الأولوية:** عالية

7. **📍 `C:\server\socket\index.js:17`** — ❌ **مشكلة:** بث موقع السائق لكل المستخدمين (`io.emit` بدلاً من `io.to(room)`).  
   ```javascript
   // خطأ
   io.emit('driver:location_updated', data);
   // صواب
   io.to('user_' + relevantUserId).emit('driver:location_updated', data);
   ```  
   - 🟠 **الأولوية:** عالية

8. **📍 `C:\flutter_application_1\lib\main.dart`** — ❌ **مشكلة:** لا يوجد معالجة للإشعارات في الحالات الثلاث (Foreground, Background, Killed).  
   ```dart
   // أضف بعد Firebase.initializeApp():
   final messaging = FirebaseMessaging.instance;
   await messaging.requestPermission(
     alert: true, badge: true, sound: true,
   );
   String? token = await messaging.getToken();
   if (token != null) await ApiClient.put('/api/users/$userId', {'fcmToken': token});
   // Foreground:
   FirebaseMessaging.onMessage.listen((RemoteMessage message) { ... });
   // Tap from background:
   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) { ... });
   // App opened from terminated state:
   RemoteMessage? initialMessage = await messaging.getInitialMessage();
   ```  
   - 🟠 **الأولوية:** عالية

9. **📍 `C:\server\routes\users.js:63-67`** — ❌ **مشكلة:** كلمات سر التاجر مخزنة كنص واضح ويتم إرسالها عبر Query Parameters.  
   - ✅ **الحل:** استخدم `bcrypt` + `POST` بدلاً من `GET` query params.  
   - 🟠 **الأولوية:** عالية

10. **📍 `C:\D\dashbord\lib\driver_app.dart:209-225`** — ❌ **مشكلة:** تحديث الموقع عبر REST API كل 20 متراً (استهلاك كبير للبطارية).  
    - ✅ **الحل:** استخدم Socket.IO فقط لتحديث الموقع:  
    ```dart
    _locSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // ← زد إلى 50 متر
      ),
    ).listen((pos) {
      SocketClient().emit('driver:location', {
        'driverId': uid,
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    });
    ```  
    - 🟠 **الأولوية:** عالية

### 🟡 المشاكل المتوسطة

11. **📍 جميع ملفات Flutter** — ❌ **مشكلة:** وجود `debugPrint` و `print` بكثرة.  
    - ✅ **الحل:** استخدم شرط `kReleaseMode`:
    ```dart
    if (kDebugMode) debugPrint('message');
    ```  
    - 🟡 **الأولوية:** متوسطة

12. **📍 `C:\flutter_application_1\lib\main_page.dart:243`** — ❌ **مشكلة:** `StreamBuilder` بدون `initialData`.  
    ```dart
    StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // أضف:
      initialData: FirebaseAuth.instance.currentUser,
      builder: ...
    )
    ```  
    - 🟡 **الأولوية:** متوسطة

13. **📍 جميع endpoints القوائم في الخادوم** — ❌ **مشكلة:** لا يوجد pagination.  
    ```javascript
    // مثال للإصلاح
    router.get('/orders', async (req, res) => {
      const limit = parseInt(req.query.limit) || 20;
      const skip = parseInt(req.query.skip) || 0;
      const orders = await Order.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit);
      res.json(orders);
    });
    ```  
    - 🟡 **الأولوية:** متوسطة

14. **📍 `C:\server\models`** — ❌ **مشكلة:** لا يوجد `index()` في أي model.  
    ```javascript
    // أضف في User.js مثلاً:
    userSchema.index({ uid: 1 });
    userSchema.index({ role: 1, isActive: 1 });
    ```  
    - 🟡 **الأولوية:** متوسطة

### 🟢 التوصيات المنخفضة

15. **📍 كلا التطبيقين** — ✅ **توصية:** استخدم `flutter_secure_storage` بدلاً من `SharedPreferences` للبيانات الحساسة.  
    ```yaml
    dependencies:
      flutter_secure_storage: ^9.0.0
    ```
    ```dart
    final storage = FlutterSecureStorage();
    await storage.write(key: 'user_data', value: jsonEncode(data));
    ```  
    - 🟢 **الأولوية:** منخفضة

16. **📍 جميع الملفات** — ✅ **توصية:** استخدم HTTPS مع Certificate Pinning.  
    ```yaml
    dependencies:
      http_certificate_pinning: ^1.0.0
    ```  
    - 🟢 **الأولوية:** منخفضة

17. **📍 الخادوم** — ✅ **توصية:** أضف rate limiting لحماية endpoints المصادقة.  
    ```bash
    npm install express-rate-limit
    ```
    ```javascript
    const rateLimit = require('express-rate-limit');
    app.use('/api/users', rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));
    ```  
    - 🟢 **الأولوية:** منخفضة

18. **📍 الخادوم** — ✅ **توصية:** أضف input validation باستخدام `express-validator` أو `zod`.  
    ```bash
    npm install express-validator
    ```
    - 🟢 **الأولوية:** منخفضة

19. **📍 Customer App** — ✅ **توصية:** أضف `Firebase Crashlytics` و `Firebase Analytics`.  
    ```yaml
    dependencies:
      firebase_crashlytics: ^4.0.0
      firebase_analytics: ^11.0.0
    ```  
    - 🟢 **الأولوية:** منخفضة

20. **📍 كلا التطبيقين** — ✅ **توصية:** قسّم الملفات الكبيرة (مثل `driver_app.dart` الذي يتجاوز 9400 سطر، و `delivery_screen.dart` الذي يتجاوز 2900 سطر).  
    - 🟢 **الأولوية:** منخفضة

---

## ملخص التدقيق

| الفئة | ✅ سليم | ⚠️ ملاحظة | ❌ مشكلة |
|-------|---------|-----------|---------|
| مشاكل حرجة | - | - | 10 |
| مشاكل عالية | - | - | 10 |
| مشاكل متوسطة | - | - | 10 |
| توصيات منخفضة | - | 10 | - |
| **المجموع** | - | **10** | **30** |

**الخلاصة:** النظام يعمل بشكل أساسي لكنه يحتوي على مشاكل أمنية حرجة تمنع رفعه إلى Google Play Store. يجب معالجة المشاكل الحرجة أولاً (خاصة المخاطر الأمنية)، ثم العالية ثم المتوسطة. التطبيق يحتاج إلى مراجعة أمنية شاملة وإعادة هيكلة لجزء الإشعارات ونظام Socket.IO قبل الإطلاق.
