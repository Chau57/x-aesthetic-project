import 'dart:ffi';

typedef ggml_backend_dev_count_func = IntPtr Function();
typedef ggml_backend_dev_count_dart = int Function();

typedef ggml_backend_load_all_func = Void Function();
typedef ggml_backend_load_all_dart = void Function();

void main() {
  final libDir = "/home/ntdpkg/Documents/test/model/.env/lib/python3.13/site-packages/llama_cpp/lib";
  
  print("Loading libggml-base.so...");
  DynamicLibrary.open("$libDir/libggml-base.so");
  
  print("Loading libggml-cpu.so...");
  DynamicLibrary.open("$libDir/libggml-cpu.so");
  
  print("Loading libggml.so...");
  final libggml = DynamicLibrary.open("$libDir/libggml.so");
  
  final loadAll = libggml.lookupFunction<ggml_backend_load_all_func, ggml_backend_load_all_dart>("ggml_backend_load_all");
  final devCount = libggml.lookupFunction<ggml_backend_dev_count_func, ggml_backend_dev_count_dart>("ggml_backend_dev_count");
  
  print("Devices count BEFORE ggml_backend_load_all(): ${devCount()}");
  
  print("Calling ggml_backend_load_all()...");
  loadAll();
  
  print("Devices count AFTER ggml_backend_load_all(): ${devCount()}");
}
