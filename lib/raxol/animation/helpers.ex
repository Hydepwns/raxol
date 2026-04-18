defmodule Raxol.Animation.Helpers do
  @moduledoc """
  View DSL helpers for attaching animation hints to elements.

  These are pure functions that attach metadata -- they do not start
  server-side animations. Starting animations is done in `update/2`
  via `Raxol.Animation.Framework.start_animation/3`.

  ## Usage

      import Raxol.Animation.Helpers

      def view(model) do
        box(id: "panel", style: %{opacity: model.panel_opacity})
        |> animate(property: :opacity, to: 1.0, duration: 300)
      end
  """

  alias Raxol.Animation.Hint

  @doc """
  Attaches an animation hint to a view element.

  The hint describes the animation shape so surface renderers can
  optionally accelerate (e.g., CSS transitions in LiveView).

  ## Options

    * `:property` - (required) The property being animated
      (`:opacity`, `:color`, `:bg`, `:width`, `:height`, `:transform`)
    * `:from` - Starting value
    * `:to` - Target value
    * `:duration` - Duration in milliseconds (default: 300)
    * `:easing` - Easing function atom (default: `:ease_out_cubic`)
    * `:delay` - Delay in milliseconds (default: 0)

  ## Examples

      box(id: "card")
      |> animate(property: :opacity, from: 0.0, to: 1.0, duration: 500)

      text("Hello")
      |> animate(property: :color, to: :cyan, easing: :ease_in_out_cubic)
      |> animate(property: :opacity, to: 1.0, duration: 200)
  """
  @spec animate(map(), keyword()) :: map()
  def animate(element, opts) when is_map(element) and is_list(opts) do
    hint = %Hint{
      property: Keyword.fetch!(opts, :property),
      from: Keyword.get(opts, :from),
      to: Keyword.get(opts, :to),
      duration_ms: Keyword.get(opts, :duration, 300),
      easing: Keyword.get(opts, :easing, :ease_out_cubic),
      delay_ms: Keyword.get(opts, :delay, 0)
    }

    existing = Map.get(element, :animation_hints, [])
    Map.put(element, :animation_hints, [hint | existing])
  end

  @doc """
  Applies the same animation hint to a list of elements with staggered delays.

  Each element gets the same animation but with an incrementing `delay_ms`
  offset, creating an entrance cascade effect.

  ## Options

  All options from `animate/2` plus:

    * `:offset` - Delay between each element in milliseconds (default: 50)

  ## Examples

      boxes = [
        box(id: "a", style: %{opacity: 0}),
        box(id: "b", style: %{opacity: 0}),
        box(id: "c", style: %{opacity: 0})
      ]

      stagger(boxes, property: :opacity, to: 1.0, duration: 300, offset: 100)
      # a: delay 0ms, b: delay 100ms, c: delay 200ms
  """
  @spec stagger([map()], keyword()) :: [map()]
  def stagger(elements, opts) when is_list(elements) and is_list(opts) do
    offset = Keyword.get(opts, :offset, 50)
    base_delay = Keyword.get(opts, :delay, 0)
    opts = Keyword.drop(opts, [:offset])

    elements
    |> Enum.with_index()
    |> Enum.map(fn {element, idx} ->
      animate(element, Keyword.put(opts, :delay, base_delay + idx * offset))
    end)
  end

  @doc """
  Chains multiple animations on a single element sequentially.

  Each animation's delay is computed from the cumulative duration of
  preceding animations, so they play one after another.

  ## Examples

      box(id: "card", style: %{opacity: 0})
      |> sequence([
        [property: :opacity, to: 1.0, duration: 300],
        [property: :bg, to: :cyan, duration: 200],
        [property: :width, to: 40, duration: 400]
      ])
      # opacity: delay 0, bg: delay 300, width: delay 500
  """
  @spec sequence(map(), [keyword()]) :: map()
  def sequence(element, animation_opts_list)
      when is_map(element) and is_list(animation_opts_list) do
    {result, _} =
      Enum.reduce(animation_opts_list, {element, 0}, fn opts,
                                                        {el, cumulative_delay} ->
        base_delay = Keyword.get(opts, :delay, 0)
        duration = Keyword.get(opts, :duration, 300)
        opts = Keyword.put(opts, :delay, cumulative_delay + base_delay)
        {animate(el, opts), cumulative_delay + base_delay + duration}
      end)

    result
  end
end
