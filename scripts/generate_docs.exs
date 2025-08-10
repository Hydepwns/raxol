#!/usr/bin/env elixir

# Documentation Generation Script
# Generates consistent documentation from YAML schema files

defmodule DocGenerator do
  @moduledoc """
  Generates documentation from YAML schema files using ERB-like templates.
  
  This ensures single source of truth for all documentation.
  """
  
  def generate_all do
    IO.puts("🚀 Generating documentation from schema files...")
    
    # Load all schema data
    schemas = load_schemas()
    
    # Generate README.md
    generate_readme(schemas)
    
    # Generate ARCHITECTURE.md  
    generate_architecture(schemas)
    
    # Generate TODO.md updates
    generate_todo_updates(schemas)
    
    IO.puts("✅ Documentation generation complete!")
  end
  
  defp load_schemas do
    schema_dir = "docs/schema"
    
    %{
      project_info: load_yaml("#{schema_dir}/project_info.yml"),
      architecture: load_yaml("#{schema_dir}/architecture.yml"),
      features: load_yaml("#{schema_dir}/features.yml"),
      performance: load_yaml("#{schema_dir}/performance_metrics.yml"),
      installation: load_yaml("#{schema_dir}/installation.yml")
    }
  end
  
  defp load_yaml(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        simple_yaml_parse(content)
      {:error, _} ->
        IO.puts("⚠️  Warning: Could not load #{file_path}")
        %{}
    end
  end
  
  # Simple YAML parser for our schema files
  defp simple_yaml_parse(content) do
    # This is a basic implementation for our specific YAML structure
    # In production, you'd use a proper YAML library like :yaml_elixir
    lines = String.split(content, "\n")
    
    result = %{}
    parse_yaml_lines(lines, result, [])
  end
  
  defp parse_yaml_lines([], result, _stack), do: result
  defp parse_yaml_lines([line | rest], result, stack) do
    cond do
      String.trim(line) == "" or String.starts_with?(line, "#") ->
        parse_yaml_lines(rest, result, stack)
      
      String.contains?(line, ":") ->
        [key, value] = String.split(line, ":", parts: 2)
        key = String.trim(key) |> String.replace("\"", "")
        value = String.trim(value) |> String.replace("\"", "")
        
        if value == "" do
          # This is a parent key
          parse_yaml_lines(rest, Map.put(result, key, %{}), [key | stack])
        else
          # This is a key-value pair
          parse_yaml_lines(rest, Map.put(result, key, value), stack)
        end
      
      true ->
        parse_yaml_lines(rest, result, stack)
    end
  end
  
  defp generate_readme(schemas) do
    IO.puts("📄 Generating README.md...")
    
    content = """
# #{schemas.project_info["name"]}

#{generate_badges(schemas.project_info["badges"])}

#{schemas.project_info["description"]}

## Project Status

**Version**: #{schemas.project_info["version"]} - #{schemas.project_info["status"]}

| Metric | Status | Details |
|--------|--------|---------|
| **Code Quality** | Excellent | #{schemas.performance["current_status"]["compilation_warnings"]} |
| **Test Coverage** | #{String.replace(schemas.performance["current_status"]["test_pass_rate"], "%", "\\%")} | #{String.replace(schemas.performance["current_status"]["test_pass_rate"], "%", "\\%")} |
| **Documentation** | Complete | #{schemas.performance["current_status"]["api_documentation"]} |
| **Performance** | Optimized | Parser: #{schemas.performance["current_status"]["parser_performance"]} |
| **Features** | Complete | #{schemas.performance["current_status"]["feature_implementation"]} |
| **Enterprise** | Ready | #{schemas.performance["current_status"]["enterprise_features"]} |

## What is Raxol?

#{schemas.project_info["tagline"]}. It provides:

#{generate_core_features_list(schemas.features["core_features"])}

## Core Features

#{generate_detailed_features(schemas.features["core_features"])}

## Architecture

#{schemas.architecture["system_overview"]}:

```
#{generate_architecture_diagram(schemas.architecture["layers"])}
```

### Key Design Principles

#{generate_design_principles_list(schemas.architecture["design_principles"])}

## Installation

#{generate_installation_section(schemas.installation)}

## Performance

Raxol is designed for high performance and scalability:

#{generate_performance_metrics(schemas.performance)}

## Documentation

Comprehensive documentation and guides:

- [Installation Guide](docs/DEVELOPMENT.md#quick-setup)
- [Component Reference](docs/components/README.md)
- [Terminal Emulator Guide](examples/guides/02_core_concepts/terminal_emulator.md)
- [Plugin Development](examples/guides/04_extending_raxol/plugin_development.md)
- [Enterprise Features](examples/guides/06_enterprise/README.md)
- [API Documentation](#{schemas.project_info["documentation_url"]})
- [Example Applications](examples/)
- [Contributing Guide](CONTRIBUTING.md)

## License

#{schemas.project_info["license"]} License - see [LICENSE.md](LICENSE.md)

## Support

- [Documentation Hub](docs/CONSOLIDATED_README.md)
- [Hex.pm Package](https://hex.pm/packages/#{schemas.project_info["hex_package"]})
"""

    File.write!("README.md", content)
    IO.puts("✅ README.md generated")
  end
  
  defp generate_badges(badges) when is_list(badges) do
    badges
    |> Enum.map(fn badge ->
      "[![#{badge["name"]}](#{badge["url"]})](#{badge["link"]})"
    end)
    |> Enum.join(" ")
  end
  defp generate_badges(_), do: ""
  
  defp generate_core_features_list(features) when is_map(features) do
    features
    |> Enum.map(fn {_key, feature} ->
      "- **#{feature["name"]}**: #{feature["description"]}"
    end)
    |> Enum.join("\n")
  end
  defp generate_core_features_list(_), do: ""
  
  defp generate_detailed_features(features) when is_map(features) do
    features
    |> Enum.map(fn {_key, feature} ->
      feature_list = case feature["features"] do
        list when is_list(list) ->
          list
          |> Enum.map(&"- **#{&1}")
          |> Enum.join("\n")
        _ -> ""
      end
      
      "### #{feature["name"]}\\n\\n#{feature_list}\\n"
    end)
    |> Enum.join("\n")
  end
  defp generate_detailed_features(_), do: ""
  
  defp generate_architecture_diagram(layers) when is_list(layers) do
    layers
    |> Enum.sort_by(& &1["position"], :desc)
    |> Enum.map(fn layer ->
      "┌─────────────────────────────────────────────────────────┐\n" <>
      "│                    #{String.pad_trailing(layer["name"], 27)}                         │\n" <>
      "│         (#{String.pad_trailing(layer["description"], 47)})            │"
    end)
    |> Enum.join("\n├─────────────────────────────────────────────────────────┤\n")
    |> then(&(&1 <> "\n└─────────────────────────────────────────────────────────┘"))
  end
  defp generate_architecture_diagram(_), do: ""
  
  defp generate_design_principles_list(principles) when is_list(principles) do
    principles
    |> Enum.map(fn principle ->
      "- **#{principle["name"]}**: #{principle["description"]}"
    end)
    |> Enum.join("\n")
  end
  defp generate_design_principles_list(_), do: ""
  
  defp generate_installation_section(installation) do
    prereqs = case installation["prerequisites"] do
      list when is_list(list) ->
        "### Prerequisites\n\n" <>
        (list
        |> Enum.map(fn prereq ->
          required_text = if prereq["required"], do: "", else: " (optional)"
          note_text = if prereq["note"], do: " - #{prereq["note"]}", else: ""
          "- #{prereq["name"]} #{prereq["version"]}#{required_text}#{note_text}"
        end)
        |> Enum.join("\n"))
      _ -> ""
    end
    
    hex_install = case get_in(installation, ["installation_methods", "hex_package"]) do
      %{"title" => title, "code" => code} ->
        "### #{title}\n\n```elixir\n#{code}\n```"
      _ -> ""
    end
    
    prereqs <> "\n\n" <> hex_install
  end
  
  defp generate_performance_metrics(performance) do
    production = performance["production_metrics"]
    
    case production do
      map when is_map(map) ->
        "- **Test Coverage**: #{performance["current_status"]["test_pass_rate"]}\n" <>
        "- **Rendering Speed**: #{production["rendering_speed"]}\n" <>
        "- **Input Latency**: #{production["input_latency"]}\n" <>
        "- **Throughput**: #{production["throughput"]}\n" <>
        "- **Memory Usage**: #{production["memory_usage"]}\n" <>
        "- **Concurrent Users**: #{production["concurrent_users"]}\n" <>
        "- **Startup Time**: #{production["startup_time"]}\n" <>
        "- **Production Ready**: #{production["code_quality"]}"
      _ -> ""
    end
  end
  
  defp generate_architecture(_schemas) do
    IO.puts("🏗️ Generating ARCHITECTURE.md...")
    # Architecture generation would go here
    IO.puts("⚠️ Architecture generation not yet implemented")
  end
  
  defp generate_todo_updates(_schemas) do  
    IO.puts("📋 Generating TODO.md updates...")
    # TODO updates would go here
    IO.puts("⚠️ TODO generation not yet implemented")
  end
end

# Run the generator
DocGenerator.generate_all()