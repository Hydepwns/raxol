---
title: Clipboard Handling
description: How Raxol interacts with the system clipboard and handles pasted input.
date: 2024-07-27 # Updated date
author: Raxol Team
section: terminal
tags: [clipboard, terminal, documentation, osc52, bracketed paste, plugin]
---

# Clipboard Handling

Raxol interacts with the system clipboard and distinguishes pasted input using standard terminal mechanisms.

## System Clipboard Interaction (OSC 52)

Modern terminal emulators commonly support clipboard access via Operating System Command (OSC) 52 sequences. Raxol utilizes this standard for copying text _to_ and potentially pasting text _from_ the system clipboard.

- **Copying to System Clipboard**: When an application component (e.g., `MultiLineInput` via its `ClipboardHelper`) or a command initiates a copy action, Raxol (likely via a core service like a `ClipboardPlugin` or directly from the `Emulator`/`Driver`) formats the selected text and sends an OSC 52 sequence to the hosting terminal. The sequence typically looks like `\e]52;c;BASE64_DATA\a` or `\e]52;p;BASE64_DATA\a`, where `c` denotes the clipboard selection (clipboard) and `p` the primary selection, and `BASE64_DATA` is the base64-encoded text to be copied.
- **Pasting from System Clipboard**: Requesting a paste via OSC 52 (`\e]52;c;?\a`) is possible, but handling the asynchronous response (the terminal sending back the clipboard content as input, possibly encoded) requires careful parsing and state management, likely coordinated between the `Parser`, `Emulator`, and potentially the `ClipboardPlugin`.
- **Dependency**: This functionality relies entirely on the hosting terminal emulator supporting OSC 52.

## Distinguishing Pasted Input (Bracketed Paste Mode)

To differentiate between text typed by the user and text pasted into the terminal, Raxol enables Bracketed Paste Mode if supported by the hosting terminal.

- **Enabling/Disabling**: The `Emulator`/`Driver` sends `\e[?2004h` to enable and `\e[?2004l` to disable this mode.
- **Input Wrapping**: When enabled, the hosting terminal wraps pasted text between `\e[200~` (start marker) and `\e[201~` (end marker).
- **Parsing**: The `Raxol.Terminal.Parser` detects these start and end markers. Input received between these markers is identified as pasted content.
- **Application Handling**: This allows the running Raxol application or component (e.g., `MultiLineInput`) to handle pasted text differently if needed (e.g., processing multi-line pastes as a single event, disabling auto-indentation).

## Core Integration

- **`ClipboardPlugin` (Core Plugin)**: A dedicated core plugin (`lib/raxol/core/plugins/core/ClipboardPlugin.ex` or similar) likely exists to centralize clipboard operations initiated via commands (e.g., `:clipboard_copy`, `:clipboard_paste`). This plugin would be responsible for constructing and triggering OSC 52 sequences or handling paste responses.
- **Component Helpers (`ClipboardHelper`)**: UI components that support clipboard actions (like `MultiLineInput`) use helper modules (e.g., `Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper`) to manage selection state and interact with the core clipboard mechanism, likely by dispatching commands to the `ClipboardPlugin`.

## Limitations

- **Plain Text**: Standard terminal clipboard mechanisms (OSC 52) primarily support plain text.
- **Rich Text/Images**: Raxol does not inherently support copying/pasting rich text formats or images via these terminal mechanisms.
- **Internal Buffers/History**: While a specific component _could_ implement its own local history, Raxol's core terminal layer does not provide multiple named clipboard buffers or persistent history management beyond interacting with the system clipboard.

(Previous sections detailing a specific `Raxol.Terminal.Clipboard` module, its API, configuration, events, examples, and testing have been removed as they do not reflect the current architecture based on OSC 52, Bracketed Paste, and core plugins/helpers.)
