defmodule Raxol.Terminal.TerminalUtils do
  @moduledoc """
  Utility functions for terminal operations, providing cross-platform and
  consistent handling of terminal capabilities and dimensions.
  """

  require Logger
  alias ExTermbox

  @doc """
  Detects terminal dimensions using a multi-layered approach:
  1. Uses `:io.columns` and `:io.rows` (preferred)
  2. Falls back to rrex_termbox v2.0.1 NIF if `:io` methods fail
  3. Falls back to `stty size` system command if needed
  4. Finally uses hardcoded default dimensions if all else fails

  Returns a tuple of {width, height}.
  """
  @spec detect_dimensions :: {pos_integer(), pos_integer()}
  def detect_dimensions do
    default_width = 80
    default_height = 24

    # Try to detect dimensions (multiple methods with fallbacks)
    {width, height} =
      with {:error, _} <- detect_with_io(),
           {:error, _} <- detect_with_termbox(),
           {:error, _} <- detect_with_stty() do
        Logger.warning("Could not determine terminal dimensions. Using defaults.")
        {default_width, default_height}
      else
        {:ok, w, h} -> {w, h}
      end

    if width == 0 or height == 0 do
      Logger.warning("Detected invalid terminal dimensions (#{width}x#{height}). Using defaults.")
      {default_width, default_height}
    else
      Logger.debug("Terminal dimensions: #{width}x#{height}")
      {width, height}
    end
  end

  @doc """
  Gets terminal dimensions and returns them in a map format.
  """
  @spec get_dimensions_map() :: %{width: pos_integer(), height: pos_integer()}
  def get_dimensions_map do
    {width, height} = detect_dimensions()
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
    {width, height} = detect_dimensions()
    %{x: 0, y: 0, width: width, height: height}
  end

  @doc """
  Returns the current cursor position, if available.
  """
  @spec cursor_position :: {:ok, {pos_integer(), pos_integer()}} | {:error, term()}
  def cursor_position do
    # This is a stub implementation - real implementation might use ANSI escape sequences
    {:error, :not_implemented}
  end

  # Private helper functions

  # Try to detect with :io.columns and :io.rows (most reliable)
  defp detect_with_io do
    try do
      with {:ok, width} when is_integer(width) and width > 0 <- :io.columns(),
           {:ok, height} when is_integer(height) and height > 0 <- :io.rows() do
        {:ok, width, height}
      else
        {:error, reason} ->
          Logger.debug("io.columns/rows error: #{inspect(reason)}")
          {:error, reason}

        other ->
          Logger.debug("io.columns/rows unexpected return: #{inspect(other)}")
          {:error, :invalid_response}
      end
    rescue
      e ->
        Logger.debug("Error in detect_with_io: #{inspect(e)}")
        {:error, e}
    end
  end

  # Try to detect with rrex_termbox
  defp detect_with_termbox do
    with {:ok, width} <- ExTermbox.width(),
         {:ok, height} <- ExTermbox.height() do
      {:ok, width, height}
    else
      error ->
        Logger.debug("rrex_termbox error: #{inspect(error)}")
        {:error, error}
    end
  end

  # Try to detect with stty size command
  defp detect_with_stty do
    try do
      case System.cmd("stty", ["size"]) do
        {output, 0} ->
          output = String.trim(output)

          case String.split(output) do
            [rows, cols] ->
              {:ok, String.to_integer(cols), String.to_integer(rows)}

            _ ->
              Logger.debug("Unexpected stty output format: #{inspect(output)}")
              {:error, :invalid_format}
          end

        {output, code} ->
          Logger.debug("stty exited with code #{code}: #{inspect(output)}")
          {:error, {:exit_code, code}}
      end
    rescue
      e ->
        Logger.debug("Error in detect_with_stty: #{inspect(e)}")
        {:error, e}
    end
  end
end
