defmodule Raxol.Config.Schema do
  @moduledoc """
  Configuration schema definitions and validation.

  Defines the structure, types, and constraints for all configuration options
  in Raxol, providing compile-time and runtime validation.
  """

  @type schema_type ::
          :string
          | :integer
          | :float
          | :boolean
          | :atom
          | {:list, schema_type()}
          | {:map, schema_type()}
          | {:enum, [term()]}
          | {:struct, module()}
          | {:one_of, [schema_type()]}

  @type constraint ::
          {:min, number()}
          | {:max, number()}
          | {:min_length, non_neg_integer()}
          | {:max_length, non_neg_integer()}
          | {:format, Regex.t()}
          | {:custom, fun()}

  @type field_schema :: %{
          type: schema_type(),
          required: boolean(),
          default: term(),
          constraints: [constraint()],
          description: String.t(),
          deprecated: boolean()
        }

  @doc """
  Returns the complete configuration schema.
  """
  def schema do
    %{
      terminal: terminal_schema(),
      buffer: buffer_schema(),
      rendering: rendering_schema(),
      plugins: plugins_schema(),
      security: security_schema(),
      performance: performance_schema(),
      theme: theme_schema(),
      logging: logging_schema(),
      accessibility: accessibility_schema(),
      keybindings: keybindings_schema()
    }
  end

  @doc """
  Validates a configuration value against a schema.
  """
  def validate(value, schema) do
    do_validate(value, schema, [])
  end

  @doc """
  Validates an entire configuration map.
  """
  def validate_config(config, schema \\ schema()) do
    errors = validate_map(config, schema, [])

    if Enum.empty?(errors) do
      {:ok, :valid}
    else
      {:error, errors}
    end
  end

  @doc """
  Gets the schema for a specific configuration path.
  """
  def get_schema(path) when is_list(path) do
    get_nested_schema(schema(), path)
  end

  @doc """
  Generates documentation for configuration options.
  """
  def generate_docs do
    schema()
    |> generate_docs_for_schema([])
    |> Enum.join("\n\n")
  end

  # Schema definitions

  defp terminal_schema do
    %{
      width: %{
        type: :integer,
        required: false,
        default: 80,
        constraints: [{:min, 10}, {:max, 500}],
        description: "Terminal width in columns"
      },
      height: %{
        type: :integer,
        required: false,
        default: 24,
        constraints: [{:min, 5}, {:max, 200}],
        description: "Terminal height in rows"
      },
      scrollback_size: %{
        type: :integer,
        required: false,
        default: 10_000,
        constraints: [{:min, 0}, {:max, 1_000_000}],
        description: "Number of lines to keep in scrollback buffer"
      },
      encoding: %{
        type: {:enum, ["UTF-8", "ASCII", "ISO-8859-1"]},
        required: false,
        default: "UTF-8",
        description: "Character encoding for terminal"
      },
      cursor: cursor_schema(),
      colors: colors_schema(),
      bell: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable terminal bell"
      },
      font: font_schema()
    }
  end

  defp cursor_schema do
    %{
      style: %{
        type: {:enum, [:block, :underline, :bar]},
        required: false,
        default: :block,
        description: "Cursor display style"
      },
      blink: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable cursor blinking"
      },
      blink_rate: %{
        type: :integer,
        required: false,
        default: 500,
        constraints: [{:min, 100}, {:max, 2000}],
        description: "Cursor blink rate in milliseconds"
      }
    }
  end

  defp colors_schema do
    %{
      palette: %{
        type: {:enum, [:default, :solarized, :dracula, :nord, :custom]},
        required: false,
        default: :default,
        description: "Color palette to use"
      },
      true_color: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable 24-bit true color support"
      },
      custom_colors: %{
        type: {:map, :string},
        required: false,
        default: %{},
        description: "Custom color definitions"
      }
    }
  end

  defp font_schema do
    %{
      family: %{
        type: :string,
        required: false,
        default: "monospace",
        description: "Font family name"
      },
      size: %{
        type: :integer,
        required: false,
        default: 12,
        constraints: [{:min, 6}, {:max, 72}],
        description: "Font size in points"
      },
      bold: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Use bold font weight"
      }
    }
  end

  defp buffer_schema do
    %{
      max_size: %{
        type: :integer,
        required: false,
        default: 1_048_576,
        constraints: [{:min, 1024}, {:max, 104_857_600}],
        description: "Maximum buffer size in bytes"
      },
      chunk_size: %{
        type: :integer,
        required: false,
        default: 4096,
        constraints: [{:min, 512}, {:max, 65_536}],
        description: "Buffer chunk size for operations"
      },
      compression: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable buffer compression"
      },
      compression_threshold: %{
        type: :integer,
        required: false,
        default: 10_240,
        constraints: [{:min, 1024}],
        description: "Minimum size before compression is applied"
      }
    }
  end

  defp rendering_schema do
    %{
      fps_target: %{
        type: :integer,
        required: false,
        default: 60,
        constraints: [{:min, 1}, {:max, 144}],
        description: "Target frames per second"
      },
      max_frame_skip: %{
        type: :integer,
        required: false,
        default: 3,
        constraints: [{:min, 0}, {:max, 10}],
        description: "Maximum consecutive frames to skip"
      },
      enable_animations: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable UI animations"
      },
      animation_duration: %{
        type: :integer,
        required: false,
        default: 200,
        constraints: [{:min, 0}, {:max, 1000}],
        description: "Default animation duration in milliseconds"
      },
      performance_mode: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable performance mode (reduces quality for speed)"
      },
      gpu_acceleration: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable GPU acceleration when available"
      }
    }
  end

  defp plugins_schema do
    %{
      enabled: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable plugin system"
      },
      directory: %{
        type: :string,
        required: false,
        default: "plugins",
        constraints: [{:min_length, 1}],
        description: "Directory containing plugins"
      },
      auto_reload: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Automatically reload plugins on file changes"
      },
      allowed: %{
        type: {:list, :string},
        required: false,
        default: [],
        description: "List of allowed plugin names (empty allows all)"
      },
      disabled: %{
        type: {:list, :string},
        required: false,
        default: [],
        description: "List of disabled plugin names"
      },
      load_timeout: %{
        type: :integer,
        required: false,
        default: 5000,
        constraints: [{:min, 100}, {:max, 30_000}],
        description: "Plugin load timeout in milliseconds"
      }
    }
  end

  defp security_schema do
    %{
      session_timeout: %{
        type: :integer,
        required: false,
        default: 1800,
        constraints: [{:min, 60}, {:max, 86_400}],
        description: "Session timeout in seconds"
      },
      max_sessions: %{
        type: :integer,
        required: false,
        default: 5,
        constraints: [{:min, 1}, {:max, 100}],
        description: "Maximum concurrent sessions per user"
      },
      enable_audit: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable security audit logging"
      },
      password_min_length: %{
        type: :integer,
        required: false,
        default: 8,
        constraints: [{:min, 6}, {:max, 128}],
        description: "Minimum password length"
      },
      password_require_special: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Require special characters in passwords"
      },
      password_require_numbers: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Require numbers in passwords"
      },
      enable_2fa: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable two-factor authentication"
      },
      rate_limiting: rate_limiting_schema()
    }
  end

  defp rate_limiting_schema do
    %{
      enabled: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable rate limiting"
      },
      window: %{
        type: :integer,
        required: false,
        default: 60_000,
        constraints: [{:min, 1000}],
        description: "Rate limit window in milliseconds"
      },
      max_requests: %{
        type: :integer,
        required: false,
        default: 100,
        constraints: [{:min, 1}],
        description: "Maximum requests per window"
      }
    }
  end

  defp performance_schema do
    %{
      profiling_enabled: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable performance profiling"
      },
      benchmark_on_start: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Run benchmarks on application start"
      },
      cache_size: %{
        type: :integer,
        required: false,
        default: 100_000,
        constraints: [{:min, 0}],
        description: "Maximum cache entries"
      },
      cache_ttl: %{
        type: :integer,
        required: false,
        default: 300_000,
        constraints: [{:min, 0}],
        description: "Cache time-to-live in milliseconds"
      },
      worker_pool_size: %{
        type: :integer,
        required: false,
        default: {:erlang, :system_info, [:schedulers_online]},
        constraints: [{:min, 1}, {:max, 128}],
        description: "Size of worker process pool"
      }
    }
  end

  defp theme_schema do
    %{
      name: %{
        type: :string,
        required: false,
        default: "default",
        description: "Active theme name"
      },
      auto_switch: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Automatically switch theme based on system"
      },
      custom_themes_dir: %{
        type: :string,
        required: false,
        default: "themes",
        description: "Directory containing custom themes"
      }
    }
  end

  defp logging_schema do
    %{
      level: %{
        type: {:enum, [:debug, :info, :warning, :error]},
        required: false,
        default: :info,
        description: "Logging level"
      },
      file: %{
        type: :string,
        required: false,
        default: "logs/raxol.log",
        description: "Log file path"
      },
      max_file_size: %{
        type: :integer,
        required: false,
        default: 10_485_760,
        constraints: [{:min, 1024}],
        description: "Maximum log file size in bytes"
      },
      rotation_count: %{
        type: :integer,
        required: false,
        default: 5,
        constraints: [{:min, 0}, {:max, 100}],
        description: "Number of rotated log files to keep"
      },
      format: %{
        type: {:enum, [:text, :json]},
        required: false,
        default: :text,
        description: "Log output format"
      },
      include_metadata: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Include metadata in log entries"
      }
    }
  end

  defp accessibility_schema do
    %{
      screen_reader: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable screen reader support"
      },
      high_contrast: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable high contrast mode"
      },
      focus_indicators: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Show focus indicators"
      },
      reduce_motion: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Reduce UI motion and animations"
      },
      font_scaling: %{
        type: :float,
        required: false,
        default: 1.0,
        constraints: [{:min, 0.5}, {:max, 3.0}],
        description: "Font scaling factor"
      }
    }
  end

  defp keybindings_schema do
    %{
      enabled: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable custom keybindings"
      },
      config_file: %{
        type: :string,
        required: false,
        default: "keybindings.toml",
        description: "Keybindings configuration file"
      },
      vim_mode: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable Vim keybindings"
      },
      emacs_mode: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable Emacs keybindings"
      }
    }
  end

  # Validation implementation

  defp do_validate(value, %{type: type} = schema, path) do
    with :ok <- validate_type(value, type, path),
         :ok <-
           validate_constraints(value, Map.get(schema, :constraints, []), path) do
      :ok
    end
  end

  defp validate_type(nil, _type, path) do
    {:error, {path, "value cannot be nil"}}
  end

  defp validate_type(value, :string, _path) when is_binary(value), do: :ok
  defp validate_type(value, :integer, _path) when is_integer(value), do: :ok
  defp validate_type(value, :float, _path) when is_float(value), do: :ok
  defp validate_type(value, :boolean, _path) when is_boolean(value), do: :ok
  defp validate_type(value, :atom, _path) when is_atom(value), do: :ok

  defp validate_type(value, {:enum, allowed}, path) do
    if value in allowed do
      :ok
    else
      {:error, {path, "must be one of: #{inspect(allowed)}"}}
    end
  end

  defp validate_type(value, {:list, item_type}, path) when is_list(value) do
    errors =
      value
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        validate_type(item, item_type, path ++ [index])
      end)
      |> Enum.filter(&(&1 != :ok))

    if Enum.empty?(errors), do: :ok, else: {:error, errors}
  end

  defp validate_type(value, {:map, value_type}, path) when is_map(value) do
    errors =
      value
      |> Enum.map(fn {key, val} ->
        validate_type(val, value_type, path ++ [key])
      end)
      |> Enum.filter(&(&1 != :ok))

    if Enum.empty?(errors), do: :ok, else: {:error, errors}
  end

  defp validate_type(_value, type, path) do
    {:error, {path, "expected type #{inspect(type)}"}}
  end

  defp validate_constraints(value, constraints, path) do
    errors =
      constraints
      |> Enum.map(fn constraint ->
        validate_constraint(value, constraint, path)
      end)
      |> Enum.filter(&(&1 != :ok))

    if Enum.empty?(errors), do: :ok, else: {:error, errors}
  end

  defp validate_constraint(value, {:min, min}, path) when is_number(value) do
    if value >= min, do: :ok, else: {:error, {path, "must be >= #{min}"}}
  end

  defp validate_constraint(value, {:max, max}, path) when is_number(value) do
    if value <= max, do: :ok, else: {:error, {path, "must be <= #{max}"}}
  end

  defp validate_constraint(value, {:min_length, min}, path)
       when is_binary(value) do
    if String.length(value) >= min,
      do: :ok,
      else: {:error, {path, "minimum length is #{min}"}}
  end

  defp validate_constraint(value, {:max_length, max}, path)
       when is_binary(value) do
    if String.length(value) <= max,
      do: :ok,
      else: {:error, {path, "maximum length is #{max}"}}
  end

  defp validate_constraint(value, {:format, regex}, path)
       when is_binary(value) do
    if Regex.match?(regex, value),
      do: :ok,
      else: {:error, {path, "invalid format"}}
  end

  defp validate_constraint(value, {:custom, validator}, path)
       when is_function(validator) do
    case validator.(value) do
      :ok -> :ok
      {:error, reason} -> {:error, {path, reason}}
      false -> {:error, {path, "custom validation failed"}}
      true -> :ok
    end
  end

  defp validate_constraint(_value, _constraint, _path), do: :ok

  defp validate_map(config, schema, path)
       when is_map(config) and is_map(schema) do
    # Check for unknown keys
    unknown_keys = Map.keys(config) -- Map.keys(schema)

    unknown_errors =
      Enum.map(unknown_keys, fn key ->
        {path ++ [key], "unknown configuration key"}
      end)

    # Validate each field
    field_errors =
      schema
      |> Enum.flat_map(fn {key, field_schema} ->
        value = Map.get(config, key)
        field_path = path ++ [key]

        validate_field(value, field_schema, field_path)
      end)

    unknown_errors ++ field_errors
  end

  defp validate_field(value, field_schema, field_path) do
    cond do
      is_nil(value) and Map.get(field_schema, :required, false) ->
        [{field_path, "required field is missing"}]

      is_nil(value) ->
        []

      is_map(field_schema) and not Map.has_key?(field_schema, :type) ->
        # Nested schema
        validate_map(value, field_schema, field_path)

      true ->
        # Regular field
        case do_validate(value, field_schema, field_path) do
          :ok -> []
          {:error, errors} when is_list(errors) -> errors
          {:error, error} -> [error]
        end
    end
  end

  defp get_nested_schema(schema, []), do: schema

  defp get_nested_schema(schema, [key | rest]) do
    case Map.get(schema, key) do
      nil -> nil
      nested -> get_nested_schema(nested, rest)
    end
  end

  defp generate_docs_for_schema(schema, path) when is_map(schema) do
    schema
    |> Enum.flat_map(fn {key, value} ->
      current_path = path ++ [key]

      if Map.has_key?(value, :type) do
        [generate_field_doc(current_path, value)]
      else
        generate_docs_for_schema(value, current_path)
      end
    end)
  end

  defp generate_field_doc(path, field_schema) do
    path_str = Enum.join(path, ".")
    type_str = format_type(field_schema.type)
    default_str = inspect(field_schema.default)

    """
    ### #{path_str}

    **Type:** `#{type_str}`  
    **Default:** `#{default_str}`  
    **Required:** #{field_schema.required}  

    #{field_schema.description}

    #{format_constraints(Map.get(field_schema, :constraints, []))}
    """
  end

  defp format_type(type) do
    case type do
      {:enum, values} -> "enum[#{Enum.join(values, ", ")}]"
      {:list, item_type} -> "list[#{format_type(item_type)}]"
      {:map, value_type} -> "map[#{format_type(value_type)}]"
      other -> to_string(other)
    end
  end

  defp format_constraints([]), do: ""

  defp format_constraints(constraints) do
    constraint_strs =
      Enum.map(constraints, fn
        {:min, value} -> "Minimum: #{value}"
        {:max, value} -> "Maximum: #{value}"
        {:min_length, value} -> "Minimum length: #{value}"
        {:max_length, value} -> "Maximum length: #{value}"
        {:format, _regex} -> "Must match format"
        {:custom, _} -> "Custom validation"
      end)

    "**Constraints:**\n" <> Enum.map_join(constraint_strs, "\n", &"- #{&1}")
  end
end
