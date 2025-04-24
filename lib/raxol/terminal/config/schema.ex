defmodule Raxol.Terminal.Config.Schema do
  @moduledoc """
  Schema definitions for terminal configuration.

  Defines the structure and types for all terminal configuration options.
  """

  @doc """
  Defines the schema for terminal configuration.

  This includes all possible configuration fields with their types,
  default values, and descriptions.
  """
  def config_schema do
    %{
      # Display configuration
      display: %{
        width: {:integer, "Terminal width in columns"},
        height: {:integer, "Terminal height in rows"},
        colors: {:integer, "Number of supported colors (0, 8, 16, 256, or 16777216)"},
        truecolor: {:boolean, "Whether the terminal supports true color (24-bit)"},
        unicode: {:boolean, "Whether the terminal supports unicode characters"},
        # ... other display fields ...
      },

      # Input configuration
      input: %{
        mouse: {:boolean, "Whether mouse support is enabled"},
        keyboard: {:boolean, "Whether keyboard support is enabled"},
        escape_timeout: {:integer, "Timeout for escape sequences in milliseconds"},
        # ... other input fields ...
      },

      # Rendering configuration
      rendering: %{
        fps: {:integer, "Target frames per second for rendering"},
        double_buffer: {:boolean, "Whether double buffering is enabled"},
        redraw_mode: {:enum, [:full, :incremental], "How screen updates are handled"},
        # ... other rendering fields ...
      },

      # ANSI configuration
      ansi: %{
        enabled: {:boolean, "Whether ANSI escape sequences are enabled"},
        color_mode: {:enum, [:none, :basic, :extended, :truecolor], "ANSI color mode"},
        # ... other ANSI fields ...
      },

      # ... other top-level configuration sections ...
    }
  end

  @doc """
  Returns the default configuration values.
  This delegates to the Defaults module for actual values.
  """
  def default_config do
    Raxol.Terminal.Config.Defaults.generate_default_config()
  end

  @doc """
  Returns the type information for a specific configuration path.

  ## Parameters

  * `path` - A list of keys representing the path to the configuration value

  ## Returns

  A tuple with type information or nil if the path doesn't exist
  """
  def get_type(path) do
    # Implementation to retrieve type info from the schema
    schema = config_schema()
    get_type_from_path(schema, path)
  end

  # Private function to retrieve type from nested schema
  defp get_type_from_path(_schema, []), do: nil
  defp get_type_from_path(schema, [key | rest]) when is_map(schema) do
    case Map.get(schema, key) do
      nil -> nil
      value when is_map(value) -> get_type_from_path(value, rest)
      value -> if rest == [], do: value, else: nil
    end
  end
  defp get_type_from_path(_schema, _path), do: nil
end
