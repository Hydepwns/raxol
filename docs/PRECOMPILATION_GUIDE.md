# Raxol Precompilation Guide

## Overview

This guide covers the precompilation process for Raxol's native dependencies, particularly the termbox2_nif NIF (Native Implemented Function) library.

## Prerequisites

- Erlang/OTP 27.0+
- Elixir 1.17.3+
- C compiler (gcc/clang)
- Make

## Precompilation Process

### 1. Native Dependencies

Raxol uses `termbox2_nif` for low-level terminal operations. The NIF is built using `elixir_make`.

### 2. Build Process

The build process automatically:
1. Compiles the C source code in `lib/termbox2_nif/c_src/`
2. Links against termbox2 library
3. Creates the NIF shared library
4. Generates the application file

### 3. Manual Compilation

If needed, you can manually compile:

```bash
cd lib/termbox2_nif/c_src
make clean
make all
```

### 4. Application File

The build process creates `termbox2_nif.app` in the appropriate ebin directory. This file is required for the OTP application to start properly.

## Troubleshooting

- Ensure all C compilation dependencies are installed
- Check that the application file exists in `lib/termbox2_nif/ebin/`
- Verify shared library permissions

## Platform Support

- Linux (Ubuntu, CentOS, etc.)
- macOS (Intel and Apple Silicon)
- Windows (with appropriate toolchain)