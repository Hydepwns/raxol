defmodule Raxol.TestFormatter do
  @moduledoc """
  Custom ExUnit formatter for Raxol test output.
  """
  # @behaviour ExUnit.Formatter # ExUnit.Formatter is not a formal OTP behaviour
  use GenServer

  # ExUnit will start the formatter as a GenServer
  def init(opts) do
    {:ok, opts}
  end

  def handle_cast({:test_finished, %{state: {:failed, _}} = test}, state) do
    IO.puts("FAILED: #{test.name} in #{test.module}")

    print_message(Map.has_key?(test, :message) and test.message, test)
    print_stacktrace(Map.has_key?(test, :stacktrace) and test.stacktrace, test)

    IO.puts("")
    {:noreply, state}
  end

  def handle_cast({:test_finished, %{state: :skipped} = test}, state) do
    IO.puts("SKIPPED: #{test.name} in #{test.module}")

    print_skip_reason(Map.has_key?(test, :message) and test.message, test)

    IO.puts("")
    {:noreply, state}
  end

  def handle_cast({:test_finished, _test}, state), do: {:noreply, state}

  def handle_cast({:suite_finished, _run_us, _load_us}, state),
    do: {:noreply, state}

  def handle_cast({:suite_started, _opts}, state), do: {:noreply, state}
  def handle_cast({:test_started, _test}, state), do: {:noreply, state}
  def handle_cast({:case_started, _case}, state), do: {:noreply, state}
  def handle_cast({:case_finished, _case}, state), do: {:noreply, state}

  # Required for GenServer but not used
  def handle_info(_msg, state), do: {:noreply, state}

  defp print_message(false, _test), do: :ok
  defp print_message(true, test), do: IO.puts("  Message: #{test.message}")

  defp print_stacktrace(false, _test), do: :ok

  defp print_stacktrace(true, test),
    do: IO.puts("  Stacktrace: #{Exception.format_stacktrace(test.stacktrace)}")

  defp print_skip_reason(false, _test), do: :ok
  defp print_skip_reason(true, test), do: IO.puts("  Reason: #{test.message}")
end
