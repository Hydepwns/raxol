defmodule Raxol.Core.Renderer.Manager do
  @moduledoc """
  Manages the rendering system for Raxol applications.

  This module coordinates:
  * Frame-based rendering
  * Terminal buffer management
  * Component rendering
  * Screen updates
  """

  use GenServer

  alias Raxol.Core.Renderer.Buffer
  alias Raxol.Core.Events.Manager, as: Manager
  alias Raxol.Core.Runtime.ComponentManager

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def initialize(opts \\ []) do
    GenServer.call(__MODULE__, {:init, opts})
  end

  def render(reply_to_pid_for_signal \\ nil) do
    GenServer.cast(__MODULE__, {:render, reply_to_pid_for_signal})
  end

  def cleanup do
    GenServer.call(__MODULE__, :cleanup)
  end

  @impl GenServer
  def init(_opts) do
    {:ok,
     %{
       buffer: nil,
       fps: 60,
       render_queue: [],
       initialized: false
     }}
  end

  @impl GenServer
  def handle_call({:init, opts}, _from, state) do
    {width, height} = get_terminal_size()

    fps = Keyword.get(opts, :fps, 60)
    buffer = Buffer.new(width, height, fps)

    {:ok, _sub_ref} = Manager.subscribe([:window])

    {:reply, :ok, %{state | buffer: buffer, fps: fps, initialized: true}}
  end

  @impl GenServer
  def handle_call(:cleanup, _from, state) do
    IO.write([IO.ANSI.clear(), IO.ANSI.home()])
    {:reply, :ok, %{state | initialized: false}}
  end

  @impl GenServer
  def handle_cast(:render, %{initialized: false} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:render, reply_to_pid_for_signal}, state) do
    component_ids = ComponentManager.get_render_queue()

    components =
      Enum.map(component_ids, &ComponentManager.get_component/1)
      |> Enum.reject(&is_nil(&1))

    buffer = Buffer.clear(state.buffer)

    buffer = Enum.reduce(components, buffer, &render_component/2)

    {buffer, should_render} = Buffer.swap_buffers(buffer)

    if should_render do
      damage = Buffer.get_damage(buffer)
      render_damage(damage)
    end

    if reply_to_pid_for_signal do
      send(reply_to_pid_for_signal, :render_cycle_complete)
    end

    {:noreply, %{state | buffer: buffer}}
  end

  @impl GenServer
  def handle_cast({:resize, width, height}, %{buffer: buffer} = state) do
    new_buffer = Buffer.resize(buffer, width, height)
    {:noreply, %{state | buffer: new_buffer}}
  end

  @impl GenServer
  def handle_info(
        {:event,
         %Raxol.Core.Events.Event{
           type: :window,
           data: %{action: :resize, width: w, height: h}
         }},
        state
      ) do
    GenServer.cast(self(), {:resize, w, h})
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:event, _event}, state) do
    {:noreply, state}
  end

  # Private Helpers

  defp get_terminal_size do
    case :io.columns() do
      {:ok, width} ->
        case :io.rows() do
          {:ok, height} -> {width, height}
          # Default size
          _ -> {80, 24}
        end

      _ ->
        # Default size
        {80, 24}
    end
  end

  defp render_component(component, buffer) do
    # Get component's view
    view = component.module.view(component.state)

    # Ensure view is correctly defined and contains the expected data
    if view && is_map(view) do
      # Convert view to buffer cells
      render_view(view, buffer)
    else
      buffer
    end
  end

  defp render_view(nil, buffer), do: buffer

  defp render_view(view, buffer) do
    case view do
      %{type: :text, content: content, position: {x, y}} ->
        render_text(content, {x, y}, buffer)

      %{type: :box, children: children} ->
        Enum.reduce(children, buffer, &render_view/2)

      _ ->
        buffer
    end
  end

  defp render_text(text, {x, y}, buffer) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, i}, acc ->
      Buffer.put_cell(acc, {x + i, y}, char)
    end)
  end

  defp render_damage(damage) do
    Enum.each(damage, &render_cell/1)
  end

  defp render_cell({{x, y}, cell}) do
    case cell do
      nil ->
        # Empty cell, just move cursor
        IO.write([IO.ANSI.cursor(y + 1, x + 1), " "])

      %{char: char, fg: fg, bg: bg, style: style} ->
        # Apply styles and write character
        styles = build_styles(fg, bg, style)

        IO.write([
          IO.ANSI.cursor(y + 1, x + 1),
          styles,
          char,
          IO.ANSI.reset()
        ])
    end
  end

  defp build_styles(fg, bg, style) do
    [
      if(fg, do: IO.ANSI.color(fg), else: []),
      if(bg, do: bg_to_ansi(bg), else: []),
      Enum.map(style, &style_to_ansi/1)
    ]
  end

  defp style_to_ansi(:bold), do: IO.ANSI.bright()
  defp style_to_ansi(:underline), do: IO.ANSI.underline()
  defp style_to_ansi(:italic), do: IO.ANSI.italic()
  defp style_to_ansi(_), do: []

  # Helper to convert background color atom/code to ANSI sequence
  defp bg_to_ansi(:black), do: IO.ANSI.color(40)
  defp bg_to_ansi(:red), do: IO.ANSI.color(41)
  defp bg_to_ansi(:green), do: IO.ANSI.color(42)
  defp bg_to_ansi(:yellow), do: IO.ANSI.color(43)
  defp bg_to_ansi(:blue), do: IO.ANSI.color(44)
  defp bg_to_ansi(:magenta), do: IO.ANSI.color(45)
  defp bg_to_ansi(:cyan), do: IO.ANSI.color(46)
  defp bg_to_ansi(:white), do: IO.ANSI.color(47)

  defp bg_to_ansi(code) when is_integer(code) and code >= 0 and code <= 7,
    do: IO.ANSI.color(code + 40)

  # Bright backgrounds
  defp bg_to_ansi(:bright_black), do: IO.ANSI.color(100)
  defp bg_to_ansi(:bright_red), do: IO.ANSI.color(101)
  defp bg_to_ansi(:bright_green), do: IO.ANSI.color(102)
  defp bg_to_ansi(:bright_yellow), do: IO.ANSI.color(103)
  defp bg_to_ansi(:bright_blue), do: IO.ANSI.color(104)
  defp bg_to_ansi(:bright_magenta), do: IO.ANSI.color(105)
  defp bg_to_ansi(:bright_cyan), do: IO.ANSI.color(106)
  defp bg_to_ansi(:bright_white), do: IO.ANSI.color(107)

  defp bg_to_ansi(code) when is_integer(code) and code >= 100 and code <= 107,
    do: IO.ANSI.color(code)

  # Default to no background color
  defp bg_to_ansi(_), do: []
end
