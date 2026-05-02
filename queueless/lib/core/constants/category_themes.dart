import 'package:flutter/material.dart';
import '../../models/business_model.dart';
import 'app_colors.dart';

class CategoryTheme {
  final LinearGradient backgroundGradient;
  final Color primaryColor;
  final Color accentColor;
  final AppAnimationStyle animationStyle;

  const CategoryTheme({
    required this.backgroundGradient,
    required this.primaryColor,
    required this.accentColor,
    required this.animationStyle,
  });
}

enum AppAnimationStyle {
  particles,
  waves,
  geometric,
  bubbles,
  confetti,
  pulse,
  smoke
}

class CategoryThemes {
  static CategoryTheme getTheme(BusinessCategory category) {
    switch (category) {
      case BusinessCategory.bakery:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF2D1E16), Color(0xFF4A2B18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          primaryColor: Color(0xFFFFD166),
          accentColor: Color(0xFFFF8C42),
          animationStyle: AppAnimationStyle.smoke,
        );
      case BusinessCategory.barber:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF2D1B36)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          primaryColor: Color(0xFFE94560),
          accentColor: Color(0xFF0F3460),
          animationStyle: AppAnimationStyle.geometric, // barber poles
        );
      case BusinessCategory.restaurant:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF2D1B2E), Color(0xFF1A0B1C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          primaryColor: Color(0xFFFF6B6B),
          accentColor: Color(0xFFFFD93D),
          animationStyle: AppAnimationStyle.particles,
        );
      case BusinessCategory.clinic:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF14213D), Color(0xFF1F4068)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          primaryColor: Color(0xFF7BDFF2),
          accentColor: Color(0xFFB2F7EF),
          animationStyle: AppAnimationStyle.waves,
        );
      case BusinessCategory.bank:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          primaryColor: Color(0xFF43D8C9),
          accentColor: Color(0xFFFFFFFF),
          animationStyle: AppAnimationStyle.waves,
        );
      case BusinessCategory.repair:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF1F2024), Color(0xFF2C2C54)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
          primaryColor: Color(0xFF474787),
          accentColor: Color(0xFFAAA69D),
          animationStyle: AppAnimationStyle.geometric, // mechanics
        );
      case BusinessCategory.beauty:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF2E1528), Color(0xFF431C3D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          primaryColor: Color(0xFFFF6B9D),
          accentColor: Color(0xFFC850C0),
          animationStyle: AppAnimationStyle.confetti,
        );
      case BusinessCategory.dentist:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF15294A), Color(0xFF1E3A8A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          primaryColor: Color(0xFF3B82F6),
          accentColor: Color(0xFF93C5FD),
          animationStyle: AppAnimationStyle.bubbles,
        );
      case BusinessCategory.gym:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF2B1212)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          primaryColor: Color(0xFFFF4136),
          accentColor: Color(0xFFFF851B),
          animationStyle: AppAnimationStyle.pulse,
        );
      case BusinessCategory.pharmacy:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF0D2A18), Color(0xFF0D3B0D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          primaryColor: Color(0xFF2CA02C),
          accentColor: Color(0xFF7CB342),
          animationStyle: AppAnimationStyle.pulse,
        );
      case BusinessCategory.grocery:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          primaryColor: Color(0xFF52B788),
          accentColor: Color(0xFF74C69D),
          animationStyle: AppAnimationStyle.particles, // leaves
        );
      case BusinessCategory.government:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF1C1C3E), Color(0xFF2A2A5A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          primaryColor: Color(0xFF8C9EFF),
          accentColor: Color(0xFFBDBDBD),
          animationStyle: AppAnimationStyle.geometric,
        );
      case BusinessCategory.cafe:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF2B1D12), Color(0xFF3B2A1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          primaryColor: Color(0xFFDEB887),
          accentColor: Color(0xFFD2691E),
          animationStyle: AppAnimationStyle.smoke,
        );
      case BusinessCategory.vet:
        return const CategoryTheme(
          backgroundGradient: LinearGradient(
            colors: [Color(0xFF1B2A3B), Color(0xFF1B3A4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          primaryColor: Color(0xFF4FC3F7),
          accentColor: Color(0xFF81D4FA),
          animationStyle: AppAnimationStyle.bubbles, // cute paws/bubbles
        );
      case BusinessCategory.other:
      default:
        return const CategoryTheme(
          backgroundGradient: AppColors.cardGradient,
          primaryColor: AppColors.primary,
          accentColor: AppColors.secondary,
          animationStyle: AppAnimationStyle.particles,
        );

    }
  }
}
