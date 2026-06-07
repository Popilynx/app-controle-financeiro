import 'package:flutter/material.dart';

class AppColors {
  // Slate / Zinc Premium Dark Mode
  static const Color background = Color(0xFF0B0F19); // Fundo escuro azulado sofisticado
  static const Color surface = Color(0xFF151D30);    // Superfície dos cartões/containers
  static const Color surfaceElevated = Color(0xFF1E2942); // Superfície com mais elevação
  
  // Cores de Acento
  static const Color primary = Color(0xFF4F46E5);    // Indigo elegante
  static const Color accent = Color(0xFF818CF8);     // Indigo claro para destaques
  
  // Status Financeiro
  static const Color income = Color(0xFF10B981);     // Verde Esmeralda para receitas
  static const Color expense = Color(0xFFEF4444);    // Vermelho/Rosa Crimson para despesas
  static const Color savings = Color(0xFF0EA5E9);    // Azul Celeste para investimentos/metas
  
  // Neutras de Texto
  static const Color textPrimary = Color(0xFFF8FAFC);   // Off-white Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Cinza Slate 400
  static const Color textMuted = Color(0xFF64748B);     // Cinza Muted Slate 500
  
  // Efeitos Glassmorphism
  static const Color glassBg = Color(0x0DFFFFFF);       // Branco com 5% de opacidade
  static const Color glassBorder = Color(0x1AFFFFFF);   // Branco com 10% de opacidade
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      
      // Esquema de cores principal
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.expense,
      ),
      
      // Tema de Card
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      
      // Tema de Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      
      // Tema da AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      
      // Tema dos Textos
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.normal),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.normal),
        labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      
      // Tema dos Inputs (Formulários)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.expense),
        ),
      ),
      
      // Tema do Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Botões
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
