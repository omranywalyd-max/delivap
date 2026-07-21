// ----------------------------------------------------------------------------
//  owner_products_manager.dart
//  ????? ?????? ????? � ?? ????????? ?? 1 ??? 8
//  ??????: uiStyle == 8 � ???? + ??? ????? + ????? ???????? + ??? + ?????
// ----------------------------------------------------------------------------

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dashbord/services/api_client.dart';
import 'package:dashbord/admin_store_owners_account.dart';

Future<String> _uploadImg(File file, String folder) async {
  try {
    return await ApiClient.upload(file);
  } catch (e) {
    return "";
  }
}

// -- ??????? ???????? --
const Color kBg = Color(0xFFE8E6F0);
const Color kSurface = Color(0xFFEFEDF5);
const Color kPrimary = Color(0xFF6A1FA3);
const Color kPrimaryLight = Color(0xFF9B59C8);
const Color kAccent = Color(0xFF4B3A8C);
const Color kWhite = Color(0xFFFFFFFF);
const Color kShadowDark = Color(0xFFC5C0D8);
const Color kShadowLight = Color(0xFFFFFFFF);
const Color kTextPrimary = Color(0xFF2D2540);
const Color kTextSecondary = Color(0xFF7B6E99);
const Color kDanger = Color(0xFFE53E6A);
const Color kSuccess = Color(0xFF27AE7A);

const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF9B59C8), Color(0xFF4B3A8C)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// -- ???? ?????? --
String _cleanPrice(dynamic v) {
  if (v == null) return '0';
  if (v is num) return v == v.toInt() ? v.toInt().toString() : v.toString();
  final n = num.tryParse(v.toString());
  if (n != null) return n == n.toInt() ? n.toInt().toString() : n.toString();
  return v.toString();
}

String _readPriceStr(Map<String, dynamic> d) {
  final raw = d['prix'] ?? d['price'] ?? 0;
  return _cleanPrice(raw);
}

int _readPriceInt(Map<String, dynamic> d) {
  final raw = d['prix'] ?? d['price'] ?? 0;
  return raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
}

String _readPriceStrFrom(Map<String, dynamic> d, String key) {
  final raw = d[key];
  return _cleanPrice(raw);
}

// ------------------------------------------------------------------------------
//  WIDGETS ?????? ?????? ?????
// ------------------------------------------------------------------------------

Widget _neuBox({required Widget child, EdgeInsets? padding, double radius = 20}) =>
    Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: kShadowDark, offset: Offset(6, 6), blurRadius: 15),
          BoxShadow(color: kShadowLight, offset: Offset(-6, -6), blurRadius: 15),
        ],
      ),
      child: child,
    );

Widget _neuButton(String txt, VoidCallback onTap, {IconData? icon}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: kPrimaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.35),
              offset: const Offset(0, 6),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: kWhite, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              txt,
              style: const TextStyle(
                color: kWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Amiri',
              ),
            ),
          ],
        ),
      ),
    );

Widget _buildInput(
  TextEditingController c,
  String hint, {
  bool isNum = false,
  int maxLines = 1,
  IconData? icon,
  String? suffix,
}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: kShadowDark, offset: Offset(3, 3), blurRadius: 8),
          BoxShadow(color: kShadowLight, offset: Offset(-3, -3), blurRadius: 8),
        ],
      ),
      child: StatefulBuilder(
        builder: (ctx, setLocalState) => TextField(
        controller: c,
        onChanged: (_) => setLocalState(() {}),
        textAlign: TextAlign.right,
        textDirection: _detectDirection(c.text),
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: const TextStyle(
          fontFamily: 'Amiri',
          color: kTextPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Amiri',
            color: kTextSecondary.withOpacity(0.7),
            fontSize: 13,
          ),
          prefixIcon: icon != null ? Icon(icon, color: kPrimaryLight, size: 20) : null,
          suffix: suffix != null
              ? Text(suffix,
                  style: const TextStyle(
                      color: kTextSecondary, fontFamily: 'Amiri', fontSize: 12))
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      ),
    );

TextDirection _detectDirection(String text) {
  if (text.isEmpty) return TextDirection.rtl;
  int arabic = 0, latin = 0;
  for (final r in text.runes) {
    if (r >= 0x0600 && r <= 0x06FF || r >= 0x0750 && r <= 0x077F || r >= 0x08A0 && r <= 0x08FF) arabic++;
    if (r >= 0x0041 && r <= 0x005A || r >= 0x0061 && r <= 0x007A || r >= 0x0030 && r <= 0x0039) latin++;
  }
  return arabic >= latin ? TextDirection.rtl : TextDirection.ltr;
}

Widget _buildTagChip(String tag, VoidCallback onDelete) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimary.withOpacity(0.12), kAccent.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimary.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(color: kDanger, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: kWhite),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            tag,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 12,
              color: kPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

class _SearchTagsSection extends StatefulWidget {
  final List<String> tags;
  final Function(List<String>) onChanged;
  const _SearchTagsSection({required this.tags, required this.onChanged});

  @override
  State<_SearchTagsSection> createState() => _SearchTagsSectionState();
}

class _SearchTagsSectionState extends State<_SearchTagsSection> {
  final _tagCtrl = TextEditingController();

  void _add() {
    final t = _tagCtrl.text.trim();
    if (t.isEmpty) return;
    widget.onChanged([...widget.tags, t]);
    _tagCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            const Icon(Icons.label_outline, color: kPrimaryLight, size: 18),
            const SizedBox(width: 6),
            const Text(
              "وسوم البحث",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Amiri',
                color: kTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: _add,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: kPrimaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: kWhite),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: kShadowDark, offset: Offset(2, 2), blurRadius: 6),
                    BoxShadow(color: kShadowLight, offset: Offset(-2, -2), blurRadius: 6),
                  ],
                ),
                child: TextField(
                  controller: _tagCtrl,
                  textAlign: TextAlign.right,
                  onSubmitted: (_) => _add(),
                  style: const TextStyle(fontFamily: 'Amiri', color: kTextPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "أضف وسماً واضغط +",
                    hintStyle: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: kTextSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: widget.tags.asMap().entries.map((e) {
              return _buildTagChip(e.value, () {
                final updated = [...widget.tags]..removeAt(e.key);
                widget.onChanged(updated);
              });
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final File? imageFile;
  final String existingUrl;
  final VoidCallback onTap;
  final double size;
  final String label;

  const _ImagePicker({
    required this.imageFile,
    required this.existingUrl,
    required this.onTap,
    this.size = 110,
    this.label = "إضافة صورة",
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kPrimary.withOpacity(0.3), width: 1.5),
          boxShadow: const [
            BoxShadow(color: kShadowDark, offset: Offset(4, 4), blurRadius: 10),
            BoxShadow(color: kShadowLight, offset: Offset(-4, -4), blurRadius: 10),
          ],
        ),
        child: imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(imageFile!, fit: BoxFit.cover),
              )
            : (existingUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(memCacheWidth: 150, imageUrl: existingUrl, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: kPrimaryLight, size: size * 0.3),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(fontFamily: 'Amiri', fontSize: 10, color: kTextSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )),
      ),
    );
  }
}

Widget _sheetHeader(String title) => Column(
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: kTextSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Amiri',
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );

Widget _sectionLabel(String label, IconData icon) => Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kPrimary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                  fontSize: 13)),
        ],
      ),
    );

void _showAlert(BuildContext context, String msg) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Amiri', fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("موافق", style: TextStyle(fontFamily: 'Amiri')),
        ),
      ],
    ),
  );
}

List<BoxShadow> _neuShadow() => [
      BoxShadow(
        color: kShadowDark.withOpacity(0.6),
        blurRadius: 10,
        offset: const Offset(5, 5),
      ),
      const BoxShadow(color: kShadowLight, blurRadius: 10, offset: Offset(-5, -5)),
    ];

// ------------------------------------------------------------------------------
//  ????? ?????????
// ------------------------------------------------------------------------------
class OwnerDrinksPage extends StatefulWidget {
  final String storeId;
  const OwnerDrinksPage({super.key, required this.storeId});

  @override
  State<OwnerDrinksPage> createState() => _OwnerDrinksPageState();
}

class _OwnerDrinksPageState extends State<OwnerDrinksPage> {
  List<Map<String, dynamic>> _drinks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.getList('/api/drinks?storeId=${widget.storeId}');
      if (mounted) {
        setState(() {
          _drinks = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text("إدارة النكهات",
            style: TextStyle(fontFamily: 'Amiri', color: kTextPrimary)),
        backgroundColor: kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DrinkEditorSheet(storeId: widget.storeId, doc: null),
        ).then((_) => _load()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _drinks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_drink_outlined,
                          size: 60, color: kTextSecondary.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      const Text("لا توجد نكهات بعد",
                          style: TextStyle(fontFamily: 'Amiri', color: kTextSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _drinks.length,
                  itemBuilder: (context, i) {
                    var d = _drinks[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFB8B1C8).withOpacity(0.6),
                              blurRadius: 10,
                              offset: const Offset(4, 4)),
                          const BoxShadow(
                              color: Colors.white,
                              blurRadius: 10,
                              offset: Offset(-4, -4)),
                        ],
                        border:
                            Border.all(color: const Color(0xFF5B0094).withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: kDanger, size: 22),
                            onPressed: () {
                              showCupertinoDialog(
                                context: context,
                                builder: (ctx) => CupertinoAlertDialog(
                                  title: const Text("حذف نوع المشروب",
                                      style: TextStyle(fontFamily: 'Amiri')),
                                  content: const Text(
                                      "هل أنت متأكد من حذف هذا النوع وجميع نكهاته؟",
                                      style: TextStyle(fontFamily: 'Amiri')),
                                  actions: [
                                    CupertinoDialogAction(
                                      child: const Text("إلغاء",
                                          style: TextStyle(fontFamily: 'Amiri')),
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                    CupertinoDialogAction(
                                      isDestructiveAction: true,
                                      child: const Text("حذف",
                                          style: TextStyle(fontFamily: 'Amiri')),
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await ApiClient.deleteImageUrl(d['image'] ?? '');
                                        await ApiClient.delete('/api/drinks/${d['_id']}');
                                        _load();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(d['name'] ?? '',
                                  style: const TextStyle(
                                      fontFamily: 'Amiri',
                                      fontWeight: FontWeight.bold,
                                      color: kTextPrimary)),
                              Text("${(d['flavors'] as List?)?.length ?? 0} نكهات",
                                  style: const TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 11,
                                      color: kTextSecondary)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: kPrimary, size: 22),
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  DrinkEditorSheet(storeId: widget.storeId, doc: d),
                            ).then((_) => _load()),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class DrinkEditorSheet extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic>? doc;
  const DrinkEditorSheet({super.key, required this.storeId, this.doc});

  @override
  State<DrinkEditorSheet> createState() => _DrinkEditorSheetState();
}

class _DrinkEditorSheetState extends State<DrinkEditorSheet> {
  final _nameCtrl = TextEditingController();
  List<Map<String, dynamic>> _flavors = [];
  List<String> _tags = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['name'] ?? '';
      if (d['flavors'] != null) {
        for (var f in d['flavors']) {
          _flavors.add({
            'name': f['label'],
            'existingUrl': f['image'],
            'imageFile': null,
            'sizes': List<Map<String, dynamic>>.from(f['sizes'] ?? []),
          });
        }
      }
      if (d['searchTags'] != null) _tags = List<String>.from(d['searchTags']);
    }
  }

  void _addFlavor() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (p != null) {
      setState(() => _flavors.add({
            'name': '',
            'imageFile': File(p.path),
            'existingUrl': '',
            'sizes': <Map<String, dynamic>>[
              {'label': '', 'price': 0.0}
            ],
          }));
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال اسم المشروب أولاً");
      return;
    }
    if (_flavors.isEmpty) {
      _showAlert(context, "يرجى إضافة نكهة واحدة على الأقل");

      return;
    }
    setState(() => _loading = true);
    try {
      List<Map<String, dynamic>> finalFlavors = [];
      for (var f in _flavors) {
        String fUrl = f['existingUrl'];
        if (f['imageFile'] != null)
          fUrl = await _uploadImg(f['imageFile'], 'drinks');
        finalFlavors.add({'label': f['name'], 'image': fUrl, 'sizes': f['sizes']});
      }
      final ts = DateTime.now().toIso8601String();
      final data = {
        'name': _nameCtrl.text,
        'flavors': finalFlavors,
        'storeId': widget.storeId,
        'searchTags': _tags,
        'updatedAt': ts,
      };
      if (widget.doc == null) {
        await ApiClient.post('/api/drinks', {...data, 'createdAt': ts});
      } else {
        await ApiClient.put('/api/drinks/${widget.doc!['_id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showAlert(context, "حدث خطأ أثناء الحفظ: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sheetHeader("إضافة مشروب"),
            _buildInput(_nameCtrl, "اسم المشروب (مثال: عصير)",
                icon: Icons.local_drink_outlined, ),
            const SizedBox(height: 16),
            ..._flavors.asMap().entries.map((fe) {
              int fIdx = fe.key;
              var f = fe.value;
              return _FlavorCard(
                flavor: f,
                onDelete: () => setState(() => _flavors.removeAt(fIdx)),
                onChanged: () => setState(() {}),
              );
            }),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _addFlavor,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: kPrimary.withOpacity(0.3), style: BorderStyle.solid),
                  boxShadow: _neuShadow(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_a_photo_outlined, color: kPrimary, size: 20),
                    SizedBox(width: 8),
                    Text("إضافة نكهة",
                        style: TextStyle(
                            fontFamily: 'Amiri', color: kPrimary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SearchTagsSection(
                tags: _tags, onChanged: (v) => setState(() => _tags = v)),
            const SizedBox(height: 24),
            _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _neuButton("حفظ المشروب", _save, icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}

class _FlavorCard extends StatelessWidget {
  final Map<String, dynamic> flavor;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _FlavorCard(
      {required this.flavor, required this.onDelete, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 10,
              offset: const Offset(4, 4)),
          const BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-4, -4)),
        ],
        border: Border.all(color: const Color(0xFF5B0094).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: kDanger, size: 20),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: flavor['name'],
                  onChanged: (v) {
                    flavor['name'] = v;
                    onChanged();
                  },
                  textAlign: TextAlign.right,
                  
                  style: const TextStyle(fontFamily: 'Amiri', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "اسم النكهة",
                    hintStyle: TextStyle(fontFamily: 'Amiri', fontSize: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final p =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (p != null) {
                    flavor['imageFile'] = File(p.path);
                    onChanged();
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimary.withOpacity(0.2)),
                  ),
                  child: flavor['imageFile'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(flavor['imageFile'], fit: BoxFit.cover),
                        )
                      : (flavor['existingUrl'] != ""
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: CachedNetworkImage(
                                  memCacheWidth: 150,
                                  imageUrl: flavor['existingUrl'], fit: BoxFit.cover),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined,
                              color: kPrimaryLight, size: 22)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if ((flavor['sizes'] as List).isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration:
                  BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: (flavor['price'] as num? ?? 0) > 0
                          ? (flavor['price'] as num).toInt().toString()
                          : '',
                      onChanged: (v) {
                        flavor['price'] = double.tryParse(v) ?? 0;
                        onChanged();
                      },
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Amiri', fontSize: 12),
                      decoration: const InputDecoration(
                          hintText: "السعر DA",
                          hintStyle: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: Color(0xFF999999)),
                          border: InputBorder.none, isDense: true),
                    ),
                  ),
                ],
              ),
            )
          else
            ...(flavor['sizes'] as List<Map<String, dynamic>>)
                .asMap()
                .entries
                .map((se) {
              int sIdx = se.key;
              return Container(
                margin: const EdgeInsets.only(top: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: kBg, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: kDanger, size: 18),
                      onPressed: () {
                        flavor['sizes'].removeAt(sIdx);
                        onChanged();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            (flavor['sizes'][sIdx]['price'] as num? ?? 0) > 0
                                ? (flavor['sizes'][sIdx]['price'] as num).toInt().toString()
                                : '',
                        onChanged: (v) {
                          flavor['sizes'][sIdx]['price'] =
                              double.tryParse(v) ?? 0;
                          onChanged();
                        },
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontFamily: 'Amiri', fontSize: 12),
                        decoration: const InputDecoration(
                            hintText: "السعر DA",
                            hintStyle: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: Color(0xFF999999)),
                            border: InputBorder.none,
                            isDense: true),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: flavor['sizes'][sIdx]['label'],
                        onChanged: (v) {
                          flavor['sizes'][sIdx]['label'] = v;
                          onChanged();
                        },
                        textAlign: TextAlign.right,
                        
                        style:
                            const TextStyle(fontFamily: 'Amiri', fontSize: 12),
                        decoration: const InputDecoration(
                            hintText: "الحجم",
                            hintStyle: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: Color(0xFF999999)),
                            border: InputBorder.none,
                            isDense: true),
                      ),
                    ),
                  ],
                ),
              );
            }),
          Row(
            children: [
              if ((flavor['sizes'] as List).isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    flavor['sizes'] = <Map<String, dynamic>>[];
                    flavor['price'] = 0;
                    onChanged();
                  },
                  icon: const Icon(Icons.block, size: 14, color: kDanger),
                  label: const Text("حذف السعر",
                      style: TextStyle(
                          fontFamily: 'Amiri', fontSize: 11, color: kDanger)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              if ((flavor['sizes'] as List).isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    (flavor['sizes'] as List<Map<String, dynamic>>)
                        .add({'label': '', 'price': 0.0});
                    onChanged();
                  },
                  icon: const Icon(Icons.add, size: 16, color: kPrimary),
                  label: const Text("إضافة حجم",
                      style: TextStyle(
                          fontFamily: 'Amiri', fontSize: 12, color: kPrimary)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              if ((flavor['sizes'] as List).isEmpty)
                TextButton.icon(
                  onPressed: () {
                    flavor['sizes'] = <Map<String, dynamic>>[
                      {'label': '', 'price': 0.0}
                    ];
                    flavor.remove('price');
                    onChanged();
                  },
                  icon: const Icon(Icons.add, size: 14, color: kPrimary),
                  label: const Text("إضافة سعر",
                      style: TextStyle(
                          fontFamily: 'Amiri', fontSize: 11, color: kPrimary)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  ???? ???????? - ???? ??? uiStyle
// ------------------------------------------------------------------------------
class OwnerProductsPage extends StatefulWidget {
  final String storeId, catId, catName;
  final bool isPizza;
  final int uiStyle;
  final String? templateId;
  const OwnerProductsPage({
    super.key,
    required this.storeId,
    required this.catId,
    required this.catName,
    required this.isPizza,
    required this.uiStyle,
    this.templateId,
  });

  @override
  State<OwnerProductsPage> createState() => _OwnerProductsPageState();
}

class _OwnerProductsPageState extends State<OwnerProductsPage> {
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _categoryData;
  Map<String, dynamic>? _storeData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        ApiClient.getList('/api/favorites?storeId=${widget.storeId}'),
        ApiClient.getList(
            '/api/products?storeId=${widget.storeId}&categorieId=${widget.catId}'),
        ApiClient.get('/api/categories/${widget.catId}'),
        ApiClient.get('/api/stores/${widget.storeId}'),
      ]);
      if (mounted) {
        setState(() {
          _favorites = List<Map<String, dynamic>>.from(responses[0] as List<dynamic>);
          _products = List<Map<String, dynamic>>.from(responses[1] as List<dynamic>);
          _categoryData = responses[2] as Map<String, dynamic>?;
          _storeData = responses[3] as Map<String, dynamic>?;
          _sortProducts();
          _loading = false;
        });
      }
      _assignMissingOrders();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sortProducts() {
    _products.sort((a, b) {
      final ao = (a['order'] as num?)?.toInt();
      final bo = (b['order'] as num?)?.toInt();
      if (ao == null && bo == null) return 0;
      if (ao == null) return 1;
      if (bo == null) return -1;
      return ao.compareTo(bo);
    });
  }

  Future<void> _assignMissingOrders() async {
    int? maxOrder;
    for (final p in _products) {
      final o = (p['order'] as num?)?.toInt();
      if (o != null && (maxOrder == null || o > maxOrder)) maxOrder = o;
    }
    int nextOrder = (maxOrder ?? 0) + 1;
    final futures = <Future>[];
    for (var p in _products) {
      if ((p['order'] as num?) == null) {
        p['order'] = nextOrder++;
        final id = p['_id'] as String?;
        if (id != null) {
          futures.add(ApiClient.put('/api/products/$id', {'order': p['order']}));
        }
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
      if (mounted) setState(() {});
    }
  }

  Future<void> _renumberAll() async {
    final futures = <Future>[];
    for (int j = 0; j < _products.length; j++) {
      _products[j]['order'] = j + 1;
      final id = _products[j]['_id'] as String?;
      if (id != null) {
        futures.add(ApiClient.put('/api/products/$id', {'order': j + 1}));
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
      if (mounted) setState(() {});
    }
  }

  Future<void> _moveProduct(int index, int direction) async {
    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= _products.length) return;
    final currentOrder = (_products[index]['order'] as num?)?.toInt() ?? newIndex + 1;
    final otherOrder = (_products[newIndex]['order'] as num?)?.toInt() ?? index + 1;
    setState(() {
      _products[index]['order'] = otherOrder;
      _products[newIndex]['order'] = currentOrder;
      _sortProducts();
    });
    try {
      await _renumberAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في الترقيم: $e', style: const TextStyle(fontFamily: 'Amiri')),
          backgroundColor: Colors.red.shade600,
        ));
      }
    }
  }

  void _showAddToFavoriteDialog(String productId, String productName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddToFavoriteSheet(
        storeId: widget.storeId,
        productId: productId,
        productName: productName,
        favorites: _favorites,
        onFavoritesChanged: _load,
      ),
    ).then((_) => _load());
  }

  void _openEditor(BuildContext context, Map<String, dynamic>? doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        // -- uiStyle 8 � ??????? ?????? --
        if (widget.uiStyle == 8) {
          return Style8ProductEditor(
            storeId: widget.storeId,
            catId: widget.catId,
            catName: widget.catName,
            doc: doc,
            templateId: widget.templateId,
          );
        }
        if (widget.uiStyle == 2 || widget.isPizza) {
          return PizzaProductEditor(
            storeId: widget.storeId,
            catId: widget.catId,
            catName: widget.catName,
            isPizza: true,
            doc: doc,
            templateId: widget.templateId,
          );
        }
        if (widget.uiStyle == 3) {
          return PatisserieProductEditor(
            storeId: widget.storeId,
            catId: widget.catId,
            catName: widget.catName,
            doc: doc,
            templateId: widget.templateId,
          );
        }
        if (widget.uiStyle == 4) {
          return GreenGrocerProductEditor(
            storeId: widget.storeId,
            catId: widget.catId,
            catName: widget.catName,
            doc: doc,
            templateId: widget.templateId,
          );
        }
        if (widget.uiStyle == 5) {
          return CosmeticProductEditor(
            storeId: widget.storeId,
            catId: widget.catId,
            catName: widget.catName,
            doc: doc,
            templateId: widget.templateId,
          );
        }
        if (widget.uiStyle == 6) {
          return ProjectsProductEditor(
            storeId: widget.storeId,
            catId: widget.catId,
            catName: widget.catName,
            doc: doc,
            templateId: widget.templateId,
          );
        }
        if (widget.uiStyle == 7) {
          return MultiSizeProductEditor(
            storeId: widget.storeId,
            catId: widget.catId,
            catName: widget.catName,
            doc: doc,
            templateId: widget.templateId,
          );
        }
        return SupermarketProductEditor(
          storeId: widget.storeId,
          catId: widget.catId,
          catName: widget.catName,
          doc: doc,
          templateId: widget.templateId,
        );
      },
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text("منتجات ${widget.catName}",
            style: const TextStyle(
                fontFamily: 'Amiri', color: kTextPrimary, fontSize: 16)),
        backgroundColor: kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _openEditor(context, null),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_categoryData != null) ...[
                  _buildCategoryFinCard(_categoryData!),
                  const SizedBox(height: 12),
                ],
                if (_products.isEmpty)
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 60, color: kTextSecondary.withOpacity(0.35)),
                          const SizedBox(height: 12),
                          const Text("لا توجد منتجات بعد",
                              style: TextStyle(fontFamily: 'Amiri', color: kTextSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ..._products.map((p) => _buildProductCard(p)).toList(),
              ],
            ),
    );
  }

  Widget _buildCategoryFinCard(Map<String, dynamic> cat) {
    final cash = (cat['cash'] as num?)?.toDouble() ?? 0;
    final total = (cat['totalEarnings'] as num?)?.toDouble() ?? 0;
    final catPct = (cat['commissionPercent'] as num?)?.toDouble();
    final storePct = (_storeData?['commissionPercent'] as num?)?.toDouble() ?? 0;
    final pct = (catPct != null && catPct > 0) ? catPct : storePct;
    final deducted = pct > 0 ? cash * pct / 100 : 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
        boxShadow: const [
          BoxShadow(color: Color(0xFFB8B1C8), offset: Offset(4,4), blurRadius: 10),
          BoxShadow(color: Colors.white, offset: Offset(-4,-4), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(CupertinoIcons.money_dollar_circle_fill, color: kPrimary, size: 18),
              ),
              const SizedBox(width: 8),
              Text(cat['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 14)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _finChip('${cash.toStringAsFixed(0)} دج', 'الحالي', Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _finChip('${total.toStringAsFixed(0)} دج', 'الإجمالي', kPrimary)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _finChip('$pct%', 'نسبة الخصم', Colors.amber.shade700)),
            const SizedBox(width: 8),
            Expanded(child: _finChip('${deducted.toStringAsFixed(0)} دج', 'يُخصم', Colors.red.shade600)),
          ]),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
              builder: (_) => CategoryStatementSheet(category: cat)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(CupertinoIcons.doc_text, color: kPrimary, size: 16),
                const SizedBox(width: 6),
                Text('كشف الحساب', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: kPrimary, fontSize: 13)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _finChip(String value, String label, Color color) => Column(
    children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color, fontFamily: 'Amiri')),
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Amiri')),
    ],
  );

  Widget _buildProductCard(Map<String, dynamic> p) {
    final int price = _readPriceInt(p);
    final int idx = _products.indexOf(p);
    final bool inAnyFav = _favorites.any(
        (f) => (f['productIds'] as List<dynamic>).contains(p['_id']));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 10,
              offset: const Offset(4, 4)),
          const BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: Offset(-4, -4)),
        ],
        border: Border.all(
            color: const Color(0xFF5B0094).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: idx > 0 ? () => _moveProduct(idx, -1) : null,
                child: Container(
                  width: 32, height: 24,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: idx > 0 ? const [
                      BoxShadow(color: kShadowDark, offset: Offset(1, 1), blurRadius: 3),
                      BoxShadow(color: kShadowLight, offset: Offset(-1, -1), blurRadius: 3),
                    ] : null,
                  ),
                  child: Icon(Icons.keyboard_arrow_up,
                    size: 18,
                    color: idx > 0 ? kPrimary : kTextSecondary.withOpacity(0.3)),
                ),
              ),
              GestureDetector(
                onTap: idx < _products.length - 1 ? () => _moveProduct(idx, 1) : null,
                child: Container(
                  width: 32, height: 24,
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: idx < _products.length - 1 ? const [
                      BoxShadow(color: kShadowDark, offset: Offset(1, 1), blurRadius: 3),
                      BoxShadow(color: kShadowLight, offset: Offset(-1, -1), blurRadius: 3),
                    ] : null,
                  ),
                  child: Icon(Icons.keyboard_arrow_down,
                    size: 18,
                    color: idx < _products.length - 1 ? kPrimary : kTextSecondary.withOpacity(0.3)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(Icons.delete_outline, kDanger, () {
                showCupertinoDialog(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: const Text("حذف المنتج",
                        style: TextStyle(fontFamily: 'Amiri')),
                    content: const Text(
                        "هل أنت متأكد من حذف هذا المنتج وجميع صوره؟",
                        style: TextStyle(fontFamily: 'Amiri')),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text("إلغاء",
                            style: TextStyle(fontFamily: 'Amiri')),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        child: const Text("حذف",
                            style: TextStyle(fontFamily: 'Amiri')),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ApiClient.deleteImageUrl(p['image'] ?? '');
                          if (p['extraImages'] is List) {
                            await ApiClient.deleteImageUrls(
                                List<String>.from(p['extraImages']));
                          }
                          await ApiClient.delete('/api/products/${p['_id']}');
                          await _load();
                          await _renumberAll();
                        },
                      ),
                    ],
                  ),
                );
              }),
              _iconBtn(Icons.edit_outlined, kPrimary,
                  () => _openEditor(context, p)),
              _iconBtn(
                inAnyFav ? Icons.favorite : Icons.favorite_border,
                inAnyFav ? kDanger : kTextSecondary,
                () => _showAddToFavoriteDialog(p['_id'], p['name'] ?? ''),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(p['name'] ?? '',
                  style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                      fontSize: 14)),
              Text("${price.toInt()} DA",
                  style: const TextStyle(
                      fontFamily: 'Amiri',
                      color: kPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              memCacheWidth: 150,
              imageUrl: p['image'] ?? '',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 52,
                height: 52,
                color: kSurface,
                child: const Icon(Icons.image_outlined,
                    color: kTextSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: kShadowDark, offset: Offset(2, 2), blurRadius: 5),
              BoxShadow(color: kShadowLight, offset: Offset(-2, -2), blurRadius: 5),
            ],
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );
}

// ------------------------------------------------------------------------------
//  ????? ????????
// ------------------------------------------------------------------------------
class FavoritesManagerSheet extends StatefulWidget {
  final String storeId;
  const FavoritesManagerSheet({super.key, required this.storeId});

  @override
  State<FavoritesManagerSheet> createState() => _FavoritesManagerSheetState();
}

class _FavoritesManagerSheetState extends State<FavoritesManagerSheet> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _favorites = [];
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadingList = true);
    try {
      final data =
          await ApiClient.getList('/api/favorites?storeId=${widget.storeId}');
      if (mounted) {
        setState(() {
          _favorites = List<Map<String, dynamic>>.from(data);
          _loadingList = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _addFavorite() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showAlert(context, "يرجى اختيار صورة للنكهة");
      return;
    }
    setState(() => _loading = true);
    await ApiClient.post('/api/favorites', {
      'name': name,
      'productIds': [],
      'storeId': widget.storeId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _nameCtrl.clear();
    setState(() => _loading = false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _sheetHeader("إضافة منتج جديد"),
          Row(
            children: [
              GestureDetector(
                onTap: _loading ? null : _addFavorite,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: kPrimaryGradient,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: kPrimary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildInput(_nameCtrl, "اسم المنتج...", )),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          Expanded(
            child: _loadingList
                ? const Center(child: CupertinoActivityIndicator())
                : _favorites.isEmpty
                    ? const Center(
                        child: Text("لا توجد منتجات مضافة",
                            style: TextStyle(
                                fontFamily: 'Amiri', color: kTextSecondary)))
                    : ListView.builder(
                        itemCount: _favorites.length,
                        itemBuilder: (context, i) {
                          final f = _favorites[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFB8B1C8).withOpacity(0.6),
                                    blurRadius: 10,
                                    offset: const Offset(4, 4)),
                                const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 10,
                                    offset: Offset(-4, -4)),
                              ],
                              border: Border.all(
                                  color: const Color(0xFF5B0094).withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    showCupertinoDialog(
                                      context: context,
                                      builder: (ctx) => CupertinoAlertDialog(
                                        title: const Text("حذف قائمة المفضلة",
                                            style: TextStyle(fontFamily: 'Amiri')),
                                        content: Text(
                                            "هل أنت متأكد من حذف قائمة '${f['name'] ?? ''}'؟",
                                            style: const TextStyle(fontFamily: 'Amiri')),
                                        actions: [
                                          CupertinoDialogAction(
                                            child: const Text("إلغاء",
                                                style: TextStyle(fontFamily: 'Amiri')),
                                            onPressed: () => Navigator.pop(ctx),
                                          ),
                                          CupertinoDialogAction(
                                            isDestructiveAction: true,
                                            child: const Text("حذف",
                                                style: TextStyle(fontFamily: 'Amiri')),
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              await ApiClient.delete('/api/favorites/${f['_id']}');
                                              _load();
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: kDanger.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.delete_sweep_outlined,
                                        color: kDanger, size: 18),
                                  ),
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(f['name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Amiri',
                                            color: kTextPrimary)),
                                    Text(
                                        "${(f['productIds'] as List).length} منتجات",
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: kTextSecondary,
                                            fontFamily: 'Amiri')),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      gradient: kPrimaryGradient,
                                      borderRadius: BorderRadius.circular(10)),
                                  child:
                                      const Icon(Icons.favorite, color: kWhite, size: 16),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  Sheet ????? ???? ??????
// ------------------------------------------------------------------------------
class _AddToFavoriteSheet extends StatefulWidget {
  final String storeId, productId, productName;
  final List<Map<String, dynamic>> favorites;
  final VoidCallback onFavoritesChanged;

  const _AddToFavoriteSheet({
    required this.storeId,
    required this.productId,
    required this.productName,
    required this.favorites,
    required this.onFavoritesChanged,
  });

  @override
  State<_AddToFavoriteSheet> createState() => _AddToFavoriteSheetState();
}

class _AddToFavoriteSheetState extends State<_AddToFavoriteSheet> {
  bool _saving = false;

  Future<void> _toggle(Map<String, dynamic> fav) async {
    setState(() => _saving = true);
    final ids = List<String>.from(fav['productIds'] as List<dynamic>);
    if (ids.contains(widget.productId)) {
      ids.remove(widget.productId);
    } else {
      ids.add(widget.productId);
    }
    await ApiClient.put('/api/favorites/${fav['_id']}', {'productIds': ids});
    widget.onFavoritesChanged();
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kTextSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "إضافة \"${widget.productName}\" للمفضلة",
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: kTextPrimary),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.favorites.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.favorite_border, color: kTextSecondary, size: 40),
                  SizedBox(height: 8),
                  Text(
                    "لا توجد مفضلة\nيمكنك إضافة منتجات للمفضلة هنا",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Amiri', color: kTextSecondary),
                  ),
                ],
              ),
            )
          else
            ...widget.favorites.map((fav) {
              final ids = List<String>.from(fav['productIds'] as List<dynamic>);
              final bool inFav = ids.contains(widget.productId);
              return GestureDetector(
                onTap: _saving ? null : () => _toggle(fav),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: inFav
                      ? BoxDecoration(
                          color: kPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kPrimary, width: 1.5),
                          boxShadow: _neuShadow(),
                        )
                      : BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFB8B1C8).withOpacity(0.6),
                                blurRadius: 10,
                                offset: const Offset(4, 4)),
                            const BoxShadow(
                                color: Colors.white,
                                blurRadius: 10,
                                offset: Offset(-4, -4)),
                          ],
                          border: Border.all(
                              color: const Color(0xFF5B0094).withOpacity(0.1)),
                        ),
                  child: Row(
                    children: [
                      Icon(inFav ? Icons.favorite : Icons.favorite_border,
                          color: inFav ? kPrimary : kTextSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(fav['name'] as String,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    inFav ? FontWeight.bold : FontWeight.w500,
                                fontFamily: 'Amiri',
                                color: inFav ? kPrimary : kTextPrimary)),
                      ),
                      if (_saving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kPrimary),
                        ),
                    ],
        ),
      ),
    );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  uiStyle == 1 � ?????????
// ------------------------------------------------------------------------------
class SupermarketProductEditor extends StatefulWidget {
  final String storeId, catId, catName;
  final Map<String, dynamic>? doc;
  final String? templateId;
  const SupermarketProductEditor({
    super.key,
    required this.storeId,
    required this.catId,
    required this.catName,
    this.doc,
    this.templateId,
  });

  @override
  State<SupermarketProductEditor> createState() =>
      _SupermarketProductEditorState();
}

class _SupermarketProductEditorState extends State<SupermarketProductEditor> {
  final _nameCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _capaciteCtrl = TextEditingController();

  File? _mainImg;
  String _existingMainImg = "";
  bool _loading = false;
  List<Map<String, dynamic>> _models = [];
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['name'] ?? "";
      _prixCtrl.text = _readPriceStr(d);
      _descCtrl.text = d['description'] ?? "";
      _existingMainImg = d['image'] ?? "";
      if (d['models'] != null) {
        for (var m in d['models']) {
          _models.add(
              {'name': m['name'] ?? '', 'existingUrl': m['image'] ?? '', 'imageFile': null});
        }
      }
      _capaciteCtrl.text = d['capacite']?.toString() ?? '';
      if (d['searchTags'] != null) _tags = List<String>.from(d['searchTags']);
    }
  }

  void _addModel() {
    final name = _modelCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _models.add({'name': name, 'existingUrl': '', 'imageFile': null});
      _modelCtrl.clear();
    });
  }

  Future<void> _pickModelImage(int idx) async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (p != null) setState(() => _models[idx]['imageFile'] = File(p.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال اسم المنتج أولاً");
      return;
    }
    if (_prixCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال السعر أولاً");
      return;
    }
    if (_mainImg == null && _existingMainImg.isEmpty) {
      _showAlert(context, "يرجى اختيار صورة للمنتج");
      return;
    }
    setState(() => _loading = true);
    try {
      String mainUrl = _existingMainImg;
      if (_mainImg != null) mainUrl = await _uploadImg(_mainImg!, 'products');
      List<Map<String, dynamic>> finalModels = [];
      for (var m in _models) {
        String mUrl = m['existingUrl'];
        if (m['imageFile'] != null)
          mUrl = await _uploadImg(m['imageFile'], 'models');
        finalModels.add({'name': m['name'], 'image': mUrl});
      }
      final String capacite = _capaciteCtrl.text.trim();
      final data = {
        'name': _nameCtrl.text.trim(),
        'image': mainUrl,
        'prix': double.tryParse(_prixCtrl.text) ?? 0,
        'description': _descCtrl.text.trim(),
        'categorieId': widget.catId,
        'categorieNom': widget.catName,
        'magasinId': widget.storeId,
        'stylePizza': false,
        'storeId': widget.storeId,
        'templateId': widget.templateId,
        'models': finalModels,
        'searchTags': _tags,
        'capacite': capacite,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (widget.doc == null) {
        await ApiClient.post(
            '/api/products', {...data, 'createdAt': DateTime.now().toIso8601String()});
      } else {
        await ApiClient.put('/api/products/${widget.doc!['_id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showAlert(context, "حدث خطأ أثناء الحفظ: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sheetHeader("إضافة / تعديل المنتج"),
            Center(
              child: _ImagePicker(
                imageFile: _mainImg,
                existingUrl: _existingMainImg,
                size: 110,
                onTap: () async {
                  final p =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (p != null) setState(() => _mainImg = File(p.path));
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildInput(_nameCtrl, "اسم المنتج", icon: Icons.inventory_2_outlined, ),
            _buildInput(_prixCtrl, "السعر",
                isNum: true, icon: Icons.payments_outlined, suffix: "DA"),
            _buildInput(_capaciteCtrl, "السعة / الحجم (مثلاً: 1.5 لتر أو 500 مل)",
                icon: Icons.scale_outlined, ),
            _buildInput(_descCtrl, "وصف المنتج",
                maxLines: 3, icon: Icons.description_outlined, ),
            const SizedBox(height: 8),
            _sectionLabel("المقاسات", Icons.style_outlined),
            Row(
              children: [
                GestureDetector(
                  onTap: _addModel,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        gradient: kPrimaryGradient,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add, color: kWhite),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildInput(_modelCtrl, "اسم المقاس (اختياري...)")),
              ],
            ),
            ..._models.asMap().entries.map((entry) {
              int idx = entry.key;
              var m = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8, top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFB8B1C8).withOpacity(0.6),
                        blurRadius: 10,
                        offset: const Offset(4, 4)),
                    const BoxShadow(
                        color: Colors.white,
                        blurRadius: 10,
                        offset: Offset(-4, -4)),
                  ],
                  border:
                      Border.all(color: const Color(0xFF5B0094).withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _models.removeAt(idx)),
                      child: const Icon(Icons.remove_circle_outline,
                          color: kDanger, size: 20),
                    ),
                    Expanded(
                      child: Text(m['name'],
                          style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontWeight: FontWeight.bold,
                              color: kTextPrimary),
                          textAlign: TextAlign.right),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _pickModelImage(idx),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: kBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: kShadowDark.withOpacity(0.5))),
                        child: m['imageFile'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.file(m['imageFile'],
                                    fit: BoxFit.cover))
                            : (m['existingUrl'] != ""
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: CachedNetworkImage(
                                        memCacheWidth: 150,
                                        imageUrl: m['existingUrl'],
                                        fit: BoxFit.cover))
                                : const Icon(Icons.add_a_photo,
                                    color: kPrimaryLight, size: 20)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            _SearchTagsSection(
                tags: _tags, onChanged: (v) => setState(() => _tags = v)),
            const SizedBox(height: 28),
            _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _neuButton("حفظ المنتج", _save, icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  uiStyle == 3 � ???????
// ------------------------------------------------------------------------------
class PatisserieProductEditor extends StatefulWidget {
  final String storeId, catId, catName;
  final Map<String, dynamic>? doc;
  final String? templateId;
  const PatisserieProductEditor({
    super.key,
    required this.storeId,
    required this.catId,
    required this.catName,
    this.doc,
    this.templateId,
  });

  @override
  State<PatisserieProductEditor> createState() =>
      _PatisserieProductEditorState();
}

class _PatisserieProductEditorState extends State<PatisserieProductEditor> {
  final _nameCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _mqiasCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _mainImg;
  String _existingMainImg = "";
  bool _loading = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['name'] ?? "";
      _prixCtrl.text = _readPriceStr(d);
      _mqiasCtrl.text = d['capacite'] ?? "";
      _descCtrl.text = d['description'] ?? "";
      _existingMainImg = d['image'] ?? "";
      if (d['searchTags'] != null) _tags = List<String>.from(d['searchTags']);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) {
      _showAlert(context, "يرجى إدخال اسم المنتج أولاً");
      return;
    }
    setState(() => _loading = true);
    try {
      String mainUrl = _existingMainImg;
      if (_mainImg != null) mainUrl = await _uploadImg(_mainImg!, 'products');
      final data = {
        'name': _nameCtrl.text.trim(),
        'image': mainUrl,
        'prix': double.tryParse(_prixCtrl.text) ?? 0,
        'capacite': _mqiasCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'categorieId': widget.catId,
        'categorieNom': widget.catName,
        'magasinId': widget.storeId,
        'storeId': widget.storeId,
        'templateId': widget.templateId,
        'stylePizza': false,
        'searchTags': _tags,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (widget.doc == null) {
        await ApiClient.post(
            '/api/products', {...data, 'createdAt': DateTime.now().toIso8601String()});
      } else {
        await ApiClient.put('/api/products/${widget.doc!['_id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showAlert(context, "حدث خطأ أثناء الحفظ: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sheetHeader("إضافة / تعديل منتج باتيسري"),
            Center(
              child: _ImagePicker(
                imageFile: _mainImg,
                existingUrl: _existingMainImg,
                size: 110,
                onTap: () async {
                  final p =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (p != null) setState(() => _mainImg = File(p.path));
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildInput(_nameCtrl, "اسم المنتج", icon: Icons.cake_outlined, ),
            _buildInput(_prixCtrl, "السعر",
                isNum: true, icon: Icons.payments_outlined, suffix: "DA"),
            _buildInput(_mqiasCtrl, "المقياس (مثلاً 20 سم...)",
                icon: Icons.straighten_outlined, ),
            _buildInput(_descCtrl, "وصف المنتج",
                maxLines: 3, icon: Icons.description_outlined, ),
            const SizedBox(height: 16),
            _SearchTagsSection(
                tags: _tags, onChanged: (v) => setState(() => _tags = v)),
            const SizedBox(height: 28),
            _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _neuButton("حفظ المنتج", _save, icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  uiStyle == 2 � ?????
// ------------------------------------------------------------------------------
class PizzaProductEditor extends StatefulWidget {
  final String storeId, catId, catName;
  final bool isPizza;
  final String? templateId;
  final Map<String, dynamic>? doc;
  const PizzaProductEditor({
    super.key,
    required this.storeId,
    required this.catId,
    required this.catName,
    required this.isPizza,
    this.doc,
    this.templateId,
  });

  @override
  State<PizzaProductEditor> createState() => _PizzaProductEditorState();
}

class _PizzaProductEditorState extends State<PizzaProductEditor> {
  final _nameCtrl = TextEditingController();
  final _prixNormalCtrl = TextEditingController();
  File? _mainImg;
  String _existingMainImg = "";
  bool _loading = false;
  List<Map<String, dynamic>> _pizzaFlavors = [];
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['name'] ?? "";
      _existingMainImg = d['image'] ?? "";
      if (!widget.isPizza) _prixNormalCtrl.text = _readPriceStr(d);
      if (widget.isPizza && d['toppings'] != null) {
        for (var t in d['toppings']) {
          final sizes = List<Map<String, dynamic>>.from(t['sizes'] ?? []);
          _pizzaFlavors.add({
            'name': t['label'],
            'existingUrl': t['image'],
            'imageFile': null,
            'sizes': sizes,
            if (sizes.isEmpty) 'price': t['price'] ?? 0,
          });
        }
      }
      if (d['searchTags'] != null) _tags = List<String>.from(d['searchTags']);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال اسم المنتج أولاً");
      return;
    }
    setState(() => _loading = true);
    try {
      String mainUrl = _existingMainImg;
      if (_mainImg != null) mainUrl = await _uploadImg(_mainImg!, 'products');
      List<Map<String, dynamic>> finalTops = [];
      for (var f in _pizzaFlavors) {
        String fUrl = f['existingUrl'];
        if (f['imageFile'] != null)
          fUrl = await _uploadImg(f['imageFile'], 'toppings');
        finalTops.add({
          'label': f['name'],
          'image': fUrl,
          'sizes': f['sizes'],
          if ((f['sizes'] as List).isEmpty) 'price': f['price'] ?? 0,
        });
      }
      double firstPrice = 0;
      if (_pizzaFlavors.isNotEmpty) {
        final f = _pizzaFlavors[0];
        firstPrice = (f['sizes'] as List).isNotEmpty
            ? (f['sizes'][0]['price'] as num).toDouble()
            : ((f['price'] as num?) ?? 0).toDouble();
      }
      final data = {
        'name': _nameCtrl.text.trim(),
        'image': mainUrl,
        'prix': widget.isPizza
            ? firstPrice
            : double.tryParse(_prixNormalCtrl.text),
        'categorieId': widget.catId,
        'magasinId': widget.storeId,
        'stylePizza': widget.isPizza,
        'storeId': widget.storeId,
        'templateId': widget.templateId,
        'toppings': finalTops,
        'searchTags': _tags,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (widget.doc == null) {
        await ApiClient.post(
            '/api/products', {...data, 'createdAt': DateTime.now().toIso8601String()});
      } else {
        await ApiClient.put('/api/products/${widget.doc!['_id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showAlert(context, "حدث خطأ أثناء الحفظ: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _sheetHeader("إضافة بيتزا"),
            Center(
              child: _ImagePicker(
                imageFile: _mainImg,
                existingUrl: _existingMainImg,
                size: 110,
                onTap: () async {
                  final p =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (p != null) setState(() => _mainImg = File(p.path));
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildInput(_nameCtrl, "اسم المنتج",
                icon: Icons.local_pizza_outlined, ),
            if (!widget.isPizza)
              _buildInput(_prixNormalCtrl, "السعر العادي",
                  isNum: true, icon: Icons.payments_outlined, suffix: "DA"),
            if (widget.isPizza) ...[
              const SizedBox(height: 8),
              ..._pizzaFlavors.asMap().entries.map((fe) {
                int fIdx = fe.key;
                var f = fe.value;
                return _FlavorCard(
                  flavor: f,
                  onDelete: () =>
                      setState(() => _pizzaFlavors.removeAt(fIdx)),
                  onChanged: () => setState(() {}),
                );
              }),
              GestureDetector(
                onTap: () async {
                  final p = await ImagePicker().pickImage(
                      source: ImageSource.gallery);
                  if (p != null) {
                    setState(() => _pizzaFlavors.add({
                          'name': '',
                          'imageFile': File(p.path),
                          'existingUrl': '',
                          'sizes': <Map<String, dynamic>>[
                            {'label': '', 'price': 0.0}
                          ],
                        }));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: kPrimary.withOpacity(0.3)),
                    boxShadow: _neuShadow(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.local_pizza_outlined, color: kPrimary, size: 20),
                      SizedBox(width: 8),
                      Text("إضافة نكهة",
                          style: TextStyle(
                              fontFamily: 'Amiri',
                              color: kPrimary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SearchTagsSection(
                tags: _tags, onChanged: (v) => setState(() => _tags = v)),
            const SizedBox(height: 28),
            _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _neuButton("حفظ المنتج", _save, icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  uiStyle == 4 � ??? ??????
// ------------------------------------------------------------------------------
class GreenGrocerProductEditor extends StatefulWidget {
  final String storeId, catId, catName;
  final Map<String, dynamic>? doc;
  final String? templateId;
  const GreenGrocerProductEditor({
    super.key,
    required this.storeId,
    required this.catId,
    required this.catName,
    this.doc,
    this.templateId,
  });

  @override
  State<GreenGrocerProductEditor> createState() =>
      _GreenGrocerProductEditorState();
}

class _GreenGrocerProductEditorState
    extends State<GreenGrocerProductEditor> {
  final _nameCtrl = TextEditingController();
  final _priceKgCtrl = TextEditingController();
  final _pricePerPieceCtrl = TextEditingController();
  File? _mainImg;
  String _existingMainImg = "";
  bool _loading = false;
  bool _hasPiecePrice = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['name'] ?? "";
      _priceKgCtrl.text = _readPriceStr(d);
      _pricePerPieceCtrl.text = _readPriceStrFrom(d, 'pricePerPiece');
      _existingMainImg = d['image'] ?? "";
      _hasPiecePrice = d['hasPiecePrice'] == true;
      if (d['searchTags'] != null) _tags = List<String>.from(d['searchTags']);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال اسم المنتج أولاً");
      return;
    }
    if (_mainImg == null && _existingMainImg.isEmpty) {
      _showAlert(context, "يرجى اختيار صورة للمنتج");
      return;
    }
    setState(() => _loading = true);
    try {
      String mainUrl = _existingMainImg;
      if (_mainImg != null) mainUrl = await _uploadImg(_mainImg!, 'products');
      final data = {
        'name': _nameCtrl.text.trim(),
        'image': mainUrl,
        'prix': double.tryParse(_priceKgCtrl.text) ?? 0,
        'pricePerKg': double.tryParse(_priceKgCtrl.text) ?? 0,
        'categorieId': widget.catId,
        'categorieNom': widget.catName,
        'magasinId': widget.storeId,
        'storeId': widget.storeId,
        'templateId': widget.templateId,
        'stylePizza': false,
        'searchTags': _tags,
        'hasPiecePrice': _hasPiecePrice,
        'pricePerPiece': double.tryParse(_pricePerPieceCtrl.text) ?? 0,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (widget.doc == null) {
        await ApiClient.post(
            '/api/products', {...data, 'createdAt': DateTime.now().toIso8601String()});
      } else {
        await ApiClient.put('/api/products/${widget.doc!['_id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showAlert(context, "حدث خطأ أثناء الحفظ: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sheetHeader("إضافة لحم / وزني"),
            Center(
              child: _ImagePicker(
                imageFile: _mainImg,
                existingUrl: _existingMainImg,
                size: 120,
                label: "اختيار صورة",
                onTap: () async {
                  final p =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (p != null) setState(() => _mainImg = File(p.path));
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildInput(_nameCtrl, "اسم المنتج (لحم مفروم...)",
                icon: Icons.eco_outlined, ),
            _buildInput(_priceKgCtrl, "سعر الكيلوغرام",
                isNum: true, suffix: "DA/كغ"),
            const SizedBox(height: 8),
            _neuBox(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SwitchListTile(
                title: const Text("إضافة سعر القطعة (حبة)؟",
                    textAlign: TextAlign.right,
                    style: TextStyle(fontFamily: 'Amiri', fontSize: 14)),
                activeColor: kPrimary,
                value: _hasPiecePrice,
                onChanged: (bool value) =>
                    setState(() => _hasPiecePrice = value),
              ),
            ),
            if (_hasPiecePrice) ...[
              const SizedBox(height: 12),
              _buildInput(_pricePerPieceCtrl, "سعر القطعة الواحدة",
                  isNum: true, icon: Icons.calculate_outlined, suffix: "DA"),
            ],
            const SizedBox(height: 16),
            _SearchTagsSection(
                tags: _tags, onChanged: (v) => setState(() => _tags = v)),
            const SizedBox(height: 28),
            _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _neuButton("حفظ المنتج", _save, icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  uiStyle == 5 � ????????
// ------------------------------------------------------------------------------
class CosmeticProductEditor extends StatefulWidget {
  final String storeId, catId, catName;
  final Map<String, dynamic>? doc;
  final String? templateId;
  const CosmeticProductEditor({
    super.key,
    required this.storeId,
    required this.catId,
    required this.catName,
    this.doc,
    this.templateId,
  });

  @override
  State<CosmeticProductEditor> createState() => _CosmeticProductEditorState();
}

class _CosmeticProductEditorState extends State<CosmeticProductEditor> {
  final _nameCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _mainImg;
  String _existingMainImg = "";
  bool _loading = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['name'] ?? "";
      _prixCtrl.text = _readPriceStr(d);
      _descCtrl.text = d['description'] ?? "";
      _existingMainImg = d['image'] ?? "";
      if (d['searchTags'] != null) _tags = List<String>.from(d['searchTags']);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال اسم المنتج أولاً");
      return;
    }
    if (_mainImg == null && _existingMainImg.isEmpty) {
      _showAlert(context, "يرجى اختيار صورة للمنتج");
      return;
    }
    setState(() => _loading = true);
    try {
      String mainUrl = _existingMainImg;
      if (_mainImg != null) mainUrl = await _uploadImg(_mainImg!, 'products');
      final data = {
        'name': _nameCtrl.text.trim(),
        'image': mainUrl,
        'prix': double.tryParse(_prixCtrl.text) ?? 0,
        'description': _descCtrl.text.trim(),
        'categorieId': widget.catId,
        'categorieNom': widget.catName,
        'magasinId': widget.storeId,
        'storeId': widget.storeId,
        'templateId': widget.templateId,
        'stylePizza': false,
        'searchTags': _tags,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (widget.doc == null) {
        await ApiClient.post(
            '/api/products', {...data, 'createdAt': DateTime.now().toIso8601String()});
      } else {
        await ApiClient.put('/api/products/${widget.doc!['_id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showAlert(context, "حدث خطأ أثناء الحفظ: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sheetHeader("إضافة / تعديل منتج تجميل"),
            Center(
              child: _ImagePicker(
                imageFile: _mainImg,
                existingUrl: _existingMainImg,
                size: 120,
                label: "اختيار صورة",
                onTap: () async {
                  final p =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (p != null) setState(() => _mainImg = File(p.path));
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildInput(_nameCtrl, "اسم المنتج", icon: Icons.spa_outlined, ),
            _buildInput(_prixCtrl, "السعر",
                isNum: true, icon: Icons.payments_outlined, suffix: "DA"),
            _buildInput(_descCtrl, "وصف المنتج (ملاحظات اختيارية...)",
                maxLines: 4, icon: Icons.description_outlined, ),
            const SizedBox(height: 12),
            _SearchTagsSection(
                tags: _tags, onChanged: (v) => setState(() => _tags = v)),
            const SizedBox(height: 28),
            _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _neuButton("حفظ المنتج", _save, icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  uiStyle == 6 � ??????
// ------------------------------------------------------------------------------
class ProjectsProductEditor extends StatefulWidget {
  final String storeId, catId, catName;
  final Map<String, dynamic>? doc;
  final String? templateId;
  const ProjectsProductEditor({
    super.key,
    required this.storeId,
    required this.catId,
    required this.catName,
    this.doc,
    this.templateId,
  });

  @override
  State<ProjectsProductEditor> createState() => _ProjectsProductEditorState();
}

class _ProjectsProductEditorState extends State<ProjectsProductEditor> {
  final _nameCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _mainImg;
  String _existingMainImg = "";
  bool _loading = false;
  List<String> _tags = [];
  List<Map<String, dynamic>> _sizes = [];
  List<Map<String, dynamic>> _extraImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['name'] ?? "";
      _prixCtrl.text = _readPriceStr(d);
      _descCtrl.text = d['description'] ?? "";
      _existingMainImg = d['image'] ?? "";
      if (d['searchTags'] != null) _tags = List<String>.from(d['searchTags']);
      if (d['sizes'] != null) {
        for (var s in d['sizes']) {
          _sizes.add({
            'label': s['label'] ?? '',
            'unit': s['sizeUnit'] ?? '',
            'price': _cleanPrice(s['price']),
            'imageFile': null,
            'existingUrl': s['image'] ?? '',
          });
        }
      }
      if (d['extraImages'] != null) {
        for (var url in d['extraImages']) {
          _extraImages.add({'file': null, 'url': url});
        }
      }
    }
  }

  void _addSize() {
    setState(() => _sizes.add(
        {'label': '', 'unit': '', 'price': '', 'imageFile': null, 'existingUrl': ''}));
  }

  Future<void> _pickExtraImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (p != null)
      setState(() => _extraImages.add({'file': File(p.path), 'url': ''}));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال اسم المنتج أولاً");
      return;
    }
    if (_mainImg == null && _existingMainImg.isEmpty) {
      _showAlert(context, "يرجى اختيار صورة للمنتج");
      return;
    }
    setState(() => _loading = true);
    try {
      String mainUrl = _existingMainImg;
      if (_mainImg != null) mainUrl = await _uploadImg(_mainImg!, 'products');
      List<Map<String, dynamic>> finalSizes = [];
      for (var s in _sizes) {
        String sUrl = s['existingUrl'];
        if (s['imageFile'] != null)
          sUrl = await _uploadImg(s['imageFile'], 'product_sizes');
        finalSizes.add({
          'label': s['label'],
          'price': double.tryParse(s['price'].toString()) ?? 0,
          'image': sUrl,
        });
      }
      List<String> finalExtraImages = [];
      for (var e in _extraImages) {
        if (e['file'] != null) {
          final url = await _uploadImg(e['file'], 'product_extras');
          if (url.isNotEmpty) finalExtraImages.add(url);
        } else if (e['url'].isNotEmpty) {
          finalExtraImages.add(e['url']);
        }
      }
      final data = {
        'name': _nameCtrl.text.trim(),
        'image': mainUrl,
        'prix': double.tryParse(_prixCtrl.text) ?? 0,
        'description': _descCtrl.text.trim(),
        'categorieId': widget.catId,
        'categorieNom': widget.catName,
        'magasinId': widget.storeId,
        'storeId': widget.storeId,
        'templateId': widget.templateId,
        'stylePizza': false,
        'searchTags': _tags,
        'sizes': finalSizes,
        'extraImages': finalExtraImages,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (widget.doc == null) {
        await ApiClient.post(
            '/api/products', {...data, 'createdAt': DateTime.now().toIso8601String()});
      } else {
        await ApiClient.put('/api/products/${widget.doc!['_id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showAlert(context, "حدث خطأ أثناء الحفظ: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.93,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sheetHeader("إضافة / تعديل منتج مشاريع"),
            Center(
              child: _ImagePicker(
                imageFile: _mainImg,
                existingUrl: _existingMainImg,
                size: 120,
                label: "اختيار صورة رئيسية",
                onTap: () async {
                  final p =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (p != null) setState(() => _mainImg = File(p.path));
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildInput(_nameCtrl, "اسم المنتج", icon: Icons.build_outlined, ),
            _buildInput(_prixCtrl, "السعر الأساسي",
                isNum: true, icon: Icons.payments_outlined, suffix: "DA"),
            _buildInput(_descCtrl, "وصف المنتج",
                maxLines: 3, icon: Icons.description_outlined, ),
            const SizedBox(height: 16),
            _sectionLabel("المقاسات المتوفرة (أبعاد)", Icons.straighten_outlined),
            ..._sizes.asMap().entries.map((entry) {
              int idx = entry.key;
              var s = entry.value;
              return _SizeItemCard(
                sizeData: s,
                onDelete: () => setState(() => _sizes.removeAt(idx)),
                onChanged: () => setState(() {}),
              );
            }),
            GestureDetector(
              onTap: _addSize,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary.withOpacity(0.3)),
                  boxShadow: _neuShadow(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add, color: kPrimary, size: 18),
                    SizedBox(width: 6),
                    Text("إضافة مقاس"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel("الصور الإضافية (اختياري)", Icons.photo_library_outlined),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._extraImages.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var e = entry.value;
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _neuShadow()),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: e['file'] != null
                              ? Image.file(e['file'], fit: BoxFit.cover)
                              : CachedNetworkImage(
                                  memCacheWidth: 150,
                                  imageUrl: e['url'], fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        left: 2,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _extraImages.removeAt(idx)),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                                color: kDanger, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 14, color: kWhite),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                GestureDetector(
                  onTap: _pickExtraImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPrimary.withOpacity(0.25)),
                      boxShadow: _neuShadow(),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: kPrimaryLight, size: 26),
                        SizedBox(height: 2),
                        Text("إضافة",
                            style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 10,
                                color: kTextSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SearchTagsSection(
                tags: _tags, onChanged: (v) => setState(() => _tags = v)),
            const SizedBox(height: 28),
            _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _neuButton("حفظ المنتج", _save, icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}

class _SizeItemCard extends StatefulWidget {
  final Map<String, dynamic> sizeData;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final String storeId;
  const _SizeItemCard({
    required this.sizeData,
    required this.onDelete,
    required this.onChanged,
    this.storeId = '',
  });

  @override
  State<_SizeItemCard> createState() => _SizeItemCardState();
}

class _SizeItemCardState extends State<_SizeItemCard> {
  late TextEditingController _labelCtrl;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl =
        TextEditingController(text: widget.sizeData['label'].toString());
    _priceCtrl =
        TextEditingController(text: _cleanPrice(widget.sizeData['price']));
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 10,
              offset: const Offset(4, 4)),
          const BoxShadow(
              color: Colors.white, blurRadius: 10, offset: Offset(-4, -4)),
        ],
        border: Border.all(color: const Color(0xFF5B0094).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: kDanger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline, color: kDanger, size: 18),
                ),
              ),
              const Spacer(),
              const Text("المقاس ١",
                  style: TextStyle(
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: kTextPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final p = await ImagePicker().pickImage(
                      source: ImageSource.gallery);
                  if (p != null) {
                    setState(() => widget.sizeData['imageFile'] = File(p.path));
                    widget.onChanged();
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimary.withOpacity(0.2)),
                  ),
                  child: widget.sizeData['imageFile'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(widget.sizeData['imageFile'],
                              fit: BoxFit.cover))
                      : (widget.sizeData['existingUrl'].isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: CachedNetworkImage(
                                  memCacheWidth: 150,
                                  imageUrl: widget.sizeData['existingUrl'],
                                  fit: BoxFit.cover))
                          : const Icon(Icons.add_a_photo_outlined,
                              color: kPrimaryLight, size: 24)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                                color: kShadowDark,
                                offset: Offset(2, 2),
                                blurRadius: 5),
                            BoxShadow(
                                color: kShadowLight,
                                offset: Offset(-2, -2),
                                blurRadius: 5),
                          ]),
                      child: TextField(
                        controller: _labelCtrl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontFamily: 'Amiri', fontSize: 13),
                        onChanged: (v) {
                          widget.sizeData['label'] = v;
                          widget.onChanged();
                        },
                        decoration: const InputDecoration(
                          hintText: "المقاس (مثلاً: 1 كغ / حبة)",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                                color: kShadowDark,
                                offset: Offset(2, 2),
                                blurRadius: 5),
                            BoxShadow(
                                color: kShadowLight,
                                offset: Offset(-2, -2),
                                blurRadius: 5),
                          ]),
                      child: TextField(
                        controller: _priceCtrl,
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontFamily: 'Amiri', fontSize: 13),
                        onChanged: (v) {
                          widget.sizeData['price'] = v;
                          widget.onChanged();
                        },
                        decoration: const InputDecoration(
                          hintText: "السعر DA",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  uiStyle == 7 � ????? ???????
// ------------------------------------------------------------------------------
class MultiSizeProductEditor extends StatefulWidget {
  final String storeId, catId, catName;
  final Map<String, dynamic>? doc;
  final String? templateId;
  const MultiSizeProductEditor({
    super.key,
    required this.storeId,
    required this.catId,
    required this.catName,
    this.doc,
    this.templateId,
  });

  @override
  State<MultiSizeProductEditor> createState() => _MultiSizeProductEditorState();
}

class _MultiSizeProductEditorState extends State<MultiSizeProductEditor> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  List<String> _tags = [];
  List<Map<String, dynamic>> _variants = [];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['name'] ?? "";
      if (d['searchTags'] != null) _tags = List<String>.from(d['searchTags']);
      if (d['variants'] != null) {
        for (var v in d['variants']) {
          _variants.add({
            'label': v['label'] ?? '',
            'unit': v['unit'] ?? '',
            'price': _cleanPrice(v['price']),
            'imageFile': null,
            'existingUrl': v['image'] ?? '',
          });
        }
      }
    }
  }

  void _addVariant() {
    setState(() => _variants.add(
        {'label': '', 'unit': '', 'price': '', 'imageFile': null, 'existingUrl': ''}));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال اسم المنتج أولاً");
      return;
    }
    if (_variants.isEmpty) {
      _showAlert(context, "يجب إضافة متغير واحد على الأقل");
      return;
    }
    setState(() => _loading = true);
    try {
      List<Map<String, dynamic>> finalVariants = [];
      for (var v in _variants) {
        String vUrl = v['existingUrl'];
        if (v['imageFile'] != null)
          vUrl = await _uploadImg(v['imageFile'], 'product_variants');
        finalVariants.add({
          'label': v['label'],
          'price': double.tryParse(v['price'].toString()) ?? 0,
          'image': vUrl,
        });
      }
      final double firstPrice = (finalVariants.isNotEmpty
          ? finalVariants[0]['price']
          : 0.0) as double;
      final data = {
        'name': _nameCtrl.text.trim(),
        'image': finalVariants.isNotEmpty ? finalVariants[0]['image'] : '',
        'prix': firstPrice,
        'categorieId': widget.catId,
        'categorieNom': widget.catName,
        'magasinId': widget.storeId,
        'storeId': widget.storeId,
        'templateId': widget.templateId,
        'stylePizza': false,
        'searchTags': _tags,
        'variants': finalVariants,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (widget.doc == null) {
        await ApiClient.post(
            '/api/products', {...data, 'createdAt': DateTime.now().toIso8601String()});
      } else {
        await ApiClient.put('/api/products/${widget.doc!['_id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showAlert(context, "حدث خطأ أثناء الحفظ: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sheetHeader("إضافة منتج متعدد المتغيرات"),
            _buildInput(_nameCtrl, "اسم المنتج",
                icon: Icons.inventory_2_outlined, ),
            const SizedBox(height: 16),
            _sectionLabel("المتغيرات المتوفرة (حجم/لون)", Icons.format_list_numbered),
            ..._variants.asMap().entries.map((entry) {
              int idx = entry.key;
              var v = entry.value;
              return _VariantCard(
                variantData: v,
                index: idx,
                onDelete: () => setState(() => _variants.removeAt(idx)),
                onChanged: () => setState(() {}),
              );
            }),
            GestureDetector(
              onTap: _addVariant,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    kPrimary.withOpacity(0.08),
                    kAccent.withOpacity(0.05)
                  ]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kPrimary.withOpacity(0.3)),
                  boxShadow: _neuShadow(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_circle_outline, color: kPrimary, size: 20),
                    SizedBox(width: 8),
                    Text("إضافة متغير"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SearchTagsSection(
                tags: _tags, onChanged: (v) => setState(() => _tags = v)),
            const SizedBox(height: 28),
            _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _neuButton("حفظ المنتج", _save, icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}

class _VariantCard extends StatefulWidget {
  final Map<String, dynamic> variantData;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final String storeId;
  const _VariantCard({
    required this.variantData,
    required this.index,
    required this.onDelete,
    required this.onChanged,
    this.storeId = '',
  });

  @override
  State<_VariantCard> createState() => _VariantCardState();
}

class _VariantCardState extends State<_VariantCard> {
  late TextEditingController _labelCtrl;
  late TextEditingController _priceCtrl;

  @override
    void initState() {
      super.initState();
      _labelCtrl =
          TextEditingController(text: widget.variantData['label'].toString());
      _priceCtrl =
          TextEditingController(text: _cleanPrice(widget.variantData['price']));
    }



  @override
  Widget build(BuildContext context) {
    final bool hasImage = widget.variantData['imageFile'] != null ||
        widget.variantData['existingUrl'].toString().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: hasImage
                ? kPrimary.withOpacity(0.2)
                : kDanger.withOpacity(0.15),
            width: 1.2),
        boxShadow: _neuShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: kDanger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline, color: kDanger, size: 17),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    gradient: kPrimaryGradient,
                    borderRadius: BorderRadius.circular(20)),
                child: Text("المقاس ${widget.index + 1}",
                    style: const TextStyle(
                        fontFamily: 'Amiri',
                        color: kWhite,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  final p = await ImagePicker().pickImage(
                      source: ImageSource.gallery);
                  if (p != null) {
                    setState(() => widget.variantData['imageFile'] = File(p.path));
                    widget.onChanged();
                  }
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: hasImage
                            ? kSuccess.withOpacity(0.4)
                            : kDanger.withOpacity(0.3),
                        width: 1.5),
                    boxShadow: _neuShadow(),
                  ),
                  child: widget.variantData['imageFile'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(widget.variantData['imageFile'],
                              fit: BoxFit.cover))
                      : (widget.variantData['existingUrl'].isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                  memCacheWidth: 150,
                                  imageUrl: widget.variantData['existingUrl'],
                                  fit: BoxFit.cover))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    color: kDanger.withOpacity(0.6), size: 24),
                                const SizedBox(height: 2),
                                const Text("الصورة",
                                    style: TextStyle(
                                        fontFamily: 'Amiri',
                                        fontSize: 9,
                                        color: kDanger)),
                              ],
                            )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                                color: kShadowDark,
                                offset: Offset(2, 2),
                                blurRadius: 5),
                            BoxShadow(
                                color: kShadowLight,
                                offset: Offset(-2, -2),
                                blurRadius: 5),
                          ]),
                      child: TextField(
                        controller: _labelCtrl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontFamily: 'Amiri', fontSize: 13),
                        onChanged: (v) {
                          widget.variantData['label'] = v;
                          widget.onChanged();
                        },
                        decoration: const InputDecoration(
                          hintText: "المقاس (مثلاً: 1 كغ / حبة)",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          kPrimary.withOpacity(0.04),
                          kAccent.withOpacity(0.02)
                        ]),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: kPrimary.withOpacity(0.15)),
                        boxShadow: const [
                          BoxShadow(
                              color: kShadowDark,
                              offset: Offset(2, 2),
                              blurRadius: 5),
                          BoxShadow(
                              color: kShadowLight,
                              offset: Offset(-2, -2),
                              blurRadius: 5),
                        ],
                      ),
                      child: TextField(
                        controller: _priceCtrl,
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kPrimary),
                        onChanged: (v) {
                          widget.variantData['price'] = v;
                          widget.onChanged();
                        },
                        decoration: const InputDecoration(
                          hintText: "السعر DA",
                          hintStyle: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              color: kTextSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  uiStyle == 8 � ??????? ??????: ???? + ??? + ????? ???????? + ??? + ?????
// ------------------------------------------------------------------------------
//
//  ?????? ??????: produits/{id}
//  name          : String
//  image         : String (URL)
//  prix          : double  (????? ???????)
//  description   : String
//  searchTags    : List<String>
//  stylePizza    : false
//  categorieId, categorieNom, magasinId, storeId, templateId : String
//
//  optionalSizes : [                 ? ???????? ???? ??? ?? ????? ??????
//    {
//      label     : String   (مثلاً: "كبير")
//      unit      : String   (مثلاً: "كغ" / "لتر" / "حبة")
//      price     : double
//      image     : String   (URL � ???????)
//    }
//  ]
//
//  createdAt, updatedAt : ISO String
// ------------------------------------------------------------------------------

class Style8ProductEditor extends StatefulWidget {
  final String storeId, catId, catName;
  final Map<String, dynamic>? doc;
  final String? templateId;

  const Style8ProductEditor({
    super.key,
    required this.storeId,
    required this.catId,
    required this.catName,
    this.doc,
    this.templateId,
  });

  @override
  State<Style8ProductEditor> createState() => _Style8ProductEditorState();
}

class _Style8ProductEditorState extends State<Style8ProductEditor> {
  // -- ?????? ???????? --
  final _nameCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  File? _mainImg;
  String _existingMainImg = "";
  bool _loading = false;

  // -- ??????? ?????????? --
  bool _hasSizes = false;
  List<Map<String, dynamic>> _sizes = [];

  // ????? ?????? ???????
  // -- ????? ????? --
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['name'] ?? "";
      _prixCtrl.text = _readPriceStr(d);
      _descCtrl.text = d['description'] ?? "";
      _existingMainImg = d['image'] ?? "";
      if (d['searchTags'] != null) _tags = List<String>.from(d['searchTags']);
      if (d['optionalSizes'] != null && (d['optionalSizes'] as List).isNotEmpty) {
        _hasSizes = true;
        for (var s in d['optionalSizes']) {
          _sizes.add({
            'label': s['label'] ?? '',
            'unit': s['unit'] ?? '',
            'price': _cleanPrice(s['price']),
            'imageFile': null,
            'existingUrl': s['image'] ?? '',
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _prixCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // -- ????? ??? ???? --
  void _addSize() {
    setState(() => _sizes.add({
          'label': '',
          'unit': '',
          'price': '',
          'imageFile': null,
          'existingUrl': '',
        }));
  }

  // -- ??? ?????? --
  Future<void> _save() async {
    // ??????
    if (_nameCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال اسم المنتج أولاً");
      return;
    }
    if (_prixCtrl.text.trim().isEmpty) {
      _showAlert(context, "يرجى إدخال سعر المنتج أولاً");
      return;
    }
    if (_mainImg == null && _existingMainImg.isEmpty) {
      _showAlert(context, "يرجى اختيار صورة للمنتج");
      return;
    }
    // ?????? ?? ??????? ?? ???? ??????
    if (_hasSizes) {
      if (_sizes.isEmpty) {
        _showAlert(context, "يجب إضافة مقاس واحد على الأقل عند تفعيل خاصية المقاسات");
        return;
      }
      for (int i = 0; i < _sizes.length; i++) {
        final s = _sizes[i];
        if (s['label'].toString().trim().isEmpty) {
          _showAlert(context, "يرجى إدخال اسم المقاس رقم ${i + 1}");
          return;
        }
        if (s['price'].toString().trim().isEmpty ||
            (double.tryParse(s['price'].toString()) ?? 0) <= 0) {
          _showAlert(context, "يرجى إدخال سعر صالح للمقاس رقم ${i + 1}");
          return;
        }
      }
    }

    setState(() => _loading = true);

    try {
      // ??? ?????? ????????
      String mainUrl = _existingMainImg;
      if (_mainImg != null) mainUrl = await _uploadImg(_mainImg!, 'products');

      // ??? ??? ??????? (????????)
      List<Map<String, dynamic>> finalSizes = [];
      if (_hasSizes) {
        for (var s in _sizes) {
          String sUrl = s['existingUrl'];
          if (s['imageFile'] != null) {
            sUrl = await _uploadImg(s['imageFile'], 'product_sizes');
          }
      finalSizes.add({
        'label': s['label'].toString().trim(),
        'price': double.tryParse(s['price'].toString()) ?? 0,
        'image': sUrl,
      });
        }
      }

      final data = {
        'name': _nameCtrl.text.trim(),
        'image': mainUrl,
        'prix': double.tryParse(_prixCtrl.text) ?? 0,
        'description': _descCtrl.text.trim(),
        'categorieId': widget.catId,
        'categorieNom': widget.catName,
        'magasinId': widget.storeId,
        'storeId': widget.storeId,
        'templateId': widget.templateId,
        'stylePizza': false,
        'searchTags': _tags,
        'optionalSizes': finalSizes,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (widget.doc == null) {
        await ApiClient.post('/api/products', {
          ...data,
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else {
        await ApiClient.put('/api/products/${widget.doc!['_id']}', data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showAlert(context, "عذراً، فشل حفظ المنتج. حاول مرة أخرى");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      height: MediaQuery.of(context).size.height * 0.93,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sheetHeader("إضافة / تعديل المنتج"),

            // -- ?????? ???????? --
            Center(
              child: _ImagePicker(
                imageFile: _mainImg,
                existingUrl: _existingMainImg,
                size: 120,
                label: "اختيار صورة",
                onTap: () async {
                  final p = await ImagePicker().pickImage(
                      source: ImageSource.gallery);
                  if (p != null) setState(() => _mainImg = File(p.path));
                },
              ),
            ),
            const SizedBox(height: 20),

            // -- ????? ?????? ??????? --
            _buildInput(_nameCtrl, "اسم المنتج",
                icon: Icons.inventory_2_outlined, ),
            _buildInput(_prixCtrl, "السعر العادي",
                isNum: true, icon: Icons.payments_outlined, suffix: "DA"),

            // -- ????? --
            _buildInput(_descCtrl, "وصف المنتج (اختياري)",
                maxLines: 3, icon: Icons.description_outlined, ),

            const SizedBox(height: 8),

            // ----------------------------------------------
            //  ??? ??????? � ????? ?????/?????
            // ----------------------------------------------
            _neuBox(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SwitchListTile(
                title: const Text(
                  "تفعيل خاصية المقاسات",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                subtitle: Text(
                  _hasSizes
                      ? "تتم إدارة المقاسات من القائمة أدناه"
                      : "المنتج بسعر ثابت بدون مقاسات",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 11,
                      color: kTextSecondary),
                ),
                activeColor: kPrimary,
                value: _hasSizes,
                onChanged: (val) {
                  setState(() {
                    _hasSizes = val;
                    if (!val) _sizes.clear();
                  });
                },
              ),
            ),

            // -- ????? ??????? --
            if (_hasSizes) ...[
              const SizedBox(height: 14),
              _sectionLabel("قائمة المقاسات", Icons.straighten_outlined),

              // ???? ???????
              ..._sizes.asMap().entries.map((entry) {
                final int idx = entry.key;
                final Map<String, dynamic> s = entry.value;
                return _Style8SizeCard(
                  index: idx,
                  sizeData: s,
                  onDelete: () => setState(() => _sizes.removeAt(idx)),
                  onChanged: () => setState(() {}),
                );
              }),

              // ?? ????? ???
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _addSize,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      kPrimary.withOpacity(0.07),
                      kAccent.withOpacity(0.04),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: kPrimary.withOpacity(0.3),
                        style: BorderStyle.solid),
                    boxShadow: _neuShadow(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_circle_outline,
                          color: kPrimary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "إضافة مقاس",
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          color: kPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // -- ????? ????? --
            _SearchTagsSection(
              tags: _tags,
              onChanged: (v) => setState(() => _tags = v),
            ),

            const SizedBox(height: 28),

            // -- ?? ????? --
            _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimary))
                : _neuButton("حفظ المنتج", _save, icon: Icons.save_outlined),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  ???? ??? ???? � ??? ???????? 8
//  ????? ???: ??? ????? + ???? + ??? + ???? ????????
// ------------------------------------------------------------------------------
class _Style8SizeCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> sizeData;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _Style8SizeCard({
    required this.index,
    required this.sizeData,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_Style8SizeCard> createState() => _Style8SizeCardState();
}

class _Style8SizeCardState extends State<_Style8SizeCard> {
  late TextEditingController _labelCtrl;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl =
        TextEditingController(text: widget.sizeData['label'].toString());
    _priceCtrl =
        TextEditingController(text: _cleanPrice(widget.sizeData['price']));
  }



  @override
  void dispose() {
    _labelCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImg = widget.sizeData['imageFile'] != null ||
        widget.sizeData['existingUrl'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: kPrimary.withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: _neuShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // -- ???? ?????? --
          Row(
            children: [
              // ?? ?????
              GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: kDanger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: kDanger, size: 18),
                ),
              ),
              const Spacer(),
              // ??? ?????
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: kPrimaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "المقاس ${widget.index + 1}",
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    color: kWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // -- ????? ?????? --
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ???? ????? � ????????
              GestureDetector(
                onTap: () async {
                  final p = await ImagePicker().pickImage(
                      source: ImageSource.gallery);
                  if (p != null) {
                    setState(
                        () => widget.sizeData['imageFile'] = File(p.path));
                    widget.onChanged();
                  }
                },
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasImg
                          ? kSuccess.withOpacity(0.4)
                          : kPrimary.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: _neuShadow(),
                  ),
                  child: widget.sizeData['imageFile'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            widget.sizeData['imageFile'],
                            fit: BoxFit.cover,
                          ),
                        )
                      : (widget.sizeData['existingUrl'].isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                memCacheWidth: 150,
                                imageUrl: widget.sizeData['existingUrl'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    color: kPrimaryLight.withOpacity(0.7),
                                    size: 22),
                                const SizedBox(height: 2),
                                const Text(
                                  "الصورة",
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 9,
                                    color: kTextSecondary,
                                  ),
                                ),
                              ],
                            )),
                ),
              ),
              const SizedBox(width: 12),

              // ??? ????? + ?????? + ?????
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // -- ??? / ???? ????? --
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: const [
                          BoxShadow(
                              color: kShadowDark,
                              offset: Offset(2, 2),
                              blurRadius: 5),
                          BoxShadow(
                              color: kShadowLight,
                              offset: Offset(-2, -2),
                              blurRadius: 5),
                        ],
                      ),
                      child: TextField(
                        controller: _labelCtrl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontFamily: 'Amiri', fontSize: 13),
                        onChanged: (v) {
                          widget.sizeData['label'] = v;
                          widget.onChanged();
                        },
                        decoration: const InputDecoration(
                          hintText: "مثال: 1 كغ / حبة",
                          hintStyle: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              color: kTextSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // -- ????? --
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          kPrimary.withOpacity(0.05),
                          kAccent.withOpacity(0.03),
                        ]),
                        borderRadius: BorderRadius.circular(11),
                        border:
                            Border.all(color: kPrimary.withOpacity(0.2)),
                        boxShadow: const [
                          BoxShadow(
                              color: kShadowDark,
                              offset: Offset(2, 2),
                              blurRadius: 5),
                          BoxShadow(
                              color: kShadowLight,
                              offset: Offset(-2, -2),
                              blurRadius: 5),
                        ],
                      ),
                      child: TextField(
                        controller: _priceCtrl,
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: kPrimary,
                        ),
                        onChanged: (v) {
                          widget.sizeData['price'] = v;
                          widget.onChanged();
                        },
                        decoration: const InputDecoration(
                          hintText: "السعر DA",
                          hintStyle: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 12,
                            color: kTextSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  ???? ????? ??????
// ------------------------------------------------------------------------------
class OwnerOffersPage extends StatefulWidget {
  final String storeId, storeName;
  const OwnerOffersPage({super.key, required this.storeId, required this.storeName});

  @override
  State<OwnerOffersPage> createState() => _OwnerOffersPageState();
}

class _OwnerOffersPageState extends State<OwnerOffersPage> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.getList(
          '/api/promotions?storeId=${widget.storeId}');
      if (mounted) {
        setState(() {
          _offers = List<Map<String, dynamic>>.from(data)
              .where((d) => d['isDeleted'] != true)
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text("محرر العروض",
            style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                color: kTextPrimary)),
        centerTitle: true,
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        onPressed: () => _openOfferEditor(context, null),
        label: const Text("إضافة عرض",
            style: TextStyle(fontFamily: 'Amiri', color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _offers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer_outlined,
                          size: 60, color: kTextSecondary.withOpacity(0.35)),
                      const SizedBox(height: 12),
                      const Text("لا توجد عروض بعد",
                          style: TextStyle(
                              fontFamily: 'Amiri', color: kTextSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _offers.length,
                  itemBuilder: (context, i) {
                    final d = _offers[i];
                    final bool isActive = d['isActive'] ?? true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _neuShadow()),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _offerIconBtn(Icons.delete_sweep_outlined,
                                    kDanger, () => _softDelete(context, d)),
                                const SizedBox(width: 6),
                                _offerIconBtn(Icons.edit_outlined, kPrimary,
                                    () => _openOfferEditor(context, d)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(d['title'] ?? '',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Amiri',
                                          color: kTextPrimary)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? kSuccess.withOpacity(0.15)
                                              : kDanger.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isActive ? "نشط" : "غير نشط",
                                          style: TextStyle(
                                              fontFamily: 'Amiri',
                                              fontSize: 10,
                                              color: isActive ? kSuccess : kDanger,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                          "${((d['price'] as num?) ?? 0).toInt()} DA",
                                          style: const TextStyle(
                                              fontFamily: 'Amiri',
                                              color: kPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            child: CachedNetworkImage(
                              memCacheWidth: 150,
                              imageUrl: d['image'] ?? '',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                color: kSurface,
                                child: const Icon(Icons.image_outlined,
                                    color: kTextSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _offerIconBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: kShadowDark, offset: Offset(2, 2), blurRadius: 5),
              BoxShadow(color: kShadowLight, offset: Offset(-2, -2), blurRadius: 5),
            ],
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );

  void _openOfferEditor(BuildContext context, Map<String, dynamic>? doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferEditorSheet(
        storeId: widget.storeId,
        storeName: widget.storeName,
        doc: doc,
      ),
    ).then((_) => _load());
  }

  void _softDelete(BuildContext context, Map<String, dynamic> doc) async {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("حذف العرض",
            style: TextStyle(fontFamily: 'Amiri')),
        content: const Text(
            "سيتم حذف هذا العرض وجميع بياناته نهائياً ولن يمكن استعادته خلال 3 أيام من تاريخ الحذف.",
            style: TextStyle(fontFamily: 'Amiri')),
        actions: [
          CupertinoDialogAction(
            child: const Text("إلغاء",
                style: TextStyle(fontFamily: 'Amiri')),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("حذف العرض",
                style: TextStyle(fontFamily: 'Amiri')),
            onPressed: () async {
              await ApiClient.put('/api/promotions/${doc['_id']}', {
                'isDeleted': true,
                'isActive': false,
                'deletedAt': DateTime.now().toIso8601String(),
              });
              _load();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  ???? ??????
// ------------------------------------------------------------------------------
class OfferEditorSheet extends StatefulWidget {
  final String storeId, storeName;
  final Map<String, dynamic>? doc;
  const OfferEditorSheet({
    super.key,
    required this.storeId,
    required this.storeName,
    this.doc,
  });

  @override
  State<OfferEditorSheet> createState() => _OfferEditorSheetState();
}

class _OfferEditorSheetState extends State<OfferEditorSheet> {
  final _titleCtrl = TextEditingController(),
      _descCtrl = TextEditingController(),
      _priceCtrl = TextEditingController();
  bool _isActive = true, _loading = false;
  File? _imgFile;
  String _existingImg = "";

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _titleCtrl.text = d['title'] ?? '';
      _descCtrl.text = d['description'] ?? '';
      _priceCtrl.text = _cleanPrice(d['price']);
      _existingImg = d['image'] ?? '';
      _isActive = d['isActive'] ?? true;
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _priceCtrl.text.trim().isEmpty ||
        (_imgFile == null && _existingImg.isEmpty)) {
      _showAlert(context, "يرجى ملء جميع الحقول المطلوبة وإضافة صورة");
      return;
    }
    setState(() => _loading = true);
    try {
      final storeData = await ApiClient.get('/api/stores/${widget.storeId}');
      String tName = storeData['templateName'] ?? '';
      String templateId = '';
      if (tName.isEmpty) {
        final String? tid = storeData['templateId'] as String?;
        if (tid != null && tid.isNotEmpty) {
          templateId = tid;
          try {
            final templateStore = await ApiClient.get('/api/stores/$tid');
            tName = templateStore['nom'] ?? '';
          } catch (_) {}
        }
      }
      double sLat = 0.0, sLng = 0.0;
      String firstCatId = '';
      String firstCatName = '';
      final catQueryId = templateId.isNotEmpty ? templateId : widget.storeId;
      try {
        final cats = await ApiClient.getList('/api/categories?templateId=$catQueryId&storeId=$catQueryId');
        if (cats.isNotEmpty) {
          final first = cats.first as Map<String, dynamic>;
          sLat = (first['lat'] as num?)?.toDouble() ?? 0.0;
          sLng = (first['lng'] as num?)?.toDouble() ?? 0.0;
          firstCatId = first['_id'] as String? ?? '';
          firstCatName = first['nom'] as String? ?? '';
        }
      } catch (_) {}
      String url = _existingImg;
      if (_imgFile != null) url = await _uploadImg(_imgFile!, 'promotions');
      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        'image': url,
        'storeId': widget.storeId,
        'storeName': widget.storeName,
        'isActive': _isActive,
        'isDeleted': false,
        'storeLat': sLat,
        'storeLng': sLng,
        'categorieId': firstCatId,
        'categoryName': firstCatName,
        'templateName': tName,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (widget.doc == null) {
        await ApiClient.post('/api/promotions',
            {...data, 'createdAt': DateTime.now().toIso8601String()});
      } else {
        await ApiClient.put('/api/promotions/${widget.doc!['_id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showAlert(context, "عذراً، فشل حفظ العرض: $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.doc != null;
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 25,
        right: 25,
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHeader(isEdit ? "تعديل العرض" : "إضافة عرض جديد"),
            GestureDetector(
              onTap: () async {
                final p = await ImagePicker().pickImage(
                    source: ImageSource.gallery);
                if (p != null) setState(() => _imgFile = File(p.path));
              },
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _neuShadow()),
                child: _imgFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(_imgFile!, fit: BoxFit.cover))
                    : (_existingImg.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                                memCacheWidth: 150,
                                imageUrl: _existingImg, fit: BoxFit.cover))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate,
                                  size: 40, color: kPrimaryLight),
                              SizedBox(height: 8),
                              Text("اختر صورة العرض",
                                  style: TextStyle(
                                      fontFamily: 'Amiri',
                                      color: kTextSecondary)),
                            ],
                          )),
              ),
            ),
            const SizedBox(height: 20),
            _buildInput(_titleCtrl, "عنوان العرض", icon: Icons.title),
            _buildInput(_descCtrl, "الوصف",
                icon: Icons.description_outlined, maxLines: 2, ),
            _buildInput(_priceCtrl, "السعر",
                icon: Icons.monetization_on_outlined, isNum: true, suffix: "DA"),
            if (isEdit) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _neuShadow()),
                child: SwitchListTile(
                  title: const Text("العرض نشط (اختياري)",
                      style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 14,
                          color: kTextPrimary)),
                  activeColor: kPrimary,
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ),
            ],
            const SizedBox(height: 25),
            _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _neuButton(
                    isEdit ? "تعديل العرض" : "نشر العرض",
                    _save,
                    icon: isEdit ? Icons.save_outlined : Icons.send_outlined,
                  ),
          ],
        ),
      ),
    );
  }
}
