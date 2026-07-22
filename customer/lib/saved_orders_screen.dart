import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_1/Order/order_models.dart';
import 'package:flutter_application_1/Services/delivery_screen.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'cardd.dart';
import 'driver_selection_screen.dart';
import 'products_list_screen.dart';
import 'product_detail_sheet.dart';
import 'ModelSelectionDialog.dart';

// ------------------------------------------------------------------------------
//  ??????? ???????? (??? ????? ?????)
// ------------------------------------------------------------------------------
const Color _kPrimary = Color(0xFF7D29C6);
const Color _kPrimaryLight = Color(0xFF6A1B9A);
const Color _kBg = Color(0xFFF1F0F5);
const Color _kWhite = Colors.white;

// ------------------------------------------------------------------------------
//  ??????? ???????????
// ------------------------------------------------------------------------------
List<BoxShadow> _neuShadow({double blur = 8, double offset = 3}) => [
  BoxShadow(
    color: Colors.grey.shade500.withOpacity(0.5),
    blurRadius: blur,
    offset: Offset(offset, offset)),
  BoxShadow(
    color: Colors.grey.shade300,
    blurRadius: blur,
    offset: Offset(-offset, -offset)),
];

List<BoxShadow> _neuShadowPressed() => [
  BoxShadow(
    color: _kPrimary.withOpacity(0.35),
    blurRadius: 12,
    offset: const Offset(0, 4)),
];

// ------------------------------------------------------------------------------
//  ???? ????? ???????? ????????
// ------------------------------------------------------------------------------
class SavedOrdersScreen extends StatefulWidget {
  const SavedOrdersScreen({super.key});

  @override
  State<SavedOrdersScreen> createState() => _SavedOrdersScreenState();
}

class _SavedOrdersScreenState extends State<SavedOrdersScreen> {
  final _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await ApiClient.getList('/api/saved-templates?userId=${user.uid}');
      if (mounted) {
        setState(() {
          _templates = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: _kPrimary,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "??????? ????????",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Amiri')),
        leading: _neumorphicBackButton(context)),
      body: SafeArea(
            bottom: false,
            child: user == null
                ? _buildLoginPrompt()
                : _loading
                    ? const Center(
                        child: CupertinoActivityIndicator(
                          radius: 14,
                          color: _kPrimary))
                    : _templates.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _templates.length,
                            itemBuilder: (context, index) {
                              return _buildTemplateCard(_templates[index], index);
                            })),
        
   )   ;
  }

  Widget _buildTemplateCard(Map<String, dynamic> doc, int index) {
    final List items = doc['items'] ?? [];
    final double total = (items as List).fold(
      0.0,
      (sum, item) =>
          sum +
          (((item['prix'] ?? item['price'] ?? 0) as num).toDouble() *
              ((item['quantity'] ?? 1) as num).toDouble()));

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SavedOrderDetailScreen(templateData: doc))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 10,
              offset: Offset(4, 4)),
            BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: Offset(-4, -4)),
          ],
          border: Border.all(color: Color(0xFF7D29C6).withOpacity(0.1))),
        child: Row(
          children: [
            // ?????? ?????????
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _kBg,
                shape: BoxShape.circle,
                boxShadow: _neuShadow(blur: 6, offset: 3)),
              child: const Icon(
                CupertinoIcons.bookmark_fill,
                color: _kPrimary,
                size: 22)),
            const SizedBox(width: 14),

            // ?????????
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    doc['templateName'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Amiri',
                      color: Colors.black87)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "${total.toStringAsFixed(0)} DZD",
                        style: const TextStyle(
                          color: _kPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Amiri')),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(
                        "${items.length} ??????",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontFamily: 'Amiri')),
                    ]),
                ])),

            // ???
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(
                CupertinoIcons.chevron_left,
                size: 14,
                color: _kPrimary)),
          ])));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: _kBg,
              shape: BoxShape.circle,
              boxShadow: _neuShadow(blur: 15, offset: 6)),
            child: Icon(
              CupertinoIcons.bookmark,
              size: 48,
              color: Colors.grey.shade400)),
          const SizedBox(height: 20),
          Text(
            "?? ???? ?????? ?????? ??????",
            style: TextStyle(
              fontFamily: 'Amiri',
              color: Colors.grey.shade500,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            "???? ?????? ?? ????? ????????? ??????",
            style: TextStyle(
              fontFamily: 'Amiri',
              color: Colors.grey.shade400,
              fontSize: 12)),
        ]));
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 10,
              offset: Offset(4, 4)),
            BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: Offset(-4, -4)),
          ],
          border: Border.all(color: Color(0xFF7D29C6).withOpacity(0.1))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kBg,
                shape: BoxShape.circle,
                boxShadow: _neuShadow(blur: 10, offset: 4)),
              child: const Icon(
                CupertinoIcons.lock_fill,
                color: _kPrimary,
                size: 30)),
            const SizedBox(height: 16),
            const Text(
              "???? ????? ??????",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri')),
          ])));
  }

  Widget _neumorphicBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _neuShadow(blur: 6, offset: 3)),
        child: const Icon(
          CupertinoIcons.chevron_left,
          color: _kPrimary,
          size: 20)));
  }
}

// ------------------------------------------------------------------------------
//  ???? ?????? ??????? ????????
// ------------------------------------------------------------------------------
class SavedOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> templateData;
  final String templateId;
  SavedOrderDetailScreen({super.key, required this.templateData})
      : templateId = (templateData['_id'] ?? templateData['id'] ?? '') as String;

  @override
  State<SavedOrderDetailScreen> createState() => _SavedOrderDetailScreenState();
}

class _SavedOrderDetailScreenState extends State<SavedOrderDetailScreen> {
  late List items;
  final double deliveryFee = 15;

  @override
  void initState() {
    super.initState();
    final raw = widget.templateData['items'];
    items = raw is List ? List.from(raw) : [];
  }

  Future<void> _updateInFirestore() async {
    await ApiClient.put('/api/saved-templates/${widget.templateId}', {'items': items});
  }

  double get _totalPrice => items.fold(
    0.0,
    (sum, item) =>
        sum +
        (((item['prix'] ?? item['price'] ?? 0) as num).toDouble() *
            ((item['quantity'] ?? 1) as num).toDouble()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: _kPrimary,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.templateData['templateName'] ?? '',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Amiri')),
        leading: _neumorphicBackButton(context),
        actions: [
          GestureDetector(
            onTap: _deleteTemplate,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _neuShadow(blur: 6, offset: 3)),
              child: const Icon(
                CupertinoIcons.trash,
                color: Colors.redAccent,
                size: 20))),
          const SizedBox(width: 6),
        ]),
      body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAddProductSearch(),
                Expanded(
                  child: items.isEmpty
                      ? _buildEmptyItemsState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) => _buildItemTile(index))),
                _buildBottomSummary(),
              ])),
        
      );
  }

  Widget _buildItemTile(int index) {
    final item = items[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(4, 4)),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4)),
        ],
        border: Border.all(color: Color(0xFF7D29C6).withOpacity(0.1))),
      child: Row(
        children: [
          // ???? ??????
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _kWhite.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _neuShadow(blur: 5, offset: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: item['image'] ?? '',
                memCacheWidth: 140,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFFEEEEEE)),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(CupertinoIcons.photo, color: Colors.grey))))),
          const SizedBox(width: 12),

          // ??? ???? ??????
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Amiri',
                    color: Colors.black87),
                  textAlign: TextAlign.right),
                if ((item['categoryName'] as String? ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item['categoryName'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7D29C6),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Amiri'),
                      textAlign: TextAlign.right),
                  ),
                const SizedBox(height: 4),
                Text(
                  "${(item['prix'] ?? item['price'] ?? 0)} DZD",
                  style: const TextStyle(
                    color: _kPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
                if (((item['quantity'] ?? 1) as int) > 1)
                  Text(
                    "× ${item['quantity']} = ${(((item['prix'] ?? item['price'] ?? 0) as num) * ((item['quantity'] ?? 1) as num)).toStringAsFixed(0)} DZD",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ])),
          const SizedBox(width: 10),

          // ????? ?????? ??????
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _neuShadow(blur: 6, offset: 3)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _quantityButton(
                      icon: Icons.remove,
                      onTap: () {
                        if (items[index]['quantity'] > 1) {
                          setState(() => items[index]['quantity']--);
                          _updateInFirestore();
                        }
                      }),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          "${item['quantity']}",
                          key: ValueKey<int>(item['quantity']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _kPrimary)))),
                    _quantityButton(
                      icon: Icons.add,
                      onTap: () {
                        setState(() => items[index]['quantity']++);
                        _updateInFirestore();
                      }),
                  ])),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() => items.removeAt(index));
                  _updateInFirestore();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 14),
                      SizedBox(width: 4),
                      Text(
                        "???",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri')),
                    ]))),
            ]),
        ]));
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: _neuShadow(blur: 4, offset: 2)),
        child: Icon(icon, size: 16, color: _kPrimary)));
  }

  Widget _buildAddProductSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GestureDetector(
        onTap: _showSearchAndAddDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _neuShadow(blur: 6, offset: 3)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "????? ???? ???? ???????...",
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontFamily: 'Amiri',
                  fontSize: 13)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(
                  CupertinoIcons.search,
                  color: _kPrimary,
                  size: 18)),
            ]))));
  }

Widget _buildBottomSummary() {
    double subtotal = _totalPrice; // ??? ???????? ???
    double total = subtotal + deliveryFee; // ???????? ?? ???????

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE1E0E0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade500.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, -5)),
        ]),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ???? ????? ?????? ?? ??????
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10))),

          // ?? ??? ????????
          _buildPriceRow("??? ????????", formatPrice(subtotal), Colors.black87),
          const SizedBox(height: 8),

          // ?? ??? ???????
          _buildPriceRow("??? ???????", formatPrice(deliveryFee), Colors.black54),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.grey.shade400, thickness: 0.8)),

          // ?? ???????? ???????
          _buildPriceRow(
            "???????? ",
            formatPrice(total),
            _kPrimary,
            isBold: true,
            fontSize: 18),
          
          const SizedBox(height: 20),

          // ?? ????? ?????
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18))),
              onPressed: items.isEmpty ? null : _reorderFromTemplate,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.cart_badge_plus, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "????? ????? ??? ?????",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Amiri')),
                ]))),
        ]));
  }

  // ???? ?????? ???? ???? ??????? (??? ???? ????????? ?? ?????)
  Widget _buildPriceRow(String label, String value, Color color, {bool isBold = false, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color,
            fontFamily: 'Amiri')),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Colors.black54,
            fontFamily: 'Amiri')),
      ]);
  }
  Widget _buildEmptyItemsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _kBg,
              shape: BoxShape.circle,
              boxShadow: _neuShadow(blur: 12, offset: 5)),
            child: Icon(
              CupertinoIcons.cart,
              size: 40,
              color: Colors.grey.shade400)),
          const SizedBox(height: 16),
          Text(
            "?? ???? ?????? ?? ??? ???????",
            style: TextStyle(
              fontFamily: 'Amiri',
              color: Colors.grey.shade500,
              fontSize: 14)),
        ]));
  }

  void _deleteTemplate() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(
          "??? ??????? ?????????",
          style: TextStyle(fontFamily: 'Amiri')),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            "?? ????? ?? ????????? ??? ?????",
            style: TextStyle(fontFamily: 'Amiri', fontSize: 13))),
        actions: [
          CupertinoDialogAction(
            child: const Text("?????", style: TextStyle(fontFamily: 'Amiri')),
            onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("???", style: TextStyle(fontFamily: 'Amiri')),
            onPressed: () async {
              await ApiClient.delete('/api/saved-templates/${widget.templateId}');
              Navigator.pop(context);
              Navigator.pop(context);
            }),
        ]));
  }

  void _reorderFromTemplate() async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final List<Product> toAdd = [];
      final List<String> notFound = [];

      for (final item in items) {
        final pid = item['productId'] as String? ?? '';
        Map<String, dynamic>? match;
        bool isActive = true;

        // 1. ????? ?? ?????? ?? ?????
        if (pid.isNotEmpty) {
          try {
            match =
                await ApiClient.get('/api/products/$pid') as Map<String, dynamic>?;
          } catch (_) { /* ignored */ }
          // ??? ?? ???? ?? ????? ??? ?? ???
          if (match == null) {
            try {
              match =
                  await ApiClient.get('/api/promotions/$pid') as Map<String, dynamic>?;
            } catch (_) { /* ignored */ }
          }
        }

        if (match == null) {
          notFound.add(item['name'] as String? ?? '');
          continue;
        }

        // 2. ?????? ?? ?????? (?????/??? ???)
        if (match['isDeleted'] == true || match['isActive'] == false) {
          notFound.add(item['name'] as String? ?? '');
          continue;
        }

        // 3. ???? ?????? ??? ??????
        toAdd.add(Product(
          productId: pid.isNotEmpty
              ? pid
              : (match['_id'] ?? match['id'] ?? '') as String,
          name: item['name'] as String? ?? '',
          price: ((item['prix'] ?? item['price'] ?? 0) as num).toDouble(),
          imagePath: (match['image'] as String?) ??
              (item['image'] as String? ?? ''),
          capacite: (match['capacite'] as String?) ??
              (item['capacite'] as String? ?? ''),
          description: match['description'] as String? ?? '',
          priceAffiche: (match['prixAffiche'] as String?) ?? '',
          storeId: item['storeId'] as String? ?? '',
          storeName: item['storeName'] as String? ?? '',
          templateName: item['templateName'] as String? ?? '',
          categoryName: item['categoryName'] as String? ?? '',
          categoryId: (match['categorieId'] as String?) ?? '',
          uiStyle: ((match['uiStyle'] as int?) ??
              (item['uiStyle'] as int? ?? 1)),
          sizes: match['sizes'] as List<dynamic>? ?? [],
          extraImages: match['extraImages'] as List<dynamic>? ?? [],
          variants: match['variants'] as List<dynamic>? ?? [],
          models: match['models'] as List<dynamic>? ?? [],
          toppings: match['toppings'] as List<dynamic>? ?? [],
          quantity: ((item['quantity'] as num?) ?? 1).toInt(),
          selectedModelName: item['selectedModelName'] as String?,
          note: item['note'] as String? ?? '',
          storeLat: (match['storeLat'] as num?)?.toDouble() ??
              (item['storeLat'] as num?)?.toDouble() ??
              (match['lat'] as num?)?.toDouble(),
          storeLng: (match['storeLng'] as num?)?.toDouble() ??
              (item['storeLng'] as num?)?.toDouble() ??
              (match['lng'] as num?)?.toDouble(),
          hasPiecePrice: match['hasPiecePrice'] == true,
          pricePerPiece: ((match['pricePerPiece'] as num?) ?? 0).toDouble(),
        ));
      }

      GlobalCart.provider.clear();
      for (final p in toAdd) {
        GlobalCart.safeToggle(p, context);
      }

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CartScreen()),
          (route) => route.isFirst,
        );

        String msg = '? ??? ????? ${toAdd.length} ?????? ??? ?????';
        if (notFound.isNotEmpty) {
          msg += '\n?? ??? ?????: ${notFound.join('? ')}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg,
              style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
          backgroundColor: notFound.isEmpty
              ? const Color(0xFF27AE60)
              : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('? ????? ????? ?????: $e',
              style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showSearchAndAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => _SearchAndAddProduct(
        onProductSelected: (p) {
          setState(() {
            items.add({
              'name': p['name'],
              'prix': p['prix'],
              'image': p['image'],
              'productId': p['id'],
              'quantity': 1,
              'capacite': p['capacite'] ?? '',
              'categoryName': p['categoryName'] ?? '',
              'storeName': p['storeName'] ?? '',
              'storeId': p['storeId'] ?? '',
              'templateName': p['templateName'] ?? '',
              'uiStyle': p['uiStyle'] ?? 1,
              'sizes': p['sizes'] ?? [],
              'extraImages': p['extraImages'] ?? [],
              'variants': p['variants'] ?? [],
            });
          });
          _updateInFirestore();
        }));
  }

  Widget _neumorphicBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _neuShadow(blur: 6, offset: 3)),
        child: const Icon(
          CupertinoIcons.chevron_left,
          color: _kPrimary,
          size: 20)));
  }
}

// ------------------------------------------------------------------------------
//  ???? ????? ???????? — ??? ????? ?? debounce
// ------------------------------------------------------------------------------
class _SearchAndAddProduct extends StatefulWidget {
  final Function(Map<String, dynamic>) onProductSelected;
  const _SearchAndAddProduct({required this.onProductSelected});

  @override
  State<_SearchAndAddProduct> createState() => _SearchAndAddProductState();
}

class _SearchAndAddProductState extends State<_SearchAndAddProduct> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String query = "";
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (v.trim().isNotEmpty) _search(v.trim());
    });
    setState(() => query = v);
  }

  Future<void> _search(String q) async {
    setState(() => _isSearching = true);
    try {
      final data = await ApiClient.getList('/api/products?search=$q');
      if (mounted) {
        setState(() {
          _results = data.cast<Map<String, dynamic>>();
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10))),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "????? ???? ???????",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    color: Colors.black87)),
                SizedBox(width: 8),
                Icon(
                  CupertinoIcons.plus_circle_fill,
                  color: _kPrimary,
                  size: 20),
              ])),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _neuShadow(blur: 6, offset: 3)),
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: "???? ?? ????...",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontFamily: 'Amiri',
                    fontSize: 13),
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    color: _kPrimary,
                    size: 20),
                  suffixIcon: _textCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(CupertinoIcons.xmark_circle_fill,
                              color: Colors.grey.shade400, size: 18),
                          onPressed: () {
                            _textCtrl.clear();
                            _onSearchChanged('');
                          })
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14)),
                onChanged: _onSearchChanged))),
          const SizedBox(height: 12),

          Expanded(
            child: _isSearching
                ? const Center(
                    child: CupertinoActivityIndicator(
                      radius: 14,
                      color: _kPrimary))
                : query.isEmpty
                    ? Center(
                        child: Text(
                          "???? ?????? ?? ???? ???????",
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            color: Colors.grey.shade400,
                            fontSize: 13)))
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              '?? ???? ????? ?? "$query"',
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                color: Colors.grey.shade500),
                              textAlign: TextAlign.center))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: _results.length,
                            itemBuilder: (context, i) =>
                                _buildResultTile(_results[i]))),
        ]));
  }

  void _addProductToTemplate(Product p) {
    widget.onProductSelected({
      'id': p.productId,
      'name': p.displayName, // Fix: Use displayName to include model name
      'prix': p.price,
      'image': p.imagePath,
      'productId': p.productId,
      'quantity': p.quantity,
      'capacite': p.capacite,
      'categoryName': p.categoryName,
      'storeName': p.storeName,
      'storeId': p.storeId,
      'templateName': p.templateName,
      'uiStyle': p.uiStyle,
      'sizes': p.sizes,
      'extraImages': p.extraImages,
      'variants': p.variants,
      'note': p.note,
      'selectedModelName': p.selectedModelName,
    });
    if (mounted) Navigator.pop(context);
  }

  void _openProductDetail(Map<String, dynamic> d) {
    final product = Product(
      productId: (d['_id'] ?? d['id'] ?? '') as String,
      name: d['name'] as String? ?? '',
      price: ((d['prix'] as num?) ?? 0).toDouble(),
      imagePath: d['image'] as String? ?? '',
      capacite: d['capacite'] as String? ?? '',
      description: d['description'] as String? ?? '',
      priceAffiche: d['prixAffiche'] as String? ?? '',
      storeId: d['storeId'] as String? ?? '',
      storeName: d['storeName'] as String? ?? '',
      templateName: d['templateName'] as String? ?? '',
      categoryName: d['categoryName'] as String? ?? '',
      categoryId: d['categorieId'] as String? ?? '',
      uiStyle: (d['uiStyle'] as int?) ?? 1,
      sizes: d['sizes'] as List<dynamic>? ?? [],
      extraImages: d['extraImages'] as List<dynamic>? ?? [],
      variants: d['variants'] as List<dynamic>? ?? [],
      models: d['models'] as List<dynamic>? ?? [],
      toppings: d['toppings'] as List<dynamic>? ?? [],
      storeLat: (d['storeLat'] as num?)?.toDouble(),
      storeLng: (d['storeLng'] as num?)?.toDouble(),
    );

    if (product.uiStyle == 2) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PizzaDetailSheet(
          product: product,
          storeId: product.storeId,
          drinks: [],
          storeColor: _kPrimary,
          onAddToCart: (cartProduct) {
            _addProductToTemplate(cartProduct);
          },
        ),
      );
      return;
    }

    if (product.uiStyle == 3) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProductDetailSheet(
          product: product,
          drinks: [],
          isInCart: false,
          onAddToCart: () {},
          onProductAddedToTemplate: (p) => _addProductToTemplate(p),
        ),
      );
      return;
    }

    if (product.uiStyle == 4) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style4DetailSheet(
          product: product,
          onProductAddedToTemplate: (p) => _addProductToTemplate(p),
        ),
      );
      return;
    }

    if (product.uiStyle == 5) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style5DetailSheet(
          product: product,
          onProductAddedToTemplate: (p) => _addProductToTemplate(p),
        ),
      );
      return;
    }

    if (product.uiStyle == 6) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style6DetailSheet(
          product: product,
          onProductAddedToTemplate: (p) => _addProductToTemplate(p),
        ),
      );
      return;
    }

    if (product.uiStyle == 7) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style7DetailSheet(
          product: product,
          onProductAddedToTemplate: (p) => _addProductToTemplate(p),
        ),
      );
      return;
    }

    if (product.uiStyle == 8) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style8DetailSheet(
          product: product,
          onProductAddedToTemplate: (p) => _addProductToTemplate(p),
        ),
      );
      return;
    }

    if (product.models.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => ProductVariantsDialog(
          product: product,
          onAction: (variantProduct) {
            _addProductToTemplate(variantProduct);
          },
        ),
      );
      return;
    }

    _addProductToTemplate(product);
  }

  Widget _buildResultTile(Map<String, dynamic> d) {
    final catName = d['categoryName'] as String? ?? d['categorieName'] as String? ?? '';
    final storeName = d['storeName'] as String? ?? '';
    final capacite = d['capacite'] as String? ?? '';
    final price = ((d['prix'] as num?) ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(4, 4)),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4)),
        ],
        border: Border.all(color: Color(0xFF7D29C6).withOpacity(0.1))),
      child: InkWell(
        onTap: () => _openProductDetail(d),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _openProductDetail(d),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                    ]),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20))),
              const SizedBox(width: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: d['image'] ?? '',
                  memCacheWidth: 96,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey.shade200,
                    child: const Icon(
                      CupertinoIcons.photo,
                      size: 20,
                      color: Colors.grey)))),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      d['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Amiri'),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      "${price.toInt()} DZD${catName.isNotEmpty ? ' - $catName' : ''}",
                      style: TextStyle(
                        color: _kPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                    if (capacite.isNotEmpty || storeName.isNotEmpty)
                      Text(
                        [capacite, storeName].where((s) => s.isNotEmpty).join(' • '),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ])),
            ]))));
  }
}

// ------------------------------------------------------------------------------
//  ???? ????? ??????? ???????? (??? ????? _CheckoutSheet ?? cardd.dart)
// ------------------------------------------------------------------------------
class CheckoutSheetFromTemplate extends StatefulWidget {
  final List items;
  final double totalPrice;

  const CheckoutSheetFromTemplate({
    super.key,
    required this.items,
    required this.totalPrice,
  });

  @override
  State<CheckoutSheetFromTemplate> createState() =>
      _CheckoutSheetFromTemplateState();
}

class _CheckoutSheetFromTemplateState extends State<CheckoutSheetFromTemplate> {
  final double deliveryFee = 15;

  List<Map<String, dynamic>> _savedLocations = [];
  bool _loadingLocations = true;
  int _selectedLocationIndex = -1;
  bool _useMap = false;
  String _mapAddress = '';

  final TextEditingController _noteCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final data = await ApiClient.getList('/api/users/${user.uid}/saved-locations');
      if (mounted) {
        setState(() {
          _savedLocations = data
              .map(
                (doc) => {
                  'id': doc['_id'],
                  'label': doc['label'] as String? ?? '',
                  'address': doc['address'] as String? ?? '',
                  'icon': _iconFromType(
                    doc['type'] as String? ?? 'other'),
                })
              .where((loc) => (loc['label'] as String).isNotEmpty)
              .toList();
          _loadingLocations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  IconData _iconFromType(String type) {
    switch (type) {
      case 'home':
      case '??????':
        return CupertinoIcons.house_fill;
      case 'work':
      case '?????':
        return CupertinoIcons.briefcase_fill;
      default:
        return CupertinoIcons.location_fill;
    }
  }

  String get _finalAddress {
    if (_useMap) return _mapAddress;
    if (_selectedLocationIndex >= 0 &&
        _selectedLocationIndex < _savedLocations.length) {
      return _savedLocations[_selectedLocationIndex]['address'] as String;
    }
    return '';
  }

  bool get _canConfirm => _finalAddress.isNotEmpty && !_isLoading;

  Future<void> _confirmOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final userData = await ApiClient.get('/api/users/${user.uid}') as Map<String, dynamic>? ?? {};
      final String apiName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      final String userName = apiName.isNotEmpty ? apiName : (FirebaseAuth.instance.currentUser?.displayName ?? '????');
      final String userPhone = userData['phone'] as String? ?? '';

      final itemsData = widget.items
          .map(
            (item) => {
              'productId': item['productId'],
              'name': item['name'],
              'price': item['price'] ?? item['prix'],
              'quantity': item['quantity'],
              'image': item['image'] ?? '',
              'capacite': item['capacite'] ?? '',
              'totalItem': ((item['price'] as num?) ?? (item['prix'] as num?) ?? 0) * (item['quantity'] as num? ?? 1),
              'templateName': item['templateName'] ?? '???? ???',
              'categoryName': item['categoryName'] ?? '',
              'storeName': item['storeName'] ?? '',
              'storeId': item['storeId'] ?? '',
              'storeLat': item['storeLat'] ?? 0,
              'storeLng': item['storeLng'] ?? 0,
              'uiStyle': item['uiStyle'] ?? 0,
              'sizes': item['sizes'] ?? [],
              'extraImages': item['extraImages'] ?? [],
              'variants': item['variants'] ?? [],
              'purchaseStatus': '',
              'note': item['note'] ?? '',
            })
          .toList();

      final double total = widget.totalPrice + deliveryFee;

      String locationLabel = _useMap
          ? '???? ?? ???????'
          : (_selectedLocationIndex >= 0
                ? _savedLocations[_selectedLocationIndex]['label'] as String
                : '');

      final orderData = {
        'userId': user.uid,
        'userName': userName.isNotEmpty ? userName : '????',
        'userPhone': userPhone,
        'items': itemsData,
        'subtotal': widget.totalPrice,
        'deliveryFee': deliveryFee,
        'total': total,
        'address': _finalAddress,
        'locationLabel': locationLabel,
        'driverNote': _noteCtrl.text.trim(),
      };

      if (!mounted) return;

      Navigator.pop(context);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverSelectionScreen(orderData: orderData)));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ???? ?????
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),

            // ??????? ??????
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    "${(widget.totalPrice + deliveryFee).toStringAsFixed(0)} DZD",
                    style: const TextStyle(
                      color: _kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Amiri'))),
                const Text(
                  "????? ??? ?????????",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    color: Color(0xFF1A1A1A))),
              ]),
            const SizedBox(height: 24),

            // ???? ???????
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "???? ???????",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: Color(0xFF1A1A1A)))),
            const SizedBox(height: 12),

            if (_loadingLocations)
              const Center(
                child: CupertinoActivityIndicator(radius: 14, color: _kPrimary))
            else if (_savedLocations.isEmpty)
              _buildNoLocationsWidget()
            else
              ..._savedLocations.asMap().entries.map(
                (e) => _buildLocationOption(e.key, e.value)),

            _buildMapOption(),
            const SizedBox(height: 22),

            // ?????? ??????
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "?????? ??????",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: Color(0xFF1A1A1A)))),
            const SizedBox(height: 10),
            _buildNoteField(),
            const SizedBox(height: 24),
            _buildConfirmButton(),
          ])));
  }

  Widget _buildLocationOption(int index, Map<String, dynamic> loc) {
    final isSelected = !_useMap && _selectedLocationIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedLocationIndex = index;
        _useMap = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : _kBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kPrimary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
                ]
              : _neuShadow(blur: 6, offset: 3)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  width: 2)),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: _kPrimary)
                  : null),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      loc['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text(
                      loc['address'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Amiri',
                        color: isSelected ? Colors.white70 : Colors.black45),
                      textAlign: TextAlign.right),
                  ]))),
            Icon(
              loc['icon'] as IconData,
              color: isSelected ? Colors.white : _kPrimary,
              size: 22),
          ])));
  }

  Widget _buildMapOption() {
    return GestureDetector(
      onTap: () async {
        final res = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const MapPickerScreen()));
        if (res != null && mounted) {
          setState(() {
            _useMap = true;
            _selectedLocationIndex = -1;
            _mapAddress = res;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _useMap ? _kPrimary : _kBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _useMap
              ? [
                  BoxShadow(
                    color: _kPrimary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
                ]
              : _neuShadow(blur: 6, offset: 3)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _useMap ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: _useMap ? Colors.white : Colors.grey.shade400,
                  width: 2)),
              child: _useMap
                  ? const Icon(Icons.check, size: 14, color: _kPrimary)
                  : null),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "????? ?? ???????",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        color: _useMap ? Colors.white : const Color(0xFF1A1A1A))),
                    Text(
                      _useMap && _mapAddress.isNotEmpty
                          ? _mapAddress
                          : "???? ???? ???????",
                      style: TextStyle(
                        fontSize: 11,
                        color: _useMap ? Colors.white70 : Colors.black45),
                      textAlign: TextAlign.right),
                  ]))),
            Icon(
              CupertinoIcons.map_fill,
              color: _useMap ? Colors.white : _kPrimary,
              size: 22),
          ])));
  }

  Widget _buildNoLocationsWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(4, 4)),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4)),
        ],
        border: Border.all(color: Color(0xFF7D29C6).withOpacity(0.1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '???? ????? ??????',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Amiri',
                    color: Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text(
                  '?????? ??????? ?????? ?????',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Amiri',
                    color: Colors.grey.shade500)),
              ])),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              shape: BoxShape.circle),
            child: const Icon(
              CupertinoIcons.location_slash,
              color: _kPrimary,
              size: 22)),
        ]));
  }

  Widget _buildNoteField() {
    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _neuShadow(blur: 6, offset: 3)),
      child: TextField(
        controller: _noteCtrl,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: "????: ????? ??????? ?????? ??????...",
          hintStyle: TextStyle(
            color: Colors.black38,
            fontSize: 12,
            fontFamily: 'Amiri'),
          prefixIcon: const Icon(
            CupertinoIcons.text_bubble,
            color: _kPrimary,
            size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14))));
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canConfirm ? _confirmOrder : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          disabledBackgroundColor: Colors.grey.shade400,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18))),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_shield,
                    color: Colors.white,
                    size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _canConfirm ? "????? ??????? ????" : "???? ???? ???????",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri')),
                ])));
  }
}

// ------------------------------------------------------------------------------
//  ?????? ?????? (????? ?? cardd.dart)
// ------------------------------------------------------------------------------
class _SuccessDialog extends StatefulWidget {
  const _SuccessDialog();

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim, _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFB8B1C8).withOpacity(0.6),
                  blurRadius: 10,
                  offset: Offset(4, 4)),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 10,
                  offset: Offset(-4, -4)),
              ],
              border: Border.all(color: Color(0xFF7D29C6).withOpacity(0.1))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    shape: BoxShape.circle),
                  child: const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: _kPrimary,
                    size: 48)),
                const SizedBox(height: 20),
                const Text(
                  "?? ????? ???????! ??",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    fontFamily: 'Amiri'),
                  textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                  "?? ??? ?????? ?????\n???? ??????? ?? ???? ???",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black45,
                    fontFamily: 'Amiri',
                    height: 1.6),
                  textAlign: TextAlign.center),
              ])))));
  }
}
