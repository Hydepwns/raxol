defmodule Raxol.LiveView.CockpitComponent do
  @moduledoc """
  Multi-pane LiveView component for the AGI Cockpit.

  Renders multiple terminal panes in a CSS grid layout. Each pane displays
  a `TerminalComponent` bound to an agent's buffer. The focused pane is
  highlighted with a border accent.

  ## Usage

      <.live_component
        module={Raxol.LiveView.CockpitComponent}
        id="cockpit"
        panes={@panes}
        focused={@focused_pane}
        pilot_mode={@pilot_mode}
        columns={2}
        theme={:synthwave84}
      />

  ## Pane Format

  Each pane in the `panes` map:

      %{
        agent_id => %{
          label: "Scout Agent",
          buffer: buffer_map,       # TerminalComponent buffer format
          status: :thinking,        # agent status atom
          dimensions: %{width: 80, height: 24}
        }
      }
  """

  if Code.ensure_loaded?(Phoenix.LiveComponent) do
    use Phoenix.LiveComponent

    @default_columns 2
    @focused_border_color "#ff00ff"
    @default_border_color "#333333"
    @status_bar_height_px 24

    @impl true
    def mount(socket) do
      {:ok, socket}
    end

    @impl true
    def update(assigns, socket) do
      panes = Map.get(assigns, :panes, %{})
      focused = Map.get(assigns, :focused)
      pilot_mode = Map.get(assigns, :pilot_mode, :observe)
      columns = Map.get(assigns, :columns, @default_columns)
      theme = Map.get(assigns, :theme, :synthwave84)

      {:ok,
       socket
       |> assign(:id, assigns.id)
       |> assign(:panes, panes)
       |> assign(:focused, focused)
       |> assign(:pilot_mode, pilot_mode)
       |> assign(:columns, columns)
       |> assign(:theme, theme)
       |> assign(:focused_border_color, @focused_border_color)
       |> assign(:default_border_color, @default_border_color)
       |> assign(:status_bar_height_px, @status_bar_height_px)}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div
        id={"cockpit-#{@id}"}
        class="raxol-cockpit"
        phx-window-keydown="cockpit_keydown"
        phx-target={@myself}
      >
        <style>
          .raxol-cockpit {
            display: grid;
            grid-template-columns: repeat(<%= @columns %>, 1fr);
            gap: 4px;
            padding: 4px;
            background: #0a0a0a;
            height: 100vh;
            box-sizing: border-box;
          }

          .raxol-pane {
            display: flex;
            flex-direction: column;
            border: 2px solid <%= @default_border_color %>;
            border-radius: 4px;
            overflow: hidden;
            min-height: 0;
          }

          .raxol-pane.focused {
            border-color: <%= @focused_border_color %>;
            box-shadow: 0 0 8px <%= @focused_border_color %>44;
          }

          .raxol-pane.taken-over {
            border-color: #ff4444;
            box-shadow: 0 0 12px #ff444466;
          }

          .raxol-pane-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 2px 8px;
            background: #1a1a1a;
            font-family: monospace;
            font-size: 12px;
            color: #888;
            height: <%= @status_bar_height_px %>px;
            flex-shrink: 0;
          }

          .raxol-pane-header .label {
            color: #ccc;
            font-weight: bold;
          }

          .raxol-pane-header .status {
            font-size: 11px;
          }

          .raxol-pane-header .status.thinking { color: #ffcc00; }
          .raxol-pane-header .status.acting { color: #00ff88; }
          .raxol-pane-header .status.waiting { color: #666; }
          .raxol-pane-header .status.paused { color: #ff8800; }
          .raxol-pane-header .status.taken_over { color: #ff4444; }

          .raxol-pane-body {
            flex: 1;
            min-height: 0;
            overflow: hidden;
          }

          .raxol-cockpit-status {
            grid-column: 1 / -1;
            padding: 4px 8px;
            background: #111;
            font-family: monospace;
            font-size: 12px;
            color: #888;
            display: flex;
            justify-content: space-between;
          }

          .raxol-cockpit-status .mode { color: #ccc; }
          .raxol-cockpit-status .mode.takeover { color: #ff4444; }
        </style>

        <!-- Panes -->
        <%= for {pane_id, pane} <- @panes do %>
          <div class={pane_classes(pane_id, @focused, @pilot_mode)}>
            <div class="raxol-pane-header">
              <span class="label"><%= pane_label(pane_id, pane) %></span>
              <span class={"status #{pane_status(pane)}"}><%= pane_status(pane) %></span>
            </div>
            <div class="raxol-pane-body">
              <%= if Map.get(pane, :buffer) do %>
                <.live_component
                  module={Raxol.LiveView.TerminalComponent}
                  id={"terminal-#{pane_id}"}
                  buffer={pane.buffer}
                  theme={@theme}
                  width={get_in(pane, [:dimensions, :width]) || 80}
                  height={get_in(pane, [:dimensions, :height]) || 24}
                />
              <% else %>
                <div style="padding: 1rem; color: #666; font-family: monospace;">
                  No buffer attached
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Status Bar -->
        <div class="raxol-cockpit-status">
          <span>
            Agents: <%= map_size(@panes) %>
            | Focused: <%= @focused || "none" %>
          </span>
          <span class={"mode #{if @pilot_mode == :takeover, do: "takeover"}"}>
            Mode: <%= @pilot_mode %>
          </span>
        </div>
      </div>
      """
    end

    @impl true
    def handle_event("cockpit_keydown", %{"key" => key}, socket) do
      send(self(), {:cockpit_keydown, socket.assigns.id, key})
      {:noreply, socket}
    end

    defp pane_classes(pane_id, focused, pilot_mode) do
      base = ["raxol-pane"]

      base =
        if pane_id == focused do
          if pilot_mode == :takeover do
            ["taken-over", "focused" | base]
          else
            ["focused" | base]
          end
        else
          base
        end

      Enum.join(base, " ")
    end

    defp pane_label(pane_id, pane) do
      Map.get(pane, :label) || to_string(pane_id)
    end

    defp pane_status(pane) do
      pane
      |> Map.get(:status, :waiting)
      |> to_string()
    end
  end
end
