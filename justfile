# https://just.systems

ODIN_PATH := `odin root`
OUT_WEB := justfile_dir() / "docs"
OUT_DESKTOP := justfile_dir() / "build"
EXE_NAME := "svc16"
SEMVER := "2.2.3"

build_desktop:
    mkdir -p {{OUT_DESKTOP}}
    odin build source/main_desktop -out:{{OUT_DESKTOP}}/{{EXE_NAME}} -o:speed

build_specs:
    typst compile specification.typ {{justfile_dir()}}/assets/specs.pdf --input semver={{SEMVER}}


build: build_specs
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf {{OUT_WEB}}/*
    mkdir -p {{OUT_WEB}}
    odin build source/main_web \
        -target:js_wasm32 \
        -build-mode:obj \
        -o:speed \
        -define:RAYLIB_WASM_LIB=env.o \
        -define:RAYGUI_WASM_LIB=env.o \
        -out:{{OUT_WEB}}/game.wasm.obj
    cp "{{ODIN_PATH}}/core/sys/wasm/js/odin.js" {{OUT_WEB}}/
    cp source/main_web/site.html {{OUT_WEB}}/index.html
    cp source/main_web/readme.html {{OUT_WEB}}/readme.html
    mkdir -p {{OUT_WEB}}/assets
    cp assets/*.png assets/*.svg assets/*.pdf assets/*.gif {{OUT_WEB}}/assets/
    emcc -O2 -o {{OUT_WEB}}/game.html \
        {{OUT_WEB}}/game.wasm.obj \
        "{{ODIN_PATH}}/vendor/raylib/wasm/libraygui.a" \
        "{{ODIN_PATH}}/vendor/raylib/wasm/libraylib.web.a" \
        -sEXPORTED_RUNTIME_METHODS="['HEAPF32', 'HEAPU8']" \
        -sEXPORTED_FUNCTIONS="['_malloc', '_free', '_main_start', '_main_update', '_main_end', '_load_user_file_data', '_set_gamepad_connected']" \
        -sUSE_GLFW=3 \
        -sWARN_ON_UNDEFINED_SYMBOLS=0 \
        -sASSERTIONS \
        -sALLOW_MEMORY_GROWTH=1 \
        --shell-file source/main_web/index_template.html
    rm -f {{OUT_WEB}}/game.wasm.obj
    echo "Web build created in {{OUT_WEB}}"

serve port="8080":
    uv run python -m http.server {{port}} --bind 0.0.0.0 --directory {{OUT_WEB}}
