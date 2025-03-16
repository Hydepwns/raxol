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
  alias Raxol.Core.Events.{Event, Manager}
  alias Raxol.Core.Runtime.ComponentManager

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts \\ []) do
    GenServer.call(__MODULE__, {:init, opts})
  end

  def render do
    GenServer.cast(__MODULE__, :render)
  end

  def cleanup do
    GenServer.call(__MODULE__, :cleanup)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      buffer: nil,
      fps: 60,
      render_queue: [],
      initialized: false
    }}
  end

  @impl true
  def handle_call({:init, opts}, _from, state) do
    # Get terminal size
    {width, height} = get_terminal_size()
    
    # Create buffer with specified FPS
    fps = Keyword.get(opts, :fps, 60)
    buffer = Buffer.new(width, height, fps)
    
    # Set up window resize handling
    Manager.subscribe(fn
      %Event{type: :window, data: %{action: :resize, width: w, height: h}} ->
        handle_resize(w, h)
      _ ->
        :ok
    end)
    
    {:reply, :ok, %{state |
      buffer: buffer,
      fps: fps,
      initialized: true
    }}
  end

  @impl true
  def handle_call(:cleanup, _from, state) do
    # Clear screen and reset cursor
    IO.write([IO.ANSI.clear(), IO.ANSI.home()])
    {:reply, :ok, %{state | initialized: false}}
  end

  @impl true
  def handle_cast(:render, %{initialized: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:render, state) do
    # Get components that need rendering
    components = ComponentManager.get_render_queue()
    
    # Clear back buffer
    buffer = Buffer.clear(state.buffer)
    
    # Render each component to back buffer
    buffer = Enum.reduce(components, buffer, &render_component/2)
    
    # Try to swap buffers (respects FPS timing)
    {buffer, should_render} = Buffer.swap_buffers(buffer)
    
    if should_render do
      # Get damaged regions and update screen
      damage = Buffer.get_damage(buffer)
      render_damage(damage)
    end
    
    {:noreply, %{state | buffer: buffer}}
  end

  # Private Helpers

  defp get_terminal_size do
    case :io.columns() do
      {:ok, width} ->
        case :io.rows() do
          {:ok, height} -> {width, height}
          _ -> {80, 24}  # Default size
        end
      _ ->
        {80, 24}  # Default size
    end
  end

  defp handle_resize(width, height) do
    GenServer.cast(__MODULE__, {:resize, width, height})
  end

  defp render_component(component, buffer) do
    # Get component's view
    view = component.module.render(component.state)
    
    # Convert view to buffer cells
    render_view(view, buffer)
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
    Enum.each(damage, fn {{x, y}, cell} ->
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
    end)
  end

  defp build_styles(fg, bg, style) do
    [
      if(fg, do: IO.ANSI.color(fg), else: []),
      if(bg, do: IO.ANSI.background_color(bg), else: []),
      Enum.map(style, &style_to_ansi/1)
    ]
  end

  defp style_to_ansi(:bold), do: IO.ANSI.bright()
  defp style_to_ansi(:underline), do: IO.ANSI.underline()
  defp style_to_ansi(:italic), do: IO.ANSI.italic()
  defp style_to_ansi(_), do: []
end 