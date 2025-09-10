---
title: Features to Emulate
description: Documentation of features to emulate in Raxol Terminal Emulator
date: 2025-04-26
author: Raxol Team
section: planning
tags: [planning, features, emulation]
---

# Features to Emulate from Inspirational Libraries

This document outlines key features from various inspirational libraries that we should consider implementing in Raxol.

## Features from Prompt (<https://hexdocs.pm/prompt/Prompt.html>)

Prompt provides an elegant API for handling user input in command-line applications. Here are the features we should consider emulating:

### Input Handling

- **Text Input**: Clean interface for collecting free-form text (`TextInput` component exists, refined)
- **Password Input**: Masked input for sensitive information (`TextInput` with `:password` flag)
- **Confirmation Prompts**: Yes/No interactions with customizable defaults (`Modal.confirmation` enhanced with defaults)
- **Custom Choice Selection**: Support for custom confirmation choices beyond Yes/No (`SelectList` component implemented)
- **Selection Lists**: Numbered menu options with easy selection (Partially covered by `SelectList`, could be enhanced)

### Display Features

- **Table Rendering**: Well-formatted tables with auto-sizing columns (`Table` component started, needs refinement)
- **Styled Text**: Color and formatting options for displayed text (Ongoing via Theme/Styling system)
- **Positioned Text**: Control over text positioning in the terminal (Partially available via layout system)

### Integration Opportunities

- Port Prompt's clean API design to our form system (Ongoing)
- Enhance our Shell Integration component with Prompt's input handling
- Integrate table rendering capabilities into our display components (Ongoing)

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

1. ~~First enhance our **Form System** with Prompt's input handling features~~ (Partially Complete - Text, Password, Confirmation, SelectList)
2. Add **Table Rendering** capabilities to our display components (In Progress - Basic implementation done, refinement needed)
3. Integrate **Command Line Parsing** from Artificery for shell integration (Partially Started - Core plugin command registry/manager implemented)
4. Implement **Help Text Generation** for all CLI components (Partially Started - Linked to Accessibility work)
5. Enhance **Release Integration** with our existing Burrito support (Partially Started - Core runtime refactoring complete, touching related areas)
