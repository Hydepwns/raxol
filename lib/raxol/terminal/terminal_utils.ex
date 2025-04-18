defmodule Raxol.Terminal.TerminalUtils do
  @moduledoc """
  Utility functions for terminal operations, providing cross-platform and
  consistent handling of terminal capabilities and dimensions.
  """

  require Logger
  alias ExTermbox.Bindings

  @doc """
  Gets the terminal dimensions using the most reliable method available.

  This function tries multiple approaches to get accurate terminal dimensions:
  1. First tries using `:io` module's functions (Erlang's built-in terminal interface)
  2. Falls back to ExTermbox.Bindings if `:io` methods fail
  3. Uses OS-specific commands as a last resort
  4. Provides sensible defaults if all else fails

  Returns a tuple of {width, height}
  """
  @spec get_terminal_dimensions() :: {pos_integer(), pos_integer()}
  def get_terminal_dimensions do
    # Try primary method using Erlang's built-in :io module
    with {:error, _} <- try_io_dimensions(),
         {:error, _} <- try_termbox_dimensions(),
         {:error, _} <- try_system_command() do
      # Default fallback dimensions if all methods fail
      {80, 24}
    end
  end

  @doc """
  Gets terminal dimensions and returns them in a map format.
  """
  @spec get_dimensions_map() :: %{width: pos_integer(), height: pos_integer()}
  def get_dimensions_map do
    {width, height} = get_terminal_dimensions()
    %{width: width, height: height}
  end

  @doc """
  Creates a bounds map with dimensions, starting at origin (0,0)
  """
  @spec get_bounds_map() :: %{
          x: 0,
          y: 0,
          width: pos_integer(),
          height: pos_integer()
        }
  def get_bounds_map do
    {width, height} = get_terminal_dimensions()
    %{x: 0, y: 0, width: width, height: height}
  end

  # Private helper functions

  # Try using Erlang's built-in :io module
  defp try_io_dimensions do
    try do
      with {:ok, width} when is_integer(width) <- :io.columns(),
           {:ok, height} when is_integer(height) <- :io.rows() do
        Logger.debug(
          "Got terminal dimensions via :io module: #{width}x#{height}"
        )

        {width, height}
      else
        _ -> {:error, :io_method_failed}
      end
    rescue
      _ -> {:error, :io_method_error}
    end
  end

  # Try using ExTermbox.Bindings
  defp try_termbox_dimensions do
    try do
      width_result = Bindings.width()
      height_result = Bindings.height()

      case {width_result, height_result} do
        # Handle potential double nesting from Bindings
        {{:ok, {:ok, w}}, {:ok, {:ok, h}}} when is_integer(w) and is_integer(h) ->
          Logger.debug(
            "Got terminal dimensions via ExTermbox (double-nested): #{w}x#{h}"
          )

          {w, h}

        # Handle standard response format
        {{:ok, w}, {:ok, h}} when is_integer(w) and is_integer(h) ->
          Logger.debug("Got terminal dimensions via ExTermbox: #{w}x#{h}")
          {w, h}

        # If only width is available, try to estimate a reasonable height
        {{:ok, w}, _} when is_integer(w) ->
          # Estimate height based on typical terminal aspect ratios
          # Most terminals have aspect ratios where height is roughly 1/2 to 1/3 of width
          h = max(24, div(w * 2, 5))

          Logger.warning(
            "Using estimated height (#{h}) with actual width (#{w})"
          )

          {w, h}

        # Any other response format is considered an error
        _ ->
          {:error, :termbox_method_failed}
      end
    rescue
      e ->
        Logger.warning("Error getting dimensions via ExTermbox: #{inspect(e)}")
        {:error, :termbox_method_error}
    end
  end

  # Try using system commands as last resort
  defp try_system_command do
    # Different commands for different operating systems
    command =
      case :os.type() do
        {:unix, :darwin} -> "stty size"
        {:unix, _} -> "stty size"
        {:win32, _} -> "powershell \"$host.UI.RawUI.WindowSize\""
        _ -> nil
      end

    if command do
      try do
        case System.cmd("sh", ["-c", command], stderr_to_stdout: true) do
          {output, 0} ->
            parse_command_output(output, command)

          _ ->
            {:error, :command_failed}
        end
      rescue
        _ -> {:error, :command_error}
      end
    else
      {:error, :unsupported_os}
    end
  end

  # Parse system command output based on the command used
  defp parse_command_output(output, "stty size") do
    case String.split(String.trim(output), " ") do
      [height_str, width_str] ->
        try do
          height = String.to_integer(height_str)
          width = String.to_integer(width_str)
          Logger.debug("Got terminal dimensions via stty: #{width}x#{height}")
          {width, height}
        rescue
          _ -> {:error, :parse_error}
        end

      _ ->
        {:error, :invalid_output_format}
    end
  end

  defp parse_command_output(output, cmd) when is_binary(cmd) do
    if String.contains?(cmd, "powershell") do
      # Parse PowerShell output which typically looks like:
      # Width : 120
      # Height: 30
      width_pattern = ~r/Width\s*:?\s*(\d+)/i
      height_pattern = ~r/Height\s*:?\s*(\d+)/i

      with [_, width_str] <- Regex.run(width_pattern, output, capture: :all),
           [_, height_str] <- Regex.run(height_pattern, output, capture: :all),
           {width, _} <- Integer.parse(width_str),
           {height, _} <- Integer.parse(height_str) do
        Logger.debug(
          "Got terminal dimensions via PowerShell: #{width}x#{height}"
        )

        {width, height}
      else
        _ -> {:error, :parse_error}
      end
    else
      {:error, :unknown_command}
    end
  end
end
