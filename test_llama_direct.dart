import 'dart:ffi';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

typedef ggml_backend_dev_count_func = IntPtr Function();
typedef ggml_backend_dev_count_dart = int Function();

void main() {
  final libDir = "/home/ntdpkg/Documents/test/model/.env/lib/python3.13/site-packages/llama_cpp/lib";

  print("Pre-loading ggml libraries in correct order...");
  late DynamicLibrary libggml;
  try {
    DynamicLibrary.open("$libDir/libggml-base.so");
    print("Loaded libggml-base.so");
    DynamicLibrary.open("$libDir/libggml-cpu.so");
    print("Loaded libggml-cpu.so");
    libggml = DynamicLibrary.open("$libDir/libggml.so");
    print("Loaded libggml.so");
  } catch (e) {
    print("Error pre-loading libraries: $e");
  }

  print("Setting library path...");
  Llama.libraryPath = "$libDir/libllama.so";

  final devCount = libggml.lookupFunction<ggml_backend_dev_count_func, ggml_backend_dev_count_dart>("ggml_backend_dev_count");
  print("GGML Devices count in Dart BEFORE Llama init: ${devCount()}");

  final modelPath = "/home/ntdpkg/Documents/hkvi/phan_tich_va_thiet_ke_phan_mem/Dean1/real/merged/models/google_gemma-3-1b-it-Q3_K_M.gguf";

  print("Creating Llama instance with mainGpu = -1...");
  try {
    final modelParams = ModelParams();
    modelParams.nGpuLayers = 0;
    modelParams.mainGpu = -1; // Try bypass

    final llama = Llama(
      modelPath,
      modelParams: modelParams,
      contextParams: ContextParams(),
      verbose: true,
    );
    print("Successfully initialized Llama!");
    llama.dispose();
  } catch (e) {
    print("Llama error: $e");
  }
}
