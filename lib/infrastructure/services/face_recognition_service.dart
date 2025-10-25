import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  late Interpreter _interpreter;
  bool _isReady = false;

  FaceRecognitionService();

  /// Inicializa el modelo
  Future<void> init() async {
    final data = await rootBundle.load('assets/facenet.tflite');
    print('✅ Modelo cargado con ${data.lengthInBytes} bytes');

    _interpreter = await Interpreter.fromAsset('assets/facenet.tflite');
    _isReady = true;
  }

  /// Genera un embedding a partir de una imagen
  Future<List<double>> getEmbedding(File imageFile) async {
    if (!_isReady) throw Exception('Interpreter not initialized');

    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception("No se pudo decodificar la imagen");

    // Redimensionar a 112x112 (input del modelo)
    final resized = img.copyResize(image, width: 112, height: 112);

    // Convertir la imagen a lista normalizada [-1, 1]
    final input = _imageToInputList(resized);

    // Crear buffer de salida
    final output = List.filled(128, 0.0).reshape([1, 128]);

    // Ejecutar el modelo
    _interpreter.run(input, output);

    // Normalizar el embedding (L2 normalization)
    final embedding = List<double>.from(output.first);
    return _normalizeEmbedding(embedding);
  }

  /// Normaliza un embedding usando L2 normalization
  List<double> _normalizeEmbedding(List<double> embedding) {
    double sum = 0.0;
    for (final value in embedding) {
      sum += value * value;
    }
    final magnitude = sqrt(sum);

    if (magnitude == 0) return embedding;

    return embedding.map((value) => value / magnitude).toList();
  }

  /// Convierte una imagen a una lista 4D [1, 112, 112, 3] con valores normalizados [-1, 1]
  List<List<List<List<double>>>> _imageToInputList(img.Image image) {
    final input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(112, (x) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();
          return [
            (r - 127.5) / 127.5,
            (g - 127.5) / 127.5,
            (b - 127.5) / 127.5,
          ];
        }),
      ),
    );
    return input;
  }

  /// Calcula la distancia euclidiana entre dos embeddings
  double calculateDistance(List<double> emb1, List<double> emb2) {
    double sum = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      sum += pow((emb1[i] - emb2[i]), 2);
    }
    return sqrt(sum);
  }

  /// Retorna true si los embeddings pertenecen a la misma persona
  bool isSamePerson(
    List<double> emb1,
    List<double> emb2, {
    double threshold = 1.0,
  }) {
    return calculateDistance(emb1, emb2) < threshold;
  }
}
