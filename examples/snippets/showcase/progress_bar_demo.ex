defmodule Raxol.Examples.ProgressBarDemo do
  @moduledoc """
  A demo application showcasing various features of the progress bar component.
  """

  use Raxol.Component
  alias Raxol.View.Elements

  @impl Raxol.Component
  def mount(_params, _session, socket) do
    socket = assign(socket,
      basic_progress: 0,
      block_progress: 0,
      custom_progress: 0,
      gradient_progress: 0,
      running: true
    )
    # Start the timer if running
    if socket.assigns.running do
      schedule_tick()
    end
    {:ok, socket}
  end

  @impl Raxol.Component
  def handle_info(:tick, socket) do
    if socket.assigns.running do
      if socket.assigns.basic_progress >= 100 do
        {:noreply, assign(socket, :running, false)}
      else
        # Schedule next tick
        schedule_tick()
        # Update progress
        new_socket = assign(socket, %{
            basic_progress: min(socket.assigns.basic_progress + 5, 100),
            block_progress: min(socket.assigns.block_progress + 3, 100),
            custom_progress: min(socket.assigns.custom_progress + 7, 100),
            gradient_progress: min(socket.assigns.gradient_progress + 4, 100)
        })
        {:noreply, new_socket}
      end
    else
      # Not running, do nothing
      {:noreply, socket}
    end
  end

  @impl Raxol.Component
  def handle_event("restart", _params, socket) do
     new_socket = assign(socket, %{
        basic_progress: 0,
        block_progress: 0,
        custom_progress: 0,
        gradient_progress: 0,
        running: true
     })
     # Schedule the first tick after restart
     schedule_tick()
    {:noreply, new_socket}
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, 100)
  end

  @impl Raxol.Component
  def render(assigns) do
    ~V"""
    <.box>
      <.column>
        <.text style={:bold}>Progress Bar Demo</.text>
        <.text></.text> {# Spacer #}

        <.progress_bar
          label="Basic"
          value={assigns.basic_progress}
          width=40
          style={:basic}
          color={:blue}
        />
        <.text></.text> {# Spacer #}

        <.progress_bar
          label="Block"
          value={assigns.block_progress}
          width=40
          style={:block}
          color={:green}
        />
        <.text></.text> {# Spacer #}

        <.progress_bar
          label="Custom"
          value={assigns.custom_progress}
          width=40
          style={:custom}
          characters={%{filled: "▣", empty: "□"}}
          color={:yellow}
        />
        <.text></.text> {# Spacer #}

        <.progress_bar
          label="Gradient"
          value={assigns.gradient_progress}
          width=40
          style={:block}
          gradient={[:red, :yellow, :green]}
        />
        <.text></.text> {# Spacer #}

        {#if !assigns.running do}
          <.button rax-click="restart">Restart</.button>
        {#else}
          <.text>(Running...)</.text>
        {#end}
      </.column>
    </.box>
    """
  end
end
