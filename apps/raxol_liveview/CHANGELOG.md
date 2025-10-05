# Changelog - Raxol LiveView

All notable changes to the raxol_liveview package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-05

### Added
- Initial release of raxol_liveview as standalone package
- `Raxol.LiveView.TerminalBridge` - Convert Raxol buffers to HTML for Phoenix LiveView
- `Raxol.LiveView.TerminalComponent` - LiveComponent for embedding terminals
- Event handling system (keyboard, mouse, paste, focus)
- Five built-in themes: Nord, Dracula, Solarized Dark/Light, Monokai
- CSS styles for terminal rendering with monospace grid layout
- JavaScript hooks for terminal interactions
- Accessibility features (ARIA labels, keyboard navigation)
- Performance monitoring with 60fps target

### Changed
- Extracted from monolithic raxol package for modular adoption

### Performance
- Average rendering time: 1.24ms (well under 16ms for 60fps)
- Virtual DOM diffing for efficient updates
- Optimized HTML generation with caching

### Dependencies
- Requires raxol_core ~> 2.0
- Phoenix LiveView ~> 0.20 or ~> 1.0
- Phoenix ~> 1.7
- Phoenix HTML ~> 4.0

[2.0.0]: https://github.com/Hydepwns/raxol/releases/tag/v2.0.0
