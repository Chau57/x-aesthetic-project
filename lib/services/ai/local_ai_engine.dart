import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/ai/aesthetic_attributes.dart';
import '../../core/ai/detection_result.dart';
import '../../core/camera/camera_frame.dart';
import 'ai_engine.dart';

class LocalAiEngine implements AiEngine {
  static final LocalAiEngine instance = LocalAiEngine._();
  LocalAiEngine._();

  bool _initialized = false;
  bool _isGenerating = false;
  
  bool get isInitialized => _initialized;

  OrtSession? _onnxSession;
  LlamaParent? _llamaParent;
  final Map<int, String> _categories = {};

  /// Resolves the file path for a model.
  /// On Android and iOS, it extracts the asset (copied from assets/models/) to the
  /// application documents directory. On other platforms (or as fallback), it uses the local path.
  Future<String> _resolveModelPath(String fileName, String relativePath) async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final localPath = '${directory.path}/$fileName';
        final localFile = File(localPath);

        if (await localFile.exists() && await localFile.length() > 0) {
          print("Local AI: Model $fileName already exists locally at $localPath");
          return localPath;
        }

        print("Local AI: Copying $fileName from assets to $localPath...");
        await localFile.parent.create(recursive: true);
        
        final data = await rootBundle.load('assets/models/$fileName');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await localFile.writeAsBytes(bytes, flush: true);
        print("Local AI: Copied $fileName successfully. Path: $localPath");
        return localPath;
      } catch (e) {
        print("Local AI: Asset copying failed for $fileName: $e. Falling back to relative/absolute paths.");
      }
    }

    // Fallback to relative/absolute path on host
    final relFile = File(relativePath);
    if (relFile.existsSync()) {
      return relFile.path;
    }
    final absPath = "/home/ntdpkg/Documents/hkvi/phan_tich_va_thiet_ke_phan_mem/Dean1/real/merged/$relativePath";
    final absFile = File(absPath);
    if (absFile.existsSync()) {
      return absFile.path;
    }
    return relativePath;
  }

  /// Pre-loads dynamic libraries and initializes OrtSession & LlamaParent.
  Future<void> init() async {
    if (_initialized) return;

    final categoriesPath = await _resolveModelPath("categories_places365.txt", "models/categories_places365.txt");
    final gemmaPath = await _resolveModelPath("google_gemma-3-1b-it-Q3_K_M.gguf", "models/google_gemma-3-1b-it-Q3_K_M.gguf");
    final resnetPath = await _resolveModelPath("resnet18_places365.onnx", "models/resnet18_places365.onnx");

    print("AI Coach Loader: Resolved Categories Path: $categoriesPath (Exists: ${File(categoriesPath).existsSync()})");
    print("AI Coach Loader: Resolved Gemma Path: $gemmaPath (Exists: ${File(gemmaPath).existsSync()})");
    print("AI Coach Loader: Resolved ResNet Path: $resnetPath (Exists: ${File(resnetPath).existsSync()})");

    // 1. Load categories
    try {
      final file = File(categoriesPath);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          final parts = line.trim().split(' ');
          if (parts.length >= 2) {
            final idx = int.tryParse(parts.last);
            if (idx != null) {
              var label = parts.first;
              // Clean label prefix: /s/street -> street
              if (label.length > 3 && label.substring(0, 3).contains('/')) {
                label = label.substring(3);
              }
              label = label.replaceAll('_', ' ').replaceAll('/', ' ');
              _categories[idx] = label;
            }
          }
        }
        print("AI Coach Loader: Loaded ${_categories.length} category labels successfully.");
      }
    } catch (e) {
      print("Error loading categories: $e");
    }

    // 2. Pre-load GGML libraries for Llama FFI (only on Linux desktop host)
    if (Platform.isLinux) {
      final libDir = "/home/ntdpkg/Documents/test/model/.env/lib/python3.13/site-packages/llama_cpp/lib";
      if (Directory(libDir).existsSync()) {
        try {
          DynamicLibrary.open("$libDir/libggml-base.so");
          DynamicLibrary.open("$libDir/libggml-cpu.so");
          DynamicLibrary.open("$libDir/libggml.so");
        } catch (e) {
          print("GGML pre-load warning: $e");
        }
        Llama.libraryPath = "$libDir/libllama.so";
        print("AI Coach Loader: Linux FFI paths set to $libDir");
      }
    }

    // 3. Initialize LlamaParent
    try {
      final modelParams = ModelParams();
      modelParams.nGpuLayers = 0;
      modelParams.mainGpu = -1; // CPU only execution
      
      final loadCommand = LlamaLoad(
        path: gemmaPath,
        modelParams: modelParams,
        contextParams: ContextParams(),
        samplingParams: SamplerParams(),
      );
      print("AI Coach Loader: Initializing Gemma-3 LlamaParent...");
      _llamaParent = LlamaParent(loadCommand);
      await _llamaParent!.init();
      print("AI Coach Loader: Gemma-3 initialized successfully.");
    } catch (e) {
      print("Error initializing LlamaParent: $e");
    }

    // 4. Initialize ONNX Runtime Session
    try {
      final sessionOptions = OrtSessionOptions();
      _onnxSession = OrtSession.fromFile(
        File(resnetPath),
        sessionOptions,
      );
      print("AI Coach Loader: ResNet18 Places365 ONNX initialized successfully.");
    } catch (e) {
      print("Error initializing OrtSession: $e");
    }

    _initialized = true;
  }

  /// Classifies a raw image into a Places365 category.
  Future<String> classifyImage(img.Image image) async {
    if (_onnxSession == null) return "general scene";

    try {
      final resized = (image.width == 224 && image.height == 224)
          ? image
          : img.copyResize(image, width: 224, height: 224);
      final floatData = Float32List(1 * 3 * 224 * 224);
      
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);
          final r = pixel.r / 255.0;
          final g = pixel.g / 255.0;
          final b = pixel.b / 255.0;

          // Normalization based on standard ImageNet stats
          floatData[0 * 224 * 224 + y * 224 + x] = (r - 0.485) / 0.229;
          floatData[1 * 224 * 224 + y * 224 + x] = (g - 0.456) / 0.224;
          floatData[2 * 224 * 224 + y * 224 + x] = (b - 0.406) / 0.225;
        }
      }

      final inputTensor = OrtValueTensor.createTensorWithDataList(
        floatData,
        [1, 3, 224, 224],
      );
      final runOptions = OrtRunOptions();
      final outputs = _onnxSession!.run(runOptions, {'input': inputTensor});
      inputTensor.release();
      runOptions.release();

      if (outputs.isEmpty || outputs[0] == null) return "general scene";

      final outputTensor = outputs[0] as OrtValueTensor;
      final outerList = outputTensor.value as List;
      final List<double> logits = List<double>.from(outerList[0]);
      outputTensor.release();

      var maxIdx = 0;
      var maxVal = logits[0];
      for (var i = 1; i < logits.length; i++) {
        if (logits[i] > maxVal) {
          maxVal = logits[i];
          maxIdx = i;
        }
      }

      return _categories[maxIdx] ?? "general scene";
    } catch (e) {
      print("Classification failed: $e");
      return "general scene";
    }
  }

  /// Classifies an image file path.
  Future<String> classifyImagePath(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return "general scene";
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return "general scene";
      return await classifyImage(decoded);
    } catch (e) {
      print("classifyImagePath failed: $e");
      return "general scene";
    }
  }

  /// Sends a prompt to the Gemma model and awaits the complete generated suggestion.
  Future<String> generateAdvice(String category, double brightness, double blurVariance) async {
    if (_llamaParent == null) {
      print("AI Coach Generator: Warning - LlamaParent is null! Returning fallback advice.");
      return "Giữ máy ổn định và căn khung hình cân đối.";
    }
    if (_isGenerating) {
      print("AI Coach Generator: Warning - Generation is already in progress. Ignoring request.");
      return ""; // Ignore concurrent requests
    }

    print("AI Coach Generator: Starting generation for: category=$category, brightness=${brightness.toStringAsFixed(2)}, blurVariance=${blurVariance.toStringAsFixed(0)}");
    _isGenerating = true;
    final completer = Completer<String>();
    final sb = StringBuffer();

    // 1. Listen to tokens generated
    final tokenSub = _llamaParent!.stream.listen((token) {
      sb.write(token);
    });

    // 2. Listen to completions stream to know when it finishes
    StreamSubscription<CompletionEvent>? completionSub;
    completionSub = _llamaParent!.completions.listen(
      (event) {
        final text = _cleanResponse(sb.toString());
        print("AI Coach Generator: Completed successfully. Raw response: '${sb.toString()}', Cleaned advice: '$text'");
        if (!completer.isCompleted) completer.complete(text);
        tokenSub.cancel();
        completionSub?.cancel();
        _isGenerating = false;
      },
      onError: (e) {
        print("AI Coach Generator: Error in completions stream: $e");
        if (!completer.isCompleted) completer.completeError(e);
        tokenSub.cancel();
        completionSub?.cancel();
        _isGenerating = false;
      },
      cancelOnError: true,
    );

    try {
      final prompt = "<bos><start_of_turn>user\n"
          "Bạn là trợ lý nhiếp ảnh AI. Hãy viết duy nhất 1 câu lời khuyên chụp ảnh siêu ngắn gọn (dưới 15 từ) bằng tiếng Việt cho:\n"
          "Bối cảnh: $category\n"
          "Độ sáng: ${brightness.toStringAsFixed(2)} (0: tối, 1: sáng)\n"
          "Độ nét: ${blurVariance.toStringAsFixed(0)} (cao là nét, thấp là mờ)\n"
          "Yêu cầu: Không tiêu đề, không chào hỏi, không định dạng viết đậm, trả lời trực tiếp lời khuyên trong 1 câu ngắn gọn.<end_of_turn>\n"
          "<start_of_turn>model\n";

      await _llamaParent!.sendPrompt(prompt);
    } catch (e) {
      print("AI Coach Generator: Error sending prompt: $e");
      if (!completer.isCompleted) completer.completeError(e);
      tokenSub.cancel();
      completionSub.cancel();
      _isGenerating = false;
    }

    return completer.future;
  }

  String _cleanResponse(String text) {
    var cleaned = text.trim();
    final prefixes = [
      'lời khuyên:',
      'mẹo:',
      'gợi ý:',
      '**lời khuyên:**',
      '**mẹo:**',
      '**gợi ý:**'
    ];
    for (final p in prefixes) {
      if (cleaned.toLowerCase().startsWith(p)) {
        cleaned = cleaned.substring(p.length).trim();
      }
    }
    cleaned = cleaned.replaceFirst(RegExp(r'^(\d+\.\s*|-\s*)'), '');
    cleaned = cleaned.replaceAll('**', '').replaceAll('*', '').replaceAll('"', '');
    return cleaned;
  }

  @override
  Future<List<DetectionResult>> detectContext(CameraFrame frame) async {
    return [];
  }

  @override
  Future<AestheticAttributes> predictAttributes(Object capturedImage) async {
    return const AestheticAttributes({});
  }

  Future<void> dispose() async {
    if (_llamaParent != null) {
      _llamaParent = null;
    }
    if (_onnxSession != null) {
      await _onnxSession!.release();
      _onnxSession = null;
    }
    _initialized = false;
  }
}
