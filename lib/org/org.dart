import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_page.dart';
import '../Order/order_models.dart';

// الألوان الخاصة بتصميمك
const kPrimaryColor = Color(0xFF7D29C6);
const kBgColor = Color(0xFFF1F0F5);
const kNeumLight = Color(0xFFD8D7DE);
const kNeumShadow = Color(0xFFB8B1C8);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingModel> _pages = [
    OnboardingModel(
      title: "مرحبًا بك في Deliv",
      desc:
          "كل ما تحتاجه من متاجرك المفضلة، اطلبه بخطوات بسيطة.",
      image: "assets/images/1.jpg",
    ),
    OnboardingModel(
      title: "توصيل سريع وآمن",
      desc: "يصل طلبك بسرعة مع سائقين موثوقين وتتبع مباشر",
      image: "assets/images/2.jpg",
    ),
    OnboardingModel(
      title: "تتبع طلبك",
      desc: "تابع طلبك لحظة بلحظة اعرف مكان طلبك واستلمه بكل راحة وأمان.",
      image: "assets/images/3.jpg",
    ),
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      'is_first_time',
      false,
    ); // حفظ أن المستخدم شاهد التعريفات
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: kBgColor,
      body: Stack(
        children: [
          statusBarGradient(context),
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              height: size.height * 0.4,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [kBgColor, Color(0xFFE6E4F0)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kNeumShadow.withOpacity(0.6),
                                    blurRadius: 10,
                                    offset: Offset(4, 4),
                                  ),
                                  BoxShadow(
                                    color: kNeumLight,
                                    blurRadius: 10,
                                    offset: Offset(-4, -4),
                                  ),
                                ],
                                border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
                              ),
                              child: Image.asset(
                                _pages[index].image,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.05),
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [kPrimaryColor, Color(0xFF9C27B0)],
                            ).createShader(b),
                            child: Text(
                              _pages[index].title,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _pages[index].desc,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                              height: 1.5,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _buildBottomSection(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // النقاط (Dots)
          Row(
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                height: 8,
                width: _currentIndex == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index ? kPrimaryColor : kNeumShadow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // الزر (Neumorphic)
          GestureDetector(
            onTap: () {
              if (_currentIndex == _pages.length - 1) {
                _finishOnboarding();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              decoration: BoxDecoration(
                color: kBgColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: kNeumShadow,
                    offset: Offset(5, 5),
                    blurRadius: 10,
                  ),
                  BoxShadow(
                    color: kNeumLight,
                    offset: Offset(-5, -5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    _currentIndex == _pages.length - 1 ? "ابدأ الآن" : "التالي",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _currentIndex == _pages.length - 1
                        ? Icons.rocket_launch
                        : Icons.arrow_forward_ios,
                    size: 16,
                    color: kPrimaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingModel {
  final String title, desc, image;
  OnboardingModel({
    required this.title,
    required this.desc,
    required this.image,
  });
}
