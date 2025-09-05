defmodule Raxol.Animation.CSSTransitions do
  @moduledoc """
  CSS-like declarative animation syntax for Raxol components.

  This module provides a familiar CSS-style API for defining animations directly
  on components using a declarative syntax similar to CSS transitions and animations.

  ## Examples

      # CSS-like transition syntax
      %{
        transition: "opacity 300ms ease-out, transform 500ms ease-in-out"
      }
      
      # CSS-like animation syntax  
      %{
        animation: "slideIn 1s ease-out forwards"
      }
      
      # Keyframe animations
      %{
        animation: "bounce 2s infinite",
        keyframes: %{
          "bounce" => %{
            "0%" => %{transform: "translateY(0)"},
            "50%" => %{transform: "translateY(-20px)"},
            "100%" => %{transform: "translateY(0)"}
          }
        }
      }
  """

  alias Raxol.Animation.Framework

  @doc """
  Parses a CSS transition string and creates corresponding animations.

  ## Examples

      iex> CSSTransitions.parse_transition("opacity 300ms ease-out")
      %{
        property: :opacity,
        duration: 300,
        easing: :ease_out,
        delay: 0
      }
      
      iex> CSSTransitions.parse_transition("all 500ms ease-in-out 100ms")
      %{
        property: :all,
        duration: 500,
        easing: :ease_in_out,
        delay: 100
      }
  """
  def parse_transition(transition_string) when is_binary(transition_string) do
    transition_string
    |> String.split(",")
    |> Enum.map(&parse_single_transition/1)
  end

  def parse_transition(transition_map) when is_map(transition_map),
    do: transition_map

  defp parse_single_transition(single_transition) do
    parts = single_transition |> String.trim() |> String.split(" ")

    {property, remaining} = extract_property(parts)
    {duration, remaining} = extract_duration(remaining)
    {easing, remaining} = extract_easing(remaining)
    {delay, _remaining} = extract_delay(remaining)

    %{
      property: property,
      duration: duration,
      easing: easing,
      delay: delay
    }
  end

  @doc """
  Parses CSS animation syntax and creates keyframe animations.

  ## Examples

      iex> CSSTransitions.parse_animation("slideIn 1s ease-out forwards")
      %{
        name: :slideIn,
        duration: 1000,
        easing: :ease_out,
        fill_mode: :forwards,
        iteration_count: 1,
        direction: :normal,
        delay: 0
      }
  """
  def parse_animation(animation_string) when is_binary(animation_string) do
    parts = animation_string |> String.trim() |> String.split(" ")

    {name, remaining} = extract_animation_name(parts)
    {duration, remaining} = extract_duration(remaining)
    {easing, remaining} = extract_easing(remaining)
    {delay, remaining} = extract_delay(remaining)
    {iteration_count, remaining} = extract_iteration_count(remaining)
    {direction, remaining} = extract_direction(remaining)
    {fill_mode, _remaining} = extract_fill_mode(remaining)

    %{
      name: name,
      duration: duration,
      easing: easing,
      delay: delay,
      iteration_count: iteration_count,
      direction: direction,
      fill_mode: fill_mode
    }
  end

  @doc """
  Creates a keyframe animation from CSS-like keyframe definitions.

  ## Examples

      iex> keyframes = %{
      ...>   "0%" => %{opacity: 0, transform: "translateX(-100px)"},
      ...>   "50%" => %{opacity: 0.5, transform: "translateX(0px)"},
      ...>   "100%" => %{opacity: 1, transform: "translateX(0px)"}
      ...> }
      iex> CSSTransitions.create_keyframe_animation(:slide_fade_in, keyframes, %{duration: 1000})
  """
  def create_keyframe_animation(name, keyframes, options \\ %{}) do
    processed_keyframes = process_keyframes(keyframes)
    duration = Map.get(options, :duration, 1000)
    easing = Map.get(options, :easing, :ease_out)

    Framework.create_animation(name, %{
      type: :keyframe,
      keyframes: processed_keyframes,
      duration: duration,
      easing: easing,
      interpolate_fn: &interpolate_keyframes/3
    })
  end

  @doc """
  Applies CSS-like transitions to a component's style changes.

  ## Examples

      # In a component's render function:
      style = %{
        opacity: if state.visible, do: 1.0, else: 0.0,
        transform: "translateY(\#{state.offset}px)",
        transition: "opacity 300ms ease-out, transform 500ms ease-in-out"
      }
      
      CSSTransitions.apply_transitions(style, element_id, previous_style)
  """
  def apply_transitions(new_style, element_id, previous_style \\ %{}) do
    transition_spec = Map.get(new_style, :transition)

    apply_transition_spec(
      transition_spec,
      new_style,
      element_id,
      previous_style
    )
  end

  defp apply_transition_spec(nil, new_style, _element_id, _previous_style),
    do: new_style

  defp apply_transition_spec(
         transition_spec,
         new_style,
         element_id,
         previous_style
       ) do
    transitions = parse_transition(transition_spec)

    Enum.each(transitions, fn transition ->
      property = transition.property

      process_property_transition(
        property,
        transition,
        new_style,
        element_id,
        previous_style
      )
    end)

    new_style
  end

  defp process_property_transition(
         :all,
         transition,
         new_style,
         element_id,
         previous_style
       ) do
    create_transition_if_changed(
      transition,
      new_style,
      element_id,
      previous_style
    )
  end

  defp process_property_transition(
         property,
         transition,
         new_style,
         element_id,
         previous_style
       ) do
    case Map.has_key?(new_style, property) do
      true ->
        create_transition_if_changed(
          transition,
          new_style,
          element_id,
          previous_style
        )

      false ->
        :ok
    end
  end

  defp create_transition_if_changed(
         transition,
         new_style,
         element_id,
         previous_style
       ) do
    property = transition.property
    old_value = Map.get(previous_style, property, get_default_value(property))
    new_value = Map.get(new_style, property)

    create_transition_for_values(
      old_value,
      new_value,
      element_id,
      property,
      transition
    )
  end

  defp create_transition_for_values(
         same_value,
         same_value,
         _element_id,
         _property,
         _transition
       ),
       do: :ok

  defp create_transition_for_values(
         old_value,
         new_value,
         element_id,
         property,
         transition
       ) do
    create_property_transition(
      element_id,
      property,
      old_value,
      new_value,
      transition
    )
  end

  # Private helper functions

  defp extract_property([property | rest]) do
    property_atom =
      case property do
        "all" -> :all
        prop -> String.to_atom(prop)
      end

    {property_atom, rest}
  end

  defp extract_property([]), do: {:all, []}

  defp extract_duration([duration_str | rest]) do
    parse_duration_value(duration_str, rest)
  end

  defp extract_duration([]), do: {300, []}

  defp extract_easing([easing_str | rest]) do
    easing_atom =
      case easing_str do
        "linear" -> :linear
        "ease" -> :ease_out_quad
        "ease-in" -> :ease_in_quad
        "ease-out" -> :ease_out_quad
        "ease-in-out" -> :ease_in_out_quad
        "ease-in-cubic" -> :ease_in_cubic
        "ease-out-cubic" -> :ease_out_cubic
        "ease-in-out-cubic" -> :ease_in_out_cubic
        "ease-in-back" -> :ease_in_back
        "ease-out-back" -> :ease_out_back
        "ease-in-out-back" -> :ease_in_out_back
        "ease-in-bounce" -> :ease_in_bounce
        "ease-out-bounce" -> :ease_out_bounce
        "ease-in-out-bounce" -> :ease_in_out_bounce
        "ease-in-elastic" -> :ease_in_elastic
        "ease-out-elastic" -> :ease_out_elastic
        "ease-in-out-elastic" -> :ease_in_out_elastic
        # Unknown easing, put back
        _ -> {:linear, [easing_str | rest]}
      end

    handle_easing_result(is_tuple(easing_atom), easing_atom, rest)
  end

  defp extract_easing([]), do: {:linear, []}

  defp extract_delay([delay_str | rest]) do
    parse_delay_value(delay_str, rest)
  end

  defp extract_delay([]), do: {0, []}

  defp extract_animation_name([name | rest]) do
    {String.to_atom(name), rest}
  end

  defp extract_animation_name([]), do: {:unnamed, []}

  defp extract_iteration_count([count_str | rest]) do
    case count_str do
      "infinite" ->
        {:infinite, rest}

      count ->
        case Integer.parse(count) do
          {num, ""} -> {num, rest}
          # Default count, put back
          _ -> {1, [count_str | rest]}
        end
    end
  end

  defp extract_iteration_count([]), do: {1, []}

  defp extract_direction([direction | rest]) do
    direction_atom =
      case direction do
        "normal" -> :normal
        "reverse" -> :reverse
        "alternate" -> :alternate
        "alternate-reverse" -> :alternate_reverse
        # Default direction, put back
        _ -> {:normal, [direction | rest]}
      end

    handle_direction_result(is_tuple(direction_atom), direction_atom, rest)
  end

  defp extract_direction([]), do: {:normal, []}

  defp extract_fill_mode([mode | rest]) do
    mode_atom =
      case mode do
        "none" -> :none
        "forwards" -> :forwards
        "backwards" -> :backwards
        "both" -> :both
        # Default fill mode, put back
        _ -> {:none, [mode | rest]}
      end

    handle_mode_result(is_tuple(mode_atom), mode_atom, rest)
  end

  defp extract_fill_mode([]), do: {:none, []}

  defp process_keyframes(keyframes) do
    keyframes
    |> Enum.map(fn {percentage, properties} ->
      progress = parse_percentage(percentage)
      {progress, properties}
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp parse_percentage(percentage_str) do
    percentage_str
    |> String.trim_trailing("%")
    |> String.to_integer()
    |> Kernel./(100)
  end

  defp interpolate_keyframes(progress, _params, keyframes) do
    # Find the two keyframes to interpolate between
    case find_keyframe_range(keyframes, progress) do
      {lower_keyframe, upper_keyframe, local_progress} ->
        interpolate_properties(lower_keyframe, upper_keyframe, local_progress)

      single_keyframe ->
        elem(single_keyframe, 1)
    end
  end

  defp find_keyframe_range(keyframes, progress) do
    keyframes
    |> Enum.reduce_while(nil, fn {keyframe_progress, properties}, acc ->
      check_keyframe_match(keyframe_progress, properties, progress, acc)
    end)
  end

  defp interpolate_properties(
         {_prev_progress, prev_props},
         {_next_progress, next_props},
         local_progress
       ) do
    all_keys =
      prev_props |> Map.keys() |> Kernel.++(Map.keys(next_props)) |> Enum.uniq()

    Enum.reduce(all_keys, %{}, fn key, acc ->
      prev_value = Map.get(prev_props, key, get_default_value(key))
      next_value = Map.get(next_props, key, prev_value)

      interpolated_value =
        interpolate_value(prev_value, next_value, local_progress)

      Map.put(acc, key, interpolated_value)
    end)
  end

  defp interpolate_value(from_value, to_value, progress)
       when is_number(from_value) and is_number(to_value) do
    from_value + (to_value - from_value) * progress
  end

  defp interpolate_value(from_value, to_value, progress)
       when is_binary(from_value) and is_binary(to_value) do
    # Handle transform strings, colors, etc.
    case {parse_transform(from_value), parse_transform(to_value)} do
      {{:transform, from_transform}, {:transform, to_transform}} ->
        interpolated_transform =
          interpolate_transform(from_transform, to_transform, progress)

        build_transform_string(interpolated_transform)

      _ ->
        # For non-interpolable strings, switch at 50% progress
        switch_at_midpoint(progress, from_value, to_value)
    end
  end

  defp interpolate_value(from_value, to_value, progress) do
    # For non-numeric values, switch at 50% progress
    switch_at_midpoint(progress, from_value, to_value)
  end

  defp parse_transform("translateX(" <> rest) do
    value =
      rest
      |> String.trim_trailing(")")
      |> String.trim_trailing("px")
      |> String.to_float()

    {:transform, %{translateX: value}}
  end

  defp parse_transform("translateY(" <> rest) do
    value =
      rest
      |> String.trim_trailing(")")
      |> String.trim_trailing("px")
      |> String.to_float()

    {:transform, %{translateY: value}}
  end

  defp parse_transform("scale(" <> rest) do
    value = rest |> String.trim_trailing(")") |> String.to_float()
    {:transform, %{scale: value}}
  end

  defp parse_transform("rotate(" <> rest) do
    value =
      rest
      |> String.trim_trailing(")")
      |> String.trim_trailing("deg")
      |> String.to_float()

    {:transform, %{rotate: value}}
  end

  defp parse_transform(other), do: {:string, other}

  defp interpolate_transform(from_transform, to_transform, progress) do
    all_keys =
      from_transform
      |> Map.keys()
      |> Kernel.++(Map.keys(to_transform))
      |> Enum.uniq()

    Enum.reduce(all_keys, %{}, fn key, acc ->
      from_val = Map.get(from_transform, key, get_default_transform_value(key))
      to_val = Map.get(to_transform, key, from_val)
      interpolated_val = from_val + (to_val - from_val) * progress
      Map.put(acc, key, interpolated_val)
    end)
  end

  defp build_transform_string(transform_map) do
    transform_map
    |> Enum.map(fn
      {:translateX, value} -> "translateX(#{value}px)"
      {:translateY, value} -> "translateY(#{value}px)"
      {:scale, value} -> "scale(#{value})"
      {:rotate, value} -> "rotate(#{value}deg)"
    end)
    |> Enum.join(" ")
  end

  defp create_property_transition(
         element_id,
         property,
         old_value,
         new_value,
         transition
       ) do
    animation_name = :"#{element_id}_#{property}_transition"

    Framework.create_animation(animation_name, %{
      type: :property_transition,
      target_path: [property],
      from: old_value,
      to: new_value,
      duration: transition.duration,
      easing: transition.easing,
      delay: transition.delay
    })

    # Start the animation after delay
    schedule_or_start_animation(transition.delay, animation_name, element_id)
  end

  defp get_default_value(:opacity), do: 1.0
  defp get_default_value(:scale), do: 1.0
  defp get_default_value(:translateX), do: 0
  defp get_default_value(:translateY), do: 0
  defp get_default_value(:rotate), do: 0
  defp get_default_value(_), do: 0

  defp get_default_transform_value(:translateX), do: 0.0
  defp get_default_transform_value(:translateY), do: 0.0
  defp get_default_transform_value(:scale), do: 1.0
  defp get_default_transform_value(:rotate), do: 0.0
  defp get_default_transform_value(_), do: 0.0

  # Helper functions for pattern matching refactoring

  # Duration parsing with pattern matching
  defp parse_duration_value(duration_str, rest) when is_binary(duration_str) do
    parse_duration_by_suffix(
      String.ends_with?(duration_str, "ms"),
      duration_str,
      rest
    )
  end

  defp parse_duration_value(duration_str, rest),
    do: {300, [duration_str | rest]}

  defp parse_duration_by_suffix(true, duration_str, rest) do
    {duration_str |> String.trim_trailing("ms") |> String.to_integer(), rest}
  end

  defp parse_duration_by_suffix(false, duration_str, rest) do
    parse_duration_seconds_or_default(duration_str, rest)
  end

  defp parse_duration_seconds_or_default(duration_str, rest) do
    parse_seconds_suffix(
      String.ends_with?(duration_str, "s"),
      duration_str,
      rest
    )
  end

  defp parse_seconds_suffix(true, duration_str, rest) do
    {((duration_str |> String.trim_trailing("s") |> String.to_float()) * 1000)
     |> round(), rest}
  end

  defp parse_seconds_suffix(false, duration_str, rest) do
    {300, [duration_str | rest]}
  end

  # Delay parsing with pattern matching
  defp parse_delay_value(delay_str, rest) when is_binary(delay_str) do
    parse_delay_by_suffix(String.ends_with?(delay_str, "ms"), delay_str, rest)
  end

  defp parse_delay_value(delay_str, rest), do: {0, [delay_str | rest]}

  defp parse_delay_by_suffix(true, delay_str, rest) do
    {delay_str |> String.trim_trailing("ms") |> String.to_integer(), rest}
  end

  defp parse_delay_by_suffix(false, delay_str, rest) do
    parse_delay_seconds_or_default(delay_str, rest)
  end

  defp parse_delay_seconds_or_default(delay_str, rest) do
    parse_delay_seconds_suffix(
      String.ends_with?(delay_str, "s"),
      delay_str,
      rest
    )
  end

  defp parse_delay_seconds_suffix(true, delay_str, rest) do
    {((delay_str |> String.trim_trailing("s") |> String.to_float()) * 1000)
     |> round(), rest}
  end

  defp parse_delay_seconds_suffix(false, delay_str, rest) do
    {0, [delay_str | rest]}
  end

  defp check_keyframe_match(keyframe_progress, properties, progress, _acc)
       when keyframe_progress == progress,
       do: {:halt, {keyframe_progress, properties}}

  defp check_keyframe_match(keyframe_progress, properties, progress, acc)
       when keyframe_progress > progress and acc != nil do
    {prev_progress, prev_properties} = acc

    local_progress =
      (progress - prev_progress) / (keyframe_progress - prev_progress)

    {:halt,
     {{prev_progress, prev_properties}, {keyframe_progress, properties},
      local_progress}}
  end

  defp check_keyframe_match(keyframe_progress, properties, _progress, _acc),
    do: {:cont, {keyframe_progress, properties}}

  # Helper functions for refactored if statements
  defp handle_easing_result(true, easing_tuple, _rest), do: easing_tuple
  defp handle_easing_result(false, easing_atom, rest), do: {easing_atom, rest}

  defp handle_direction_result(true, direction_tuple, _rest),
    do: direction_tuple

  defp handle_direction_result(false, direction_atom, rest),
    do: {direction_atom, rest}

  defp handle_mode_result(true, mode_tuple, _rest), do: mode_tuple
  defp handle_mode_result(false, mode_atom, rest), do: {mode_atom, rest}

  defp switch_at_midpoint(progress, from_value, _to_value) when progress < 0.5,
    do: from_value

  defp switch_at_midpoint(_progress, _from_value, to_value), do: to_value

  defp schedule_or_start_animation(delay, animation_name, element_id)
       when delay > 0 do
    Process.send_after(
      self(),
      {:start_delayed_animation, animation_name, element_id},
      delay
    )
  end

  defp schedule_or_start_animation(_delay, animation_name, element_id) do
    Framework.start_animation(animation_name, element_id)
  end
end
