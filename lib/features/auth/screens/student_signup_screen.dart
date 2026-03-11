// 학생 가입은 소셜/이메일 후 닉네임 화면으로 바로 연결됩니다.
// 이 파일은 라우터 임포트를 위해 NicknameScreen을 재노출합니다.
export 'nickname_screen.dart';

// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import 'nickname_screen.dart';

class StudentSignupScreen extends StatelessWidget {
  const StudentSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NicknameScreen(role: UserRole.student);
  }
}
