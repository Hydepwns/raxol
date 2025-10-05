# Changelog - Raxol Core

All notable changes to the raxol_core package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-05

### Added
- Initial release of raxol_core as standalone package
- `Raxol.Core.Buffer` - Terminal buffer primitives with zero dependencies
- `Raxol.Core.Renderer` - Pure functional rendering with diff calculation
- `Raxol.Core.Box` - Box drawing utilities with multiple border styles
- `Raxol.Core.Style` - ANSI style management and color helpers
- Complete API documentation and examples
- Property-based testing with 100% coverage
- Performance optimizations: <1ms operations for 80x24 buffers

### Changed
- Extracted from monolithic raxol package for modular adoption

### Performance
- Buffer operations: <1ms for standard 80x24 terminal size
- Render diff calculation: optimized for minimal updates
- Zero runtime dependencies for minimal footprint

[2.0.0]: https://github.com/Hydepwns/raxol/releases/tag/v2.0.0
