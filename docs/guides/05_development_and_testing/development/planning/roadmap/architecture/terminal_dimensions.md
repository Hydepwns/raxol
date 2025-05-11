---
title: Terminal Dimension Handling
description: Documentation on how Raxol handles terminal dimensions
date: 2023-04-15
author: Raxol Team
section: terminal
tags: [terminal, dimensions, rendering]
---

## Terminal Dimension Handling in Raxol

## Overview

Getting accurate terminal dimensions is critical for proper rendering of UI elements in a terminal-based application. Raxol previously faced challenges with inconsistent terminal height reporting from the `rrex_termbox` library, which led to using hardcoded dimensions. This document explains how terminal dimensions are now handled reliably across different environments.

## The Challenge

The `rrex_termbox` library was found to report terminal width correctly but had issues with reporting the terminal height in some environments. This inconsistent behavior caused:

1. Inaccurate UI rendering
2. Layout issues with elements positioned incorrectly
3. Text truncation or overflow
4. Scaling problems with visualizations

To work around this issue, Raxol previously hardcoded the terminal height to a fixed value (30), which limited flexibility and caused problems with terminals of different sizes.

## The Solution: `TerminalUtils`

We created a robust solution with the `Raxol.Terminal.TerminalUtils` module which implements a multi-layered approach for getting terminal dimensions:

### Multiple Fallback Methods

The module tries to get terminal dimensions using multiple methods, falling back to subsequent methods if the previous ones fail:

1. **Erlang's `:io` module** - The first attempt uses Erlang's built-in `:io.columns()` and `:io.rows()` functions
2. **rrex_termbox v2.0.1 NIF** - If `:io` fails, it tries to use the NIF-based interface
3. **System Commands** - If rrex_termbox fails, it tries platform-specific commands:
   - Unix/macOS: Uses `stty size`
   - Windows: Uses PowerShell's `$host.UI.RawUI.WindowSize`
4. **Default Values** - If all methods fail, it uses sensible defaults (80x24)

### Benefits

1. **Reliability** - Multiple fallback mechanisms ensure dimensions are always available
2. **Cross-Platform** - Works consistently across different operating systems
3. **Dynamic Updates** - Responds correctly to terminal resize events
4. **Better UI Rendering** - More accurate dimensions lead to better UI rendering
5. **No Hardcoding** - Eliminated the need for hardcoded values

## Implementation Details

### Dimension Retrieval Function

The main function for getting terminal dimensions is:

```elixir
@spec detect_dimensions() :: {pos_integer(), pos_integer()}
def detect_dimensions do
  # Try all methods with fallbacks
  {width, height} =
    with {:error, _} <- detect_with_io(),
         {:error, _} <- detect_with_termbox(),
         {:error, _} <- detect_with_stty() do
      # Default fallback dimensions if all methods fail
      {80, 24}
    else
      {:ok, w, h} -> {w, h}
    end

  if width == 0 or height == 0 do
    {80, 24}  # Use default if invalid
  else
    {width, height}
  end
end
```

### Helper Format Functions

For convenience, the module also provides helper functions to get dimensions in different formats:

```elixir
@spec get_dimensions_map() :: %{width: pos_integer(), height: pos_integer()}
def get_dimensions_map do
  {width, height} = detect_dimensions()
  %{width: width, height: height}
end

@spec get_bounds_map() :: %{x: 0, y: 0, width: pos_integer(), height: pos_integer()}
def get_bounds_map do
  {width, height} = detect_dimensions()
  %{x: 0, y: 0, width: width, height: height}
end
```

## Verification

To verify that dimensions are correctly detected, we created a script that can be run to test all dimension detection methods:

```
mix run scripts/verify_terminal_dimensions.exs
```

This script tests all methods for getting terminal dimensions and reports the results, making it easy to see which methods work in the current environment.

## Integration with Runtime and Rendering

The `TerminalUtils` module is integrated with the `Raxol.Core.Runtime` modules to ensure that accurate dimensions are used for UI rendering. This integration replaced the previous hardcoded height value.

## Impact on Visualization and Layout

With accurate terminal dimensions, the following improvements have been achieved:

1. **Layouts Adapt to Available Space** - UI elements now correctly use available terminal space
2. **Visualizations Scale Properly** - Charts and other visualizations now scale correctly to different terminal sizes
3. **Improved User Experience** - No more truncated or overflowing UI elements due to incorrect dimensions
4. **Terminal Resize Handled Correctly** - UI updates properly when the terminal is resized

## Conclusion

The implementation of `TerminalUtils` has successfully addressed the terminal dimension reporting inconsistencies in the `rrex_termbox` library. By using a multi-layered approach with multiple fallback methods, Raxol now reliably determines terminal dimensions across different environments, improving UI rendering and user experience.

This approach demonstrates the value of defensive programming and graceful fallbacks when dealing with external dependencies that may have limitations or inconsistencies.
