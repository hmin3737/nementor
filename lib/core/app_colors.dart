import 'package:flutter/material.dart';

/// 내멘토 색상 시스템
/// 색상 변경 시 이 파일만 수정하면 앱 전체에 반영됩니다.
abstract final class AppColors {
  // ── 브랜드 기본 ──────────────────────────────────────────────
  static const Color primary = Color(0xFF1A1A2E); // 딥 네이비
  static const Color accent = Color(0xFF4F8EF7); // 블루 (문제해결 CTA)
  static const Color consultAccent = Color(0xFF10B981); // 그린 (학습상담 CTA)
  static const Color surface = Color(0xFFF7F8FC); // 오프화이트 배경
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEAEDF3);

  // ── 내멘토 인증 ───────────────────────────────────────────────
  static const Color proCertColor = Color(0xFF4F8EF7); // 프로 인증 — 파란색
  static const Color masterCertColor = Color(0xFF10D9A0); // 마스터 인증 — 에메랄드

  // ── 시멘틱 ──────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ── 텍스트 ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSub = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFFD1D5DB);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ── 다크모드 ─────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F0F17);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF1E2035);
  static const Color darkBorder = Color(0xFF2A2D45);

  // ── 기타 ────────────────────────────────────────────────────
  static const Color mathBlock = Color(0xFFF0F4FF); // 수식 블록 배경
  static const Color studentBubble = accent; // 학생 말풍선
  static const Color mentorBubble = card; // 멘토 말풍선
  static const Color divider = Color(0xFFF0F2F5);
  static const Color shimmerBase = Color(0xFFE8ECF0);
  static const Color shimmerHighlight = Color(0xFFF5F7FA);

  // ── 그라디언트 ───────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF4F8EF7), Color(0xFF6B5CEF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient consultGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── ThemeData 헬퍼 ───────────────────────────────────────────
  static ColorScheme get lightColorScheme => const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: textOnAccent,
        onSecondary: textOnAccent,
        onSurface: textPrimary,
        onError: textOnAccent,
        outline: border,
      );

  static ColorScheme get darkColorScheme => const ColorScheme.dark(
        primary: accent,
        secondary: consultAccent,
        surface: darkSurface,
        error: error,
        onPrimary: textOnAccent,
        onSecondary: textOnAccent,
        onSurface: Color(0xFFE8EAF0),
        onError: textOnAccent,
        outline: darkBorder,
      );
}
