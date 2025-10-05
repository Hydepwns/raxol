# Changelog - Raxol Plugin

All notable changes to the raxol_plugin package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-05

### Added
- Initial release of raxol_plugin as standalone package
- `Raxol.Plugin` behaviour for building terminal plugins
- Plugin lifecycle management (init, handle_input, render, cleanup)
- Plugin registry and loader system
- Testing utilities for plugin development
- Documentation generators for plugin APIs
- Example plugin implementations (Spotify integration showcase)

### Changed
- Extracted from monolithic raxol package for modular adoption

### Features
- Simple behaviour-based plugin API
- State management patterns for plugins
- Input handling and event processing
- Buffer rendering integration
- Plugin testing helpers

### Dependencies
- Requires raxol_core ~> 2.0

[2.0.0]: https://github.com/Hydepwns/raxol/releases/tag/v2.0.0
