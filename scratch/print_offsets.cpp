#include <iostream>
#include <cstddef>
#include "llama.h"

int main() {
    std::cout << "Size of llama_context_params: " << sizeof(llama_context_params) << std::endl;
    
    #define PRINT_OFFSET(field) \
        std::cout << "Offset of " << #field << ": " << offsetof(llama_context_params, field) \
                  << " (size: " << sizeof(((llama_context_params*)0)->field) << ")" << std::endl;

    PRINT_OFFSET(n_ctx);
    PRINT_OFFSET(n_batch);
    PRINT_OFFSET(n_ubatch);
    PRINT_OFFSET(n_seq_max);
    PRINT_OFFSET(n_threads);
    PRINT_OFFSET(n_threads_batch);
    PRINT_OFFSET(rope_scaling_type);
    PRINT_OFFSET(pooling_type);
    PRINT_OFFSET(attention_type);
    PRINT_OFFSET(flash_attn_type);
    PRINT_OFFSET(rope_freq_base);
    PRINT_OFFSET(rope_freq_scale);
    PRINT_OFFSET(yarn_ext_factor);
    PRINT_OFFSET(yarn_attn_factor);
    PRINT_OFFSET(yarn_beta_fast);
    PRINT_OFFSET(yarn_beta_slow);
    PRINT_OFFSET(yarn_orig_ctx);
    PRINT_OFFSET(defrag_thold);
    PRINT_OFFSET(cb_eval);
    PRINT_OFFSET(cb_eval_user_data);
    PRINT_OFFSET(type_k);
    PRINT_OFFSET(type_v);
    PRINT_OFFSET(abort_callback);
    PRINT_OFFSET(abort_callback_data);
    PRINT_OFFSET(embeddings);
    PRINT_OFFSET(offload_kqv);
    PRINT_OFFSET(no_perf);
    PRINT_OFFSET(op_offload);
    PRINT_OFFSET(swa_full);
    PRINT_OFFSET(kv_unified);

    return 0;
}
