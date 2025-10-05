#!/usr/bin/env elixir

# Simple Counter Plugin Example
#
# Demonstrates the basic Raxol plugin structure:
# - State management
# - Input handling
# - Rendering
#
# Run with: mix run examples/plugins/counter.exs

defmodule CounterPlugin do
  @behaviour Raxol.Plugin

  alias Raxol.Core.{Buffer, Box}

  @impl true
  def init(_opts) do
    {:ok, %{counter: 0, step: 1}}
  end

  @impl true
  def handle_input(key, _modifiers, state) do
    case key do
      " " ->
        {:ok, %{state | counter: state.counter + state.step}}

      "-" ->
        {:ok, %{state | counter: state.counter - state.step}}

      "+" ->
        {:ok, %{state | step: state.step + 1}}

      "=" ->
        {:ok, %{state | step: max(state.step - 1, 1)}}

      "r" ->
        {:ok, %{counter: 0, step: 1}}

      "q" ->
        {:exit, state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def render(buffer, state) do
    # Draw border
    buffer = Box.draw_box(buffer, 0, 0, buffer.width, buffer.height, :double)

    # Title
    buffer =
      Buffer.write_at(buffer, 2, 0, " Counter Plugin ", %{
        bold: true,
        fg_color: :cyan
      })

    # Counter display
    buffer =
      Buffer.write_at(buffer, 2, 2, "Counter: #{state.counter}", %{
        bold: true,
        fg_color: :green
      })

    buffer =
      Buffer.write_at(buffer, 2, 3, "Step: #{state.step}", %{fg_color: :yellow})

    # Controls
    buffer
    |> Buffer.write_at(2, 5, "Controls:", %{bold: true})
    |> Buffer.write_at(4, 6, "SPACE  - Increment by step")
    |> Buffer.write_at(4, 7, "-      - Decrement by step")
    |> Buffer.write_at(4, 8, "+      - Increase step")
    |> Buffer.write_at(4, 9, "=      - Decrease step")
    |> Buffer.write_at(4, 10, "r      - Reset")
    |> Buffer.write_at(4, 11, "q      - Quit")
  end

  @impl true
  def cleanup(_state) do
    IO.puts("\nGoodbye!")
    :ok
  end
end

# Run the plugin
Raxol.Plugin.run(CounterPlugin, buffer_width: 50, buffer_height: 15)
