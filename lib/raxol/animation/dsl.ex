defmodule Raxol.Animation.DSL do
  @moduledoc """
  Declarative animation DSL for composing complex animation sequences.

  This module provides a fluent, chainable API for creating sophisticated animations
  with timing controls, parallel execution, and conditional logic.

  ## Examples

      # Simple animation sequence
      import Raxol.Animation.DSL
      
      sequence()
      |> fade_in(duration: 300)
      |> slide_up(distance: 20, duration: 400)
      |> scale_bounce(scale: 1.2, duration: 200)
      |> execute(element_id)
      
      # Parallel animations
      parallel()
      |> with_animation(fade_in(duration: 500))
      |> with_animation(rotate(degrees: 360, duration: 1000))
      |> execute(element_id)
      
      # Conditional animations
      sequence()
      |> fade_in(duration: 300)
      |> when_condition(fn state -> state.user_type == :premium end)
      |> sparkle_effect(duration: 1000)
      |> end_condition()
      |> slide_out(direction: :right, duration: 400)
      |> execute(element_id)
      
      # Complex choreographed animation
      choreography()
      |> stage("entrance",
           sequence()
           |> fade_in(duration: 300)
           |> slide_up(distance: 30, duration: 500, easing: :ease_out_back)
         )
      |> stage("highlight",
           parallel()
           |> with_animation(glow_effect(duration: 800))
           |> with_animation(pulse_scale(scale: 1.05, duration: 600))
         )
      |> stage("exit",
           sequence()
           |> fade_out(duration: 400)
           |> scale_down(scale: 0.8, duration: 300)
         )
      |> execute_choreography(element_id)
  """

  alias Raxol.Animation.Framework

  # Animation sequence structure
  defmodule Sequence do
    defstruct [:type, :animations, :options, :conditions, :context]

    def new(type \\ :sequence, options \\ %{}) do
      %__MODULE__{
        type: type,
        animations: [],
        options: options,
        conditions: [],
        context: %{}
      }
    end

    def add_animation(sequence, animation) do
      %{sequence | animations: [animation | sequence.animations]}
    end

    def add_condition(sequence, condition) do
      %{sequence | conditions: [condition | sequence.conditions]}
    end
  end

  # Animation definition structure
  defmodule Animation do
    defstruct [:name, :type, :params, :conditions, :meta]

    def new(name, type, params \\ %{}) do
      %__MODULE__{
        name: name,
        type: type,
        params: params,
        conditions: [],
        meta: %{}
      }
    end
  end

  # Choreography structure for complex multi-stage animations
  defmodule Choreography do
    defstruct [:stages, :options, :context]

    def new(options \\ %{}) do
      %__MODULE__{
        stages: [],
        options: options,
        context: %{}
      }
    end

    def add_stage(choreo, name, sequence) do
      %{choreo | stages: [{name, sequence} | choreo.stages]}
    end
  end

  # DSL functions

  @doc """
  Creates a new animation sequence.
  """
  def sequence(options \\ %{}) do
    Sequence.new(:sequence, options)
  end

  @doc """
  Creates a parallel animation group.
  """
  def parallel(options \\ %{}) do
    Sequence.new(:parallel, options)
  end

  @doc """
  Creates a new choreography for complex multi-stage animations.
  """
  def choreography(options \\ %{}) do
    Choreography.new(options)
  end

  # Basic animation primitives

  @doc """
  Adds a fade in animation to the sequence.
  """
  def fade_in(sequence_or_options \\ %{})

  def fade_in(%Sequence{} = sequence) do
    fade_in(sequence, %{})
  end

  def fade_in(options) when is_map(options) do
    sequence() |> fade_in(options)
  end

  def fade_in(%Sequence{} = sequence, options) do
    animation =
      Animation.new(
        :fade_in,
        :opacity,
        Map.merge(
          %{
            from: 0.0,
            to: 1.0,
            duration: 300,
            easing: :ease_out
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  @doc """
  Adds a fade out animation to the sequence.
  """
  def fade_out(sequence_or_options \\ %{})

  def fade_out(%Sequence{} = sequence) do
    fade_out(sequence, %{})
  end

  def fade_out(options) when is_map(options) do
    sequence() |> fade_out(options)
  end

  def fade_out(%Sequence{} = sequence, options) do
    animation =
      Animation.new(
        :fade_out,
        :opacity,
        Map.merge(
          %{
            from: 1.0,
            to: 0.0,
            duration: 300,
            easing: :ease_in
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  @doc """
  Adds a slide animation to the sequence.
  """
  def slide(sequence_or_options \\ %{})

  def slide(%Sequence{} = sequence) do
    slide(sequence, %{})
  end

  def slide(options) when is_map(options) do
    sequence() |> slide(options)
  end

  def slide(%Sequence{} = sequence, options) do
    direction = Map.get(options, :direction, :up)
    distance = Map.get(options, :distance, 20)

    {from_transform, to_transform} =
      calculate_slide_transform(direction, distance)

    animation =
      Animation.new(
        :slide,
        :transform,
        Map.merge(
          %{
            from: from_transform,
            to: to_transform,
            duration: 400,
            easing: :ease_out
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  # Convenience functions for specific slide directions
  def slide_up(sequence, options \\ %{}) do
    slide(sequence, Map.put(options, :direction, :up))
  end

  def slide_down(sequence, options \\ %{}) do
    slide(sequence, Map.put(options, :direction, :down))
  end

  def slide_left(sequence, options \\ %{}) do
    slide(sequence, Map.put(options, :direction, :left))
  end

  def slide_right(sequence, options \\ %{}) do
    slide(sequence, Map.put(options, :direction, :right))
  end

  @doc """
  Adds a slide in animation.
  """
  def slide_in(sequence_or_options \\ %{}, options \\ %{})

  def slide_in(%Sequence{} = sequence, options) do
    direction = Map.get(options, :direction, :up)
    distance = Map.get(options, :distance, 30)

    {from_transform, to_transform} =
      calculate_slide_in_transform(direction, distance)

    animation =
      Animation.new(
        :slide_in,
        :transform,
        Map.merge(
          %{
            from: from_transform,
            to: to_transform,
            duration: 500,
            easing: :ease_out_back
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  def slide_in(options, _extra) when is_map(options) do
    sequence() |> slide_in(options)
  end

  @doc """
  Adds a slide out animation.
  """
  def slide_out(sequence_or_options \\ %{}, options \\ %{})

  def slide_out(%Sequence{} = sequence, options) do
    direction = Map.get(options, :direction, :down)
    distance = Map.get(options, :distance, 30)

    {from_transform, to_transform} =
      calculate_slide_out_transform(direction, distance)

    animation =
      Animation.new(
        :slide_out,
        :transform,
        Map.merge(
          %{
            from: from_transform,
            to: to_transform,
            duration: 400,
            easing: :ease_in
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  def slide_out(options, _extra) when is_map(options) do
    sequence() |> slide_out(options)
  end

  @doc """
  Adds a scale animation to the sequence.
  """
  def scale(sequence_or_options \\ %{})

  def scale(%Sequence{} = sequence) do
    scale(sequence, %{})
  end

  def scale(options) when is_map(options) do
    sequence() |> scale(options)
  end

  def scale(%Sequence{} = sequence, options) do
    animation =
      Animation.new(
        :scale,
        :scale,
        Map.merge(
          %{
            from: 1.0,
            to: Map.get(options, :scale, 1.2),
            duration: 300,
            easing: :ease_out
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  @doc """
  Adds a scale bounce animation.
  """
  def scale_bounce(sequence_or_options \\ %{})

  def scale_bounce(%Sequence{} = sequence) do
    scale_bounce(sequence, %{})
  end

  def scale_bounce(options) when is_map(options) do
    sequence() |> scale_bounce(options)
  end

  def scale_bounce(%Sequence{} = sequence, options) do
    scale_to = Map.get(options, :scale, 1.2)

    # Create a sequence of scale up -> scale down for bounce effect
    bounce_sequence =
      parallel(%{})
      |> with_animation(
        Animation.new(:scale_up, :scale, %{
          from: 1.0,
          to: scale_to,
          duration: Map.get(options, :duration, 200) |> div(2),
          easing: :ease_out_bounce
        })
      )
      |> with_animation(
        Animation.new(:scale_down, :scale, %{
          from: scale_to,
          to: 1.0,
          duration: Map.get(options, :duration, 200) |> div(2),
          easing: :ease_in_bounce,
          delay: Map.get(options, :duration, 200) |> div(2)
        })
      )

    Sequence.add_animation(sequence, bounce_sequence)
  end

  @doc """
  Adds a scale down animation.
  """
  def scale_down(sequence_or_options \\ %{})

  def scale_down(%Sequence{} = sequence) do
    scale_down(sequence, %{})
  end

  def scale_down(options) when is_map(options) do
    sequence() |> scale_down(options)
  end

  def scale_down(%Sequence{} = sequence, options) do
    animation =
      Animation.new(
        :scale_down,
        :scale,
        Map.merge(
          %{
            from: 1.0,
            to: Map.get(options, :scale, 0.8),
            duration: 300,
            easing: :ease_in
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  @doc """
  Adds a rotation animation.
  """
  def rotate(sequence_or_options \\ %{})

  def rotate(%Sequence{} = sequence) do
    rotate(sequence, %{})
  end

  def rotate(options) when is_map(options) do
    sequence() |> rotate(options)
  end

  def rotate(%Sequence{} = sequence, options) do
    animation =
      Animation.new(
        :rotate,
        :rotate,
        Map.merge(
          %{
            from: 0,
            to: Map.get(options, :degrees, 360),
            duration: 1000,
            easing: :ease_in_out
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  # Advanced effects

  @doc """
  Adds a glow effect animation.
  """
  def glow_effect(sequence_or_options \\ %{})

  def glow_effect(%Sequence{} = sequence) do
    glow_effect(sequence, %{})
  end

  def glow_effect(options) when is_map(options) do
    sequence() |> glow_effect(options)
  end

  def glow_effect(%Sequence{} = sequence, options) do
    animation =
      Animation.new(
        :glow,
        :glow,
        Map.merge(
          %{
            from: 0.0,
            to: 1.0,
            duration: 800,
            easing: :ease_in_out_sine,
            type: :glow_effect
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  @doc """
  Adds a pulse scale animation.
  """
  def pulse_scale(sequence_or_options \\ %{})

  def pulse_scale(%Sequence{} = sequence) do
    pulse_scale(sequence, %{})
  end

  def pulse_scale(options) when is_map(options) do
    sequence() |> pulse_scale(options)
  end

  def pulse_scale(%Sequence{} = sequence, options) do
    scale_to = Map.get(options, :scale, 1.05)
    duration = Map.get(options, :duration, 600)

    # Create pulsing effect with back-and-forth scaling
    pulse_animation =
      Animation.new(
        :pulse_scale,
        :scale,
        Map.merge(
          %{
            keyframes: %{
              "0%" => %{scale: 1.0},
              "50%" => %{scale: scale_to},
              "100%" => %{scale: 1.0}
            },
            duration: duration,
            easing: :ease_in_out_sine,
            type: :pulse
          },
          options
        )
      )

    Sequence.add_animation(sequence, pulse_animation)
  end

  @doc """
  Adds a sparkle effect animation.
  """
  def sparkle_effect(sequence_or_options \\ %{})

  def sparkle_effect(%Sequence{} = sequence) do
    sparkle_effect(sequence, %{})
  end

  def sparkle_effect(options) when is_map(options) do
    sequence() |> sparkle_effect(options)
  end

  def sparkle_effect(%Sequence{} = sequence, options) do
    animation =
      Animation.new(
        :sparkle,
        :particle_system,
        Map.merge(
          %{
            particle_count: 12,
            spawn_area: %{x: 0, y: 0, width: 50, height: 30},
            velocity_range: %{min: 20, max: 80},
            duration: 1000,
            particle_lifetime: 800,
            type: :sparkle
          },
          options
        )
      )

    Sequence.add_animation(sequence, animation)
  end

  # Sequence composition and control

  @doc """
  Adds an animation to a parallel group.
  """
  def with_animation(%Sequence{type: :parallel} = parallel_sequence, animation) do
    Sequence.add_animation(parallel_sequence, animation)
  end

  @doc """
  Adds a delay to the sequence.
  """
  def delay(sequence, duration) do
    animation = Animation.new(:delay, :delay, %{duration: duration})
    Sequence.add_animation(sequence, animation)
  end

  @doc """
  Adds a conditional block to the sequence.
  """
  def when_condition(%Sequence{} = sequence, condition_fn)
      when is_function(condition_fn, 1) do
    condition = %{type: :when, condition: condition_fn}
    Sequence.add_condition(sequence, condition)
  end

  @doc """
  Ends a conditional block.
  """
  def end_condition(%Sequence{} = sequence) do
    condition = %{type: :end_when}
    Sequence.add_condition(sequence, condition)
  end

  @doc """
  Repeats the previous animation or sequence.
  """
  def repeat(%Sequence{} = sequence, times) when is_integer(times) do
    repeat_animation = Animation.new(:repeat, :repeat, %{times: times})
    Sequence.add_animation(sequence, repeat_animation)
  end

  @doc """
  Loops the sequence infinitely or for a specified number of iterations.
  """
  def loop(%Sequence{} = sequence, iterations \\ :infinite) do
    loop_animation = Animation.new(:loop, :loop, %{iterations: iterations})
    Sequence.add_animation(sequence, loop_animation)
  end

  # Choreography functions

  @doc """
  Adds a stage to a choreography.
  """
  def stage(%Choreography{} = choreo, name, sequence) do
    Choreography.add_stage(choreo, name, sequence)
  end

  # Execution functions

  @doc """
  Executes the animation sequence for the given element.
  """
  def execute(%Sequence{} = sequence, element_id, options \\ %{}) do
    compiled_animations = compile_sequence(sequence)

    Enum.each(compiled_animations, fn {animation_name, animation_config} ->
      Framework.create_animation(animation_name, animation_config)
      Framework.start_animation(animation_name, element_id, options)
    end)

    :ok
  end

  @doc """
  Executes a choreography with multiple stages.
  """
  def execute_choreography(%Choreography{} = choreo, element_id, options \\ %{}) do
    total_delay = 0

    _final_delay =
      Enum.reduce(choreo.stages, total_delay, fn {stage_name, sequence},
                                                 acc_delay ->
        # Execute this stage with accumulated delay
        stage_options = Map.put(options, :delay, acc_delay)
        execute(sequence, "#{element_id}_#{stage_name}", stage_options)

        # Calculate delay for next stage
        stage_duration = calculate_sequence_duration(sequence)
        acc_delay + stage_duration
      end)

    :ok
  end

  # Private helper functions

  defp calculate_slide_transform(direction, distance) do
    case direction do
      :up -> {"translateY(#{distance}px)", "translateY(0px)"}
      :down -> {"translateY(-#{distance}px)", "translateY(0px)"}
      :left -> {"translateX(#{distance}px)", "translateX(0px)"}
      :right -> {"translateX(-#{distance}px)", "translateX(0px)"}
    end
  end

  defp calculate_slide_in_transform(direction, distance) do
    case direction do
      :up -> {"translateY(#{distance}px)", "translateY(0px)"}
      :down -> {"translateY(-#{distance}px)", "translateY(0px)"}
      :left -> {"translateX(-#{distance}px)", "translateX(0px)"}
      :right -> {"translateX(#{distance}px)", "translateX(0px)"}
    end
  end

  defp calculate_slide_out_transform(direction, distance) do
    case direction do
      :up -> {"translateY(0px)", "translateY(-#{distance}px)"}
      :down -> {"translateY(0px)", "translateY(#{distance}px)"}
      :left -> {"translateY(0px)", "translateX(-#{distance}px)"}
      :right -> {"translateY(0px)", "translateX(#{distance}px)"}
    end
  end

  defp compile_sequence(%Sequence{type: :sequence, animations: animations}) do
    animations
    |> Enum.with_index()
    |> Enum.map(fn {animation, index} ->
      animation_name = :"sequence_#{index}_#{animation.name}"
      animation_config = compile_animation(animation)
      {animation_name, animation_config}
    end)
  end

  defp compile_sequence(%Sequence{type: :parallel, animations: animations}) do
    animations
    |> Enum.with_index()
    |> Enum.map(fn {animation, index} ->
      animation_name = :"parallel_#{index}_#{animation.name}"
      animation_config = compile_animation(animation)
      {animation_name, animation_config}
    end)
  end

  defp compile_animation(%Animation{type: animation_type, params: params}) do
    case animation_type do
      type when type in [:opacity, :scale, :rotate] ->
        Map.merge(
          %{
            type: :generic,
            target_path: [type]
          },
          params
        )

      :transform ->
        Map.merge(
          %{
            type: :morph,
            from_state: %{transform: params.from},
            to_state: %{transform: params.to}
          },
          params
        )

      :particle_system ->
        Map.merge(
          %{
            type: :particle_system
          },
          params
        )

      :glow ->
        Map.merge(
          %{
            type: :generic,
            target_path: [:glow_intensity]
          },
          params
        )

      :delay ->
        %{
          type: :delay,
          duration: params.duration,
          from: 0,
          to: 0,
          target_path: [:_delay]
        }

      other_type ->
        Map.merge(
          %{
            type: other_type
          },
          params
        )
    end
  end

  defp compile_animation(%Sequence{} = nested_sequence) do
    # Handle nested sequences (like for bounce effects)
    compiled_animations = compile_sequence(nested_sequence)

    %{
      type: :nested_sequence,
      animations: compiled_animations
    }
  end

  defp calculate_sequence_duration(%Sequence{animations: animations}) do
    Enum.reduce(animations, 0, fn animation, acc ->
      duration =
        case animation do
          %Animation{params: params} ->
            Map.get(params, :duration, 300) + Map.get(params, :delay, 0)

          %Sequence{} = nested ->
            calculate_sequence_duration(nested)
        end

      acc + duration
    end)
  end
end
