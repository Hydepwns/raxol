# Scrubber Demo
#
# A transport control over an ordered position: seek, tick marks, playback
# speed, and the three messages an MCP tool call turns into.
#
# The scrubber is a declaration, not a component instance, so it needs an
# explicit :id. That id is what namespaces its MCP tools ("timeline.seek",
# "timeline.play", ...) and what focus matches against, so it has to be stable
# across frames -- which is exactly why `scrubber/1` does not mint one.
#
# `handle_tool_call/3` returns {:scrubber_seek, id, pos} / {:scrubber_play, id}
# / {:scrubber_pause, id}. The app translates those into the component's own
# {:seek, pos} / :play / :pause, which is what the update/2 clauses below do:
# one keyboard path and one agent path converging on the same state change.
#
# Usage:
#   mix run examples/components/scrubber_demo.exs

defmodule ScrubberDemo do
  use Raxol.Core.Runtime.Application

  alias Raxol.Core.Events.Event
  alias Raxol.UI.Components.Input.Scrubber

  @id "timeline"
  @max 47
  @tick_ms 250

  @impl true
  def init(_context) do
    schedule_tick()

    %{
      scrubber: Scrubber.new(id: @id, min: 0, max: @max, marks: [0, 18, 33]),
      last_action: "ready"
    }
  end

  @impl true
  def update(message, model) do
    case message do
      %Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [Directive.stop()]}

      # Advance the playhead only while playing, so pause is observable.
      :tick ->
        schedule_tick()
        {tick(model), []}

      # The agent path. These are what Scrubber.handle_tool_call/3 emits, and
      # they are deliberately distinct from the component's own vocabulary so
      # the app decides whether a tool may move this transport.
      {:scrubber_seek, @id, position} ->
        {act(model, {:seek, position}, "agent sought to #{position}"), []}

      {:scrubber_play, @id} ->
        {act(model, :play, "agent pressed play"), []}

      {:scrubber_pause, @id} ->
        {act(model, :pause, "agent pressed pause"), []}

      # The human path: every key the widget understands, including space to
      # toggle, arrows to step, 0-9 for deciles, and [ / ] for speed.
      %Event{} = event ->
        {%{model | scrubber: Scrubber.handle_event(model.scrubber, event, %{})}
         |> describe(event), []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    s = model.scrubber

    column style: %{padding: 1, gap: 1} do
      [
        text("Scrubber Demo", style: [:bold]),
        scrubber(
          id: @id,
          min: s.min,
          max: s.max,
          position: s.position,
          playing?: s.playing?,
          speed: s.speed,
          marks: s.marks,
          label: "Timeline"
        ),
        text("last: #{model.last_action}"),
        text("space play/pause  <- -> step  0-9 decile  [ ] speed  q quit")
      ]
    end
  end

  defp act(model, message, description) do
    %{
      model
      | scrubber: Scrubber.update(message, model.scrubber),
        last_action: description
    }
  end

  defp tick(%{scrubber: %{playing?: true, position: pos, max: max}} = model)
       when pos < max do
    act(model, {:seek, pos + 1}, "playing")
  end

  defp tick(%{scrubber: %{playing?: true}} = model),
    do: act(model, :pause, "reached the end")

  defp tick(model), do: model

  defp describe(model, %Event{data: %{char: char}}) when is_binary(char),
    do: %{model | last_action: "key #{inspect(char)}"}

  defp describe(model, %Event{data: %{key: key}}),
    do: %{model | last_action: "key #{inspect(key)}"}

  defp describe(model, _event), do: model

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)
end

{:ok, pid} = Raxol.start_link(ScrubberDemo, [])
ref = Process.monitor(pid)

receive do
  {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
end
