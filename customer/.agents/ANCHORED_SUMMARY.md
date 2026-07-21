# Current Session Summary

## Goal
إصلاح فلترة المدينة في اختيار السائقين للمشاريع، تغيير تدفق إنشاء الطلبية من شيتات لصفحات كاملة، إضافة سحب للتحديث + تحديث تلقائي للطلبيات، معالجة رفض السائق لطلبات الخدمة وإعادة الطلب من المنتهية (يضيف المنتجات للسلة بدل ما يعين سائق).

## Progress

### Done
1. **فلترة المدينة** (`owner_project_orders.dart`): أضفت `_extractCitiesFromDrivers()` fallback تستخرج `cityName` من السائقين النشيطين إذا API `/api/drivers/cities` فشل أو رجع فاضي
2. **صفحة إنشاء طلبية جديدة** (`_CreateDeliveryPage`): بدل شيت → صفحة كاملة مع AppBar، نفس الحقول، validation، `Navigator.pop` مع الداتا
3. **صفحة اختيار سائق** (`_DriverSelectionPage`): بدل `_DriverSelectionSheet` → صفحة كاملة مع AppBar، فلترة، اختيار السائق يرجع بالداتا
4. **Navigation في `_createNewDelivery()`**: بدل `showModalBottomSheet` → `Navigator.push` للصفحتين
5. **Navigation في `_acceptProjectOrder()`**: برضو `showModalBottomSheet` → `Navigator.push` لـ `_DriverSelectionPage`
6. **سحب للتحديث (pull-to-refresh)**: `RefreshIndicator` على `ListView.builder` في `_OrdersTab` (`Order.dart`)
7. **تحديث تلقائي 15s**: `Timer.periodic(15s)` في `_OrdersTabState.initState()` + `_refreshTimer?.cancel()` في `dispose()`
8. **معالجة رفض السائق لطلبات الخدمة/النقل**: `removeWhere` للمرفوض + زر إعادة الطلب في `ServiceOrderCard` (PUT back to pending)
9. **السلة لا تمسح قبل الرادار**: حذفت `GlobalCart.provider.clear()` من `cardd.dart:2735`
10. **إعادة الطلب من المنتهية يضيف للسلة** (جديد): بدلت `_showReorderSheet` → `_reorderToCart`:
    - يجيب المنتجات من API (`/api/products?storeId=...`)
    - يطابقها بالاسم مع items الطلبية
    - يضيف المتوفر منها لـ `GlobalCart`
    - ينقل المستخدم لـ `CartScreen` (cardd.dart)
    - المنتجات الغير متوفرة يظهرها في SnackBar
    - الزر ظاهر للطلبات `cancelled` و `delivered`
