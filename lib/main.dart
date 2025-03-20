import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_detection_realtime_flutter/features/home/presentation/pages/home_view.dart';
import 'package:object_detection_realtime_flutter/features/home/presentation/pages/starting_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartingPage(),
      routes: {
        '/home': (context) => HomeView(cameras: cameras),
      },
    );
  }
}
