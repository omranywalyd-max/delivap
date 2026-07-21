import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dashbord/admin_panel.dart';
import 'package:dashbord/driver_app.dart';
import 'package:dashbord/services/api_client.dart';

class DriverSplashScreen extends StatefulWidget {
  const DriverSplashScreen({super.key});

  @override
  State<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends State<DriverSplashScreen> {
  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    final prefsFuture = SharedPreferences.getInstance();
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final prefs = await prefsFuture;
    final savedRole = prefs.getString('userRole');

    if (FirebaseAuth.instance.currentUser != null) {
      ApiClient.setToken(null);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const _DriverAuthGate()),
        (r) => false,
      );
      return;
    }
    if (savedRole == 'admin') {
      Navigator.of(context).pushReplacementNamed('/admin');
      return;
    }
    if (savedRole == 'owner') {
      final dataRaw = prefs.getString('ownerData');
      if (dataRaw != null) {
        try {
          final token = prefs.getString('adminToken');
          if (token != null) ApiClient.setToken(token);
          final data = jsonDecode(dataRaw);
          // Validate token by making a test API call
          if (token != null) {
            try {
              final testRes = await ApiClient.get('/api/stores/${data['magasinId'] ?? ''}');
              if (testRes.isEmpty) {
                ApiClient.setToken(null);
                await prefs.remove('adminToken');
                await prefs.remove('ownerData');
                await prefs.remove('userRole');
                if (mounted) Navigator.of(context).pushReplacementNamed('/login');
                return;
              }
            } catch (_) {
              // Token might be invalid, but continue anyway - orders page will handle it
            }
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => OwnerDashboard(ownerData: data)),
          );
          return;
        } catch (_) {}
      }
    }
    Navigator.of(context).pushReplacementNamed('/login');
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

class _DriverAuthGate extends StatefulWidget {
  const _DriverAuthGate();
  @override
  State<_DriverAuthGate> createState() => _DriverAuthGateState();
}

class _DriverAuthGateState extends State<_DriverAuthGate> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? 'driver';
    if (!mounted) return;
    if (role == 'admin') {
      Navigator.of(context).pushReplacementNamed('/admin');
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DriverMainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
