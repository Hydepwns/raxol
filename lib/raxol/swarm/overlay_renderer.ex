defmodule Raxol.Swarm.OverlayRenderer do
  @moduledoc """
  Composites multi-node state into cell tuples for rendering.

  Pure functional module. Takes tactical overlay state and renders it
  into a list of positioned cell tuples `{x, y, char, fg, bg, attrs}`.

  Staleness rendering: data older than 5s renders dimmed with "[stale]".
  Data older than 30s renders as "[OFFLINE]".
  """

  @stale_threshold_ms 5_000
  @offline_threshold_ms Raxol.Core.Defaults.health_check_interval_ms()

  @type cell ::
          {non_neg_integer(), non_neg_integer(), String.t(), atom(), atom(),
           map()}
  @type region ::
          {non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer()}

  @doc """
  Renders the full tactical overlay into cell tuples.

  Returns a list of `{x, y, char, fg, bg, attrs}` tuples.
  """
  @spec render_overlay(map(), keyword()) :: [cell()]
  def render_overlay(overlay_state, opts \\ []) do
    now = Keyword.get(opts, :now, System.monotonic_time(:millisecond))
    region = Keyword.get(opts, :region, {0, 0, 80, 24})

    entities = Map.get(overlay_state, :entities, %{})
    waypoints = Map.get(overlay_state, :waypoints, [])

    entity_cells = render_entities(entities, region, now)
    waypoint_cells = render_waypoints(waypoints, region)

    entity_cells ++ waypoint_cells
  end

  @doc """
  Renders a condensed wingmate summary for each connected node.

  Format per node: `[role] node_name  RTT:12ms  status`
  """
  @spec render_wingmate_summary(region(), [map()], keyword()) :: [cell()]
  def render_wingmate_summary({x, y, w, _h}, node_statuses, opts \\ []) do
    now = Keyword.get(opts, :now, System.monotonic_time(:millisecond))

    node_statuses
    |> Enum.with_index()
    |> Enum.flat_map(fn {node_status, idx} ->
      render_wingmate_line(x, y + idx, w, node_status, now)
    end)
  end

  @doc """
  Renders comms link quality per node.

  Format per node: `node_name  [====]  12ms`
  """
  @spec render_comms_status(region(), %{node() => map()}) :: [cell()]
  def render_comms_status({x, y, w, _h}, links) do
    links
    |> Enum.with_index()
    |> Enum.flat_map(fn {{node, link_info}, idx} ->
      render_comms_line(x, y + idx, w, node, link_info)
    end)
  end

  # -- Private: Entity rendering --

  defp render_entities(entities, {rx, ry, rw, rh}, now) do
    Enum.flat_map(entities, fn {_id, entity} ->
      age_ms = now - Map.get(entity, :last_updated, now)
      {fg, bg, suffix} = staleness_style(age_ms)
      label = format_entity_label(entity, suffix)

      {ex, ey} = screen_pos(entity, {rx, ry, rw, rh})

      if in_bounds?({ex, ey}, {rx, ry, rw, rh}) do
        string_to_cells(ex, ey, label, fg, bg)
      else
        []
      end
    end)
  end

  defp render_waypoints(waypoints, {rx, ry, rw, rh}) do
    Enum.flat_map(waypoints, fn waypoint ->
      label = "[W] #{Map.get(waypoint, :label, "?")}"
      {wx, wy} = screen_pos(waypoint, {rx, ry, rw, rh})

      if in_bounds?({wx, wy}, {rx, ry, rw, rh}) do
        string_to_cells(wx, wy, label, :cyan, :default)
      else
        []
      end
    end)
  end

  # -- Private: Wingmate summary --

  defp render_wingmate_line(x, y, w, node_status, now) do
    %{
      node: node_name,
      role: role,
      avg_rtt_ms: rtt,
      last_seen: last_seen,
      status: status
    } =
      Map.merge(
        %{
          node: :unknown,
          role: :wingmate,
          avg_rtt_ms: 0.0,
          last_seen: now,
          status: :healthy
        },
        node_status
      )

    node_name = node_name |> to_string() |> String.slice(0, 15)
    rtt = Float.round(rtt, 1)
    age_ms = now - last_seen
    {fg, _bg, suffix} = staleness_style(age_ms)

    line =
      "#{role_badge(role)} #{node_name}  RTT:#{rtt}ms  #{status}#{suffix}"
      |> String.pad_trailing(w)
      |> String.slice(0, w)

    string_to_cells(x, y, line, fg, :default)
  end

  # -- Private: Comms status --

  defp render_comms_line(x, y, w, node, link_info) do
    %{quality: quality, rtt_ms: rtt} =
      Map.merge(%{quality: :disconnected, rtt_ms: 0.0}, link_info)

    node_name = to_string(node) |> String.slice(0, 15)
    rtt = Float.round(rtt, 1)
    fg = quality_color(quality)

    line =
      "#{node_name}  #{quality_bar(quality)}  #{rtt}ms"
      |> String.pad_trailing(w)
      |> String.slice(0, w)

    string_to_cells(x, y, line, fg, :default)
  end

  # -- Private: Staleness --

  defp staleness_style(age_ms) when age_ms >= @offline_threshold_ms do
    {:red, :default, " [OFFLINE]"}
  end

  defp staleness_style(age_ms) when age_ms >= @stale_threshold_ms do
    {:yellow, :default, " [stale]"}
  end

  defp staleness_style(_age_ms) do
    {:white, :default, ""}
  end

  # -- Private: Bounds --

  defp in_bounds?({px, py}, {rx, ry, rw, rh}) do
    px >= rx and px < rx + rw and py >= ry and py < ry + rh
  end

  # -- Private: Helpers --

  defp format_entity_label(entity, suffix) do
    id = Map.get(entity, :id, :unknown)
    status = Map.get(entity, :status, :active) |> status_char()
    "#{status}#{id}#{suffix}"
  end

  defp status_char(:active), do: "* "
  defp status_char(:damaged), do: "! "
  defp status_char(:offline), do: "x "
  defp status_char(_), do: "? "

  defp role_badge(:commander), do: "[C]"
  defp role_badge(:wingmate), do: "[W]"
  defp role_badge(:observer), do: "[O]"
  defp role_badge(:relay), do: "[R]"
  defp role_badge(_), do: "[?]"

  defp quality_bar(:excellent), do: "[====]"
  defp quality_bar(:good), do: "[=== ]"
  defp quality_bar(:degraded), do: "[==  ]"
  defp quality_bar(:poor), do: "[=   ]"
  defp quality_bar(:disconnected), do: "[    ]"

  defp quality_color(:excellent), do: :green
  defp quality_color(:good), do: :green
  defp quality_color(:degraded), do: :yellow
  defp quality_color(:poor), do: :red
  defp quality_color(:disconnected), do: :red

  defp screen_pos(item, {rx, ry, rw, rh}) do
    {px, py, _pz} = Map.get(item, :position, {0.0, 0.0, 0.0})
    {rx + round(px * (rw - 1)), ry + round(py * (rh - 1))}
  end

  defp string_to_cells(x, y, string, fg, bg) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.map(fn {char, offset} ->
      {x + offset, y, char, fg, bg, %{}}
    end)
  end
end
