#!/usr/bin/env elixir

# Simple Documentation Generation Demo
# Shows the concept of generated documentation from structured data

defmodule SimpleDocGenerator do
  @moduledoc """
  Simplified documentation generator to demonstrate the DRY architecture concept.
  """
  
  def generate_demo do
    IO.puts("🚀 Generating demo documentation...")
    
    # Hardcoded data structure (would come from YAML files)
    data = get_demo_data()
    
    # Generate README demo
    generate_readme_demo(data)
    
    IO.puts("✅ Demo documentation generated!")
  end
  
  defp get_demo_data do
    %{
      project: %{
        name: "Raxol",
        version: "1.0.0", 
        status: "Production Ready",
        tagline: "A modern Elixir framework for building terminal-based applications with web capabilities"
      },
      architecture: %{
        layers: [
          %{name: "Applications", description: "User TUI Apps, Plugins, Extensions"},
          %{name: "UI Framework Layer", description: "Components, Layouts, Themes, Event System"},
          %{name: "Web Interface Layer", description: "Phoenix LiveView, WebSockets, Auth, API"},
          %{name: "Terminal Emulator Core", description: "ANSI Parser, Buffer Manager, Input Handler"},
          %{name: "Platform Services", description: "Plugins, Config, Metrics, Security, Persistence"}
        ]
      },
      performance: %{
        test_coverage: "100% (1751/1751 tests passing)",
        compilation_warnings: "0 warnings",
        response_time: "< 2ms average",
        parser_performance: "3.3 μs/op (30x improvement)"
      },
      features: [
        %{name: "Advanced Terminal Emulator", description: "Full ANSI/VT100+ compliance with Sixel graphics"},
        %{name: "Component-Based UI", description: "React-style components with lifecycle management"},
        %{name: "Real-Time Web Interface", description: "Phoenix LiveView with collaborative features"},
        %{name: "Plugin Architecture", description: "Runtime extensibility with hot-reloading"}
      ]
    }
  end
  
  defp generate_readme_demo(data) do
    content = """
# #{data.project.name}

[![CI](https://github.com/Hydepwns/raxol/workflows/CI/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)
[![Tests](https://img.shields.io/badge/tests-1751%20passing-brightgreen.svg)](https://github.com/Hydepwns/raxol/actions)

#{data.project.tagline}

## Project Status

**Version**: #{data.project.version} - #{data.project.status}

| Metric | Status |
|--------|--------|
| **Test Coverage** | #{data.performance.test_coverage} |
| **Code Quality** | #{data.performance.compilation_warnings} |
| **Performance** | #{data.performance.parser_performance} |
| **Response Time** | #{data.performance.response_time} |

## Core Features

#{generate_features_list(data.features)}

## Architecture

Raxol follows a layered, modular architecture:

```
#{generate_architecture_diagram(data.architecture.layers)}
```

## Installation

Add Raxol to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:raxol, "~> 1.0.0"}
  ]
end
```

---
*🤖 This README was generated from structured data using the DRY documentation system.*
"""

    File.write!("README_GENERATED_DEMO.md", content)
    IO.puts("✅ Generated README_GENERATED_DEMO.md")
  end
  
  defp generate_features_list(features) do
    features
    |> Enum.map(fn feature ->
      "- **#{feature.name}**: #{feature.description}"
    end)
    |> Enum.join("\n")
  end
  
  defp generate_architecture_diagram(layers) do
    layers
    |> Enum.map(fn layer ->
      "┌─────────────────────────────────────────┐\n" <>
      "│  #{String.pad_trailing(layer.name, 36)} │\n" <>
      "│  #{String.pad_trailing(layer.description, 36)} │"
    end)
    |> Enum.join("\n├─────────────────────────────────────────┤\n")
    |> then(&(&1 <> "\n└─────────────────────────────────────────┘"))
  end
end

SimpleDocGenerator.generate_demo()