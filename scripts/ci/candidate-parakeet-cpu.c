#include "transcribe.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void check_status(const char *action, transcribe_status status) {
    if (status != TRANSCRIBE_OK) {
        fprintf(stderr, "%s: %s\n", action, transcribe_status_string(status));
        exit(EXIT_FAILURE);
    }
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <model.gguf> <jfk.f32>\n", argv[0]);
        return EXIT_FAILURE;
    }

    static float pcm[176000];
    FILE *audio = fopen(argv[2], "rb");
    if (!audio || fread(pcm, sizeof(*pcm), 176000, audio) != 176000 || fgetc(audio) != EOF) {
        fprintf(stderr, "Could not read the complete 11-second JFK fixture\n");
        return EXIT_FAILURE;
    }
    fclose(audio);

    if (transcribe_abi_struct_size(TRANSCRIBE_ABI_MODEL_LOAD_PARAMS) != sizeof(struct transcribe_model_load_params)) {
        fprintf(stderr, "Public model-parameter ABI mismatch\n");
        return EXIT_FAILURE;
    }

    check_status("initialize engine", transcribe_init_backends_default());
    struct transcribe_model_load_params load;
    transcribe_model_load_params_init(&load);
    load.backend = TRANSCRIBE_BACKEND_CPU;
    struct transcribe_model *model = NULL;
    check_status("load CPU model", transcribe_model_load_file(argv[1], &load, &model));

    const char *backend = transcribe_model_backend(model);
    printf("backend: %s\n", backend);
    if (strcmp(backend, "CPU") != 0 && strcmp(backend, "cpu") != 0) {
        fprintf(stderr, "Expected the CPU backend\n");
        return EXIT_FAILURE;
    }

    struct transcribe_session *session = NULL;
    check_status("create session", transcribe_session_init(model, NULL, &session));
    struct transcribe_run_params run;
    transcribe_run_params_init(&run);
    run.timestamps = TRANSCRIBE_TIMESTAMPS_WORD;
    check_status("recognize JFK fixture", transcribe_run(session, pcm, 176000, &run));

    const char *transcript = transcribe_full_text(session);
    printf("heard: %s\n", transcript);
    char lower[512];
    size_t parsed = strlen(transcript);
    if (parsed >= sizeof(lower)) {
        fprintf(stderr, "Unexpected transcript length\n");
        return EXIT_FAILURE;
    }
    for (size_t i = 0; i <= parsed; ++i) {
        lower[i] = (char)tolower((unsigned char)transcript[i]);
    }

    int timed_words = 0;
    const int words = transcribe_n_words(session);
    for (int i = 0; i < words; ++i) {
        struct transcribe_word word;
        transcribe_word_init(&word);
        check_status("read word through public API", transcribe_get_word(session, i, &word));
        if (word.text && word.t1_ms > word.t0_ms) {
            ++timed_words;
        }
    }
    printf("words: %d, with timestamps: %d\n", words, timed_words);
    transcribe_session_free(session);
    transcribe_model_free(model);
    return strstr(lower, "ask") && strstr(lower, "country") && strstr(lower, "you") && timed_words > 0
           ? EXIT_SUCCESS : EXIT_FAILURE;
}
