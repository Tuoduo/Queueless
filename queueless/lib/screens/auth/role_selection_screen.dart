import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/user_model.dart';
import 'register_screen.dart';
import 'dart:math' as math;

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
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
                    ],
                    begin: Alignment(
                      math.cos(_bgController.value * 2 * math.pi) * 0.5,
                      math.sin(_bgController.value * 2 * math.pi) * 0.5,
                    ),
                    end: Alignment(
                      -math.cos(_bgController.value * 2 * math.pi) * 0.5,
                      -math.sin(_bgController.value * 2 * math.pi) * 0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          // Orbs
          Positioned(
            top: 100,
            left: -80,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) => Transform.translate(
                  offset: Offset(
                    12 * math.sin(_bgController.value * 2 * math.pi),
                    8 * math.cos(_bgController.value * 2 * math.pi),
                  ),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.primary.withOpacity(0.12), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            right: -60,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) => Transform.translate(
                  offset: Offset(
                    10 * math.cos(_bgController.value * 2 * math.pi),
                    14 * math.sin(_bgController.value * 2 * math.pi),
                  ),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.secondary.withOpacity(0.1), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.glassWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title
                  _buildStaggeredChild(0, Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => AppColors.heroGradient.createShader(bounds),
                        child: Text(
                          'Who are you?',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose your role to get started',
                        style: TextStyle(color: AppColors.textHint, fontSize: 15),
                      ),
                    ],
                  )),
                  const Spacer(),
                  _buildStaggeredChild(1, _buildRoleCard(
                    context: context,
                    title: AppStrings.customer,
                    description: AppStrings.customerDesc,
                    icon: Icons.person_outline,
                    role: UserRole.customer,
                    gradient: AppColors.primaryGradient,
                    color: AppColors.primary,
                    emoji: '👤',
                  )),
                  const SizedBox(height: 20),
                  _buildStaggeredChild(2, _buildRoleCard(
                    context: context,
                    title: AppStrings.businessOwner,
                    description: AppStrings.businessOwnerDesc,
                    icon: Icons.storefront_outlined,
                    role: UserRole.businessOwner,
                    gradient: AppColors.accentGradient,
                    color: AppColors.secondary,
                    emoji: '🏪',
                  )),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaggeredChild(int index, Widget child) {
    final delay = index * 0.15;
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        final progress = ((_staggerController.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(progress);
        return Transform.translate(
          offset: Offset(0, 30 * (1 - curved)),
          child: Opacity(opacity: curved, child: child),
        );
      },
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required UserRole role,
    required LinearGradient gradient,
    required Color color,
    required String emoji,
  }) {
    return _ScaleTapCard(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => RegisterScreen(selectedRole: role),
            transitionDuration: const Duration(milliseconds: 450),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: AppColors.glassGradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon with gradient background
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textHint,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaleTapCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScaleTapCard({required this.child, required this.onTap});

  @override
  State<_ScaleTapCard> createState() => _ScaleTapCardState();
}

class _ScaleTapCardState extends State<_ScaleTapCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
