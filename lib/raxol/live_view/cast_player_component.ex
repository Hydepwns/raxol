defmodule Raxol.LiveView.CastPlayerComponent do
  @moduledoc """
  LiveView component for playing `.cast` (asciicast v2) recordings in the browser.

  Parses ANSI output into displayable HTML lines and drives playback via ticks.

  ## Usage

      <.live_component
        module={Raxol.LiveView.CastPlayerComponent}
        id="player"
        cast_path="priv/recordings/demo.cast"
      />

      <.live_component
        module={Raxol.LiveView.CastPlayerComponent}
        id="player"
        session={@session}
        speed={2.0}
        autoplay={true}
      />

  ## Parent LiveView

  The parent must forward tick messages:

      def handle_info({:cast_player_tick, id}, socket) do
        send_update(Raxol.LiveView.CastPlayerComponent, id: id, tick: true)
        {:noreply, socket}
      end
  """

  if Code.ensure_loaded?(Phoenix.LiveComponent) do
    use Phoenix.LiveComponent

    import Phoenix.HTML, only: [raw: 1]

    alias Raxol.Recording.{Asciicast, Session}

    @tick_interval_ms 16

    @impl true
    def mount(socket) do
      {:ok,
       assign(socket,
         session: nil,
         events: [],
         index: 0,
         playing: false,
         speed: 1.0,
         controls: true,
         autoplay: false,
         lines: [],
         width: 80,
         height: 24,
         elapsed_us: 0,
         total_us: 0
       )}
    end

    @impl true
    def update(%{tick: true}, socket) do
      {:ok, advance_playback(socket)}
    end

    @impl true
    def update(assigns, socket) do
      socket =
        assign(socket, Map.take(assigns, [:id, :speed, :controls, :autoplay]))

      socket =
        cond do
          Map.has_key?(assigns, :session) and
              assigns[:session] != socket.assigns.session ->
            load_session(socket, assigns.session)

          Map.has_key?(assigns, :cast_path) and is_nil(socket.assigns.session) ->
            case Asciicast.read(assigns.cast_path) do
              {:ok, session} -> load_session(socket, session)
              {:error, _reason} -> socket
            end

          true ->
            socket
        end

      socket =
        if socket.assigns.autoplay and not socket.assigns.playing do
          schedule_tick(socket)
          assign(socket, playing: true)
        else
          socket
        end

      {:ok, socket}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <div class="cast-player" id={@id}>
        <div class="cast-terminal" style={"font-family: 'Fira Code', 'SF Mono', monospace; background: #1a1a2e; color: #e0e0e0; padding: 8px; border-radius: 4px; overflow: hidden; line-height: 1.2;"}>
          <%= for line <- @lines do %>
            <div style="white-space: pre; height: 1.2em;"><%= raw(line) %></div>
          <% end %>
        </div>
        <%= if @controls do %>
          <div style="display: flex; align-items: center; gap: 8px; padding: 4px 0; font-family: sans-serif; font-size: 12px; color: #999;">
            <button phx-click="toggle_play" phx-target={@myself} style="cursor: pointer; background: none; border: 1px solid #666; color: #ccc; padding: 2px 8px; border-radius: 3px;">
              <%= if @playing, do: "||", else: ">" %>
            </button>
            <span><%= format_time(@elapsed_us) %> / <%= format_time(@total_us) %></span>
            <input type="range" min="0" max={@total_us} value={@elapsed_us}
                   phx-change="seek" phx-target={@myself}
                   style="flex: 1;" />
            <select phx-change="set_speed" phx-target={@myself} style="background: #222; color: #ccc; border: 1px solid #666; border-radius: 3px;">
              <%= for s <- [0.25, 0.5, 1.0, 2.0, 4.0, 8.0] do %>
                <option value={s} selected={s == @speed}><%= s %>x</option>
              <% end %>
            </select>
          </div>
        <% end %>
      </div>
      """
    end

    @impl true
    def handle_event("toggle_play", _params, socket) do
      socket =
        if socket.assigns.playing do
          assign(socket, playing: false)
        else
          schedule_tick(socket)
          assign(socket, playing: true)
        end

      {:noreply, socket}
    end

    @impl true
    def handle_event("seek", %{"value" => value}, socket) do
      case Integer.parse(value) do
        {target_us, _} -> {:noreply, seek_to(socket, target_us)}
        :error -> {:noreply, socket}
      end
    end

    @impl true
    def handle_event("set_speed", %{"value" => value}, socket) do
      {speed, _} = Float.parse(value)
      {:noreply, assign(socket, speed: speed)}
    end

    # -- Private --

    defp load_session(socket, %Session{} = session) do
      total_us =
        case List.last(session.events) do
          {us, _, _} -> us
          nil -> 0
        end

      assign(socket,
        session: session,
        events: session.events,
        index: 0,
        width: session.width,
        height: session.height,
        total_us: total_us,
        elapsed_us: 0,
        lines: List.duplicate("", session.height)
      )
    end

    defp schedule_tick(socket) do
      Process.send_after(
        self(),
        {:cast_player_tick, socket.assigns.id},
        @tick_interval_ms
      )
    end

    defp advance_playback(socket) do
      %{events: events, index: idx, elapsed_us: elapsed_us, speed: speed} =
        socket.assigns

      if idx >= length(events) do
        assign(socket, playing: false)
      else
        new_elapsed = elapsed_us + round(@tick_interval_ms * 1_000 * speed)

        {new_idx, lines} =
          render_events_up_to(events, idx, new_elapsed, socket.assigns)

        if socket.assigns.playing do
          schedule_tick(socket)
        end

        assign(socket,
          index: new_idx,
          elapsed_us: min(new_elapsed, socket.assigns.total_us),
          lines: lines
        )
      end
    end

    defp seek_to(socket, target_us) do
      lines = List.duplicate("", socket.assigns.height)

      {new_idx, lines} =
        render_events_up_to(socket.assigns.events, 0, target_us, %{
          socket.assigns
          | lines: lines
        })

      assign(socket, index: new_idx, elapsed_us: target_us, lines: lines)
    end

    defp render_events_up_to(events, idx, target_us, assigns) do
      events
      |> Enum.drop(idx)
      |> Enum.reduce_while({idx, assigns.lines}, fn {event_us, type, data},
                                                    {i, acc_lines} ->
        cond do
          event_us > target_us ->
            {:halt, {i, acc_lines}}

          type == :output ->
            {:cont, {i + 1, apply_output(acc_lines, data)}}

          true ->
            {:cont, {i + 1, acc_lines}}
        end
      end)
    end

    defp apply_output(lines, data) do
      output_lines = String.split(data, ~r/\r?\n/, parts: :infinity)

      case output_lines do
        [single] ->
          last_idx = length(lines) - 1
          updated = (Enum.at(lines, last_idx) || "") <> escape_html(single)
          List.replace_at(lines, last_idx, updated)

        [first | rest] ->
          last_idx = length(lines) - 1

          lines =
            List.replace_at(
              lines,
              last_idx,
              (Enum.at(lines, last_idx) || "") <> escape_html(first)
            )

          Enum.reduce(rest, lines, fn line, acc ->
            Enum.drop(acc, 1) ++ [escape_html(line)]
          end)
      end
    end

    defp escape_html(str) do
      str
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
      |> strip_ansi()
    end

    defp strip_ansi(str) do
      String.replace(str, ~r/\e\[[0-9;]*[a-zA-Z]/, "")
    end

    defp format_time(us) do
      total_s = div(us, 1_000_000)
      min = div(total_s, 60)
      sec = rem(total_s, 60)
      "#{min}:#{String.pad_leading(Integer.to_string(sec), 2, "0")}"
    end
  end
end
