import 'package:flutter/material.dart';

/// 내멘토 "n°" 브랜드 로고 위젯
/// [color] 기본값은 흰색 (어두운 배경 위 사용)
/// [size] 는 "n" 글자의 폰트 크기 기준
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'n',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.0,
            letterSpacing: -1,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: size * 0.04),
          child: Text(
            '°',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: size * 0.46,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
