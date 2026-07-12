import 'package:flutter/material.dart';

import '../features/splash/splash_screen.dart';
import '../shared/widgets/tajgo_scope.dart';
import 'tajgo_theme.dart';

class TajGoApp extends StatelessWidget {
  const TajGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return TajGoScope(
      child: MaterialApp(
        title: 'TajGo+',
        debugShowCheckedModeBanner: false,
        theme: TajGoTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
