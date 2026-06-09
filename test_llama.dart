import 'dart:io';
import 'dart:ffi';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() async {
  final libDir = "/home/ntdpkg/Documents/test/model/.env/lib/python3.13/site-packages/llama_cpp/lib";
  print("Pre-loading ggml libraries...");
  try {
    DynamicLibrary.open("$libDir/libggml-base.so");
    DynamicLibrary.open("$libDir/libggml-cpu.so");
    DynamicLibrary.open("$libDir/libggml.so");
  } catch (e) {
    print("Pre-load warning: $e");
  }

  print("Setting library path...");
  Llama.libraryPath = "$libDir/libllama.so";
  
  final modelPath = "/home/ntdpkg/Documents/hkvi/phan_tich_va_thiet_ke_phan_mem/Dean1/real/merged/models/google_gemma-3-1b-it-Q3_K_M.gguf";
  if (!File(modelPath).existsSync()) {
    print("Error: Model file does not exist at $modelPath");
    return;
  }

  print("Configuring load command...");
  final modelParams = ModelParams();
  modelParams.nGpuLayers = 0;
  modelParams.mainGpu = -1;

  final loadCommand = LlamaLoad(
    path: modelPath,
    modelParams: modelParams,
    contextParams: ContextParams(),
    samplingParams: SamplerParams(),
  );

  print("Initializing LlamaParent...");
  final llamaParent = LlamaParent(loadCommand);
  await llamaParent.init();

  print("Listening to stream...");
  llamaParent.stream.listen((response) {
    stdout.write(response);
  }, onDone: () {
    print("\nStream done!");
  });

  print("Sending prompt...");
  llamaParent.sendPrompt("Gợi ý 1 mẹo ngắn chụp ảnh phong cảnh bằng tiếng Việt (dưới 15 từ).");
}
