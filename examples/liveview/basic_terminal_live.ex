defmodule Raxol.LiveView.Examples.BasicTerminalLive do
  @moduledoc """
  Basic example showing how to use Raxol.LiveView.TerminalComponent.

  This is a minimal working example that demonstrates:
  - Creating a terminal buffer
  - Rendering it with the TerminalComponent
  - Handling keyboard events
  - Updating the display

  ## Usage in router.ex

      live "/terminal", Raxol.LiveView.Examples.BasicTerminalLive

  ## What it does

  - Displays "Hello, Raxol!" message
  - Shows current time
  - Updates on keypress
  - Demonstrates styled text
  """

  use Phoenix.LiveView
  alias Raxol.LiveView.TerminalComponent

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:buffer, create_initial_buffer())
     |> assign(:key_count, 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="terminal-example">
      <h1>Raxol LiveView Basic Example</h1>

      <.live_component
        module={TerminalComponent}
        id="basic-terminal"
        buffer={@buffer}
        theme={:synthwave84}
        width={60}
        height={20}
        crt_mode={false}
        high_contrast={false}
        aria_label="Basic terminal example"
        on_keypress="handle_key"
      />

      <div class="instructions">
        <p>Press any key to update the terminal</p>
        <p>Keys pressed: <%= @key_count %></p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("handle_key", %{"key" => key}, socket) do
    new_count = socket.assigns.key_count + 1

    updated_buffer =
      create_updated_buffer(
        key,
        new_count,
        DateTime.utc_now()
      )

    {:noreply,
     socket
     |> assign(:buffer, updated_buffer)
     |> assign(:key_count, new_count)}
  end

  # Private Functions

  defp create_initial_buffer do
    lines = [
      create_line("┌────────────────────────────────────────────────────────┐"),
      create_line("│                                                        │"),
      create_line("│           Welcome to Raxol Terminal!                  │",
        bold: true
      ),
      create_line("│                                                        │"),
      create_line("│  This is a basic example of terminal rendering        │"),
      create_line("│  using Phoenix LiveView and Raxol.LiveView.           │"),
      create_line("│                                                        │"),
      create_line("│  Features:                                            │"),
      create_styled_line("│    • Real-time updates", :green),
      create_styled_line("│    • Keyboard events", :cyan),
      create_styled_line("│    • Styled text", :yellow),
      create_styled_line("│    • Box-drawing characters", :magenta),
      create_line("│                                                        │"),
      create_line("│  Press any key to see it in action!                   │"),
      create_line("│                                                        │"),
      create_line(
        "│  Time: #{format_time(DateTime.utc_now())}                                │"
      ),
      create_line("│  Keys pressed: 0                                       │"),
      create_line("│                                                        │"),
      create_line("└────────────────────────────────────────────────────────┘")
    ]

    # Add blank line at bottom
    lines = lines ++ [create_line("")]

    %{
      lines: lines,
      width: 60,
      height: 20
    }
  end

  defp create_updated_buffer(key, count, time) do
    lines = [
      create_line("┌────────────────────────────────────────────────────────┐"),
      create_line("│                                                        │"),
      create_line("│           Welcome to Raxol Terminal!                  │",
        bold: true
      ),
      create_line("│                                                        │"),
      create_line("│  This is a basic example of terminal rendering        │"),
      create_line("│  using Phoenix LiveView and Raxol.LiveView.           │"),
      create_line("│                                                        │"),
      create_line("│  Features:                                            │"),
      create_styled_line("│    • Real-time updates", :green),
      create_styled_line("│    • Keyboard events", :cyan),
      create_styled_line("│    • Styled text", :yellow),
      create_styled_line("│    • Box-drawing characters", :magenta),
      create_line("│                                                        │"),
      create_styled_line(
        "│  Last key: #{String.pad_trailing(key, 40)} │",
        :bright_green
      ),
      create_line("│                                                        │"),
      create_line(
        "│  Time: #{format_time(time)}                                │"
      ),
      create_line(
        "│  Keys pressed: #{String.pad_trailing(to_string(count), 36)} │"
      ),
      create_line("│                                                        │"),
      create_line("└────────────────────────────────────────────────────────┘")
    ]

    # Add blank line at bottom
    lines = lines ++ [create_line("")]

    %{
      lines: lines,
      width: 60,
      height: 20
    }
  end

  defp create_line(text, opts \\ []) do
    bold = Keyword.get(opts, :bold, false)

    cells =
      text
      |> String.graphemes()
      |> Enum.map(fn char ->
        %{
          char: char,
          style: %{
            bold: bold,
            italic: false,
            underline: false,
            reverse: false,
            fg_color: nil,
            bg_color: nil
          }
        }
      end)

    %{cells: cells}
  end

  defp create_styled_line(text, color) do
    cells =
      text
      |> String.graphemes()
      |> Enum.map(fn char ->
        %{
          char: char,
          style: %{
            bold: false,
            italic: false,
            underline: false,
            reverse: false,
            fg_color: color,
            bg_color: nil
          }
        }
      end)

    %{cells: cells}
  end

  defp format_time(datetime) do
    datetime
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0..7)
  end
end
