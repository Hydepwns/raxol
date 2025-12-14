defmodule Raxol.CLI.Spinner do
  @moduledoc """
  Animated progress spinners for CLI operations.

  Provides visual feedback during long-running operations like compilation,
  dialyzer analysis, and test runs. Based on TJ Holowaychuk's feedback
  about the importance of progress indicators.

  ## Usage

      # Simple spinner with message
      Spinner.with_spinner("Compiling...", fn ->
        # long running operation
        Mix.Task.run("compile")
      end)

      # Custom spinner style
      Spinner.with_spinner("Analyzing...", style: :dots, fn ->
        # operation
      end)

      # Manual control
      {:ok, spinner} = Spinner.start("Processing...")
      # do work
      Spinner.succeed(spinner, "Done!")

      # Or on failure
      Spinner.fail(spinner, "Failed!")
  """

  alias Raxol.CLI.Colors

  @type spinner_style :: :dots | :line | :arc | :bounce | :braille
  @type spinner_state :: %{
          pid: pid(),
          message: String.t(),
          style: spinner_style()
        }

  # Spinner frame definitions (ASCII only per project requirements)
  @frames %{
    dots: [".", "..", "...", "..", "."],
    line: ["-", "\\", "|", "/"],
    arc: ["(", "{", "[", "|", "]", "}", ")"],
    bounce: ["[", "[=", "[==", "[===", "[====", "===]", "==]", "=]", "]"],
    braille: ["o", "O", "0", "O", "o", ".", "o", "O"]
  }

  @frame_delay 80

  # ============================================================================
  # High-Level API
  # ============================================================================

  @doc """
  Runs a function with an animated spinner.

  Returns the result of the function.

  ## Options

    * `:style` - Spinner animation style (default: `:dots`)
    * `:success` - Message to show on success (default: "Done")
    * `:failure` - Message to show on failure (default: "Failed")

  ## Examples

      result = Spinner.with_spinner("Compiling...", fn ->
        Mix.Task.run("compile")
      end)

      result = Spinner.with_spinner("Running tests...", style: :line, fn ->
        Mix.Task.run("test")
      end)
  """
  @spec with_spinner(String.t(), keyword(), (-> any())) :: any()
  def with_spinner(message, opts \\ [], fun) when is_function(fun, 0) do
    {:ok, spinner} = start(message, opts)

    try do
      result = fun.()
      success_msg = Keyword.get(opts, :success, "Done")
      succeed(spinner, success_msg)
      result
    rescue
      e ->
        failure_msg = Keyword.get(opts, :failure, "Failed")
        fail(spinner, failure_msg)
        reraise e, __STACKTRACE__
    catch
      :exit, reason ->
        failure_msg = Keyword.get(opts, :failure, "Failed")
        fail(spinner, failure_msg)
        exit(reason)
    end
  end

  @doc """
  Starts a spinner with the given message.

  Returns `{:ok, spinner_state}` which can be used with `succeed/2`,
  `fail/2`, or `stop/1`.
  """
  @spec start(String.t(), keyword()) :: {:ok, spinner_state()}
  def start(message, opts \\ []) do
    style = Keyword.get(opts, :style, :dots)
    frames = Map.get(@frames, style, @frames.dots)

    pid =
      spawn_link(fn ->
        spin_loop(message, frames, 0)
      end)

    {:ok, %{pid: pid, message: message, style: style}}
  end

  @doc """
  Stops the spinner and shows a success message.
  """
  @spec succeed(spinner_state(), String.t()) :: :ok
  def succeed(spinner, message \\ "Done") do
    stop_spinner(spinner.pid)
    clear_line()
    IO.write("  " <> Colors.success("[OK]") <> " " <> message <> "\n")
    :ok
  end

  @doc """
  Stops the spinner and shows a failure message.
  """
  @spec fail(spinner_state(), String.t()) :: :ok
  def fail(spinner, message \\ "Failed") do
    stop_spinner(spinner.pid)
    clear_line()
    IO.write("  " <> Colors.error("[!!]") <> " " <> message <> "\n")
    :ok
  end

  @doc """
  Stops the spinner and shows a warning message.
  """
  @spec warn(spinner_state(), String.t()) :: :ok
  def warn(spinner, message \\ "Warning") do
    stop_spinner(spinner.pid)
    clear_line()
    IO.write("  " <> Colors.warning("[??]") <> " " <> message <> "\n")
    :ok
  end

  @doc """
  Stops the spinner without showing any status.
  """
  @spec stop(spinner_state()) :: :ok
  def stop(spinner) do
    stop_spinner(spinner.pid)
    clear_line()
    :ok
  end

  @doc """
  Updates the spinner message while it's running.
  """
  @spec update_message(spinner_state(), String.t()) :: :ok
  def update_message(spinner, new_message) do
    send(spinner.pid, {:update_message, new_message})
    :ok
  end

  # ============================================================================
  # Progress Bar
  # ============================================================================

  @doc """
  Displays a progress bar.

  ## Options

    * `:width` - Bar width in characters (default: 30)
    * `:filled` - Character for filled portion (default: "=")
    * `:empty` - Character for empty portion (default: " ")
    * `:prefix` - Text before the bar (default: "")
    * `:suffix` - Text after the bar (default: "")
  """
  @spec progress_bar(number(), number(), keyword()) :: String.t()
  def progress_bar(current, total, opts \\ []) do
    width = Keyword.get(opts, :width, 30)
    filled_char = Keyword.get(opts, :filled, "=")
    empty_char = Keyword.get(opts, :empty, " ")
    prefix = Keyword.get(opts, :prefix, "")
    suffix = Keyword.get(opts, :suffix, "")

    percent = if total > 0, do: current / total, else: 0
    filled_width = round(percent * width)
    empty_width = width - filled_width

    bar =
      String.duplicate(filled_char, filled_width) <>
        String.duplicate(empty_char, empty_width)

    percent_str = "#{round(percent * 100)}%"

    "#{prefix}[#{bar}] #{percent_str}#{suffix}"
  end

  @doc """
  Writes a progress bar to the terminal, overwriting the current line.
  """
  @spec write_progress(number(), number(), keyword()) :: :ok
  def write_progress(current, total, opts \\ []) do
    bar = progress_bar(current, total, opts)
    IO.write("\r" <> bar)
    :ok
  end

  @doc """
  Completes a progress bar with a newline.
  """
  @spec complete_progress() :: :ok
  def complete_progress do
    IO.write("\n")
    :ok
  end

  # ============================================================================
  # Step Indicator
  # ============================================================================

  @doc """
  Displays a step indicator for multi-step operations.

  ## Examples

      Spinner.step(1, 5, "Compiling...")
      # [1/5] Compiling...

      Spinner.step(2, 5, "Running tests...", status: :in_progress)
      # [2/5] Running tests...
  """
  @spec step(pos_integer(), pos_integer(), String.t(), keyword()) :: :ok
  def step(current, total, message, opts \\ []) do
    status = Keyword.get(opts, :status, :in_progress)

    indicator =
      case status do
        :done -> Colors.success("[#{current}/#{total}]")
        :failed -> Colors.error("[#{current}/#{total}]")
        :skipped -> Colors.muted("[#{current}/#{total}]")
        _ -> Colors.info("[#{current}/#{total}]")
      end

    IO.puts("#{indicator} #{message}")
    :ok
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp spin_loop(message, frames, index) do
    frame = Enum.at(frames, rem(index, length(frames)))
    output = "  " <> Colors.info(frame) <> " " <> message
    IO.write("\r" <> output <> "   ")

    receive do
      :stop ->
        :ok

      {:update_message, new_message} ->
        spin_loop(new_message, frames, index + 1)
    after
      @frame_delay ->
        spin_loop(message, frames, index + 1)
    end
  end

  defp stop_spinner(pid) do
    if Process.alive?(pid) do
      send(pid, :stop)
      # Give it time to stop cleanly
      Process.sleep(10)
    end
  end

  defp clear_line do
    IO.write("\r" <> String.duplicate(" ", 80) <> "\r")
  end
end
