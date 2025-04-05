---
title: Features to Emulate
description: Documentation of features to emulate in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: planning
tags: [planning, features, emulation]
---

# Features to Emulate from Inspirational Libraries

This document outlines key features from various inspirational libraries that we should consider implementing in Raxol.

## Features from Prompt (<https://hexdocs.pm/prompt/Prompt.html>)

Prompt provides an elegant API for handling user input in command-line applications. Here are the features we should consider emulating:

### Input Handling

- **Text Input**: Clean interface for collecting free-form text
- **Password Input**: Masked input for sensitive information
- **Confirmation Prompts**: Yes/No interactions with customizable defaults
- **Custom Choice Selection**: Support for custom confirmation choices beyond Yes/No
- **Selection Lists**: Numbered menu options with easy selection

### Display Features

- **Table Rendering**: Well-formatted tables with auto-sizing columns
- **Styled Text**: Color and formatting options for displayed text
- **Positioned Text**: Control over text positioning in the terminal

### Integration Opportunities

- Port Prompt's clean API design to our form system
- Enhance our Shell Integration component with Prompt's input handling
- Integrate table rendering capabilities into our display components

## Features from Artificery (<https://github.com/bitwalker/artificery>)

Artificery provides robust tooling for creating command-line interfaces. Here are the standout features:

### Command Line Parsing

- **Command Definition**: Easy macro-based definition of commands
- **Argument Parsing**: Sophisticated argument parsing and validation
- **Help Text Generation**: Automatic help text generation for commands
- **Option Handling**: Support for required and optional arguments

### Architecture

- **Modular Command Structure**: Well-organized structure for complex CLIs
- **Release Integration**: Seamless integration with Distillery releases
- **Entry Point Management**: Clean definition of CLI entry points

### Integration Opportunities

- Enhance our Shell Integration component with Artificery's command parsing
- Adopt Artificery's approach to help text generation
- Implement Artificery's modular command structure for complex applications
- Enhance Burrito integration using Artificery's release integration approach

## Implementation Priority

1. First enhance our **Form System** with Prompt's input handling features
2. Add **Table Rendering** capabilities to our display components
3. Integrate **Command Line Parsing** from Artificery for shell integration
4. Implement **Help Text Generation** for all CLI components
5. Enhance **Release Integration** with our existing Burrito support
