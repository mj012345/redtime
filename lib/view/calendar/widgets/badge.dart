import 'package:flutter/material.dart';

class Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const Badge({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: TextStyle(fontSize: 14, color: fg)),
    );
  }
}
