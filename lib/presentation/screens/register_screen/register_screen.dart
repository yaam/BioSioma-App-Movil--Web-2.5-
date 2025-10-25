import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:sioma_biometrics/domain/entities/employee.dart';
import 'package:sioma_biometrics/infrastructure/services/face_recognition_service.dart';
import 'package:sioma_biometrics/presentation/providers/local_db_repository_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final _faceService = FaceRecognitionService();
  final _nameController = TextEditingController();
  String _detectionResult = '';

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    final hasPermission = await _requestCameraPermission();
    if (!hasPermission) return;

    await _faceService.init();
    await _initializeCamera();
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ Permiso de cámara denegado')),
    );
    return false;
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(frontCam, ResolutionPreset.medium);
    await _cameraController!.initialize();

    if (!mounted) return;
    setState(() => _isCameraInitialized = true);
  }

  Future<void> _detectFaces(File imageFile) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: false,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    final inputImage = InputImage.fromFile(imageFile);
    final faces = await detector.processImage(inputImage);

    setState(() {
      _detectionResult = faces.isEmpty
          ? '❌ No se detectó rostro'
          : '✅ Rostro detectado';
    });

    await detector.close();
  }

  Future<File> _saveImage(File image) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = 'face_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File('${dir.path}/$name');
    await image.copy(file.path);
    return file;
  }

  Future<void> _registerEmployee() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre')),
      );
      return;
    }

    // 1️⃣ Capturar foto
    final image = await _cameraController!.takePicture();
    final file = File(image.path);

    // 2️⃣ Detectar rostro
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: false,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    final inputImage = InputImage.fromFile(file);
    final faces = await detector.processImage(inputImage);
    await detector.close();

    if (faces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ No se detectó ningún rostro')),
      );
      await file.delete();
      return;
    }

    // 🔹 Solo tomamos el primer rostro detectado
    final face = faces.first;

    // 3️⃣ Recortar la región del rostro
    final croppedFace = await _cropFaceFromImage(file, face.boundingBox);
    if (croppedFace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No se pudo recortar el rostro')),
      );
      await file.delete();
      return;
    }

    // 4️⃣ Guardar rostro recortado
    final dir = await getApplicationDocumentsDirectory();
    final savedFace = await croppedFace.copy(
      '${dir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    // 5️⃣ Obtener embedding facial
    final embedding = await _faceService.getEmbedding(savedFace);
    if (embedding.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No se pudo procesar el rostro')),
      );
      await savedFace.delete();
      return;
    }

    // 6️⃣ Guardar empleado
    final repo = ref.read(localDbRepositoryProvider);
    final employee = Employee(
      name: name,
      photoPath: savedFace.path,
      faceEmbedding: embedding,
    );

    await repo.createEmployee(employee);
    _nameController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('✅ $name registrado correctamente')));

    if (mounted) context.go('/');
  }

  Future<File?> _cropFaceFromImage(File imageFile, Rect faceRect) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final cropRect = Rect.fromLTWH(
        faceRect.left.clamp(0, image.width.toDouble()),
        faceRect.top.clamp(0, image.height.toDouble()),
        faceRect.width.clamp(0, image.width.toDouble() - faceRect.left),
        faceRect.height.clamp(0, image.height.toDouble() - faceRect.top),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();
      final src = cropRect;
      final dst = Rect.fromLTWH(0, 0, cropRect.width, cropRect.height);
      canvas.drawImageRect(image, src, dst, paint);
      final cropped = await recorder.endRecording().toImage(
        cropRect.width.toInt(),
        cropRect.height.toInt(),
      );

      final byteData = await cropped.toByteData(format: ImageByteFormat.png);
      final croppedFile = File(
        '${(await getTemporaryDirectory()).path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await croppedFile.writeAsBytes(byteData!.buffer.asUint8List());

      return croppedFile;
    } catch (e) {
      debugPrint('Error al recortar rostro: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar nuevo empleado')),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          if (_detectionResult.isNotEmpty)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _detectionResult,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Nombre del empleado',
                    hintStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _registerEmployee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    'Registrar Empleado',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
