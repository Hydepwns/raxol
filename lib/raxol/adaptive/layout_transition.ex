defmodule Raxol.Adaptive.LayoutTransition do
  @moduledoc """
  Pure functional layout interpolation between two layouts.

  Lerps pane positions and sizes. Snaps z_order and hidden lists.
  Supports linear, ease_in_out, and ease_out easing curves.
  """

  @type pane_spec :: %{
          id: atom(),
          position: {number(), number()},
          size: {number(), number()},
          z_order: integer()
        }

  @type layout_spec :: %{
          panes: [pane_spec()],
          focus: atom() | nil,
          hidden: [atom()]
        }

  @type easing :: :linear | :ease_in_out | :ease_out

  @type transition :: %{
          from: layout_spec(),
          to: layout_spec(),
          duration_ms: pos_integer(),
          easing: easing(),
          started_at: integer(),
          progress: float()
        }

  @spec start(layout_spec(), layout_spec(), keyword()) :: transition()
  def start(from, to, opts \\ []) do
    %{
      from: from,
      to: to,
      duration_ms: Keyword.get(opts, :duration_ms, 300),
      easing: Keyword.get(opts, :easing, :ease_in_out),
      started_at: System.monotonic_time(:millisecond),
      progress: 0.0
    }
  end

  @spec tick(transition(), integer()) ::
          {:in_progress, layout_spec(), transition()}
          | {:done, layout_spec()}
  def tick(transition, elapsed_ms) do
    raw_progress = min(elapsed_ms / transition.duration_ms, 1.0)
    t = apply_easing(raw_progress, transition.easing)

    if raw_progress >= 1.0 do
      {:done, transition.to}
    else
      layout = interpolate_layout(transition.from, transition.to, t)
      updated = %{transition | progress: raw_progress}
      {:in_progress, layout, updated}
    end
  end

  @spec cancel(transition()) :: layout_spec()
  def cancel(transition) do
    interpolate_layout(transition.from, transition.to, transition.progress)
  end

  @spec interpolate_layout(layout_spec(), layout_spec(), float()) ::
          layout_spec()
  def interpolate_layout(from, to, t) do
    from_panes = Map.new(from.panes, fn p -> {p.id, p} end)
    to_panes = Map.new(to.panes, fn p -> {p.id, p} end)

    all_ids =
      MapSet.union(
        MapSet.new(Map.keys(from_panes)),
        MapSet.new(Map.keys(to_panes))
      )

    panes =
      Enum.map(all_ids, fn id ->
        case {Map.get(from_panes, id), Map.get(to_panes, id)} do
          {nil, to_pane} -> to_pane
          {from_pane, nil} -> from_pane
          {from_pane, to_pane} -> interpolate_pane(from_pane, to_pane, t)
        end
      end)

    %{
      panes: panes,
      focus: if(t >= 0.5, do: to.focus, else: from.focus),
      hidden: if(t >= 0.5, do: to.hidden, else: from.hidden)
    }
  end

  # -- Private --

  defp interpolate_pane(from, to, t) do
    {fx, fy} = from.position
    {tx, ty} = to.position
    {fw, fh} = from.size
    {tw, th} = to.size

    %{
      id: from.id,
      position: {lerp(fx, tx, t), lerp(fy, ty, t)},
      size: {lerp(fw, tw, t), lerp(fh, th, t)},
      z_order: if(t >= 0.5, do: to.z_order, else: from.z_order)
    }
  end

  defp lerp(a, b, t), do: a + (b - a) * t

  defp apply_easing(t, :linear), do: t
  defp apply_easing(t, :ease_out), do: 1.0 - :math.pow(1.0 - t, 2)

  defp apply_easing(t, :ease_in_out) do
    if t < 0.5 do
      2.0 * t * t
    else
      1.0 - :math.pow(-2.0 * t + 2.0, 2) / 2.0
    end
  end
end
