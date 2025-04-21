defmodule Raxol.Renderer do
  @moduledoc """
  The Renderer module handles drawing UI elements to the terminal.

  This module translates the virtual DOM representation of the UI
  into actual terminal output using rex_termbox.
  """

  use GenServer

  alias Raxol.Renderer.Layout
  alias ExTermbox.Bindings
  alias ExTermbox.Constants

  # Client API

  @doc """
  Starts a new renderer process.

  ## Options

  * `:fps` - Target frames per second (default: 60)
  * `:debug` - Enable debug mode (default: false)
  """
  def start_link(options \\ %{}) do
    GenServer.start_link(__MODULE__, options)
  end

  @doc """
  Renders a view to the terminal.
  """
  def render(pid, view) do
    GenServer.cast(pid, {:render, view})
  end

  # Server callbacks

  @impl true
  def init(options) do
    case Bindings.init() do
      :ok ->
        state = %{
          fps: Map.get(options, :fps, 60),
          debug: Map.get(options, :debug, false),
          last_render: nil,
          render_count: 0,
          last_dimensions: get_terminal_dimensions()
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, {:failed_to_initialize_termbox, reason}}
    end
  end

  @impl true
  def handle_cast({:render, view}, state) do
    dimensions = get_terminal_dimensions()

    should_render =
      state.last_render != view ||
        state.last_dimensions != dimensions

    if should_render do
      _ = Bindings.clear()
      _ = render_view(view, dimensions)
      _ = Bindings.present()

      state = %{
        state
        | last_render: view,
          render_count: state.render_count + 1,
          last_dimensions: dimensions
      }

      if state.debug do
        IO.puts("Rendered frame ##{state.render_count}")
      end

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, _state) do
    Bindings.shutdown()
    IO.puts("Termbox shut down. Reason: #{inspect(reason)}")
    :ok
  end

  # Private functions

  defp get_terminal_dimensions do
    case {Bindings.width(), Bindings.height()} do
      {{:ok, w}, {:ok, h}} ->
        %{width: w, height: h}

      {{:error, reason}, _} ->
        raise "Failed to get terminal width: #{inspect(reason)}"

      {_, {:error, reason}} ->
        raise "Failed to get terminal height: #{inspect(reason)}"
    end
  end

  defp render_view(view, dimensions) do
    # Apply layouts to get absolute positions
    positioned_elements = Layout.apply_layout(view, dimensions)

    # Draw each element at its calculated position
    Enum.each(positioned_elements, &draw_element/1)
  end

  defp draw_element(%{type: :text, x: x, y: y, text: text, attrs: attrs}) do
    fg = parse_color(attrs.fg)
    bg = parse_color(attrs.bg)

    # Combine attributes using Constants module
    attr = 0

    attr =
      if Map.get(attrs, :bold, false),
        do: Bitwise.bor(attr, Constants.attribute(:bold)),
        else: attr

    attr =
      if Map.get(attrs, :underline, false),
        do: Bitwise.bor(attr, Constants.attribute(:underline)),
        else: attr

    attr =
      if Map.get(attrs, :reverse, false),
        do: Bitwise.bor(attr, Constants.attribute(:reverse)),
        else: attr

    fg_attr = Bitwise.bor(fg, attr)

    # Draw the text character by character
    _ =
      Enum.reduce(String.graphemes(text), x, fn grapheme, current_x ->
        <<char::utf8, _rest::binary>> = grapheme
        _ = Bindings.change_cell(current_x, y, char, fg_attr, bg)
        # Increment by 1 for now
        current_x + 1
      end)
  end

  defp draw_element(%{
         type: :box,
         x: x,
         y: y,
         width: w,
         height: h,
         attrs: attrs
       }) do
    fg = parse_color(attrs.fg)
    bg = parse_color(attrs.bg)

    # Combine attributes using Constants module
    attr = 0

    attr =
      if Map.get(attrs, :bold, false),
        do: Bitwise.bor(attr, Constants.attribute(:bold)),
        else: attr

    attr =
      if Map.get(attrs, :underline, false),
        do: Bitwise.bor(attr, Constants.attribute(:underline)),
        else: attr

    attr =
      if Map.get(attrs, :reverse, false),
        do: Bitwise.bor(attr, Constants.attribute(:reverse)),
        else: attr

    fg_attr = Bitwise.bor(fg, attr)
    bg_attr = bg

    # Get border style
    border_style = Map.get(attrs, :border_style, :normal)

    {h_char, v_char, tl_char, tr_char, bl_char, br_char} =
      get_border_chars(border_style)

    # Draw lines
    for dx <- 0..(w - 1) do
      _ = Bindings.change_cell(x + dx, y, h_char, fg_attr, bg_attr)
      _ = Bindings.change_cell(x + dx, y + h - 1, h_char, fg_attr, bg_attr)
    end

    for dy <- 1..(h - 2) do
      _ = Bindings.change_cell(x, y + dy, v_char, fg_attr, bg_attr)
      _ = Bindings.change_cell(x + w - 1, y + dy, v_char, fg_attr, bg_attr)
    end

    _ = Bindings.change_cell(x, y, tl_char, fg_attr, bg_attr)
    _ = Bindings.change_cell(x + w - 1, y, tr_char, fg_attr, bg_attr)
    _ = Bindings.change_cell(x, y + h - 1, bl_char, fg_attr, bg_attr)
    _ = Bindings.change_cell(x + w - 1, y + h - 1, br_char, fg_attr, bg_attr)

    # Fill box
    fill = Map.get(attrs, :fill, true)
    # Use ?\s for space character
    fill_char = Map.get(attrs, :fill_char, ?\s)

    if fill do
      for dy <- 1..(h - 2), dx <- 1..(w - 2) do
        _ = Bindings.change_cell(x + dx, y + dy, fill_char, fg_attr, bg_attr)
      end
    end
  end

  defp draw_element(_) do
    # Ignore unsupported elements
  end

  defp get_border_chars(:normal), do: {?─, ?│, ?┌, ?┐, ?└, ?┘}
  defp get_border_chars(:thick), do: {?━, ?┃, ?┏, ?┓, ?┗, ?┛}
  defp get_border_chars(:double), do: {?═, ?║, ?╔, ?╗, ?╚, ?╝}
  defp get_border_chars(:rounded), do: {?─, ?│, ?╭, ?╮, ?╰, ?╯}
  # Default to normal
  defp get_border_chars(_), do: {?─, ?│, ?┌, ?┐, ?└, ?┘}

  defp parse_color(:default), do: Constants.color(:default)
  defp parse_color(:black), do: Constants.color(:black)
  defp parse_color(:red), do: Constants.color(:red)
  defp parse_color(:green), do: Constants.color(:green)
  defp parse_color(:yellow), do: Constants.color(:yellow)
  defp parse_color(:blue), do: Constants.color(:blue)
  defp parse_color(:magenta), do: Constants.color(:magenta)
  defp parse_color(:cyan), do: Constants.color(:cyan)
  defp parse_color(:white), do: Constants.color(:white)
  defp parse_color(:light_black), do: Constants.color(:black)
  defp parse_color(:light_red), do: Constants.color(:red)
  defp parse_color(:light_green), do: Constants.color(:green)
  defp parse_color(:light_yellow), do: Constants.color(:yellow)
  defp parse_color(:light_blue), do: Constants.color(:blue)
  defp parse_color(:light_magenta), do: Constants.color(:magenta)
  defp parse_color(:light_cyan), do: Constants.color(:cyan)
  defp parse_color(:light_white), do: Constants.color(:white)
  defp parse_color(:gray), do: Constants.color(:black)
  defp parse_color(:dark_gray), do: Constants.color(:black)
  # Assume direct 256 color index
  defp parse_color(n) when is_integer(n) and n >= 0 and n <= 255, do: n
  # Default
  defp parse_color(_), do: Constants.color(:default)
end
