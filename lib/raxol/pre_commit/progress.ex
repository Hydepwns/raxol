defmodule Raxol.PreCommit.Progress do
  @moduledoc """
  Progress indicator for pre-commit checks.

  Provides real-time feedback during check execution with animated
  indicators and clear status updates.
  """

  use GenServer

  @spinner_frames ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
  # milliseconds
  @refresh_interval 100

  # Client API

  @doc """
  Start the progress indicator server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize a new check with pending status.
  """
  def init_check(name) do
    GenServer.cast(__MODULE__, {:init_check, name})
  end

  @doc """
  Update check status to running.
  """
  def start_check(name) do
    GenServer.cast(__MODULE__, {:start_check, name})
  end

  @doc """
  Mark check as completed successfully.
  """
  def complete_check(name, elapsed_ms \\ nil) do
    GenServer.cast(__MODULE__, {:complete_check, name, elapsed_ms})
  end

  @doc """
  Mark check as failed.
  """
  def fail_check(name, reason \\ nil) do
    GenServer.cast(__MODULE__, {:fail_check, name, reason})
  end

  @doc """
  Mark check as having warnings.
  """
  def warn_check(name, reason \\ nil) do
    GenServer.cast(__MODULE__, {:warn_check, name, reason})
  end

  @doc """
  Stop the progress indicator and clean up.
  """
  def stop do
    GenServer.stop(__MODULE__)
  end

  @doc """
  Check if progress display is enabled.
  """
  def enabled?(config) do
    not Map.get(config, :quiet, false) and
      not Map.get(config, :ci, false) and
      System.get_env("CI") == nil
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    state = %{
      checks: %{},
      spinner_index: 0,
      timer_ref: nil,
      verbose: Keyword.get(opts, :verbose, false),
      parallel: Keyword.get(opts, :parallel, true)
    }

    # Start animation timer
    timer_ref = Process.send_after(self(), :tick, @refresh_interval)

    {:ok, %{state | timer_ref: timer_ref}}
  end

  @impl GenServer
  def handle_cast({:init_check, name}, state) do
    check_state = %{
      status: :pending,
      start_time: nil,
      elapsed: nil,
      reason: nil
    }

    new_state = put_in(state, [:checks, name], check_state)
    render(new_state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:start_check, name}, state) do
    check_state = %{
      status: :running,
      start_time: System.monotonic_time(:millisecond),
      elapsed: nil,
      reason: nil
    }

    new_state = put_in(state, [:checks, name], check_state)
    render(new_state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:complete_check, name, elapsed_ms}, state) do
    check = Map.get(state.checks, name, %{})

    elapsed =
      case {elapsed_ms, check[:start_time]} do
        {nil, nil} ->
          nil

        {nil, start_time} ->
          System.monotonic_time(:millisecond) - start_time

        {ms, _} when is_integer(ms) ->
          ms

        _ ->
          nil
      end

    check_state = %{
      status: :completed,
      start_time: check[:start_time],
      elapsed: elapsed,
      reason: nil
    }

    new_state = put_in(state, [:checks, name], check_state)
    render(new_state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:fail_check, name, reason}, state) do
    check = Map.get(state.checks, name, %{})

    elapsed =
      case check[:start_time] do
        nil -> nil
        start -> System.monotonic_time(:millisecond) - start
      end

    check_state = %{
      status: :failed,
      start_time: check[:start_time],
      elapsed: elapsed,
      reason: reason
    }

    new_state = put_in(state, [:checks, name], check_state)
    render(new_state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:warn_check, name, reason}, state) do
    check = Map.get(state.checks, name, %{})

    elapsed =
      case check[:start_time] do
        nil -> nil
        start -> System.monotonic_time(:millisecond) - start
      end

    check_state = %{
      status: :warning,
      start_time: check[:start_time],
      elapsed: elapsed,
      reason: reason
    }

    new_state = put_in(state, [:checks, name], check_state)
    render(new_state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:tick, state) do
    # Cancel old timer
    case state.timer_ref do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    # Update spinner
    new_index = rem(state.spinner_index + 1, length(@spinner_frames))
    new_state = %{state | spinner_index: new_index}

    # Render with new spinner frame
    render(new_state)

    # Schedule next tick
    timer_ref = Process.send_after(self(), :tick, @refresh_interval)

    {:noreply, %{new_state | timer_ref: timer_ref}}
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Cancel timer
    case state.timer_ref do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    # Final render with all statuses
    render_final(state)
    :ok
  end

  # Private functions

  defp render(state) do
    # Move cursor up by number of checks to overwrite previous output
    line_count = map_size(state.checks)

    case line_count do
      0 -> :ok
      n -> IO.write("\r\e[#{n}A")
    end

    # Render each check
    state.checks
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {name, check} ->
      render_check(name, check, state)
    end)

    # Flush output
    IO.write("")
  end

  defp render_final(state) do
    # Clear lines and render final state
    line_count = map_size(state.checks)

    case line_count do
      0 -> :ok
      n -> IO.write("\r\e[#{n}A\e[J")
    end

    # Render each check with final status
    state.checks
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {name, check} ->
      render_check_final(name, check, state)
    end)
  end

  defp render_check(name, check, state) do
    icon = status_icon(check.status, state.spinner_index)
    name_str = format_check_name(name)
    time_str = format_time(check)

    line =
      case check.status do
        :pending ->
          "#{icon} #{name_str}..."

        :running ->
          "#{icon} #{name_str}..."

        :completed ->
          "#{icon} #{name_str} #{time_str}"

        :warning ->
          "#{icon} #{name_str} #{time_str}"

        :failed ->
          "#{icon} #{name_str} #{time_str}"
      end

    # Clear line and write new content
    IO.puts("\r\e[K#{line}")
  end

  defp render_check_final(name, check, state) do
    icon = final_status_icon(check.status)
    name_str = format_check_name(name)
    time_str = format_time(check)

    line = "  #{icon} #{name_str}#{time_str}"
    IO.puts(line)

    # Show error reason if verbose and failed
    case {state.verbose, check.status, check.reason} do
      {true, :failed, reason} when reason != nil ->
        IO.puts("     #{reason}")

      {true, :warning, reason} when reason != nil ->
        IO.puts("     #{reason}")

      _ ->
        :ok
    end
  end

  defp status_icon(:pending, _), do: "⏳"

  defp status_icon(:running, spinner_index) do
    Enum.at(@spinner_frames, spinner_index)
  end

  defp status_icon(:completed, _), do: "✅"
  defp status_icon(:warning, _), do: "⚠️"
  defp status_icon(:failed, _), do: "❌"

  defp final_status_icon(:pending), do: "⏳"
  defp final_status_icon(:running), do: "🔄"
  defp final_status_icon(:completed), do: "✅"
  defp final_status_icon(:warning), do: "⚠️"
  defp final_status_icon(:failed), do: "❌"

  defp format_check_name(name) when is_atom(name) do
    name |> to_string() |> String.capitalize() |> String.pad_trailing(10)
  end

  defp format_time(%{elapsed: nil}), do: ""
  defp format_time(%{elapsed: ms}) when ms < 1000, do: "(#{ms}ms)"
  defp format_time(%{elapsed: ms}), do: "(#{Float.round(ms / 1000, 1)}s)"
end
