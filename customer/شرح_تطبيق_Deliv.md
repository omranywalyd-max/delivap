# 📱 تطبيق Deliv — شرح كامل

تطبيق توصيل طلبيات وسيارات أجرة وخدمات متكامل مبني بـ **Flutter** مع Firebase.

---

## 🎨 الألوان الأساسية (من `theme.dart`)

| اللون | الكود | الاستخدام |
|-------|-------|-----------|
| `#7D29C6` | `primary` | اللون الرئيسي (بنفسجي) — الأزرار، الأيقونات، التبويب المحدد |
| `#9232E8` | `accent` | أكسنت (بنفسجي فاتح) — التدرجات، اللمسات |
| `#6D22AC` | `primaryDark` | بنفسجي داكن — التدرجات |
| `#F1F0F5` | `background` | خلفية الصفحات (رمادي بارد جداً) |
| `#DCDAE6` | `cardColor` | لون الكروت |
| `#B8B1C8` | `neumShadow` | ظل نيومورفيك (رمادي بنفسجي) |
| `#D8D7DE` | `neumLight` | الضوء في النيومورفيك |
| `#2D2A3A` | `textDark` | النصوص الأساسية |
| `#6E6B7B` | `textGrey` | النصوص الثانوية |
| `#27AE60` | `success` | أخضر — نجاح، موافقة |
| `#D50000` / `#FF5252` | `danger` / `error` | أحمر — أخطاء، إلغاء |
| `#9C27B0` | `warning` | تحذير |
| `#FFFFFF` | `white` | أبيض |

> **اتجاه الألوان:** تدرج بنفسجي من اليمين إلى اليسار في الأزرار والكروت المميزة.

---

## 📂 هيكلة المشروع

```
lib/
├── main.dart                          # نقطة الدخول — MaterialApp + routes
├── theme.dart                         # الألوان + ThemeData + نيومورفيك
├── user_local.dart                    # تخزين محلي لبيانات المستخدم
├── splash_screen.dart                 # شاشة البداية (GIF)
├── main_page.dart                     # الصفحة الرئيسية (StreamBuilder<FirebaseUser>)
├── bottom_nav.dart                    # الـ BottomNavigationBar المخصص
│
├── org/
│   └── org.dart                       # Onboarding (3 شاشات تعريفية)
│
├── Sign in/
│   ├── sign_in.dart                   # تسجيل الدخول (بريد + Google + Facebook)
│   └── auth_service.dart              # خدمة المصادقة (FirebaseAuth)
│
├── Sign Up/
│   └── Sign_Up.dart                   # إنشاء حساب + PhoneScreen + LocationScreen
│
├── Services/
│   ├── Services.dart                  # شاشة الخدمات (توصيل، إحضار، تاكسي...)
│   ├── delivery_screen.dart           # ServiceOrderScreen, TransportOrderScreen, MapPickerScreen
│   ├── api_client.dart                # عميل API (HTTP)
│   ├── socket_client.dart             # WebSockets للتواصل المباشر
│   └── env_config.dart                # إعدادات البيئة
│
├── Order/
│   ├── Order.dart                     # OrdersScreen (جارية + منتهية)
│   ├── order_models.dart              # Models: Order, OrderItem, OrderStatus
│   ├── active_orders_screen.dart      # الطلبات الجارية (قائمة + تتبع)
│   └── notification_helperr.dart      # مساعد الإشعارات
│
├── dashboard_screen.dart              # الصفحة الرئيسية (المتاجر، العروض، البحث)
├── dashboard_search_bar.dart          # شريط البحث
├── stores_widget.dart                 # قائمة المتاجر الأفقية (دوائر)
├── stores_view.dart                   # شبكة أقسام المتجر (Category Cards)
├── products_list_screen.dart          # قائمة المنتجات (8 Styles)
├── product_detail_sheet.dart          # تفاصيل المنتج + المشروبات
├── cardd.dart                         # CartScreen + تأكيد الطلبية
├── saved_orders_screen.dart           # الطلبيات المحفوظة
├── driver_selection_screen.dart       # اختيار السائق
├── profile_screen.dart                # الملف الشخصي + تعديل + مكافآت
├── messages_screen.dart               # المحادثة مع الإدارة
├── notification_settings_screen.dart  # إعدادات الإشعارات
├── custom_order_story_view.dart       # طلب حسب الطلب (صورة + وصف)
├── neumorphic_open_container.dart     # حاوية نيومورفيك عامة
├── app_cached_image.dart              # صور مخبأة
├── ModelSelectionDialog.dart          # اختيار الموديل/المقاس
├── store_accounts_screen.dart         # حسابات المتاجر
└── cardd.dart                         # السلة + تأكيد الطلبية
```

---

## 📄 الصفحات كاملة

### 1. `splash_screen.dart` — شاشة البداية
- خلفية: **تدرج بنفسجي** (#7D29C6 → #5B1D9E)
- يعرض GIF (`assets/deliv.gif`)
- بعد 3.6 ثانية يقرر: **OnboardingScreen** (لأول مرة) أو **MainPage**
- ترجمة: `precacheImage` → `_startSplash` → `SharedPreferences`

### 2. `org/org.dart` — Onboarding (التعريف بالتطبيق)
- 3 صفحات تعريفية (PageView):
  1. "مرحبًا بك في Deliv"
  2. "توصيل سريع وآمن"
  3. "تتبع طلبك"
- حفظ `is_first_time = false` بعد العرض
- يستعمل ألوان: `kPrimaryColor`, `kNeumShadow`

### 3. `main_page.dart` — الصفحة الرئيسية (سقالة التطبيق)
- **StreamBuilder\<User?\>** من FirebaseAuth
- **غير مسجل:** DashboardScreen + ServicesScreen + OrdersScreen + SignInScreen
- **مسجل:** DashboardScreen + ServicesScreen + OrdersScreen + ProfileScreen
- يتفقد: **Ban** ← **Deactivated** ← Gender → Phone → Location → التطبيق الكامل
- IndexedStack مع BottomNavBar
- **SocketClient** للأحداث المباشرة (حذف الحساب، تحديث المستخدم)

### 4. `bottom_nav.dart` — شريط التنقل السفلي
- **Gradient بنفسجي** (#9232E8 → #7D29C6 → #6D22AC)
- GNav مع تأثيرات زجاجية (Glossy)
- الأيقونات: الرئيسية، الخدمات، الطلبيات، الحساب
- **ظل بنفسجي متوهج** (#7D29C6.withOpacity(0.4))
- Border أبيض شفاف 0.2

### 5. `dashboard_screen.dart` — الصفحة الرئيسية (المتاجر)
- **Animations**: 4 مراحل (Header → Search → Banner → Content)
- **LocationProvider**: متتبع الموقع (Singleton + ChangeNotifier)
- **Neumorphic Container**: ظل (#B8B1C8) من الجانبين
- المكونات:
  - `_UserAvatar` (حسب الجنس: `avatar.png` / `avatarf.png`)
  - `_LocationChip` (تدرج #F1F0F5 → #E6E4F0 + أيقونة بنفسجية)
  - `DashboardSearchBar`
  - `_PromotionsBanner` (PageView + تمرير تلقائي كل 3 ثوانٍ)
  - `StoresWidget` (قائمة المتاجر الأفقية)
  - `StoresView` (أقسام المتجر)
- **Double-click Back** للخروج
- **RefreshIndicator** مع سحب للتحديث
- Gradient أعلى الشاشة (#8F698F → #A7A6A7 → #9F7BB1)

### 6. `stores_widget.dart` — المتاجر (أفقية)
- دوائر للمتاجر مع صورة + اسم
- اللون المحدد: **بنفسجي (#7D29C6)** مع ظل متوهج
- **Stagger animation** (تأخير تدريجي للظهور)

### 7. `stores_view.dart` — أقسام المتجر (شبكة 2 عمود)
- `CategoryCardWidget`: صورة + اسم + مسافة
- كارد "حسب الطلب" مع **Pulse Animation**
- حساب المسافة (Haversine formula) ← تصفية المحلات البعيدة
- **CatCache** (20 دقيقة TTL)

### 8. `products_list_screen.dart` — المنتجات (8 Styles)
- 8 أنماط عرض مختلفة:
  - **Style 1**: شبكة 3 أعمدة (عادي)
  - **Style 2**: بيتزا — 2 عمود + PizzaDetailSheet
  - **Style 3**: باتيسري — 2 عمود + ProductDetailSheet
  - **Style 4**: خضر وفواكه — وزن/مبلغ
  - **Style 5**: كوسميتيك — تفاصيل
  - **Style 6**: مشاريع حسب الطلب — معرض صور
  - **Style 7**: فارماسي — أحجام متعددة
  - **Style 8**: منتجات صور — سعر أساسي + أحجام اختيارية
- **CartProvider** (ChangeNotifier) + **GlobalCart**
- **AddToCartAnimation** (إضافة للسلة مع حركة)
- بحث، ترتيب (سعر)، مفضلات، ترشيح بالسعر
- **ProdCache** (10 دقائق) + **DrinksCache**
- شريط السلة السفلي (Gradient لون المتجر)

### 9. `product_detail_sheet.dart` — تفاصيل المنتج
- BottomSheet كامل لتفاصيل المنتج
- دعم المشروبات (DrinkPickerDialog)
- اختيار المقاسات والنكهات

### 10. `cardd.dart` — سلة المشتريات + تأكيد الطلب
- **CartScreen**: قائمة المنتجات في السلة
- تعديل الكمية، حذف، إضافة ملاحظة
- اختيار السائق (DriverSelectionScreen)
- إرسال الطلب (FCMSender ← إشعار للسائق)
- حفظ الطلب (SavedOrdersScreen)

### 11. `Services/Services.dart` — شاشة الخدمات
- قسمين: **شحن وتوصيل** + **خدمات التنقل**
- 5 خدمات:
  - توصيل الطلبيات (بنفسجي)
  - إحضار الطلبيات (#283593 أزرق)
  - طلب سيارة أجرة (#E65100 برتقالي)
  - طلب هاربين (#00695C أخضر داكن)
  - طلب فورغو (#4527A0 بنفسجي غامق)
- Animation متدرج + Stagger
- Gradient الخلفية (#F1F0F5 → #E6E4F0)

### 12. `Services/delivery_screen.dart` — شاشات الخدمات الكاملة
- **ServiceOrderScreen**: توصيل/إحضار (خريطة + عنوان + صورة)
- **TransportOrderScreen**: تاكسي/هاربين/فورغو (نقطة انطلاق + وجهة)
- **MapPickerScreen**: خريطة Google Maps + بحث + GPS
- **ServiceDriverSelectionScreen**: رادار السائقين المتاحين

### 13. `Order/Order.dart` — صفحة الطلبيات
- **SummaryCard** (Gradient بنفسجي): جارية | منتهية | ملغاة
- **TabBar**: جارية / منتهية
- **NeumTabBar** (Gradient بنفسجي)
- **Shimmer loading** + Stagger animation
- **Socket events**: خدمة محدثة، طلب محدث، عرض سعر جديد
- 3 أنواع: TransportCard, ServiceOrderCard, AnimCard (Order)
- **StatusBar**: 5 خطوات (انتظار → قبول → شراء → طريق → وصول)

### 14. `Order/active_orders_screen.dart` — الطلبات الجارية
- بحث في الطلبات
- Auto-refresh كل 15 ثانية
- 4 أقسام: مشاريعي، طلبات النقل، طلبات الخدمة، الطلبات
- Track driver (DriverTrackingScreen)
- تغيير السائق (ChangeDriverSheet)
- إعادة الطلب (ReorderSheet)
- PriceChangedBanner, UnavailableAlternativesBanner, CounterOfferBanner
- إخفاء الطلبية

### 15. `profile_screen.dart` — الملف الشخصي
- Header (Gradient بنفسجي): الصورة، الاسم، البريد، الجنس
- **برنامج المكافآت**: كارد بنفسجي مع نقاط السائقين
- معلومات الحساب (هاتف، بريد، جنس)
- المواقع المحفوظة (إضافة + حذف + تعديل)
- الإجراءات: تعديل، إشعارات، تسجيل خروج، حذف حساب
- **ProfileMiniMenu**: BottomSheet سريع للملف

### 16. `Sign in/sign_in.dart` — تسجيل الدخول
- حقل بريد + كلمة سر (نيومورفيك)
- Google + Facebook
- نسيت كلمة السر (إعادة تعيين)
- "ليس لديك حساب؟ إنشاء حساب"
- **GenderScreen**: اختيار الجنس (ذكر/أنثى) — Gradient بنفسجي
- Privacy Policy link

### 17. `Sign Up/Sign_Up.dart` — إنشاء حساب (3 خطوات)
- **Step 1**: الاسم، اللقب، الجنس، البريد، كلمة السر
- **Step 2 (PhoneScreen)**: رقم الهاتف + بطاقة توعوية (خصوصية)
- **Step 3 (LocationScreen)**: اسم الموقع + اختيار من الخريطة
- NeuField, GradientButton, ErrorBox مشتركة
- QuickLabels (منزل، عمل، دراسة، عائلة)

### 18. `messages_screen.dart` — المحادثة مع الإدارة
- إرسال/استقبال رسائل عبر API + WebSocket
- فقاعات: **الإدارة** (أسود #2D2A3A) / **المستخدم** (أبيض)
- Scroll تلقائي للأسفل
- زر إرسال (#2D2A3A)

### 19. `notification_settings_screen.dart` — إعدادات الإشعارات
- Toggle: إلغاء صوت الإشعارات
- Toggle: إلغاء إشعارات تم شراء منتج
- حفظ الإعدادات عند التغيير (API.put)
- CupertinoSwitch باللون البنفسجي

### 20. `custom_order_story_view.dart` — طلب حسب الطلب
- نموذج: صورة + اسم المنتج + سعر + وصف + عنوان الشراء
- رفع الصورة (ImagePicker + API)
- إضافة للسلة

### 21. `saved_orders_screen.dart` — الطلبيات المحفوظة
- حفظ الطلبيات كمسودة (Draft)
- إعادة استخدام طلبية سابقة
- أزرار: حذف، استخدام

### 22. `driver_selection_screen.dart` — اختيار السائق
- قائمة السائقين المتاحين
- اختيار السائق المفضل

### 23. `neumorphic_open_container.dart` — حاوية نيومورفيك
- Widget عام لعناصر نيومورفيك

---

## 🛠 التقنيات المستخدمة

| التقنية | الاستخدام |
|---------|-----------|
| **Firebase Core** | تشغيل Firebase |
| **Firebase Auth** | تسجيل/دخول (بريد + Google) |
| **Firebase Messaging** | الإشعارات الفورية |
| **Flutter Local Notifications** | إشعارات محلية |
| **Google Maps** | الخريطة + تتبع السائق |
| **Geolocator** | تحديد المواقع |
| **Geocoding** | تحويل الإحداثيات إلى عنوان |
| **HTTP / ApiClient** | REST API |
| **Socket.io** | WebSockets (أحداث مباشرة) |
| **CachedNetworkImage** | تحميل الصور + تخزين مؤقت |
| **Image Picker** | اختيار الصور من الكاميرا/المعرض |
| **SharedPreferences** | تخزين محلي (Onboarding) |
| **Google Nav Bar** | Bottom Navigation |
| **Add to Cart Animation** | أنيميشن إضافة للسلة |
| **Provider (ChangeNotifier)** | إدارة الحالة (Cart, Location) |

---

## 🔄 تدفق المستخدم الكامل

```
Splash → Onboarding (مرة واحدة) → MainPage
                                    │
                          ┌─────────┼─────────┐
                    غير مسجل       مسجل (يحتاج)
                                    │
                            ┌───────┴───────┐
                        ينقص جنس     ينقص هاتف
                            │              │
                      GenderScreen    PhoneScreen
                            │              │
                            └───────┬───────┐
                                ينقص موقع
                                    │
                              LocationScreen
                                    │
                              ┌─────┘
                         التطبيق الكامل
                    ┌───────────┬───────────┬───────────┐
                الرئيسية     الخدمات     الطلبيات    الحساب
                    │            │            │           │
              متاجر+عروض    توصيل+تنقل   جارية+منتهية   ملف+مكافآت
              منتجات+سلة                              إعدادات+خروج
```

---

## ☁️ API Endpoints المستخدمة

| المسار | الطريقة | الوصف |
|--------|---------|-------|
| `/api/users/{uid}` | GET/PUT/DELETE | المستخدم |
| `/api/users/{uid}/messages` | GET | رسائلي |
| `/api/users/{uid}/messages/reply` | POST | رد على رسالة |
| `/api/users/{uid}/saved-locations` | GET/POST | المواقع المحفوظة |
| `/api/users/{uid}/saved-locations/{id}` | DELETE | حذف موقع |
| `/api/stores` | GET | المتاجر |
| `/api/categories` | GET | الأقسام |
| `/api/products` | GET | المنتجات |
| `/api/promotions` | GET | العروض |
| `/api/orders` | GET/POST/PUT | الطلبيات |
| `/api/transport-orders` | GET | طلبات النقل |
| `/api/service-orders` | GET | طلبات الخدمة |
| `/api/drivers/{id}` | GET | بيانات السائق |
| `/api/drivers/available` | GET | السائقين المتاحين |
| `/api/favorites` | GET | المفضلات |
| `/api/drinks` | GET | المشروبات |
| `/api/project-deliveries` | GET | توصيلات المشاريع |

---

## 📱 أسماء الصفحات والمسارات

| المسار | الشاشة | الملف |
|--------|--------|-------|
| `/` | SplashScreen | `splash_screen.dart` |
| `/home` | MainPage (IndexedStack) | `main_page.dart` |
| `/map-picker` | MapPickerScreen | `Services/delivery_screen.dart` |
| `/phone_screen` | PhoneScreen | `Sign Up/Sign_Up.dart` |
| `/location_screen` | LocationScreen | `Sign Up/Sign_Up.dart` |
| — | OnboardingScreen | `org/org.dart` |
| — | SignInScreen | `Sign in/sign_in.dart` |
| — | SignUpScreen | `Sign Up/Sign_Up.dart` |
| — | GenderScreen | `Sign in/sign_in.dart` |
| — | DashboardScreen | `dashboard_screen.dart` |
| — | ServicesScreen | `Services/Services.dart` |
| — | OrdersScreen | `Order/Order.dart` |
| — | ProfileScreen | `profile_screen.dart` |
| — | ProductsListScreen | `products_list_screen.dart` |
| — | CartScreen | `cardd.dart` |
| — | SavedOrdersScreen | `saved_orders_screen.dart` |
| — | ActiveOrdersScreen | `Order/active_orders_screen.dart` |
| — | NotificationSettingsScreen | `notification_settings_screen.dart` |
| — | MessagesScreen | `messages_screen.dart` |
| — | EditProfileScreen | `profile_screen.dart` |
| — | ServiceOrderScreen | `Services/delivery_screen.dart` |
| — | TransportOrderScreen | `Services/delivery_screen.dart` |
| — | DriverTrackingScreen | `Order/active_orders_screen.dart` |
| — | CustomOrderStoryView | `custom_order_story_view.dart` |

---

## ⚡ Socket Events

| الحدث | الاستماع | الإرسال |
|-------|----------|---------|
| `user:updated` | تحديث بيانات المستخدم | — |
| `user:deleted` | حذف الحساب | — |
| `order:updated` | تحديث الطلبية | — |
| `order:created` | طلبية جديدة | — |
| `service:updated` | تحديث طلب الخدمة | — |
| `service:created` | طلب خدمة جديد | — |
| `transport:updated` | تحديث طلب النقل | — |
| `transport:created` | طلب نقل جديد | — |
| `delivery:updated` | تحديث التوصيل | — |
| `delivery:created` | توصيل جديد | — |
| `new_message` | رسالة جديدة من الإدارة | — |
| `driver:status_changed` | تغير حالة السائق | — |

---

## 📝 ملاحظات إضافية

- **Neumorphism**: التصميم يستعمل النيومورفيك (ظل داخلي/خارجي) في معظم الكروت والحقول.
- **الاتجاه**: التطبيق كامل RTL (من اليمين لليسار) باللغة العربية.
- **الخط**: Amiri (عربي) + Cairo (للأرقام).
- **الأيقونات**: CupertinoIcons (أيقونات iOS) في كل مكان.
- **النسخة**: Material3 + `useMaterial3: true`.
- **التدرجات**: Gradient من اليمين إلى اليسار (begin: centerRight, end: centerLeft).
