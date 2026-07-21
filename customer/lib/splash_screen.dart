import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_page.dart';
import 'org/org.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/deliv.gif'), context).then((_) {
        _startSplash();
      });
    });
  }

  Future<void> _startSplash() async {
    final prefsFuture = SharedPreferences.getInstance();
    await Future.delayed(const Duration(milliseconds: 3600));
    if (!mounted) return;
    final prefs = await prefsFuture;
    final bool isFirstTime = prefs.getBool('is_first_time') ?? true;
    if (!mounted) return;
    final destination = isFirstTime ? const OnboardingScreen() : const MainPage();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7D29C6), Color(0xFF5B1D9E)],
          ),
        ),
        child: Image.asset(
          'assets/deliv.gif',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
