# This script verifies terminal dimensions using various methods
# Run with: mix run scripts/verify_terminal_dimensions.exs

defmodule TerminalDimensionVerifier do
  require Logger

  def run do
    IO.puts("Terminal Dimension Verification")
    IO.puts("==============================\n")

    verify_io_module()
    verify_extermbox()
    verify_system_command()
    verify_terminal_utils()

    IO.puts("\nVerification complete!")
  end

  defp verify_io_module do
    IO.puts("Checking dimensions using :io module:")

    width_result = :io.columns()
    height_result = :io.rows()

    IO.puts("  :io.columns() = #{inspect(width_result)}")
    IO.puts("  :io.rows() = #{inspect(height_result)}")

    case {width_result, height_result} do
      {{:ok, w}, {:ok, h}} ->
        IO.puts("  SUCCESS: Terminal dimensions via :io module: #{w}x#{h}")
      _ ->
        IO.puts("  FAILED: Unable to get terminal dimensions via :io module")
    end

    IO.puts("")
  end

  defp verify_extermbox do
    IO.puts("Checking dimensions using ExTermbox.Bindings:")

    # Try to initialize ExTermbox - handle potential errors
    init_result = try do
      ExTermbox.Bindings.init()
    rescue
      e -> {:error, e}
    end

    case init_result do
      :ok ->
        width_result = ExTermbox.Bindings.width()
        height_result = ExTermbox.Bindings.height()

        IO.puts("  ExTermbox.Bindings.width() = #{inspect(width_result)}")
        IO.puts("  ExTermbox.Bindings.height() = #{inspect(height_result)}")

        # Attempt to unwrap results properly
        width = case width_result do
          {:ok, {:ok, w}} -> w
          {:ok, w} when is_integer(w) -> w
          _ -> nil
        end

        height = case height_result do
          {:ok, {:ok, h}} -> h
          {:ok, h} when is_integer(h) -> h
          _ -> nil
        end

        if width && height do
          IO.puts("  SUCCESS: Terminal dimensions via ExTermbox: #{width}x#{height}")
        else
          IO.puts("  PARTIAL FAILURE: Unable to get both dimensions via ExTermbox")
          if width, do: IO.puts("    Width only: #{width}")
          if height, do: IO.puts("    Height only: #{height}")
        end

        # Clean up ExTermbox
        try do
          ExTermbox.Bindings.stop_polling()
          ExTermbox.Bindings.shutdown()
        rescue
          _ -> IO.puts("  WARNING: Error during ExTermbox cleanup")
        end

      {:error, reason} ->
        IO.puts("  FAILED: Unable to initialize ExTermbox: #{inspect(reason)}")
    end

    IO.puts("")
  end

  defp verify_system_command do
    IO.puts("Checking dimensions using system commands:")

    # Different commands for different operating systems
    command =
      case :os.type() do
        {:unix, :darwin} -> "stty size"
        {:unix, _} -> "stty size"
        {:win32, _} -> "powershell \"$host.UI.RawUI.WindowSize\""
        _ -> nil
      end

    if command do
      IO.puts("  Using command: #{command}")
      try do
        case System.cmd("sh", ["-c", command], stderr_to_stdout: true) do
          {output, 0} ->
            IO.puts("  Raw output: #{inspect(output)}")
            dimensions = parse_command_output(output, command)
            case dimensions do
              {width, height} ->
                IO.puts("  SUCCESS: Terminal dimensions via system command: #{width}x#{height}")
              {:error, reason} ->
                IO.puts("  FAILED: Unable to parse dimensions: #{reason}")
            end
          {error, code} ->
            IO.puts("  FAILED: Command failed with exit code #{code}: #{error}")
        end
      rescue
        e -> IO.puts("  ERROR: Exception running command: #{inspect(e)}")
      end
    else
      IO.puts("  SKIPPED: No suitable command for this operating system")
    end

    IO.puts("")
  end

  defp verify_terminal_utils do
    IO.puts("Checking dimensions using Raxol.Terminal.TerminalUtils:")

    {width, height} = Raxol.Terminal.TerminalUtils.get_terminal_dimensions()
    IO.puts("  Raxol.Terminal.TerminalUtils.get_terminal_dimensions() = {#{width}, #{height}}")

    dims_map = Raxol.Terminal.TerminalUtils.get_dimensions_map()
    IO.puts("  Raxol.Terminal.TerminalUtils.get_dimensions_map() = #{inspect(dims_map)}")

    bounds_map = Raxol.Terminal.TerminalUtils.get_bounds_map()
    IO.puts("  Raxol.Terminal.TerminalUtils.get_bounds_map() = #{inspect(bounds_map)}")

    IO.puts("")
  end

  # Parse system command output based on the command used
  defp parse_command_output(output, "stty size") do
    case String.split(String.trim(output), " ") do
      [height_str, width_str] ->
        try do
          height = String.to_integer(height_str)
          width = String.to_integer(width_str)
          {width, height}
        rescue
          _ -> {:error, :parse_error}
        end
      _ ->
        {:error, :invalid_output_format}
    end
  end

  defp parse_command_output(output, cmd) when is_binary(cmd) and cmd =~ "powershell" do
    # Parse PowerShell output which typically looks like:
    # Width : 120
    # Height: 30
    width_pattern = ~r/Width\s*:?\s*(\d+)/i
    height_pattern = ~r/Height\s*:?\s*(\d+)/i

    with [_, width_str] <- Regex.run(width_pattern, output, capture: :all),
         [_, height_str] <- Regex.run(height_pattern, output, capture: :all),
         {width, _} <- Integer.parse(width_str),
         {height, _} <- Integer.parse(height_str) do
      {width, height}
    else
      _ -> {:error, :parse_error}
    end
  end

  defp parse_command_output(_, _) do
    {:error, :unknown_command}
  end
end

TerminalDimensionVerifier.run()
