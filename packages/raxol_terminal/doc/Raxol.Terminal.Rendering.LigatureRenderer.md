# `Raxol.Terminal.Rendering.LigatureRenderer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/rendering/ligature_renderer.ex#L1)

Programming font ligature rendering system for Raxol terminals.

This module provides comprehensive support for programming font ligatures with:
- Multi-character ligature detection and replacement
- Font-specific ligature mapping (FiraCode, JetBrains Mono, Cascadia Code, etc.)
- Unicode rendering with proper character width calculation
- Performance-optimized ligature processing
- Customizable ligature sets and user preferences
- Fallback handling for non-ligature fonts

## Supported Ligatures

### Arrows and Flow
- `->`, `<-`, `=>`, `<=`, `>=`, `!=`, `==`, `===`
- `|>`, `<|`, `>>`, `<<`, `<>`, `<=>`, `<->`
- `~>`, `<~`, `~>>`, `<<~`, `<~~`, `~~>`

### Programming Symbols
- `++`, `--`, `**`, `//`, `::`, `;;`, `??`, `!!`
- `&&`, `||`, `&&&`, `|||`
- `#=`, `#!`, `#?`, `#_`, `##`
- `/*`, `*/`, `/**`, `**/`

### Mathematical
- `<=`, `>=`, `!=`, `==`, `===`, `!==`
- `<<=`, `>>=`, `<=>`, `<->`
- `+-`, `-+`, `*=`, `/=`, `%=`, `^=`

## Usage

    # Configure ligature rendering
    config = LigatureRenderer.config(
      font: :fira_code,
      enabled_sets: [:arrows, :programming, :math],
      disabled_ligatures: ["->"]  # Disable specific ligatures
    )

    # Render text with ligatures
    text = "const arrow = (x) => x + 1; // Lambda function"
    rendered = LigatureRenderer.render(text, config)

    # Check if text contains ligatures
    has_ligatures? = LigatureRenderer.contains_ligatures?(text, config)

# `font_family`

```elixir
@type font_family() ::
  :fira_code | :jetbrains_mono | :cascadia_code | :iosevka | :hack | :custom
```

# `ligature_config`

```elixir
@type ligature_config() :: %Raxol.Terminal.Rendering.LigatureRenderer{
  custom_ligatures: %{required(String.t()) =&gt; unicode_point()},
  disabled_ligatures: [String.t()],
  enabled_sets: [ligature_set()],
  fallback_enabled: boolean(),
  font: font_family(),
  performance_mode: boolean()
}
```

# `ligature_set`

```elixir
@type ligature_set() ::
  :arrows | :programming | :math | :brackets | :comments | :operators
```

# `unicode_point`

```elixir
@type unicode_point() :: 0..1_114_111
```

# `available_ligatures`

Gets all available ligatures for a specific font and configuration.

## Examples

    config = LigatureRenderer.config(font: :fira_code)
    ligatures = LigatureRenderer.available_ligatures(config)

# `config`

Creates a ligature rendering configuration.

## Examples

    config = LigatureRenderer.config(
      font: :fira_code,
      enabled_sets: [:arrows, :programming],
      disabled_ligatures: ["->", "<="]
    )

# `contains_ligatures?`

Checks if text contains any ligatures that would be rendered.

## Examples

    config = LigatureRenderer.config()
    LigatureRenderer.contains_ligatures?("hello -> world", config)
    # true

    LigatureRenderer.contains_ligatures?("hello world", config)
    # false

# `cursor_position_map`

Gets cursor position mapping after ligature rendering.

When ligatures are rendered, cursor positions need to be adjusted
because multiple characters may render as one.

# `default_config`

# `detect_font_ligatures`

Detects font ligature capabilities.

Attempts to determine if the current terminal font supports ligatures.

# `ligatures_to_text`

Converts ligature unicode points back to original text sequences.

Useful for editing operations where you need the original text.

# `optimize_config`

Optimizes ligature configuration for performance.

Analyzes text patterns to suggest optimal ligature sets.

# `performance_stats`

Gets performance statistics for ligature rendering.

# `render`

Renders text with ligatures applied.

## Examples

    config = LigatureRenderer.config(font: :fira_code)
    text = "const sum = (a, b) => a + b;"
    rendered = LigatureRenderer.render(text, config)

# `to_ligature_structure`

Converts text to a ligature-aware representation for processing.

This creates a structure that maintains both original text and
ligature information for complex text operations.

# `validate_config`

Validates ligature configuration.

# `visual_width`

Calculates the visual width of text after ligature rendering.

Some ligatures reduce the visual width (e.g., "->" becomes one character),
which is important for proper text alignment and cursor positioning.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
