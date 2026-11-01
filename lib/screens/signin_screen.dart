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

class _SignInScreenState extends State<SignInScreen> with TickerProviderStateMixin {
  static const int _virtualInitialPage = 3000;
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  // Final Transition Controller (Converging into Brand Logo with Spring Bounce)
  late final AnimationController _finalTransitionController;
  late final Animation<double> _contentFadeAnimation;
  late final Animation<double> _contentScaleAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoOpacityAnimation;

  static const List<OnboardingSlide> _slides = [
    OnboardingSlide(
      image: 'assets/images/slider_2.png',
      title: 'Save your time\nand energy',
      subtitle: 'Stay updated at every step, we report to you.\nSmart and effortless financial management\nfor your daily growth.',
    ),
    OnboardingSlide(
      image: 'assets/images/slider_1.png',
      title: 'Track every expense\nautomatically',
      subtitle: 'Clear insights and analytics to keep your\nfinancial goals on track effortlessly and\nsecurely every day.',
    ),
    OnboardingSlide(
      image: 'assets/images/slider_3.png',
      title: 'Sync your data\nwith private cloud',
      subtitle: 'Your personal finance data is encrypted,\nalways private and accessible anytime\nwherever you are.',
    ),
  ];

  // Spacing Configuration: Top Padding is 2X of Bottom Padding
  static const double _bottomPadding = 36.0;
  static const double _topPadding = _bottomPadding * 2; // 72.0

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 1.0,
      initialPage: _virtualInitialPage,
    );

    _startAutoSlideTimer();

    // Final Transition Animation Setup
    _finalTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _contentFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _finalTransitionController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _contentScaleAnimation = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(
        parent: _finalTransitionController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInBack),
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _finalTransitionController,
        curve: const Interval(0.35, 0.65, curve: Curves.easeIn),
      ),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _finalTransitionController,
        curve: const Interval(0.35, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  void _startAutoSlideTimer() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.previousPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _triggerFinalTransitionAndNavigate() async {
    _autoSlideTimer?.cancel();
    await _finalTransitionController.forward();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: const BankingDashboardScreen(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    _finalTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isLoading = authService.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Rich Ambient Radiant Background Gradient (Pristine White at top, Rich Blue at bottom)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.40, 0.55, 0.72, 0.88, 1.0],
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0xFFEEF7FD),
                    Color(0xFFBBE0F9),
                    Color(0xFF70BEF5),
                    Color(0xFF1E93FF),
                  ],
                ),
              ),
            ),
          ),

          // Main Onboarding Screen Content
          AnimatedBuilder(
            animation: _finalTransitionController,
            builder: (context, child) {
              return Transform.scale(
                scale: _contentScaleAnimation.value,
                child: Opacity(
                  opacity: _contentFadeAnimation.value,
                  child: child,
                ),
              );
            },
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Padding: Exactly 2X of Bottom Padding (72.0)
                  const SizedBox(height: _topPadding),

                  // 1. Left-Aligned Top Header: App Logo + OneWallet
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 30,
                          height: 30,
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
                  ),
                  
                  // Gap between Header Logo and Headline (44.0)
                  const SizedBox(height: 44),

                  // 2. Left-Aligned Headline & Subtitle Text Section (FIXED CONTAINER HEIGHTS)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Headline Word-by-Word Sequential Fade Animator (FIXED HEIGHT FOR 2 LINES: 84px)
                        SizedBox(
                          height: 84.0,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: WordByWordAnimator(
                              text: _slides[_currentPage].title,
                              style: const TextStyle(
                                color: Color(0xFF111111),
                                fontSize: 34,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                              ),
                              spacing: 7.0,
                              runSpacing: 4.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Subtitle Word-by-Word Sequential Fade Animator (FIXED HEIGHT FOR 3 LINES: 78px)
                        SizedBox(
                          height: 78.0,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: WordByWordAnimator(
                              text: _slides[_currentPage].subtitle,
                              style: const TextStyle(
                                color: Color(0xFF444444),
                                fontSize: 18,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                              ),
                              spacing: 5.0,
                              runSpacing: 4.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Middle PNG Illustration Slider (Per-Slide Smooth Left-to-Right Glide - Zero Reset Jump!)
                  Expanded(
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.76,
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollStartNotification) {
                                _autoSlideTimer?.cancel();
                              } else if (notification is ScrollEndNotification) {
                                _startAutoSlideTimer();
                              }
                              return false;
                            },
                            child: PageView.builder(
                              controller: _pageController,
                              clipBehavior: Clip.none,
                              onPageChanged: (pageIndex) {
                                setState(() {
                                  _currentPage = ((pageIndex % _slides.length) + _slides.length) % _slides.length;
                                });
                              },
                              itemBuilder: (context, index) {
                                final slideIndex = ((index % _slides.length) + _slides.length) % _slides.length;
                                final slide = _slides[slideIndex];
                                final isCurrentSlide = slideIndex == _currentPage;

                                return SlideImageItem(
                                  key: ValueKey<int>(index),
                                  imagePath: slide.image,
                                  isActive: isCurrentSlide,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Carousel Dot Indicators (ALWAYS Centered)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final bool isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF111111) : Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  // 5. Google Sign-In Button ("Continue with Gmail")
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (isLoading || _finalTransitionController.isAnimating)
                            ? null
                            : () async {
                                final success = await context.read<AuthService>().signIn();
                                if (context.mounted) {
                                  if (success) {
                                    // Trigger Spring Bounce Final Transition
                                    await _triggerFinalTransitionAndNavigate();
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
                            if (isLoading) ...[
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ] else ...[
                              Image.asset(
                                'assets/images/google_g.png',
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 12),
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

                  // Bottom Padding (36.0)
                  const SizedBox(height: _bottomPadding),
                ],
              ),
            ),
          ),

          // Final Transition Overlay: Centered Brand App Icon with Spring Bounce
          AnimatedBuilder(
            animation: _finalTransitionController,
            builder: (context, child) {
              if (_finalTransitionController.value == 0.0) {
                return const SizedBox.shrink();
              }
              return Opacity(
                opacity: _logoOpacityAnimation.value,
                child: Transform.scale(
                  scale: _logoScaleAnimation.value,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D72FF).withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Independent Per-Slide Image Glide Item:
/// Prevents the outgoing slide image from snapping back or jumping on transition!
class SlideImageItem extends StatefulWidget {
  final String imagePath;
  final bool isActive;

  const SlideImageItem({
    super.key,
    required this.imagePath,
    required this.isActive,
  });

  @override
  State<SlideImageItem> createState() => _SlideImageItemState();
}

class _SlideImageItemState extends State<SlideImageItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animation = Tween<Offset>(
      begin: const Offset(-0.08, 0.0), // Starts at Left
      end: const Offset(0.08, 0.0),    // Glides slowly to Right over 5 seconds
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );

    if (widget.isActive) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(SlideImageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SlideTransition(
        position: _animation,
        child: Image.asset(
          widget.imagePath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Generic Word-by-Word Sequential Fade Animator for Headline & Paragraph
class WordByWordAnimator extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final double spacing;
  final double runSpacing;

  const WordByWordAnimator({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.left,
    this.spacing = 6.0,
    this.runSpacing = 4.0,
  });

  @override
  State<WordByWordAnimator> createState() => _WordByWordAnimatorState();
}

class _WordByWordAnimatorState extends State<WordByWordAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<String> _words;
  String _targetText = '';

  @override
  void initState() {
    super.initState();
    _targetText = widget.text;
    _words = _targetText.split(RegExp(r'\s+'));
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 250 + (_words.length * 35)),
    );
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(WordByWordAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // Rapid sequential fade out (12ms per word - faster than entrance)
      _controller.duration = Duration(milliseconds: 100 + (_words.length * 12));
      _controller.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _targetText = widget.text;
          _words = _targetText.split(RegExp(r'\s+'));
          // Normal entrance fade in (35ms per word)
          _controller.duration = Duration(milliseconds: 250 + (_words.length * 35));
          _controller.forward(from: 0.0);
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int wordCount = _words.length;

    return Wrap(
      alignment: widget.textAlign == TextAlign.center
          ? WrapAlignment.center
          : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: List.generate(wordCount, (index) {
        final word = _words[index];

        final double wordStart = (index / wordCount) * 0.65;
        final double wordEnd = (wordStart + 0.35).clamp(0.1, 1.0);

        final wordAnimation = CurvedAnimation(
          parent: _controller,
          curve: Interval(
            wordStart.clamp(0.0, 0.9),
            wordEnd,
            curve: Curves.easeOut,
          ),
        );

        return AnimatedBuilder(
          animation: wordAnimation,
          builder: (context, child) {
            final opacity = wordAnimation.value.clamp(0.0, 1.0);
            final slideY = (1.0 - wordAnimation.value) * 8.0;

            return Transform.translate(
              offset: Offset(0, slideY),
              child: Opacity(
                opacity: opacity,
                child: Text(
                  word,
                  textAlign: widget.textAlign,
                  style: widget.style,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
