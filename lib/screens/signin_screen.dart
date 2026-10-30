import 'dart:async';
import 'package:flutter/material.dart';
import 'package:financeapp/screens/banking_dashboard_screen.dart';
import 'package:financeapp/services/auth_service.dart';
import 'package:provider/provider.dart';

class OnboardingSlide {
  final String image;
  final String title;
  final String subtitle;

  const OnboardingSlide({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const int _virtualInitialPage = 3000; // Multi-thousand offset for seamless infinite loop both ways
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  static const List<OnboardingSlide> _slides = [
    OnboardingSlide(
      image: 'assets/images/slider_2.png',
      title: 'Manage Your Finance',
      subtitle: 'Secure & Seamless',
    ),
    OnboardingSlide(
      image: 'assets/images/slider_1.png',
      title: 'Track Every Expense',
      subtitle: 'Smart & Automatic Insights',
    ),
    OnboardingSlide(
      image: 'assets/images/slider_3.png',
      title: 'Sync with Cloud',
      subtitle: 'Always Private & Accessible',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.78, // Reduced gap between cards
      initialPage: _virtualInitialPage,
    );
    _startAutoSlideTimer();
  }

  void _startAutoSlideTimer() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isLoading = authService.isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (Pure white at top, radiant blue at bottom)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.36, 0.48, 0.60, 0.72, 0.86, 1.0],
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0xFFE6EFF5),
                    Color(0xFF5597BF),
                    Color(0xFF32BBFD),
                    Color(0xFF1A90FF),
                    Color(0xFF0D72FF),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Top Header: App Logo + OneWallet
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'OneWallet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F1F1F),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Center Infinite 3-Card Carousel with Auto-slide & Touch Support
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification) {
                        // Pause auto-slide while user is dragging
                        _autoSlideTimer?.cancel();
                      } else if (notification is ScrollEndNotification) {
                        // Resume auto-slide after user finishes touch/scroll
                        _startAutoSlideTimer();
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (pageIndex) {
                        setState(() {
                          _currentPage = ((pageIndex % _slides.length) + _slides.length) % _slides.length;
                        });
                      },
                      itemBuilder: (context, index) {
                        final slideIndex = ((index % _slides.length) + _slides.length) % _slides.length;
                        final slide = _slides[slideIndex];

                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double scale = 1.0;
                            if (_pageController.position.haveDimensions) {
                              final page = _pageController.page ?? _virtualInitialPage.toDouble();
                              scale = (1 - ((page - index).abs() * 0.08)).clamp(0.92, 1.0);
                            }
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  slide.image,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Dynamic Title and Subtitle
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    key: ValueKey<int>(_currentPage),
                    children: [
                      Text(
                        _slides[_currentPage].title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _slides[_currentPage].subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Indicators (Dots: inactive white circle, active dark pill)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) {
                    final bool isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 24 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF1F1F1F) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 26),

                // Google Sign-In Button ("Continue with Gmail")
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final success = await context.read<AuthService>().signIn();
                              if (context.mounted) {
                                if (success) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const BankingDashboardScreen()),
                                  );
                                } else {
                                  final error = context.read<AuthService>().errorMessage;
                                  if (error != null && !error.toLowerCase().contains('cancelled')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(error),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F1F1F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else ...[
                            Image.asset(
                              'assets/images/google_g.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            isLoading ? 'Signing in with Google...' : 'Continue with Gmail',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
