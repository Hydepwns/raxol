defmodule Raxol.Terminal.TerminalUtils do
  @moduledoc """
  Utility functions for terminal operations, providing cross-platform and
  consistent handling of terminal capabilities and dimensions.
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Core.ErrorHandling

  # Check if termbox2_nif is available at compile time
  @termbox2_available Code.ensure_loaded?(:termbox2_nif)

  @doc """
  Detects terminal dimensions using a multi-layered approach:
  1. Uses `:io.columns` and `:io.rows` (preferred)
  2. Falls back to termbox2 NIF if `:io` methods fail
  3. Falls back to `stty size` system command if needed
  4. Finally uses hardcoded default dimensions if all else fails

  Returns a tuple of {width, height}.
  """
  @spec detect_dimensions :: {pos_integer(), pos_integer()}
  def detect_dimensions do
    default_width = 80
    default_height = 24

    {width, height} =
      with {:error, _} <- detect_with_io(:io),
           {:error, _} <- try_termbox_detection(),
           {:error, _} <- detect_with_stty() do
        Raxol.Core.Runtime.Log.warning_with_context(
          "Could not determine terminal dimensions. Using defaults.",
          %{}
        )

        {default_width, default_height}
      else
        {:ok, w, h} -> {w, h}
      end

    validate_dimensions(width, height, default_width, default_height)
  end

  defp try_termbox_detection do
    case {real_tty?(), Mix.env()} do
      {true, env} when env != :test ->
        Raxol.Core.Runtime.Log.debug(
          "[TerminalUtils] TTY detected, attempting detect_with_termbox..."
        )
        detect_with_termbox()
      _ ->
        Raxol.Core.Runtime.Log.debug(
          "[TerminalUtils] Not a real TTY, skipping detect_with_termbox."
        )
        {:error, :not_a_tty}
    end
  end

  defp validate_dimensions(0, _, default_width, default_height) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Detected invalid terminal dimensions (0x?). Using defaults.",
      %{}
    )
    {default_width, default_height}
  end

  defp validate_dimensions(_, 0, default_width, default_height) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Detected invalid terminal dimensions (?x0). Using defaults.",
      %{}
    )
    {default_width, default_height}
  end

  defp validate_dimensions(width, height, _default_width, _default_height) do
    Raxol.Core.Runtime.Log.debug("Terminal dimensions: #{width}x#{height}")
    {width, height}
  end

  defp get_termbox_width do
    case @termbox2_available do
      true -> apply(:termbox2_nif, :tb_width, [])
      false -> 0
    end
  end

  defp get_termbox_height do
    case @termbox2_available do
      true -> apply(:termbox2_nif, :tb_height, [])
      false -> 0
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
  @spec cursor_position ::
          {:ok, {pos_integer(), pos_integer()}} | {:error, term()}
  def cursor_position do
    {:error, :not_implemented}
  end

  @doc """
  Detects terminal dimensions using :io.columns and :io.rows.
  Returns {:ok, width, height} or {:error, reason}.
  """
  @spec detect_with_io(atom()) ::
          {:ok, pos_integer(), pos_integer()} | {:error, term()}
  def detect_with_io(io_facade) do
    case ErrorHandling.safe_call(fn ->
           with {:ok, width} when is_integer(width) and width > 0 <-
                  apply(io_facade, :columns, []),
                {:ok, height} when is_integer(height) and height > 0 <-
                  apply(io_facade, :rows, []) do
             {:ok, width, height}
           else
             {:error, reason} ->
               Raxol.Core.Runtime.Log.debug(
                 "io.columns/rows error: #{inspect(reason)}"
               )

               {:error, reason}

             other ->
               Raxol.Core.Runtime.Log.debug(
                 "io.columns/rows unexpected return: #{inspect(other)}"
               )

               {:error, :invalid_response}
           end
         end) do
      {:ok, result} ->
        result

      {:error, reason} ->
        Raxol.Core.Runtime.Log.debug(
          "Error in detect_with_io: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Detects terminal dimensions using the termbox2 NIF.
  Returns {:ok, width, height} or {:error, reason}.
  """
  @spec detect_with_termbox() ::
          {:ok, pos_integer(), pos_integer()} | {:error, term()}
  def detect_with_termbox do
    Raxol.Core.Runtime.Log.debug(
      "[TerminalUtils] Calling Termbox2Nif.tb_width/tb_height (NIF)..."
    )

    width = get_termbox_width()
    height = get_termbox_height()

    case {is_integer(width) and width > 0, is_integer(height) and height > 0} do
      {true, true} -> 
        {:ok, width, height}
      _ ->
        error = {:error, :invalid_termbox_dimensions}
        Raxol.Core.Runtime.Log.debug("termbox2_nif error: #{inspect(error)}")
        error
    end
  end

  @doc """
  Detects terminal dimensions using the stty size command.
  Returns {:ok, width, height} or {:error, reason}.
  """
  @spec detect_with_stty() ::
          {:ok, pos_integer(), pos_integer()} | {:error, term()}
  def detect_with_stty do
    case ErrorHandling.safe_call(fn ->
           case System.cmd("stty", ["size"]) do
             {output, 0} ->
               output = String.trim(output)

               case String.split(output) do
                 [rows, cols] ->
                   {:ok, String.to_integer(cols), String.to_integer(rows)}

                 _ ->
                   Raxol.Core.Runtime.Log.debug(
                     "Unexpected stty output format: #{inspect(output)}"
                   )

                   {:error, :invalid_format}
               end

             {output, code} ->
               Raxol.Core.Runtime.Log.debug(
                 "stty exited with code #{code}: #{inspect(output)}"
               )

               {:error, {:exit_code, code}}
           end
         end) do
      {:ok, result} ->
        result

      {:error, reason} ->
        Raxol.Core.Runtime.Log.debug(
          "Error in detect_with_stty: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Returns true if the current process is attached to a real TTY device.
  """
  @spec real_tty?() :: boolean()
  def real_tty? do
    case System.cmd("tty", []) do
      {tty, 0} ->
        tty = String.trim(tty)
        tty != "not a tty" and String.starts_with?(tty, "/dev/")

      _ ->
        false
    end
  end
end
