import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sioma_biometrics/config/router/app_router.dart';
import 'package:sioma_biometrics/presentation/screens/camera/camera_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'Sioma Biometrics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.dark(),
      ),
    );
  }
}

class PermissionHandlerPage extends StatefulWidget {
  const PermissionHandlerPage({super.key});

  @override
  State<PermissionHandlerPage> createState() => _PermissionHandlerPageState();
}

class _PermissionHandlerPageState extends State<PermissionHandlerPage> {
  bool _cameraGranted = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _cameraGranted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraGranted) {
      return const CameraPage();
    } else {
      return const Scaffold(
        body: Center(
          child: Text('Concede el permiso de cámara para continuar.'),
        ),
      );
    }
  }
}
