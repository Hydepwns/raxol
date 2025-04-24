defmodule Raxol.Terminal.Config.Capabilities do
  @moduledoc """
  Terminal capability detection and management.

  Provides functionality to detect and determine terminal capabilities
  such as color support, unicode support, etc.
  """

  alias Raxol.Terminal.Config.Defaults

  @doc """
  Detects terminal capabilities based on the environment.

  This examines environment variables, terminal responses, and other indicators
  to determine capabilities of the current terminal.

  ## Returns

  A map of detected capabilities.
  """
  def detect_capabilities do
    %{
      display: detect_display_capabilities(),
      input: detect_input_capabilities(),
      ansi: detect_ansi_capabilities()
    }
  end

  @doc """
  Merges detected capabilities with configuration.

  Takes a terminal configuration and enhances it with detected capabilities
  where those capabilities aren't already explicitly configured.

  ## Parameters

  * `config` - The existing configuration

  ## Returns

  The configuration enhanced with detected capabilities.
  """
  def apply_capabilities(config) do
    capabilities = detect_capabilities()

    # Merge capabilities into config, only overriding if not explicitly set
    deep_merge_capabilities(config, capabilities)
  end

  @doc """
  Creates an optimized configuration based on detected capabilities.

  This generates a configuration that's optimized for the current terminal
  environment, balancing features and performance.

  ## Returns

  An optimized configuration for the current terminal.
  """
  def optimized_config do
    # Start with defaults
    defaults = Defaults.generate_default_config()

    # Enhance with detected capabilities
    capabilities = detect_capabilities()
    config = deep_merge_capabilities(defaults, capabilities)

    # Apply optimizations based on capabilities
    optimize_config_for_capabilities(config)
  end

  # Private functions

  defp detect_display_capabilities do
    %{
      width: detect_width(),
      height: detect_height(),
      colors: detect_color_support(),
      truecolor: detect_truecolor_support(),
      unicode: detect_unicode_support()
    }
  end

  defp detect_input_capabilities do
    %{
      mouse: detect_mouse_support(),
      keyboard: true, # All terminals support basic keyboard
      clipboard: detect_clipboard_support()
    }
  end

  defp detect_ansi_capabilities do
    %{
      enabled: detect_ansi_support(),
      color_mode: detect_color_mode()
    }
  end

  defp detect_width do
    case System.get_env("COLUMNS") do
      nil ->
        # Try to get from tput if available
        case System.cmd("tput", ["cols"], stderr_to_stdout: true) do
          {cols, 0} -> String.to_integer(String.trim(cols))
          _ -> 80 # Default fallback
        end
      cols -> String.to_integer(cols)
    end
  rescue
    _ -> 80 # Default fallback on any error
  end

  defp detect_height do
    case System.get_env("LINES") do
      nil ->
        # Try to get from tput if available
        case System.cmd("tput", ["lines"], stderr_to_stdout: true) do
          {lines, 0} -> String.to_integer(String.trim(lines))
          _ -> 24 # Default fallback
        end
      lines -> String.to_integer(lines)
    end
  rescue
    _ -> 24 # Default fallback on any error
  end

  defp detect_color_support do
    # Check environment variables first
    case System.get_env("COLORTERM") do
      "truecolor" -> 16_777_216 # 24-bit color
      "24bit" -> 16_777_216     # 24-bit color
      _ ->
        # Get the TERM environment variable
        term = System.get_env("TERM")

        cond do
          term == "xterm-256color" -> 256
          is_binary(term) && String.contains?(term, "256") -> 256
          is_binary(term) && String.contains?(term, "color") -> 16
          true ->
            # Try to get from tput if available
            case System.cmd("tput", ["colors"], stderr_to_stdout: true) do
              {colors, 0} ->
                case String.trim(colors) do
                  "-1" -> 0
                  num -> String.to_integer(num)
                end
              _ -> 8 # Default fallback
            end
        end
    end
  rescue
    _ -> 8 # Default fallback on any error
  end

  defp detect_truecolor_support do
    case System.get_env("COLORTERM") do
      "truecolor" -> true
      "24bit" -> true
      _ -> false
    end
  end

  defp detect_unicode_support do
    # Get the LANG environment variable
    lang = System.get_env("LANG")

    cond do
      is_binary(lang) && String.contains?(lang, "UTF-8") -> true
      is_binary(lang) && String.contains?(lang, "utf8") -> true
      true -> false
    end
  end

  defp detect_mouse_support do
    # Simple heuristic - most modern terminal emulators support mouse
    # Get the TERM environment variable
    term = System.get_env("TERM")

    cond do
      is_binary(term) && String.contains?(term, "xterm") -> true
      is_binary(term) && String.contains?(term, "screen") -> true
      is_binary(term) && String.contains?(term, "tmux") -> true
      true -> false
    end
  end

  defp detect_clipboard_support do
    # Check if in GUI environment
    case System.get_env("DISPLAY") do
      nil -> false
      _ -> true
    end
  end

  defp detect_ansi_support do
    case System.get_env("TERM") do
      "dumb" -> false
      nil -> false
      _ -> true
    end
  end

  defp detect_color_mode do
    colors = detect_color_support()
    cond do
      colors >= 16_777_216 -> :truecolor
      colors >= 256 -> :extended
      colors >= 16 -> :basic
      colors >= 8 -> :basic
      true -> :none
    end
  end

  # Recursively merge capabilities into configuration
  defp deep_merge_capabilities(config, capabilities) when is_map(config) and is_map(capabilities) do
    Map.merge(config, capabilities, fn
      # If both values are maps, merge them recursively
      _, config_value, capability_value when is_map(config_value) and is_map(capability_value) ->
        deep_merge_capabilities(config_value, capability_value)

      # For any other case, keep the config value (don't override explicit configuration)
      _, config_value, _capability_value ->
        config_value
    end)
  end

  defp deep_merge_capabilities(config, _), do: config

  # Apply optimizations based on detected capabilities
  defp optimize_config_for_capabilities(config) do
    # Adjust rendering settings based on capabilities
    rendering = Map.get(config, :rendering, %{})
    updated_rendering = case Map.get(config, :display, %{}) do
      %{colors: colors} when colors <= 16 ->
        # For terminals with limited colors, reduce other graphics settings
        rendering
        |> Map.put(:fps, 30)
        |> Map.put(:optimize_empty_cells, true)
        |> Map.put(:smooth_resize, false)

      %{width: width, height: height} when width < 80 or height < 24 ->
        # For small terminals, reduce rendering overhead
        rendering
        |> Map.put(:fps, 30)
        |> Map.put(:optimize_empty_cells, true)

      _ ->
        # Keep existing settings for capable terminals
        rendering
    end

    %{config | rendering: updated_rendering}
  end
end
