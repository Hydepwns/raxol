defmodule Raxol.Terminal.Config.Capabilities do
  @moduledoc """
  Terminal capability detection and management.

  Provides functionality to detect and determine terminal capabilities
  such as color support, unicode support, etc.
  """

  alias Raxol.Terminal.Config.Defaults
  alias Raxol.System.EnvironmentAdapterImpl

  @doc """
  Detects terminal capabilities based on the environment using a specific adapter.

  This examines environment variables, terminal responses, and other indicators
  to determine capabilities of the current terminal.

  ## Parameters
  * `adapter_module` - The module implementing `EnvironmentAdapterBehaviour`.

  ## Returns

  A map of detected capabilities.
  """
  def detect_capabilities(adapter_module) do
    %{
      display: detect_display_capabilities(adapter_module),
      input: detect_input_capabilities(adapter_module),
      ansi: detect_ansi_capabilities(adapter_module)
    }
  end

  @doc """
  Merges detected capabilities with configuration using a specific adapter.

  Takes a terminal configuration and enhances it with detected capabilities
  where those capabilities aren't already explicitly configured.

  ## Parameters
  * `config` - The existing configuration
  * `adapter_module` - The module implementing `EnvironmentAdapterBehaviour`.

  ## Returns

  The configuration enhanced with detected capabilities.
  """
  def apply_capabilities(config, adapter_module) do
    capabilities = detect_capabilities(adapter_module)

    # Merge capabilities into config, only overriding if not explicitly set
    deep_merge_capabilities(config, capabilities)
  end

  @doc """
  Creates an optimized configuration based on detected capabilities using the default adapter.

  This generates a configuration that's optimized for the current terminal
  environment, balancing features and performance.

  ## Returns

  An optimized configuration for the current terminal.
  """
  def optimized_config do
    optimized_config(EnvironmentAdapterImpl)
  end

  @doc """
  Creates an optimized configuration based on detected capabilities using a specific adapter.

  ## Parameters
  * `adapter_module` - The module implementing `EnvironmentAdapterBehaviour`.

  ## Returns

  An optimized configuration for the current terminal.
  """
  def optimized_config(adapter_module) do
    # Start with defaults
    defaults = Defaults.generate_default_config()

    # Enhance with detected capabilities
    capabilities = detect_capabilities(adapter_module)
    config = deep_merge_capabilities(defaults, capabilities)

    # Apply optimizations based on capabilities
    optimize_config_for_capabilities(config)
  end

  # Private functions

  defp detect_display_capabilities(adapter_module) do
    %{
      width: detect_width(adapter_module),
      height: detect_height(adapter_module),
      colors: detect_color_support(adapter_module),
      truecolor: detect_truecolor_support(adapter_module),
      unicode: detect_unicode_support(adapter_module)
    }
  end

  defp detect_input_capabilities(adapter_module) do
    %{
      mouse: detect_mouse_support(adapter_module),
      # All terminals support basic keyboard
      keyboard: true,
      clipboard: detect_clipboard_support(adapter_module)
    }
  end

  defp detect_ansi_capabilities(adapter_module) do
    %{
      enabled: detect_ansi_support(adapter_module),
      color_mode: detect_color_mode(adapter_module)
    }
  end

  defp detect_width(adapter_module) do
    case adapter_module.get_env("COLUMNS") do
      nil ->
        # Try to get from tput if available
        case adapter_module.cmd("tput", ["cols"], stderr_to_stdout: true) do
          {cols, 0} -> String.to_integer(String.trim(cols))
          # Default fallback
          _ -> 80
        end

      cols ->
        String.to_integer(cols)
    end
  rescue
    # Default fallback on any error
    _ -> 80
  end

  defp detect_height(adapter_module) do
    case adapter_module.get_env("LINES") do
      nil ->
        # Try to get from tput if available
        case adapter_module.cmd("tput", ["lines"], stderr_to_stdout: true) do
          {lines, 0} -> String.to_integer(String.trim(lines))
          # Default fallback
          _ -> 24
        end

      lines ->
        String.to_integer(lines)
    end
  rescue
    # Default fallback on any error
    _ -> 24
  end

  defp detect_color_support(adapter_module) do
    # Check environment variables first
    case adapter_module.get_env("COLORTERM") do
      # 24-bit color
      "truecolor" ->
        16_777_216

      # 24-bit color
      "24bit" ->
        16_777_216

      _ ->
        # Get the TERM environment variable
        term = adapter_module.get_env("TERM")

        cond do
          term == "xterm-256color" ->
            256

          is_binary(term) && String.contains?(term, "256") ->
            256

          is_binary(term) && String.contains?(term, "color") ->
            16

          true ->
            # Try to get from tput if available
            case adapter_module.cmd("tput", ["colors"], stderr_to_stdout: true) do
              {colors, 0} ->
                case String.trim(colors) do
                  "-1" -> 0
                  num -> String.to_integer(num)
                end

              # Default fallback
              _ ->
                8
            end
        end
    end
  rescue
    # Default fallback on any error
    _ -> 8
  end

  defp detect_truecolor_support(adapter_module) do
    case adapter_module.get_env("COLORTERM") do
      "truecolor" -> true
      "24bit" -> true
      _ -> false
    end
  end

  defp detect_unicode_support(adapter_module) do
    # Get the LANG environment variable
    lang = adapter_module.get_env("LANG")

    cond do
      is_binary(lang) && String.contains?(lang, "UTF-8") -> true
      is_binary(lang) && String.contains?(lang, "utf8") -> true
      true -> false
    end
  end

  defp detect_mouse_support(adapter_module) do
    # Simple heuristic - most modern terminal emulators support mouse
    # Get the TERM environment variable
    term = adapter_module.get_env("TERM")

    cond do
      is_binary(term) && String.contains?(term, "xterm") -> true
      is_binary(term) && String.contains?(term, "screen") -> true
      is_binary(term) && String.contains?(term, "tmux") -> true
      true -> false
    end
  end

  defp detect_clipboard_support(adapter_module) do
    # Check if in GUI environment
    case adapter_module.get_env("DISPLAY") do
      nil -> false
      _ -> true
    end
  end

  defp detect_ansi_support(adapter_module) do
    case adapter_module.get_env("TERM") do
      "dumb" -> false
      nil -> false
      _ -> true
    end
  end

  defp detect_color_mode(adapter_module) do
    colors = detect_color_support(adapter_module)

    cond do
      colors >= 16_777_216 -> :truecolor
      colors >= 256 -> :extended
      colors >= 16 -> :basic
      colors >= 8 -> :basic
      true -> :none
    end
  end

  # Recursively merge capabilities into configuration
  defp deep_merge_capabilities(config, capabilities)
       when is_map(config) and is_map(capabilities) do
    Map.merge(config, capabilities, fn
      # If both values are maps, merge them recursively
      _, config_value, capability_value
      when is_map(config_value) and is_map(capability_value) ->
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

    updated_rendering =
      case Map.get(config, :display, %{}) do
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
