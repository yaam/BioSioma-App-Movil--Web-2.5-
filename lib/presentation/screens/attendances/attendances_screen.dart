import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sioma_biometrics/domain/entities/attendance.dart';
import 'package:sioma_biometrics/domain/entities/employee.dart';
import 'package:sioma_biometrics/infrastructure/services/face_recognition_service.dart';
import 'package:sioma_biometrics/presentation/providers/local_db_repository_provider.dart';

class Attendances extends ConsumerStatefulWidget {
  const Attendances({super.key});

  @override
  ConsumerState<Attendances> createState() => _AttendancesState();
}

class _AttendancesState extends ConsumerState<Attendances> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String _statusText = 'Iniciando cámara...';
  final _faceService = FaceRecognitionService();

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
    setState(() => _statusText = '⚠️ No se puede acceder a la cámara');
    return false;
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() => _isCameraInitialized = true);
  }

  Future<void> _markAttendance({required bool isEntry}) async {
    setState(() => _statusText = '📸 Capturando rostro...');

    try {
      // 1️⃣ Capturar foto
      final xFile = await _cameraController!.takePicture();
      final imageFile = File(xFile.path);

      // 2️⃣ Detectar rostro con mejor configuración
      setState(() => _statusText = '🔍 Detectando rostro...');
      final options = FaceDetectorOptions(
        enableContours: false,
        enableClassification: false,
        performanceMode: FaceDetectorMode.accurate,
      );
      final detector = FaceDetector(options: options);
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await detector.processImage(inputImage);
      await detector.close();

      if (faces.isEmpty) {
        setState(() => _statusText = '❌ No se detectó ningún rostro');
        return;
      }

      // 🔹 Tomamos el primer rostro y lo recortamos
      final face = faces.first;
      final croppedFace = await _cropFaceFromImage(imageFile, face.boundingBox);
      if (croppedFace == null) {
        setState(() => _statusText = '⚠️ No se pudo recortar el rostro');
        return;
      }

      // 3️⃣ Generar embedding solo del rostro
      setState(() => _statusText = '🧠 Analizando rostro...');
      final embedding = await _faceService.getEmbedding(croppedFace);
      if (embedding.isEmpty) {
        setState(
          () => _statusText = '⚠️ No se pudo generar embedding del rostro',
        );
        return;
      }

      // 4️⃣ Buscar coincidencia en la base local
      final repo = ref.read(localDbRepositoryProvider);
      final employees = await repo.getAllEmployees();

      debugPrint('👥 Total empleados registrados: ${employees.length}');
      debugPrint(
        '🧠 Embedding capturado tiene ${embedding.length} dimensiones',
      );

      Employee? matchedEmployee;
      double minDistance = double.infinity;
      for (final emp in employees) {
        if (emp.faceEmbedding != null) {
          debugPrint(
            '📝 Empleado: ${emp.name}, Embedding: ${emp.faceEmbedding!.length} dimensiones',
          );

          final distance = _faceService.calculateDistance(
            emp.faceEmbedding!,
            embedding,
          );
          debugPrint('🔍 Distancia con ${emp.name}: $distance');

          if (distance < minDistance) {
            minDistance = distance;
          }

          if (_faceService.isSamePerson(
            emp.faceEmbedding!,
            embedding,
            threshold: 0.6,
          )) {
            // 🔹 Threshold ajustado para embeddings normalizados
            matchedEmployee = emp;
            debugPrint('✅ Match encontrado con ${emp.name}!');
            break;
          }
        } else {
          debugPrint('⚠️ Empleado ${emp.name} no tiene embedding guardado');
        }
      }

      debugPrint('📊 Distancia mínima encontrada: $minDistance');

      if (matchedEmployee == null) {
        setState(() => _statusText = '❌ Rostro no reconocido');
        return;
      }

      // 5️⃣ Validar entradas/salidas del día
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final todayAttendances = await repo.getAttendancesForEmployeeBetween(
        matchedEmployee.id,
        todayStart,
        todayEnd,
      );

      final alreadyEntered = todayAttendances.any((a) => a.isEntry);
      final alreadyExited = todayAttendances.any((a) => !a.isEntry);

      if (isEntry && alreadyEntered) {
        setState(
          () =>
              _statusText = '⚠️ ${matchedEmployee!.name} ya marcó ENTRADA hoy.',
        );
        return;
      }
      if (!isEntry && alreadyExited) {
        setState(
          () =>
              _statusText = '⚠️ ${matchedEmployee!.name} ya marcó SALIDA hoy.',
        );
        return;
      }

      // 6️⃣ Registrar asistencia
      final attendance = Attendance(timestamp: now, isEntry: isEntry);
      attendance.employee.target = matchedEmployee;
      await repo.createAttendance(attendance);

      _showEmployeeModal(matchedEmployee, isEntry);

      setState(() {
        _statusText =
            '✅ ${isEntry ? "Entrada" : "Salida"} registrada para ${matchedEmployee!.name}';
      });
    } catch (e) {
      setState(() => _statusText = '⚠️ Error: ${e.toString()}');
    }
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

  void _showEmployeeModal(Employee employee, bool isEntry) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: employee.photoPath != null
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(
                            math.pi,
                          ), // efecto espejo
                          child: Image.file(
                            File(employee.photoPath!),
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 120,
                          color: Colors.white54,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${employee.id}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  '${isEntry ? "Entrada" : "Salida"} registrada correctamente',
                  style: TextStyle(
                    color: isEntry ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Hora: ${TimeOfDay.now().format(context)}',
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marcar Entrada/Salida')),
      backgroundColor: Colors.black,
      body: _isCameraInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController!),
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      _statusText,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _markAttendance(isEntry: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Entrada'),
                      ),
                      ElevatedButton(
                        onPressed: () => _markAttendance(isEntry: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Salida'),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                _statusText,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
    );
  }
}
