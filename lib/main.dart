import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'modules/pro/services/pro_access_service.dart';
import 'modules/pro/services/pro_purchase_service.dart';
import 'modules/splash/views/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // KAMLOKA UI is intentionally portrait-only.
  // Physical orientation is tracked separately for camera capture.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  Get.put<ProAccessService>(ProAccessService(), permanent: true);
  Get.put<ProPurchaseService>(ProPurchaseService(), permanent: true);

  runApp(const KamlokaApp());
}

class KamlokaApp extends StatelessWidget {
  const KamlokaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KAMLOKA',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F6F3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0C5A3E),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F6F3),
          foregroundColor: Color(0xFF202522),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
