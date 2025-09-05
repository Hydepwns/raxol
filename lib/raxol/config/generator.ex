defmodule Raxol.Config.Generator do
  @moduledoc """
  Generates configuration files and templates.

  Provides utilities for creating default configurations, generating
  configuration templates, and creating environment-specific configs.
  """

  alias Raxol.Config.Schema

  @doc """
  Generates a default configuration file.
  """
  def generate_default_config(path, opts \\ []) do
    format = Keyword.get(opts, :format, detect_format_from_path(path))
    include_comments = Keyword.get(opts, :comments, true)
    include_examples = Keyword.get(opts, :examples, false)

    config = build_default_config(include_comments, include_examples)

    case write_config_file(config, path, format, opts) do
      :ok ->
        {:ok, path}

      {:error, reason} ->
        {:error, {:generation_failed, reason}}
    end
  end

  @doc """
  Generates environment-specific configuration.
  """
  def generate_env_config(env, path, opts \\ []) do
    config =
      case env do
        :development -> development_config()
        :production -> production_config()
        :test -> test_config()
        _ -> %{}
      end

    merged_config = Map.merge(base_config(), config)

    write_config_file(merged_config, path, detect_format_from_path(path), opts)
  end

  @doc """
  Generates a configuration template with all possible options.
  """
  def generate_template(path, opts \\ []) do
    template = build_template_from_schema(Schema.schema())

    write_config_file(template, path, detect_format_from_path(path), opts)
  end

  @doc """
  Generates documentation for configuration options.
  """
  def generate_config_docs(output_path \\ "docs/configuration.md") do
    docs = Schema.generate_docs()

    full_content = """
    # Raxol Configuration Reference

    This document describes all available configuration options for Raxol.

    ## Configuration Sources

    Raxol loads configuration from multiple sources in the following order of precedence:

    1. Runtime configuration (highest priority)
    2. Environment variables with `RAXOL_` prefix
    3. Configuration files:
       - `config/raxol.toml`
       - `config/raxol.json`
       - `~/.raxol/config.toml`
       - `~/.raxol/config.json`
       - `/etc/raxol/config.toml`
    4. Application environment
    5. Default values (lowest priority)

    ## Environment Variables

    Configuration can also be set via environment variables using the `RAXOL_` prefix.
    Nested configuration is specified using double underscores (`__`).

    Examples:
    ```bash
    export RAXOL_TERMINAL__WIDTH=120
    export RAXOL_TERMINAL__HEIGHT=40
    export RAXOL_THEME__NAME=dark
    ```

    ## Configuration Options

    #{docs}

    ## Example Configuration Files

    ### TOML Format (config/raxol.toml)

    ```toml
    #{generate_example_toml()}
    ```

    ### JSON Format (config/raxol.json)

    ```json
    #{generate_example_json()}
    ```
    """

    File.mkdir_p!(Path.dirname(output_path))
    File.write!(output_path, full_content)

    {:ok, output_path}
  end

  @doc """
  Validates configuration template against schema.
  """
  def validate_template(template_path) do
    with {:ok, config} <- Raxol.Config.Loader.load_file(template_path),
         {:ok, :valid} <- Schema.validate_config(config) do
      {:ok, :valid}
    else
      {:error, reason} ->
        {:error, {:validation_failed, reason}}
    end
  end

  @doc """
  Creates a minimal configuration for quick setup.
  """
  def generate_minimal_config(path) do
    minimal = %{
      terminal: %{
        width: 80,
        height: 24
      },
      theme: %{
        name: "default"
      },
      logging: %{
        level: :info,
        file: "logs/raxol.log"
      }
    }

    write_config_file(minimal, path, detect_format_from_path(path), [])
  end

  # Private functions - Pattern Matching Helpers

  defp maybe_add_metadata(true, config, schema, include_comments, include_examples) do
    add_metadata_to_config(config, schema, include_comments, include_examples)
  end

  defp maybe_add_metadata(false, config, _schema, _include_comments, _include_examples), do: config

  defp handle_schema_value(true, key, value, acc) do
    Map.put(acc, key, value.default)
  end

  defp handle_schema_value(false, key, value, acc) do
    nested_defaults = extract_defaults_from_schema(value)
    handle_nested_defaults(map_size(nested_defaults) > 0, key, nested_defaults, acc)
  end

  defp handle_nested_defaults(true, key, nested_defaults, acc) do
    Map.put(acc, key, nested_defaults)
  end

  defp handle_nested_defaults(false, _key, _nested_defaults, acc), do: acc

  defp handle_template_value(true, key, value, acc) do
    # This is a field
    template_value = generate_template_value(value)
    Map.put(acc, key, template_value)
  end

  defp handle_template_value(false, key, value, acc) do
    # This is a nested section
    nested_template = extract_template_from_schema(value)
    Map.put(acc, key, nested_template)
  end

  # Private functions

  defp build_default_config(include_comments, include_examples) do
    schema = Schema.schema()

    config = extract_defaults_from_schema(schema)

    maybe_add_metadata(include_comments or include_examples, config, schema, include_comments, include_examples)
  end

  defp extract_defaults_from_schema(schema) when is_map(schema) do
    Enum.reduce(schema, %{}, fn {key, value}, acc ->
      handle_schema_value(Map.has_key?(value, :default), key, value, acc)
    end)
  end

  defp add_metadata_to_config(
         config,
         _schema,
         _include_comments,
         _include_examples
       ) do
    # This would add comments and examples to the configuration
    # For now, return the config as-is
    config
  end

  defp base_config do
    %{
      terminal: %{
        width: 80,
        height: 24,
        scrollback_size: 10_000,
        encoding: "UTF-8"
      },
      buffer: %{
        max_size: 1_048_576,
        chunk_size: 4096
      },
      rendering: %{
        fps_target: 60,
        enable_animations: true
      },
      theme: %{
        name: "default"
      }
    }
  end

  def development_config do
    %{
      logging: %{
        level: :debug,
        file: "logs/dev.log"
      },
      plugins: %{
        auto_reload: true
      },
      performance: %{
        profiling_enabled: true
      },
      rendering: %{
        performance_mode: false
      }
    }
  end

  def production_config do
    %{
      logging: %{
        level: :info,
        file: "logs/prod.log",
        # 50MB
        max_file_size: 52_428_800,
        rotation_count: 10
      },
      performance: %{
        cache_size: 1_000_000,
        profiling_enabled: false
      },
      rendering: %{
        performance_mode: true,
        max_frame_skip: 5
      },
      security: %{
        # 1 hour
        session_timeout: 3600,
        enable_audit: true
      }
    }
  end

  defp test_config do
    %{
      logging: %{
        level: :warning,
        file: "logs/test.log"
      },
      buffer: %{
        # Smaller for tests
        max_size: 65_536
      },
      rendering: %{
        enable_animations: false
      },
      performance: %{
        cache_size: 1000
      }
    }
  end

  defp build_template_from_schema(schema) do
    # Build a comprehensive template showing all options
    extract_template_from_schema(schema)
  end

  defp extract_template_from_schema(schema) when is_map(schema) do
    Enum.reduce(schema, %{}, fn {key, value}, acc ->
      handle_template_value(Map.has_key?(value, :type), key, value, acc)
    end)
  end

  defp generate_template_value(field_schema) do
    case field_schema.type do
      :string -> field_schema.default || "example_string"
      :integer -> field_schema.default || 42
      :float -> field_schema.default || 3.14
      :boolean -> field_schema.default || true
      :atom -> field_schema.default || :example
      {:enum, values} -> field_schema.default || hd(values)
      {:list, _} -> field_schema.default || []
      {:map, _} -> field_schema.default || %{}
      _ -> field_schema.default
    end
  end

  defp write_config_file(config, path, format, opts) do
    ensure_directory(path)

    case format do
      :toml -> write_toml_file(config, path, opts)
      :json -> write_json_file(config, path, opts)
      :yaml -> write_yaml_file(config, path, opts)
      _ -> {:error, {:unsupported_format, format}}
    end
  end

  defp write_toml_file(config, path, _opts) do
    # Simplified TOML generation
    content = generate_toml_content(config, 0)
    File.write(path, content)
  end

  defp write_json_file(config, path, opts) do
    pretty = Keyword.get(opts, :pretty, true)

    case Jason.encode(stringify_keys(config), pretty: pretty) do
      {:ok, content} -> File.write(path, content)
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_yaml_file(config, path, _opts) do
    # Would need a YAML encoder
    content =
      "# YAML format not yet implemented\n" <> inspect(config, pretty: true)

    File.write(path, content)
  end

  defp generate_toml_content(config, indent_level) do
    indent = String.duplicate("  ", indent_level)

    config
    |> Enum.map(fn {key, value} ->
      case value do
        v when is_map(v) ->
          "#{indent}[#{key}]\n" <> generate_toml_content(v, indent_level + 1)

        v when is_binary(v) ->
          "#{indent}#{key} = \"#{v}\""

        v when is_atom(v) ->
          "#{indent}#{key} = \"#{v}\""

        v when is_boolean(v) ->
          "#{indent}#{key} = #{v}"

        v when is_number(v) ->
          "#{indent}#{key} = #{v}"

        v when is_list(v) ->
          list_str = v |> Enum.map(&inspect/1) |> Enum.join(", ")
          "#{indent}#{key} = [#{list_str}]"

        v ->
          "#{indent}#{key} = #{inspect(v)}"
      end
    end)
    |> Enum.join("\n")
  end

  defp generate_example_toml do
    example_config = %{
      terminal: %{
        width: 120,
        height: 40,
        scrollback_size: 50_000
      },
      theme: %{
        name: "dark",
        auto_switch: true
      },
      logging: %{
        level: "info",
        file: "logs/raxol.log"
      }
    }

    generate_toml_content(example_config, 0)
  end

  defp generate_example_json do
    example_config = %{
      "terminal" => %{
        "width" => 120,
        "height" => 40,
        "scrollback_size" => 50_000
      },
      "theme" => %{
        "name" => "dark",
        "auto_switch" => true
      },
      "logging" => %{
        "level" => "info",
        "file" => "logs/raxol.log"
      }
    }

    case Jason.encode(example_config, pretty: true) do
      {:ok, json} -> json
      _ -> "{}"
    end
  end

  defp detect_format_from_path(path) do
    case String.downcase(Path.extname(path)) do
      ".toml" -> :toml
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      # Default to TOML
      _ -> :toml
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      string_key = to_string(key)

      stringified_value =
        case value do
          v when is_map(v) -> stringify_keys(v)
          v when is_list(v) -> Enum.map(v, &stringify_keys/1)
          v -> v
        end

      Map.put(acc, string_key, stringified_value)
    end)
  end

  defp stringify_keys(value), do: value

  defp ensure_directory(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()
  end
end
