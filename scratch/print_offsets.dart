import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:llama_cpp_dart/src/llama_cpp.dart';

void main() {
  final size = sizeOf<llama_context_params>();
  print("Dart sizeOf<llama_context_params>(): $size");

  final pointer = calloc<llama_context_params>();
  final params = pointer.ref;

  // Set sentinels:
  params.n_ctx = 0x11111111;
  params.n_batch = 0x22222222;
  params.n_ubatch = 0x33333333;
  params.n_seq_max = 0x44444444;
  params.n_threads = 0x55555555;
  params.n_threads_batch = 0x66666666;
  params.rope_scaling_typeAsInt = 0x77777777;
  params.pooling_typeAsInt = 0x88888888;
  params.attention_typeAsInt = 0x1A1A1A1A;
  params.flash_attn_typeAsInt = 0x1B1B1B1B;

  // Floats: we can set them to specific float values
  // e.g. 1.0f is 0x3F800000. Let's set distinct float values:
  // 1.0 = 0x3f800000
  // 2.0 = 0x40000000
  // 3.0 = 0x40400000
  // 4.0 = 0x40800000
  // 5.0 = 0x40a00000
  // 6.0 = 0x40c00000
  // 7.0 = 0x40e00000
  // 8.0 = 0x41000000
  params.rope_freq_base = 1.0;     // should be 00 00 80 3f
  params.rope_freq_scale = 2.0;    // should be 00 00 00 40
  params.yarn_ext_factor = 3.0;    // should be 00 00 40 40
  params.yarn_attn_factor = 4.0;   // should be 00 00 80 40
  params.yarn_beta_fast = 5.0;     // should be 00 00 a0 40
  params.yarn_beta_slow = 6.0;     // should be 00 00 c0 40
  params.yarn_orig_ctx = 0x1C1C1C1C;
  params.defrag_thold = 8.0;       // should be 00 00 00 41

  // Pointers:
  params.cb_eval = Pointer<NativeFunction<ggml_backend_sched_eval_callbackFunction>>.fromAddress(0xDEADBEEFCAFE1111);
  params.cb_eval_user_data = Pointer<Void>.fromAddress(0xDEADBEEFCAFE2222);

  params.type_kAsInt = 0x1D1D1D1D;
  params.type_vAsInt = 0x1E1E1E1E;

  params.abort_callback = Pointer<NativeFunction<ggml_abort_callbackFunction>>.fromAddress(0xDEADBEEFCAFE3333);
  params.abort_callback_data = Pointer<Void>.fromAddress(0xDEADBEEFCAFE4444);

  params.embeddings = true;
  params.offload_kqv = true;
  params.no_perf = true;
  params.op_offload = true;
  params.swa_full = true;
  params.kv_unified = true;

  // Read raw bytes:
  final bytePointer = pointer.cast<Uint8>();
  print("Raw bytes of llama_context_params in Dart (little endian):");
  for (int i = 0; i < size; i += 4) {
    final hexParts = <String>[];
    for (int j = 0; j < 4; j++) {
      if (i + j < size) {
        hexParts.add(bytePointer[i + j].toRadixString(16).padLeft(2, '0'));
      }
    }
    print("Offset ${i.toString().padLeft(3)}: ${hexParts.join(' ')}");
  }

  calloc.free(pointer);
}
