import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'modules/camera/bindings/camera_binding.dart';
import 'modules/camera/views/camera_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // KAMLOKA UI is intentionally portrait-only.
  // Physical orientation is still tracked separately for camera capture.  
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      initialBinding: CameraBinding(),
      home: const CameraView(),
    );
  }
}
