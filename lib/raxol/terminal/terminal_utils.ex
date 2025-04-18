defmodule Raxol.Terminal.TerminalUtils do
  @moduledoc """
  Utility functions for terminal operations, providing cross-platform and
  consistent handling of terminal capabilities and dimensions.
  """

  require Logger
  # alias ExTermbox.Bindings  # Unused alias

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

  # Try to get dimensions using :io module
  defp try_io_dimensions do
    try do
      {cols, rows} = :io.columns()

      if cols > 0 and rows > 0 do
        {cols, rows}
      else
        {:error, :invalid_dimensions}
      end
    rescue
      _ -> {:error, :io_failure}
    catch
      _, _ -> {:error, :io_failure}
    end
  end

  # Try to get dimensions using ExTermbox
  defp try_termbox_dimensions do
    # Check if we should use mock termbox in test environment
    use_termbox =
      Application.get_env(:raxol, :terminal, [])[:use_termbox] != false

    mock_termbox =
      Application.get_env(:raxol, :terminal, [])[:mock_termbox] == true

    try do
      # Initialize ExTermbox if not already initialized
      init_result =
        cond do
          mock_termbox ->
            Raxol.Test.MockTermbox.init()

          use_termbox ->
            ExTermbox.Bindings.init()

          true ->
            {:ok, :skipped}
        end

      case init_result do
        {:ok, _} ->
          # Get dimensions
          width_result =
            if mock_termbox do
              Raxol.Test.MockTermbox.width()
            else
              if use_termbox, do: ExTermbox.Bindings.width(), else: {:ok, 80}
            end

          height_result =
            if mock_termbox do
              Raxol.Test.MockTermbox.height()
            else
              if use_termbox, do: ExTermbox.Bindings.height(), else: {:ok, 24}
            end

          # Clean up if we had to initialize
          if mock_termbox do
            Raxol.Test.MockTermbox.shutdown()
          else
            if use_termbox, do: ExTermbox.Bindings.shutdown()
          end

          # Extract dimensions
          with {:ok, width} when is_integer(width) <- width_result,
               {:ok, height} when is_integer(height) <- height_result do
            {width, height}
          else
            _ -> {:error, :invalid_termbox_dimensions}
          end

        _ ->
          {:error, :termbox_init_failed}
      end
    rescue
      e -> {:error, {:termbox_exception, e}}
    catch
      type, value -> {:error, {:termbox_error, {type, value}}}
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
