import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import 'register_screen.dart';
import 'dart:math' as math;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'customer@test.com');
  final _passwordController = TextEditingController(text: '123456');
  bool _obscurePassword = true;

  late AnimationController _bgController;
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;

  // Particle system
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    // Generate particles
    for (int i = 0; i < 25; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 1,
        speed: _random.nextDouble() * 0.3 + 0.1,
        opacity: _random.nextDouble() * 0.4 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgController.dispose();
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        if (authProvider.isCustomer) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged in as Customer')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged in as Business Owner')));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [
                      Color(0xFF06060F),
                      Color(0xFF0E0A2A),
                      Color(0xFF080D1E),
                      Color(0xFF06060F),
                    ],
                    begin: Alignment(
                      math.cos(_bgController.value * 2 * math.pi),
                      math.sin(_bgController.value * 2 * math.pi),
                    ),
                    end: Alignment(
                      -math.cos(_bgController.value * 2 * math.pi),
                      -math.sin(_bgController.value * 2 * math.pi),
                    ),
                  ),
                ),
              );
            },
          ),
          // Floating particles
          // Background pattern animation
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _BackgroundPainter(progress: _bgController.value),
                );
              },
            ),
          ),
          // Floating orbs — large
          Positioned(
            top: -100,
            right: -80,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(
                      25 * math.sin(_bgController.value * 2 * math.pi),
                      15 * math.cos(_bgController.value * 2 * math.pi),
                    ),
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.primary.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(
                      18 * math.cos(_bgController.value * 2 * math.pi),
                      22 * math.sin(_bgController.value * 2 * math.pi),
                    ),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.secondary.withOpacity(0.12),
                            AppColors.secondary.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Third orb — accent
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: -60,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(
                      12 * math.sin(_bgController.value * 2 * math.pi + 1.5),
                      18 * math.cos(_bgController.value * 2 * math.pi + 1.5),
                    ),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.08),
                            AppColors.accent.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo — staggered reveal
                        _buildStaggeredChild(0, _buildLogo()),
                        const SizedBox(height: 48),

                        // Form Fields
                        _buildStaggeredChild(1, _buildGlassContainer(
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _emailController,
                                label: AppStrings.email,
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.validateEmail,
                                onChanged: (_) => context.read<AuthProvider>().clearError(),
                              ),
                              Divider(color: AppColors.glassBorder.withValues(alpha: 0.3), height: 1),
                              _buildTextField(
                                controller: _passwordController,
                                label: AppStrings.password,
                                icon: Icons.lock_outline,
                                isPassword: true,
                                validator: Validators.validatePassword,
                                onChanged: (_) => context.read<AuthProvider>().clearError(),
                              ),
                            ],
                          ),
                        )),

                        _buildStaggeredChild(2, Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: Text(
                              AppStrings.forgotPassword,
                              style: TextStyle(color: AppColors.primaryLight.withOpacity(0.7), fontSize: 13),
                            ),
                          ),
                        )),
                        const SizedBox(height: 8),

                        // Login Button
                        _buildStaggeredChild(3, _buildLoginButton()),
                        const SizedBox(height: 28),

                        // Test accounts
                        _buildStaggeredChild(4, _buildGlassContainer(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.science_outlined, size: 14, color: AppColors.primaryLight),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Test Accounts', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'customer@test.com  •  test@mail.com',
                                  style: TextStyle(color: AppColors.textHint, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )),

                        const SizedBox(height: 24),

                        // Register link
                        _buildStaggeredChild(5, Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(AppStrings.noAccount, style: TextStyle(color: AppColors.textHint)),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) => const RegisterScreen(),
                                    transitionDuration: const Duration(milliseconds: 450),
                                    transitionsBuilder: (_, animation, __, child) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.08),
                                            end: Offset.zero,
                                          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                                          child: child,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                              child: Text(
                                AppStrings.signUp,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                              ),
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaggeredChild(int index, Widget child) {
    final delay = index * 0.12;
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        final progress = ((_staggerController.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(progress);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - curved)),
          child: Opacity(opacity: curved, child: child),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textHint,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
      keyboardType: keyboardType,
      obscureText: isPassword ? _obscurePassword : false,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary),
    );
  }

  Widget _buildLoginButton() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: auth.error == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(auth.error),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.error.withOpacity(0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              auth.error!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(AppStrings.login, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            width: 216,
            height: 216,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.45), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(
                'assets/branding/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildLegacyLogoMark(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          AppStrings.appTagline,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textHint,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLegacyLogoMark() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
      ),
      child: const Center(
        child: Icon(Icons.flash_on_rounded, size: 56, color: Colors.white),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.4), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17.5),
        child: child,
      ),
    );
  }
}

// Particle model
class _Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// Custom particle painter
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animValue;

  _ParticlePainter({required this.particles, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + animValue * p.speed) % 1.0;
      final x = p.x + 0.02 * math.sin(animValue * 2 * math.pi + p.y * 6);

      final paint = Paint()
        ..color = AppColors.primaryLight.withOpacity(p.opacity * 0.5)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _BackgroundPainter extends CustomPainter {
  final double progress;

  _BackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.04)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    final offset = progress * spacing;

    for (double x = -spacing + (offset % spacing); x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = -spacing + (offset % spacing); y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
