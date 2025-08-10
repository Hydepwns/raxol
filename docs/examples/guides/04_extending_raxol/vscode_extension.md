---
title: VS Code Extension Guide
description: Integrating Raxol with the VS Code Extension.
date: 2025-04-27
author: Raxol Team
section: guides
tags: [vscode, extension, integration, guides]
---

# Raxol VS Code Extension Guide

This guide explains how to use and develop with the Raxol VS Code Extension, which aims to enable Raxol applications to run within a VS Code WebView panel.

> **Feature Status: Not Implemented**
> While the VS Code extension frontend exists (`extensions/vscode/`), the corresponding backend logic in the Raxol Elixir application to handle communication via stdio JSON is **currently missing or incomplete**. This guide describes the existing frontend structure and the _intended_ communication protocol, but the integration **does not function** at this time.

## 1. Introduction

- **Purpose:** Allow running and interacting with Raxol terminal applications directly within a VS Code panel.
- **Intended Mechanism:** Uses a VS Code WebView to display the UI and communicates with a Raxol backend process via stdio using a JSON-based protocol.
- **Potential Benefits:** Integrated development workflow, easier debugging.

## 2. User Guide (Intended)

- **Installation:** Assumed to be via VS Code Marketplace (if published) or manual installation.
- **Running:** A command like `Raxol: Show Terminal` (registered in `extension.ts`) would launch the panel.
- **Interaction:** User input in the panel would be sent to the backend; backend render updates would be displayed in the panel.

## 3. Development Guide (Frontend Structure)

- **Location:** `extensions/vscode/`
- **Architecture:**
  - **Extension Entry:** `src/extension.ts` handles activation and command registration.
  - **Panel Management:** `src/RaxolPanelManager.ts` creates/manages the WebView panel, loads HTML (`media/index.html`), JS (`media/main.js`), and CSS (`media/styles.css`), and orchestrates communication between the WebView and the backend manager.
  - **Backend Process Management:** `src/BackendManager.ts` is responsible for spawning and managing the Raxol Elixir backend process (`mix run --no-halt`) and handling stdio communication with it.
- **Building Locally:** Requires Node.js/npm. Use `npm install` and standard VS Code extension development workflows (`Run Extension` task).

## 4. Communication Protocol (Intended)

- **Transport:** Standard I/O (stdin/stdout) between `BackendManager.ts` and the Raxol Elixir process.
- **Backend Identification:** `BackendManager.ts` sets the environment variable `RAXOL_MODE=vscode_ext` when spawning the backend.
- **Extension -> Backend Messages (Sent to Backend stdin):**
  - JSON objects, newline-delimited (`JSON.stringify(message) + '\n'`).
  - Key types: `initialize` (with workspace info, dimensions), `userInput`, `resize_panel`, `shutdown`.
- **Backend -> Extension Messages (Expected from Backend stdout):**
  - JSON objects wrapped in markers: `RAXOL-JSON-BEGIN{...json...}RAXOL-JSON-END`.
  - Intended types: Render updates (specific type TBD), `log` messages.
  - Output not wrapped in markers is treated as plain log text by `BackendManager.ts`.
- **Current Status:** The Elixir backend **does not** currently implement logic to detect `RAXOL_MODE=vscode_ext` or handle the stdio JSON protocol described above. Existing stdio handling (`Terminal.Driver`) is for native terminal interaction.

## 5. Raxol Application Considerations (Hypothetical)

- **Environment Detection:** Backend would need to check `System.get_env("RAXOL_MODE")`.
- **I/O Handling:** Backend would need a dedicated I/O loop/process to read JSON from stdin and write marker-wrapped JSON to stdout, bypassing the `Terminal.Driver` used for native mode.
- **Rendering:** The `Rendering.Engine` has a non-functional `render_to_vscode/2` placeholder.

## 6. Troubleshooting

- **Backend Logs:** `BackendManager.ts` logs backend stdout/stderr and status messages to the "Raxol Backend" Output Channel in VS Code.
- **Extension Logs:** Standard VS Code developer tools can be used to debug the TypeScript extension code.

## 7. Future Development

- Implementing the backend stdio JSON communication handler.
- Defining the specific render update message format.
- Connecting the rendering engine to the VS Code communication channel.
