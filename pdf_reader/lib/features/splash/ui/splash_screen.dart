import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../routes/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _iconController;
  late final AnimationController _textController;
  late final AnimationController _progressController;

  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _progressWidth;

  @override
  void initState() {
    super.initState();

    // Icon: scale + fade in
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _iconScale = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    ).drive(Tween(begin: 0.4, end: 1.0));
    _iconOpacity = CurvedAnimation(
      parent: _iconController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ).drive(Tween(begin: 0.0, end: 1.0));

    // Text: fade + slide up
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));
    _textSlide = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ).drive(Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ));

    // Progress bar
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _progressWidth = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Step 1: icon appears
    await _iconController.forward();
    // Step 2: text fades in shortly after
    await Future.delayed(const Duration(milliseconds: 100));
    _textController.forward();
    // Step 3: progress bar fills
    await Future.delayed(const Duration(milliseconds: 200));
    await _progressController.forward();
    // Step 4: short pause then navigate
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) context.go(AppRouter.home);
  }

  @override
  void dispose() {
    _iconController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFF5A8FBF) : const Color(0xFF1F2D3D);
    final bg = isDark ? const Color(0xFF080A0C) : const Color(0xFFF2F3F5);
    final onBg = isDark ? const Color(0xFFE8EAED) : const Color(0xFF0A0C0F);
    final subtle = isDark
        ? const Color(0xFF1C232B)
        : const Color(0xFFDDE1E7);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // App icon
            AnimatedBuilder(
              animation: _iconController,
              builder: (_, __) => Opacity(
                opacity: _iconOpacity.value,
                child: Transform.scale(
                  scale: _iconScale.value,
                  child: Container(
                    width: 96.w,
                    height: 96.w,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.30),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 48.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 28.h),

            // App name + tagline
            AnimatedBuilder(
              animation: _textController,
              builder: (_, __) => FadeTransition(
                opacity: _textOpacity,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
                      Text(
                        'PDF Reader Pro',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w700,
                          color: onBg,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Read, convert & manage your files',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: onBg.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(flex: 3),

            // Loading bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 48.w),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (_, __) => Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Stack(
                        children: [
                          // Track
                          Container(
                            height: 3.h,
                            color: subtle,
                          ),
                          // Fill
                          FractionallySizedBox(
                            widthFactor: _progressWidth.value,
                            child: Container(
                              height: 3.h,
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Opacity(
                      opacity: _progressWidth.value.clamp(0.0, 1.0),
                      child: Text(
                        'Loading…',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.sp,
                          color: onBg.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 48.h),
          ],
        ),
      ),
    );
  }
}