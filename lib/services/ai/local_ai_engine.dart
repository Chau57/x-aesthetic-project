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
          print(
              "Local AI: Model $fileName already exists locally at $localPath");
          return localPath;
        }

        print("Local AI: Copying $fileName from assets to $localPath...");
        await localFile.parent.create(recursive: true);

        final data = await rootBundle.load('assets/models/$fileName');
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await localFile.writeAsBytes(bytes, flush: true);
        print("Local AI: Copied $fileName successfully. Path: $localPath");
        return localPath;
      } catch (e) {
        print(
            "Local AI: Asset copying failed for $fileName: $e. Falling back to relative/absolute paths.");
      }
    }

    // Fallback to relative/absolute path on host
    final relFile = File(relativePath);
    if (relFile.existsSync()) {
      return relFile.path;
    }
    final absPath =
        "/home/ntdpkg/Documents/hkvi/phan_tich_va_thiet_ke_phan_mem/Dean1/real/merged/$relativePath";
    final absFile = File(absPath);
    if (absFile.existsSync()) {
      return absFile.path;
    }
    return relativePath;
  }

  /// Pre-loads dynamic libraries and initializes OrtSession & LlamaParent.
  Future<void> init() async {
    print("AI Coach Loader: init() called. _initialized = $_initialized");
    if (_initialized) return;

    final categoriesPath = await _resolveModelPath(
        "categories_places365.txt", "models/categories_places365.txt");
    final gemmaPath = await _resolveModelPath(
        "google_gemma-3-1b-it-Q3_K_M.gguf",
        "models/google_gemma-3-1b-it-Q3_K_M.gguf");
    final resnetPath = await _resolveModelPath(
        "resnet18_places365.onnx", "models/resnet18_places365.onnx");

    print(
        "AI Coach Loader: Resolved Categories Path: $categoriesPath (Exists: ${File(categoriesPath).existsSync()})");
    print(
        "AI Coach Loader: Resolved Gemma Path: $gemmaPath (Exists: ${File(gemmaPath).existsSync()})");
    print(
        "AI Coach Loader: Resolved ResNet Path: $resnetPath (Exists: ${File(resnetPath).existsSync()})");

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
        print(
            "AI Coach Loader: Loaded ${_categories.length} category labels successfully.");
      } else {
        print(
            "AI Coach Loader: Categories file does not exist at path: $categoriesPath");
      }
    } catch (e) {
      print("AI Coach Loader: Error loading categories: $e");
    }

    // 2. Pre-load GGML libraries for Llama FFI on Linux desktop host
    if (Platform.isLinux) {
      var libDir = "/home/ntdpkg/Documents/hkvi/phan_tich_va_thiet_ke_phan_mem/Dean1/real/merged/scratch/build_llama_linux/bin";
      if (!Directory(libDir).existsSync()) {
        libDir = "/home/ntdpkg/Documents/test/model/.env/lib/python3.13/site-packages/llama_cpp/lib";
      }
      if (Directory(libDir).existsSync()) {
        try {
          print(
              "AI Coach Loader: Pre-loading libraries on Linux desktop host from $libDir...");
          DynamicLibrary.open("$libDir/libggml-base.so");
          DynamicLibrary.open("$libDir/libggml-cpu.so");
          DynamicLibrary.open("$libDir/libggml.so");
        } catch (e) {
          print("AI Coach Loader: GGML pre-load warning: $e");
        }
        Llama.libraryPath = "$libDir/libllama.so";
        print("AI Coach Loader: Linux FFI paths set to $libDir");
      } else {
        print("AI Coach Loader: Linux libDir does not exist at $libDir");
      }
    }

    // 2b. Pre-load libraries for Android FFI to resolve dependencies transitively
    if (Platform.isAndroid) {
      try {
        print(
            "AI Coach Loader: Pre-loading libraries on Android to resolve libmtmd.so dependencies...");
        DynamicLibrary.open("libc++_shared.so");
        DynamicLibrary.open("libomp.so");
        DynamicLibrary.open("libggml-base.so");
        DynamicLibrary.open("libggml-cpu.so");
        DynamicLibrary.open("libggml.so");
        DynamicLibrary.open("libmtmd.so");
        print(
            "AI Coach Loader: Android libraries pre-loaded successfully.");
      } catch (e) {
        print("AI Coach Loader: Android library pre-load error: $e");
      }
    }

    // 3. Initialize LlamaParent
    try {
      final modelParams = ModelParams();
      modelParams.nGpuLayers = 0;
      modelParams.mainGpu = -1; // CPU only execution

      final contextParams = ContextParams();
      contextParams.nCtx = 2048;
      contextParams.autoTrimContext = true;

      final loadCommand = LlamaLoad(
        path: gemmaPath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: SamplerParams(),
      );
      print(
          "AI Coach Loader: Initializing Gemma-3 LlamaParent with command: path=${loadCommand.path}");
      final parent = LlamaParent(loadCommand);
      print("AI Coach Loader: Awaiting parent.init()...");
      await parent.init();
      _llamaParent = parent;
      print(
          "AI Coach Loader: Gemma-3 initialized successfully. _llamaParent = $_llamaParent");
    } catch (e, stackTrace) {
      print("AI Coach Loader: Error initializing LlamaParent: $e");
      print("AI Coach Loader: Stack trace:\n$stackTrace");
      _llamaParent = null;
    }

    // 4. Initialize ONNX Runtime Session
    try {
      final sessionOptions = OrtSessionOptions();
      print(
          "AI Coach Loader: Initializing ResNet18 Places365 ONNX from path: $resnetPath");
      _onnxSession = OrtSession.fromFile(
        File(resnetPath),
        sessionOptions,
      );
      print(
          "AI Coach Loader: ResNet18 Places365 ONNX initialized successfully. _onnxSession = $_onnxSession");
    } catch (e, stackTrace) {
      print("AI Coach Loader: Error initializing OrtSession: $e");
      print("AI Coach Loader: Stack trace:\n$stackTrace");
    }

    _initialized = true;
    print(
        "AI Coach Loader: init() finished. _initialized = $_initialized, _llamaParent is null: ${_llamaParent == null}, _onnxSession is null: ${_onnxSession == null}");
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
  Future<String> generateAdvice(
    String category,
    double brightness,
    double blurVariance, {
    String? contrast,
    String? colorTemp,
    String? subjectPosition,
    double? tiltDegrees,
  }) async {
    print(
        "AI Coach Generator: generateAdvice() called. _llamaParent is null: ${_llamaParent == null}, _isGenerating = $_isGenerating");
    if (_llamaParent == null) {
      print(
          "AI Coach Generator: Warning - LlamaParent is null! Returning fallback advice.");
      return "Giữ máy ổn định và căn khung hình cân đối.";
    }

    final finalContrast = contrast ?? "trung bình";
    final finalColorTemp = colorTemp ?? "trung tính";
    final finalSubjectPos = subjectPosition ?? "giữa-giữa";
    final finalTilt = tiltDegrees ?? 0.0;

    print(
        "AI Coach Generator: Starting generation for: category=$category, brightness=${brightness.toStringAsFixed(2)}, blurVariance=${blurVariance.toStringAsFixed(0)}, contrast=$finalContrast, colorTemp=$finalColorTemp, subjectPos=$finalSubjectPos, tilt=${finalTilt.toStringAsFixed(1)}");
    _isGenerating = true;
    final completer = Completer<String>();
    final sb = StringBuffer();
    int tokenCount = 0;

    // 1. Listen to tokens generated
    print("AI Coach Generator: Subscribing to LlamaParent stream...");
    final tokenSub = _llamaParent!.stream.listen((token) {
      tokenCount++;
      print("AI Coach Generator: Received token #$tokenCount: '$token'");
      sb.write(token);
    }, onError: (e) {
      print("AI Coach Generator: Error in LlamaParent token stream: $e");
    }, onDone: () {
      print("AI Coach Generator: LlamaParent token stream done.");
    });

    // 2. Listen to completions stream to know when it finishes
    print(
        "AI Coach Generator: Subscribing to LlamaParent completions stream...");
    StreamSubscription<CompletionEvent>? completionSub;
    completionSub = _llamaParent!.completions.listen(
      (event) {
        final text = _cleanResponse(sb.toString());
        print(
            "AI Coach Generator: Completed successfully. Prompt ID: ${event.promptId}, Success: ${event.success}, ErrorDetails: ${event.errorDetails}");
        print(
            "AI Coach Generator: Raw response: '${sb.toString()}', Cleaned advice: '$text'");
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

    // 3. Set a timeout timer to prevent lockups
    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        print("AI Coach Generator: Generation timed out after 10 seconds. Forcing completion.");
        final partialText = sb.toString().trim();
        final text = partialText.isNotEmpty 
            ? _cleanResponse(partialText) 
            : "Giữ máy ổn định và căn khung hình cân đối.";
        completer.complete(text);
        tokenSub.cancel();
        completionSub?.cancel();
        _isGenerating = false;
      }
    });

    final cleanCategory = category.replaceAll('_', ' ').replaceAll('/', ' ');
    final vietnameseCategory = _translateCategoryToVietnamese(cleanCategory);

    // Interpret brightness
    String exposureDesc;
    if (brightness < 0.235) {
      exposureDesc = "tối/thiếu sáng";
    } else if (brightness > 0.745) {
      exposureDesc = "quá sáng/cháy sáng";
    } else {
      exposureDesc = "cân bằng";
    }

    String tiltDesc = finalTilt.abs() < 1.0 ? "thẳng" : "nghiêng ${finalTilt.toStringAsFixed(1)}°";

    // Format rich context prompt
    final contextPrompt = 
        "- Bối cảnh/Chủ thể: $vietnameseCategory\n"
        "- Ánh sáng: $exposureDesc, nhiệt độ màu: $finalColorTemp, tương phản: $finalContrast\n"
        "- Bố cục: chủ thể ở vị trí $finalSubjectPos, đường chân trời: $tiltDesc\n"
        "- Độ sắc nét: ${blurVariance < 15.0 ? 'bị mờ/out nét' : 'rất rõ nét'}";

    try {
      final prompt = "<bos><start_of_turn>user\n"
          "Bạn là một huấn luyện viên nhiếp ảnh chuyên nghiệp chuyên cung cấp lời khuyên ngắn gọn bằng tiếng Việt.\n"
          "Dựa trên bối cảnh camera bên dưới, hãy đưa ra DUY NHẤT 1 lời khuyên cụ thể, thực tế và có thể thực hiện ngay lập tức để cải thiện bức ảnh.\n\n"
          "$contextPrompt\n\n"
          "Quy tắc quan trọng:\n"
          "1. Lời khuyên phải cực kỳ ngắn gọn (dưới 15 từ) và mang tính hành động rõ ràng (ví dụ: 'Hãy hạ thấp góc máy để lấy trọn chiều sâu bối cảnh', 'Căn thẳng máy để sửa đường chân trời bị nghiêng', 'Tăng sáng một chút để chủ thể nổi bật hơn', 'Giữ chắc tay chụp để tránh bị nhòe hình', 'Đưa chủ thể sang bên phải để bối cảnh cân đối hơn').\n"
          "2. Chỉ trả lời trực tiếp đúng 1 câu lời khuyên bằng tiếng Việt. KHÔNG chào hỏi, KHÔNG có từ dẫn dắt (như 'Lời khuyên:', 'Mẹo:'), KHÔNG giải thích thêm, KHÔNG đánh số, KHÔNG gạch đầu dòng.\n"
          "3. Đóng vai một nhiếp ảnh gia thực thụ nói chuyện tự nhiên và chuyên nghiệp, tránh các cụm từ máy móc hay các thông số kỹ thuật khô khan.<end_of_turn>\n"
          "<start_of_turn>model\n";

      print(
          "AI Coach Generator: Sending prompt to LlamaParent. Prompt size: ${prompt.length} chars.");
      final promptId = await _llamaParent!.sendPrompt(prompt);
      print(
          "AI Coach Generator: Prompt sent successfully. Assigned Prompt ID: $promptId");
    } catch (e, stackTrace) {
      print("AI Coach Generator: Error sending prompt: $e");
      print("AI Coach Generator: Stack trace:\n$stackTrace");
      if (!completer.isCompleted) completer.completeError(e);
      tokenSub.cancel();
      completionSub.cancel();
      _isGenerating = false;
    }

    // Cancel the timeout timer if the completer finishes normally
    completer.future.then((_) => timeoutTimer.cancel()).catchError((_) => timeoutTimer.cancel());

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
    cleaned =
        cleaned.replaceAll('**', '').replaceAll('*', '').replaceAll('"', '');
    return cleaned;
  }

  String _translateCategoryToVietnamese(String category) {
    final cat = category.toLowerCase().trim();
    // Common mappings for Places365
    final map = {
      'server room': 'phòng máy chủ / thiết bị công nghệ',
      'berth': 'phòng ngủ nhỏ / bến tàu',
      'elevator shaft': 'buồng thang máy / kiến trúc đứng',
      'street': 'đường phố / phố phường',
      'bedroom': 'phòng ngủ',
      'living room': 'phòng khách',
      'kitchen': 'phòng bếp',
      'office': 'văn phòng làm việc',
      'beach': 'bờ biển / bãi cát',
      'mountain': 'núi non / phong cảnh',
      'forest': 'rừng cây / tự nhiên',
      'garden': 'sân vườn / cây cảnh',
      'restaurant': 'nhà hàng / quán ăn',
      'classroom': 'lớp học / phòng học',
      'corridor': 'hành lang / lối đi',
      'staircase': 'cầu thang',
      'lobby': 'sảnh chờ / phòng khách lớn',
      'highway': 'đường cao tốc / xa lộ',
      'sky': 'bầu trời',
      'waterfall': 'thác nước',
      'sea': 'biển cả',
      'desert': 'sa mạc',
      'park': 'công viên / khu vui chơi',
      'playground': 'sân chơi trẻ em',
      'athletic field': 'sân thể thao / sân bóng',
      'general scene': 'cảnh tổng quan',
      'computer room': 'phòng máy tính / văn phòng công nghệ',
      'doorway': 'cửa ra vào',
      'elevator lobby': 'sảnh thang máy',
      'engine room': 'buồng máy / phòng kỹ thuật',
      'entrance hall': 'sảnh ra vào / sảnh chính',
      'office cubicles': 'khoang làm việc / văn phòng',
      'utility room': 'phòng tiện ích / phòng kho',
      'waiting room': 'phòng chờ / sảnh đợi',
    };
    for (final entry in map.entries) {
      if (cat.contains(entry.key)) {
        return entry.value;
      }
    }
    return category; // fallback
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
