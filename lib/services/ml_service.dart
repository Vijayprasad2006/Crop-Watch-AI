import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class MLService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool isInitialized = false;
  final int _inputSize = 300; // SSD MobileNet typically expects 300x300
  TensorType? _inputType;

  Future<void> initialize() async {
    try {
      // Load interpreter
      _interpreter = await Interpreter.fromAsset('assets/models/ssd_mobilenet.tflite');

      // Read model IO info (important: many SSD models are quantized uint8)
      final inputTensors = _interpreter!.getInputTensors();
      if (inputTensors.isNotEmpty) {
        _inputType = inputTensors.first.type;
        log('ML input tensor: type=${inputTensors.first.type} shape=${inputTensors.first.shape}');
      }
      final outputTensors = _interpreter!.getOutputTensors();
      for (int i = 0; i < outputTensors.length; i++) {
        log('ML output[$i]: type=${outputTensors[i].type} shape=${outputTensors[i].shape}');
      }
      
      // Load labels
      final labelData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelData.split('\n');
      isInitialized = true;
      log('ML Service initialized successfully.');
    } catch (e) {
      log('Failed to initialize ML Service: $e');
    }
  }

  void dispose() {
    _interpreter?.close();
  }

  List<dynamic> processCameraImage(CameraImage image) {
    if (!isInitialized || _interpreter == null) return [];

    try {
      final rgb = _convertCameraImageToRgb(image);
      if (rgb == null) return [];

      final resized = img.copyResize(
        rgb,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.average,
      );

      final input = _imageToModelInput(resized);

      // SSD MobileNet outputs (common signature):
      // boxes:   [1, 10, 4]
      // classes: [1, 10]
      // scores:  [1, 10]
      // num:     [1]
      final boxes = List.generate(1, (_) => List.generate(10, (_) => List.filled(4, 0.0)));
      final classes = List.generate(1, (_) => List.filled(10, 0.0));
      final scores = List.generate(1, (_) => List.filled(10, 0.0));
      final num = List.filled(1, 0.0);

      _interpreter!.runForMultipleInputs(
        [input],
        {
          0: boxes,
          1: classes,
          2: scores,
          3: num,
        },
      );

      final results = <dynamic>[];
      for (int i = 0; i < 10; i++) {
        final score = (scores[0][i]).toDouble();
        if (score < 0.45) continue;

        final classIdx = (classes[0][i]).toInt();
        final label = (classIdx >= 0 && classIdx < _labels.length) ? _labels[classIdx] : 'Unknown';

        // Focus on humans + animals for this app
        final l = label.toLowerCase();
        final isRelevant = l.contains('person') ||
            l.contains('dog') ||
            l.contains('cat') ||
            l.contains('cow') ||
            l.contains('horse') ||
            l.contains('sheep') ||
            l.contains('bird') ||
            l.contains('elephant') ||
            l.contains('bear') ||
            l.contains('zebra') ||
            l.contains('giraffe');
        if (!isRelevant) continue;

        final yMin = boxes[0][i][0].toDouble();
        final xMin = boxes[0][i][1].toDouble();
        final yMax = boxes[0][i][2].toDouble();
        final xMax = boxes[0][i][3].toDouble();

        final x = xMin.clamp(0.0, 1.0);
        final y = yMin.clamp(0.0, 1.0);
        final w = (xMax - xMin).clamp(0.0, 1.0);
        final h = (yMax - yMin).clamp(0.0, 1.0);

        String formatLabel(String l) {
          if (l == 'person') return 'Human / Unknown Person';
          return l[0].toUpperCase() + l.substring(1).toLowerCase();
        }

        results.add({
          'rect': {'x': x, 'y': y, 'w': w, 'h': h},
          'confidenceInClass': score,
          'detectedClass': formatLabel(label),
        });
      }

      results.sort((a, b) => (b['confidenceInClass'] as double).compareTo(a['confidenceInClass'] as double));
      return results;
    } catch (e) {
      log('ML inference error: $e');
      return [];
    }
  }

  Object _imageToModelInput(img.Image image) {
    // If model is quantized (uint8), feed 0..255 bytes. Otherwise feed float 0..1.
    if (_inputType == TensorType.uint8) {
      final input = Uint8List(_inputSize * _inputSize * 3);
      int idx = 0;
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final p = image.getPixel(x, y);
          input[idx++] = p.r.toInt().clamp(0, 255);
          input[idx++] = p.g.toInt().clamp(0, 255);
          input[idx++] = p.b.toInt().clamp(0, 255);
        }
      }
      return input.reshape([1, _inputSize, _inputSize, 3]);
    } else {
      final input = Float32List(_inputSize * _inputSize * 3);
      int idx = 0;
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final p = image.getPixel(x, y);
          input[idx++] = p.r / 255.0;
          input[idx++] = p.g / 255.0;
          input[idx++] = p.b / 255.0;
        }
      }
      return input.reshape([1, _inputSize, _inputSize, 3]);
    }
  }

  img.Image? _convertCameraImageToRgb(CameraImage image) {
    // Android: YUV_420_888 / iOS: BGRA8888 (depending on setup)
    if (image.format.group == ImageFormatGroup.bgra8888) {
      return _bgra8888ToImage(image);
    }
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _yuv420ToImage(image);
    }
    return null;
  }

  img.Image _bgra8888ToImage(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final width = image.width;
    final height = image.height;
    final out = img.Image(width: width, height: height);

    int pixelIndex = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final b = bytes[pixelIndex++];
        final g = bytes[pixelIndex++];
        final r = bytes[pixelIndex++];
        final a = bytes[pixelIndex++];
        out.setPixelRgba(x, y, r, g, b, a);
      }
    }
    return out;
  }

  img.Image _yuv420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final out = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final yRowOffset = yRowStride * y;
      final uvRowOffset = uvRowStride * (y >> 1);
      for (int x = 0; x < width; x++) {
        final yVal = yBytes[yRowOffset + x];
        final uvIndex = uvRowOffset + (x >> 1) * uvPixelStride;
        final uVal = uBytes[uvIndex];
        final vVal = vBytes[uvIndex];

        // Convert YUV to RGB (BT.601)
        final yf = yVal.toDouble();
        final uf = uVal.toDouble() - 128.0;
        final vf = vVal.toDouble() - 128.0;

        int r = (yf + 1.402 * vf).round();
        int g = (yf - 0.344136 * uf - 0.714136 * vf).round();
        int b = (yf + 1.772 * uf).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        out.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return out;
  }
}
