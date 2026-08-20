import 'package:flutter/foundation.dart';

/// مخزن الرسائل غير المقروءة لمحادثات المشاريع (الزبون).
/// تستمع له شاشة الطلبيات وشريط التنقل السفلي ليتحدثا فور وصول رسالة.
class ProjectUnreadStore extends ChangeNotifier {
  ProjectUnreadStore._();
  static final ProjectUnreadStore instance = ProjectUnreadStore._();

  final Map<String, int> _counts = {};

  Map<String, int> get counts => Map.unmodifiable(_counts);

  int get total => _counts.values.fold(0, (a, b) => a + b);

  int countFor(String projectId) => _counts[projectId] ?? 0;

  void setFromServer(Map<String, int> counts) {
    _counts
      ..clear()
      ..addAll(counts);
    notifyListeners();
  }

  void add(String projectId, int n) {
    if (projectId.isEmpty || n <= 0) return;
    _counts[projectId] = (_counts[projectId] ?? 0) + n;
    notifyListeners();
  }

  void markRead(String projectId) {
    if (_counts.remove(projectId) != null) notifyListeners();
  }

  void resetAll() {
    _counts.clear();
    notifyListeners();
  }
}
