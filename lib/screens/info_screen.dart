import 'package:flutter/material.dart';

import '../core/theme/tajgo_colors.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TajGoColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}
