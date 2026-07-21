# 📱 Deliv ديليف - دليل نشر التطبيق في Google Play Store

## 📋 ملخص الخطوات

| # | الخطوة | الوقت المقدر |
|---|--------|-------------|
| 1 | إنشاء حساب مطور Google Play | 48 ساعة (التوثيق) |
| 2 | بناء AAB (App Bundle) | 10 دقائق |
| 3 | إعداد Store Listing | 30 دقيقة |
| 4 | إعداد Content Rating | 10 دقائق |
| 5 | إعداد Data Safety | 20 دقيقة |
| 6 | إعداد Privacy Policy | 5 دقائق |
| 7 | رفع التطبيق واختباره | 15 دقيقة |
| 8 | المراجعة والنشر | 3-7 أيام |

---

## الخطوة 1: إنشاء حساب مطور Google Play

1. دخل على https://play.google.com/console
2. سجّل بحساب Gmail جديد أو اللي عندك
3. دفع **25$** (مرة واحدة للعمر)
4. أكمل **توثيق الهوية** (ID Card + selfie) - ممكن ياخذ من 24 لـ 48 ساعة
5. حسابك يتحوّل لـ **Developer Account**

> ⚠️ **مهم**: استعمل Gmail رسمي فيه اسم حقيقي - قوقل كيرفض الحسابات المجهولة

---

## الخطوة 2: بناء AAB (App Bundle)

### في terminal، سوّ هاد الأوامر:

```bash
cd C:\flutter_application_1

# نظّف المشروع
flutter clean

# حدّث الباكيجات
flutter pub get

# بناء Release AAB
flutter build appbundle --release
```

> ⚠️ **مهم**: خصك الـ **keystore signing** يكون معد مزيان. تأكد من `key.properties`:
> ```
> storePassword=كلمة_مرور_keystore
> keyPassword=كلمة_مرور_key
> keyAlias=deliv
> storeFile=../../keystore.jks
> ```

### الملف اللي يطلع:
```
build/app/outputs/bundle/release/app-release.aab
```

هادا الملف اللي غادي ترفعه لـ Google Play Console.

---

## الخطوة 3: إنشاء التطبيق في Google Play Console

1. دخل على https://play.google.com/console
2. اضغط **"Create app"**
3. حط المعلومات:

| الحقل | القيمة |
|-------|--------|
| **App name** | `Deliv ديليف` |
| **Default language** | Arabic (Morocco) |
| **App or game** | App |
| **Free or paid** | Free |
| **Contains ads** | No |
| **Store listing not directed to children** | Yes |

4. اضغط **"Create app"**

---

## الخطوة 4: Store Listing (قائمة المتجر)

### 4.1 Main store listing

#### App name (الاسم):
```
Deliv ديليف
```

#### Short description (الوصف القصير - 80 حرف بالzeptzer):
```
تطبيق توصيل سريع وموثوق من محلاتك المفضلة مباشرة لباب دارك
```

#### Full description (الوصف الكامل - 4000 حرف):
```
Deliv ديليف - تطبيق التوصيل الأسرع في المغرب 🚀

طلّب من محلاتك المفضلة ومطاعمك اللي كتحب، وتوصلك لباب دارك بالدراجة النارية في أقل من 30 دقيقة.

🔥 مميزات التطبيق:
• تصفح عشرات المحلات والمطاعم القريبة منك
• اختر منتجاتك بدقة من كتالوغات محدّثة
• تتبع السائق في الوقت الحقيقي على الخريطة
• ادفع بالبطاقة البنكية أو عند الاستلام
• احفظ عناوينك المفضلة (الدار، الخدمة، الخوت...)
• اطلب توصيل سريع بالدراجة النارية
• تقييم المحلات والسائقين
• سجل طلباتك السابقة وأعد الطلب بضغطة واحدة

📍 الموقع:
يُستخدم لعرض المحلات القريبة منك وحساب مسافة التوصيل والسائقين المتوفرين في منطقتك.

👤 المعلومات الشخصية (الاسم، الإيميل، رقم التيليفون):
تُستخدم لإنشاء حسابك والتواصل معك بشأن طلبك وتأكيد التوصيل.

📸 الصور:
تُستخدم لرفع صور الملف الشخصي والطلبات المخصصة (عندما تريد طلب منتج بعينه).

🔔 الإشعارات:
تُستخدم لإرسال إشعارات حالة طلبك (تم القبول، في الطريق، تم التوصيل).

🛡️ الخصوصية:
نحترم خصوصيتك. لا نشارك معلوماتك مع أي طرف ثالث. يمكنك حذف حسابك في أي من داخل التطبيق.

الموقع: يُستخدم لعرض المحلات القريبة وحساب مسافة التوصيل
المعلومات الشخصية: للتواصل بشأن الطلبات
الصور: لرفع صور الملف الشخصي والطلبات المخصصة
الجهاز (FCM Token): لإرسال الإشعارات
معلومات الشراء: لتتبع الطلبات
```

### 4.2 Graphic assets

| الأصل | الحجم | المطلوب |
|-------|-------|---------|
| **App icon** | 512x512 PNG | ✅ مطلوب - بدون زوايا مدورة |
| **Feature graphic** | 1024x500 PNG | ✅ مطلوب |
| **Phone screenshots** | 16:9 أو 9:16 | ✅ 2-8 صور على الأقل |
| **Tablet screenshots** | 7:10 أو 10:7 | اختياري |

> 💡 **نصيحة**: صوّر الشاشات من التطبيق على تيليفون حقيقي، ما تستخدمش emulator

---

## الخطوة 5: App content (محتوى التطبيق)

### 5.1 Privacy Policy

| الحقل | القيمة |
|-------|--------|
| **Privacy policy URL** | `https://delivap.com/privacy/privacy-policy-ar.html` |

> ⚠️ تأكد من أن الرابط شغال 24/7 ومتوفر بالعربية والإنجليزية

### 5.2 App access

اختار: **No, this app does not require access to any content or services that are restricted to a specific group of users**

### 5.3 Ads

اختار: **No, my app does not contain ads**

### 5.4 Content rating

أجب على الأسئلة:

| السؤال | الجواب |
|--------|--------|
| Which category best describes your app? | **Lifestyle** or **Shopping** |
| Does your app contain user-generated content? | **Yes** (صور الملف الشخصي) |
| If yes, can users upload content? | **Yes** |
| Can other users view this uploaded content? | **No** (غير صاحب الحساب) |
| Does your app allow users to interact? | **No** (مافيش محادثات مباشرة) |
| Does your app share users' personal information with other users? | **No** |
| Does your app contain features that are primarily appealing to children? | **No** |
| Does your app contain violent content? | **No** |
| Does your app contain sexual content? | **No** |
| Does your app contain drug-related content? | **No** |
| Does your app contain realistic violence? | **No** |
| Does your app contain blood and gore? | **No** |
| Does your app contain fear-inducing content? | **No** |

**النتيجة المتوقعة**: `Everyone` أو `Teen` (مقبول)

### 5.4 Data safety

> ⚠️ **مهم بزاف** - خصك ت declaring بالضبط شنو كتجمع من البيانات

#### Section 1: Data collection and security

| السؤال | الجواب |
|--------|--------|
| Does your app collect or share user data? | **Yes** |
| Is the data collected by your app encrypted in transit? | **Yes** |
| Can users request that their data be deleted? | **Yes** |

#### Section 2: Data types collected

**Location** (الموقع)
| الحقل | القيمة |
|-------|--------|
| Collected | ✅ Yes |
| Shared with third parties | ❌ No |
| Purpose | **App functionality** (حساب المسافة وعرض المحلات القريبة) |
| Optional | ❌ No (مطلوب للتطبيق) |

**Personal info** (معلومات شخصية: اسم، إيميل، تيليفون)
| الحقل | القيمة |
|-------|--------|
| Collected | ✅ Yes |
| Shared with third parties | ❌ No |
| Purpose | **Account management** + **App functionality** |
| Optional | ❌ No (مطلوب لإنشاء الحساب) |

**Photos and videos** (صور وفيديو)
| الحقل | القيمة |
|-------|--------|
| Collected | ✅ Yes |
| Shared with third parties | ❌ No |
| Purpose | **App functionality** (صور الملف الشخصي والطلبات المخصصة) |
| Optional | ✅ Yes |

**Device and other identifiers** (معرفات الجهاز: FCM Token)
| الحقل | القيمة |
|-------|--------|
| Collected | ✅ Yes |
| Shared with third parties | ✅ Yes (Firebase) |
| Purpose | **Analytics** + **App functionality** (推送通知) |

**Purchase history** (سجل الشراء)
| الحقل | القيمة |
|-------|--------|
| Collected | ✅ Yes |
| Shared with third parties | ❌ No |
| Purpose | **App functionality** (تتبع الطلبات) |

#### Section 3: Data safety section on store listing

اكتب في **Data safety description**:
```
نجمع بعض البيانات لتحسين تجربتك في التطبيق:
• موقعك: لعرض المحلات القريبة وحساب مسافة التوصيل
• معلوماتك الشخصية (الاسم، الإيميل، التيليفون): لإنشاء حسابك والتواصل معك
• صور: لرفع صور الملف الشخصي والطلبات المخصصة
• معرفات الجهاز: لإرسال الإشعارات عبر Firebase

لا نشارك معلوماتك مع أي طرف ثالث إلا Firebase (للإشعارات فقط).
يمكنك طلب حذف حسابك وبياناتك في أي من داخل التطبيق.
```

#### Section 4: Account deletion

| الحقل | القيمة |
|-------|--------|
| Can users request account deletion? | **Yes** |
| Account deletion link or instructions | `يمكن حذف الحساب من داخل التطبيق > الملف الشخصي > حذف الحساب` |

---

## الخطوة 6: Content declarations (تصنيف المحتوى)

### Government IDs
اختار: **No, my app does not request government-issued IDs**

### Financial info
| السؤال | الجواب |
|--------|--------|
| Does your app handle payment card data? | **No** (الدفع عند الاستلام أو عبر بوابة خارجية) |
| Does your app handle bank accounts? | **No** |

### Health
| السؤال | الجواب |
|--------|--------|
| Does your app collect health information? | **No** |

---

## الخطوة 7: Audience and content

### Target age group
اختار: **Not primarily directed to kids**

### Store listing directed to children
اختار: **No, my store listing is not directed to children under age 13**

---

## الخطوة 8: Countries and regions

اختار **Morocco** (المغرب) كدولة أساسية، ويمكنك إضافة دول أخرى لاحقاً.

---

## الخطوة 9: تسعير ونظام الدفع

اختار: **Free** (مجاني)

> ⚠️ التطبيق مجاني والدفع عند الاستلام، ما يحتاجش بوابة دفع في التطبيق

---

## الخطوة 10: رفع App Bundle ونشر التطبيق

1. روح لـ **Production** في Play Console
2. اضغط **"Create new release"**
3. اضغط **"Upload app bundle"** وارفع الملف:
   ```
   C:\flutter_application_1\build\app\outputs\bundle\release\app-release.aab
   ```
4. اكتب **Release notes** (ملاحظات الإصدار):
   ```
   الإصدار الأول من تطبيق Deliv ديليف
   - تصفح المحلات والمطاعم القريبة
   - طلب توصيل سريع
   - تتبع السائق في الوقت الحقيقي
   - الدفع عند الاستلام
   - حفظ العناوين المفضلة
   ```
5. اضغط **"Review release"**
6. راجع كل المعلومات
7. اضغط **"Start rollout to production"**

---

## ⏳ المدة المتوقعة

| المرحلة | المدة |
|---------|-------|
| مراجعة التطبيق (أول مرة) | **3-7 أيام** (ممكن أكثر) |
| مراجعة التحديثات | **ساعات إلى أيام** |
| تأخير المراجعة بسبب سياسات جديدة | **ممكن يصل لـ 14 يوم** |

---

## ⚠️ أخطاء شائعة تسبب الرفض - تجنّبهم

### 1.缺少 Privacy Policy
- **السبب**: لازم يكون عندك رابط Privacy Policy شغال وموجود في Store Listing
- **الحل**: تأكد من `https://delivap.com/privacy/privacy-policy-ar.html` شغال

### 2. Data Safety غير صحيح
- **السباب**: ما声明تش بالضبط شنو كتجمع من البيانات
- **الحل**: كمل Data Safety بالضبط كما هو مكتوب في الخطوة 5.4

### 3. SYSTEM_ALERT_WINDOW بدون مبرر
- **السبب**: إذن رسم فوق التطبيقات autres requires justification
- **الحل**: وضح في "App permissions" أنك كتستعملو لإشعار وصول السائق (مثل المكالمة)

### 4. USE_FULL_SCREEN_INTENT على Android 14+
- **السبب**: هادا إذن مقيد في Android 14+
- **الحل**: وضح أنه مخصص لـ "driver arrival alerts that function like incoming calls"

### 5. بدون Adaptive Icons
- **السباب**: قوقل باغي Adaptive Icons للجيل الجديد من الأجهزة
- **الحل**: ✅ تم إصلاحو - عندنا adaptive icons

### 6. Keystore ضايع
- **السبب**: لو فقدت الـ keystore ما تقدر تحدّث التطبيق
- **الحل**: خزّن `keystore.jks` في بلاصة آمنة واعمل backup!

### 7. معلومات حساب المطور ناقصة
- **السباب**: خصك تكمل معلوماتك الشخصية في حساب المطور
- **الحل**: روح لـ **Account details** في Play Console وكمّل كلشي

---

## 📦 ملخص الملفات اللي تغيّرو

| الملف | شنو تغيّر |
|-------|----------|
| `android/app/google-services.json` | حذف معلومات `com.deliv.driver` |
| `android/hs_err_pid*.log` | تحذفوهم (7 ملفات) |
| `lib/Services/env_config.dart` | حذف `googleMapsKey` المكرر |
| `lib/main.dart` | حذف `/api/debug/arrival-log` (3 بلايص) |
| `pubspec.yaml` | وصف التطبيق + حذف `dart_jsonwebtoken` |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | Adaptive Icon |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml` | Round Adaptive Icon |
| `android/app/src/main/res/values/colors.xml` | لون الخلفية `#7D29C6` |
| `android/app/src/main/res/drawable-*/ic_launcher_foreground.png` | أيقونة الأمام (5 أحجام) |

---

## 🔐 نصائح أمان مهمة

1. **لا ترفع `keystore.jks` لـ GitHub أو أي مستودع**
2. **لا ترفع `google-services.json` لـ GitHub** (محفوظ في `.gitignore`)
3. **لا تشارك كلمة مرور الـ keystore مع أحد**
4. **اعمل backup للـ keystore في بلاصة آمنة** (USB أو Google Drive مشترك)
5. **المفتاح اللي في AndroidManifest** خصك يُقيّد في Google Cloud Console:
   - روح على https://console.cloud.google.com
   - اختر **APIs & Services > Credentials**
   - اضغط على المفتاح `AIzaSyCp2VwwSQSY2vvyCot-oq7UFvlO61xpo2s`
   - **Application restrictions**: Android apps
   - **Package name**: `com.deliv.customer`
   - **SHA-1 certificate fingerprint**: `9e8f1fa158f8780c3345150282eee5df9c0b824f`

---

*آخر تحديث: 14 يوليو 2026*
