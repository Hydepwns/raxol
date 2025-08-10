---
title: Cross-Platform Testing Guide
description: Guide for cross-platform testing in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: testing
tags: [testing, cross-platform, guide]
---

# Cross-Platform Testing

This document outlines the cross-platform testing strategy for Raxol, providing instructions on how to run tests, interpret results, and troubleshoot platform-specific issues.

## Table of Contents

1. [Overview](#overview)
2. [Testing Infrastructure](#testing-infrastructure)
3. [Running Platform Tests](#running-platform-tests)
4. [Test Categories](#test-categories)
5. [CI Integration](#ci-integration)
6. [Troubleshooting](#troubleshooting)
7. [Common Issues](#common-issues)

## Overview

Raxol is designed to work seamlessly across macOS, Linux, and Windows. Our cross-platform testing ensures that:

- Core functionality works consistently across all platforms
- Terminal-specific features gracefully degrade when not supported
- Platform-specific optimizations are activated appropriately
- Unicode, colors, and interactions behave correctly on each platform

## Testing Infrastructure

### Components

1. **Platform Detection Module**: `Raxol.System.Platform` provides platform identification and feature support detection
2. **Platform-Specific Tests**: Test files in `test/platform/` contain platform-specific test cases
3. **Terminal Compatibility Script**: Verifies terminal features like true color and Unicode support
4. **Component Rendering Tests**: Ensure components render appropriately for each platform's capabilities
5. **CI Workflow**: GitHub Actions workflow for automated platform testing

### Test Organization

```
test/
  platform/
    platform_detection_test.exs   # Tests for platform detection
    component_rendering_test.exs  # Tests for component rendering
    verify_terminal_compatibility.exs  # Terminal capability tests
scripts/
  run_platform_tests.exs          # Comprehensive platform test runner
.github/
  workflows/
    cross_platform_tests.yml      # CI workflow for platform testing
```

## Running Platform Tests

### Full Test Suite

To run the complete platform test suite locally:

```bash
mix run scripts/run_platform_tests.exs
```

This will:

1. Detect your current platform
2. Run appropriate platform-specific tests
3. Verify terminal compatibility
4. Test component rendering
5. Generate a comprehensive report

### Individual Tests

To run specific platform tests:

```bash
# Platform detection tests
mix test test/platform/platform_detection_test.exs

# Component rendering tests
mix test test/platform/component_rendering_test.exs

# Terminal compatibility tests
mix run test/platform/verify_terminal_compatibility.exs
```

### CI Tests

The CI system automatically runs cross-platform tests on each supported platform when:

- Code is pushed to `main` or `develop` branches
- Pull requests target `main` or `develop` branches
- Manual trigger is initiated with `workflow_dispatch`

## Test Categories

### 1. Platform Detection

Tests in `platform_detection_test.exs` verify:

- Correct platform identification
- Platform-specific information gathering
- File extension determination
- Executable name handling

### 2. Terminal Compatibility

The `verify_terminal_compatibility.exs` script checks:

- Basic color support
- True color (24-bit) support
- Unicode character rendering
- Box drawing capabilities
- Input method support
- Clipboard integration

### 3. Component Rendering

Tests in `component_rendering_test.exs` ensure:

- Components render with appropriate styling
- Unicode is handled correctly
- Box borders use correct characters
- Progress bars display appropriately
- Color fallbacks work on limited terminals

### 4. Platform-Specific Tests

Platform-specific tests verify features unique to each platform:

- **Windows**: Console type detection, Unicode fallbacks
- **macOS**: Terminal app identification, Apple Silicon optimizations
- **Linux**: Distribution detection, Wayland/X11 identification

## CI Integration

The GitHub Actions workflow `.github/workflows/cross_platform_tests.yml` automatically:

1. Runs on Ubuntu, macOS, and Windows
2. Executes all platform tests
3. Builds test binaries
4. Verifies binary functionality
5. Uploads test results as artifacts

## Troubleshooting

### When Tests Fail

1. Check the test logs to identify the specific failing tests
2. Review the terminal compatibility report for clues
3. Verify your terminal supports the required features
4. Check for platform-specific issues in the error message

### Generating Debug Information

For detailed platform debugging:

```bash
MIX_ENV=test DEBUG=true mix run scripts/run_platform_tests.exs
```

This produces verbose output with additional diagnostic information.

## Common Issues

### Windows

- **Unicode rendering**: Some Windows consoles don't fully support Unicode. Use Windows Terminal for best results.
- **Color support**: Command Prompt has limited color support. Use Windows Terminal or PowerShell for full color support.
- **Console detection**: Use `Platform.get_platform_info()` to check console type.

### Linux

- **Terminal detection**: Some Linux terminals may not be correctly identified. Set `TERM` environment variable appropriately.
- **Clipboard support**: Install `xclip` (X11) or `wl-copy` (Wayland) for clipboard support.
- **Font issues**: Unicode rendering depends on the terminal font. Use a font with good Unicode coverage.

### macOS

- **Terminal.app limitations**: Some advanced features work better in iTerm2 than Terminal.app.
- **Font rendering**: Some older versions may have Unicode limitations. Update to the latest macOS.
- **Apple Silicon**: Ensure native ARM64 binaries are used on M1/M2/M3 Macs for best performance.

## Minimum Requirements

To ensure Raxol works correctly, these minimum requirements should be met:

- **Windows**: Windows 10 or higher with Windows Terminal recommended
- **macOS**: macOS 10.15 (Catalina) or higher
- **Linux**: Any modern distribution with UTF-8 locale support

## Conclusion

Cross-platform testing is essential to ensure Raxol provides a consistent experience across different environments. By following the procedures outlined in this document, you can verify compatibility and identify platform-specific issues early in the development process.
