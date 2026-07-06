import 'package:flutter/material.dart';

import 'core/theme/tajgo_theme.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const TajGoApp());
}

class TajGoApp extends StatelessWidget {
  const TajGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TajGo+',
      debugShowCheckedModeBanner: false,
      theme: TajGoTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}
