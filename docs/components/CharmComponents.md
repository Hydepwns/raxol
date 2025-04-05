---
title: Charm Components
description: Documentation for charm-based components in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [components, charm, documentation]
---

# Detailed Analysis of Charm.sh Ecosystem Components

## Bubble Tea (TUI Framework)

### Core Architecture

- Based on The Elm Architecture (TEA) with unidirectional data flow
- Three primary functions: Init, Update, and View
- Model-driven design where application state is central
- Event-loop processing for handling user input and system events

### Technical Implementation

- Written in Go, leveraging goroutines for concurrency
- Uses channels for message passing between components
- Framerate-based renderer for smooth animations and transitions
- Supports both inline and full-window terminal applications

### Performance Considerations

- Event loop speed is critical for responsive UIs
- Update() and View() methods should execute quickly to prevent lag
- Message processing can back up if these methods are slow

### Advanced Features

- Nested model support for complex UI hierarchies
- Focus management between different interface components
- Command system for side effects and asynchronous operations
- Mouse support and focus reporting for enhanced interactivity
- Window size detection and responsive layouts

### Testing Capabilities

- Can be integrated with VHS for automated integration testing
- Supports golden file testing for UI consistency

## Lip Gloss (Styling Library)

### Core Capabilities

- Declarative, CSS-like approach to terminal styling
- Expressive API for defining and combining styles
- Style inheritance and composition

### Color Support

- ANSI 16 colors (4-bit) - Basic terminal colors
- ANSI 256 colors (8-bit) - Extended color palette
- True Color (24-bit) - 16.7 million colors with hex code support
- Adaptive colors that adjust based on terminal background
- CompleteColor for specifying exact values across color profiles

### Style Properties

- Text attributes: bold, italic, underline, strikethrough, etc.
- Foreground and background colors with various color models
- Padding and margins with directional control (top, right, bottom, left)
- Width and height constraints
- Alignment options: left, center, right
- Border styles: rounded, thick, double, hidden, etc.

### Layout System

- Box model similar to CSS with content, padding, border, margin
- Horizontal and vertical alignment options
- Width and height constraints with overflow handling
- Joining of styled elements with configurable alignment

### Table Rendering

- Added in recent updates for static table displays
- Customizable headers, rows, and borders
- Column alignment and width management
- Row striping and styling for even/odd rows
- Border customization and color theming

## Bubbles (Component Library)

### Text Input Components

- Single-line text input with cursor navigation
- Multi-line text area with vertical scrolling
- Unicode character support
- Clipboard operations (cut, copy, paste)
- Password masking for secure input
- Placeholder text capabilities

### Selection Components

- List component with keyboard navigation
- Paginated interface with configurable page size
- Filtering/search functionality for long lists
- Cursor highlighting and custom rendering

### Data Display Components

- Table component for tabular data with vertical scrolling
- Column sorting and custom formatting
- Row selection and highlighting
- Header customization and theming

### Progress Indicators

- Progress bar with configurable styling
- Spinner with multiple animation styles
- Support for percentage display
- Optional animation via Harmonica integration
- Gradient fill capabilities

### Navigation Components

- Paginator for managing multi-page interfaces
- Dot-style pagination (iOS-like)
- Numeric pagination with current/total display

## Huh (Form Library)

### Form Architecture

- Groups concept for multi-page forms
- Field-based design with various input types
- Value binding to application variables
- Validation framework with custom error messages

### Field Types

- Input: Single-line text input with masking options
- Text: Multi-line text input with character limits
- Select: Single option selection from a list
- MultiSelect: Multiple option selection with limits
- Confirm: Yes/no confirmation prompts
- File: File system navigation and selection

### Advanced Capabilities

- Accessible mode for screen readers
- Scrollable forms for handling overflow
- Dynamic forms reacting to changes in other fields
- Autocomplete suggestions for text inputs
- Filtering in select components
- Standalone or Bubble Tea integration modes

### Theming System

- Multiple built-in themes (Charm, Dracula, Catppuccin, Base16)
- Custom theme creation with full Lip Gloss styling
- Conditional styling based on field state

## Harmonica (Animation Library)

### Spring Animation System

- Physics-based spring simulations for natural motion
- Framework-agnostic design for portability
- Simple API for position/velocity updates

### Configuration Parameters

- Time Delta: Controls animation timing resolution
- Angular Velocity: Affects animation speed
- Damping Ratio: Controls bounciness and oscillation

### Animation Types

- Under-damped: Oscillating with decreasing amplitude
- Critically-damped: Fastest non-oscillating motion
- Over-damped: Slower non-oscillating motion

### Integration Approaches

- Per-frame update model for smooth animations
- Time-based rather than frame-based for consistency
- Works with any coordinate system or value range

## Glow (Markdown Renderer)

### Rendering Capabilities

- Terminal-optimized markdown display
- Syntax highlighting for code blocks
- Custom styling for different markdown elements
- Support for tables, lists, and other formatting

### Interface Options

- CLI mode for direct file rendering
- TUI interface with navigation and pagination
- Customizable styling through themes

## Gum (Shell Script Enhancer)

### Input Components

- Text input with validation options
- Multi-line text input (Write)
- Filter with fuzzy matching capabilities
- Option selection (Choose) with multi-select support
- Confirmation prompts with customizable text

### Display Components

- Spinner for progress indication
- Styled text output with colors and formatting
- Pager for scrollable content viewing
- Table for structured data presentation

### File Operations

- File browser with navigation and selection
- Directory tree visualization

## VHS (Terminal Recorder)

### Recording Capabilities

- Captures terminal sessions as GIFs
- Script-based recording for reproducibility
- Customizable frame rate and dimensions

### Automation Features

- Programmable keyboard input
- Timed delays between actions
- Support for testing terminal applications

## Log (Logging Library)

### Logging Features

- Structured logging with customizable formatting
- Multiple output formats (text, JSON, Logfmt)
- Log level filtering and contextual data

### Styling Options

- Lip Gloss integration for styled log output
- Customizable colors for different log levels
- Timestamp and context formatting options

## Wish (SSH Application Framework)

### SSH Capabilities

- Terminal application serving over SSH
- Authentication and session management
- Command execution in secure context

### Application Integration

- Bubble Tea application serving over SSH
- Custom command handling and middleware
- Server configuration and management
