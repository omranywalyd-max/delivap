import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Services/version_check.dart';

class ForceUpdateScreen extends StatelessWidget {
  final VersionConfig config;

  const ForceUpdateScreen({super.key, required this.config});

  Future<void> _openUpdate(BuildContext context) async {
    final uri = Uri.parse(config.updateUrl);
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7D29C6), Color(0xFF5B1D9E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/deliv.gif',
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.system_update_alt,
                    color: Colors.white,
                    size: 72,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'نسخة جديدة متوفرة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'التطبيق اللي عندك قديم. جدّدها للتطبيق باش تواصل الخدمة بشكل كامل وأفضل.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  if (config.latestVersion.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'النسخة الجديدة: ${config.latestVersion}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => _openUpdate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF7D29C6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text(
                      'تحديث الآن',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
