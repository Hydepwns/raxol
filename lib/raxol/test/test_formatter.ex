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

    if Map.has_key?(test, :message) and test.message do
      IO.puts("  Message: #{test.message}")
    end

    if Map.has_key?(test, :stacktrace) and test.stacktrace do
      IO.puts("  Stacktrace: #{Exception.format_stacktrace(test.stacktrace)}")
    end

    IO.puts("")
    {:noreply, state}
  end

  def handle_cast({:test_finished, %{state: :skipped} = test}, state) do
    IO.puts("SKIPPED: #{test.name} in #{test.module}")

    if Map.has_key?(test, :message) and test.message do
      IO.puts("  Reason: #{test.message}")
    end

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
end
