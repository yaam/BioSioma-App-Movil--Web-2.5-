import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sioma_biometrics/domain/entities/employee.dart';
import 'package:sioma_biometrics/domain/entities/attendance.dart';
import 'package:sioma_biometrics/infrastructure/services/face_recognition_service.dart';
import 'package:sioma_biometrics/presentation/providers/local_db_repository_provider.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String _detectionResult = '';
  final _faceService = FaceRecognitionService();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    await _faceService.init();
    await _initializeCamera();
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

  Future<void> _detectFaces(File imageFile) async {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    );
    final faceDetector = FaceDetector(options: options);
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await faceDetector.processImage(inputImage);

    setState(() {
      _detectionResult = faces.isEmpty
          ? '❌ No se detectaron rostros'
          : '✅ Rostros detectados: ${faces.length}';
    });

    await faceDetector.close();
  }

  Future<File> saveImageLocally(File image) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'face_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImage = File('${directory.path}/$fileName');
    await image.copy(savedImage.path);
    return savedImage;
  }

  Future<void> _registerEmployee() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre')),
      );
      return;
    }

    final image = await _cameraController!.takePicture();
    final file = await saveImageLocally(File(image.path));
    await _detectFaces(file);

    final embedding = await _faceService.getEmbedding(file);
    final repo = ref.read(localDbRepositoryProvider);

    final employee = Employee(
      name: name,
      photoPath: file.path,
      faceEmbedding: embedding,
    );
    await repo.createEmployee(employee);

    _nameController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Empleado "$name" registrado correctamente')),
    );
  }

  Future<void> _markAttendance({required bool isEntry}) async {
    final image = await _cameraController!.takePicture();
    final file = await saveImageLocally(File(image.path));
    await _detectFaces(file);

    final embedding = await _faceService.getEmbedding(file);
    final repo = ref.read(localDbRepositoryProvider);
    final employees = await repo.getAllEmployees();

    Employee? matchedEmployee;
    for (final emp in employees) {
      if (emp.faceEmbedding != null &&
          _faceService.isSamePerson(emp.faceEmbedding!, embedding)) {
        matchedEmployee = emp;
        break;
      }
    }

    if (matchedEmployee != null) {
      final attendance = Attendance(
        timestamp: DateTime.now(),
        isEntry: isEntry,
      );
      attendance.employee.target = matchedEmployee;
      await repo.createAttendance(attendance);

      // ✅ Mostrar modal con info del empleado
      _showEmployeeModal(matchedEmployee, isEntry);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Rostro no reconocido')));
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
                  child: Image.file(
                    File(employee.photoPath!),
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
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
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isCameraInitialized
          ? Stack(
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
                          fontSize: 20,
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
                          hintStyle: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
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
                        child: const Text('Registrar Empleado'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _markAttendance(isEntry: true),
                        child: const Text('Marcar Entrada'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _markAttendance(isEntry: false),
                        child: const Text('Marcar Salida'),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
