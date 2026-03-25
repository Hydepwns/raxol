defmodule Raxol.Animation.DSL.Compiler do
  @moduledoc """
  Sequence and animation compilation for the Animation DSL.

  Converts DSL Sequence and Animation structs into Framework-compatible
  configuration maps.
  """

  alias Raxol.Animation.DSL.{Animation, Sequence}

  @compile {:no_warn_undefined, Raxol.Animation.DSL.Animation}
  @compile {:no_warn_undefined, Raxol.Animation.DSL.Sequence}

  @doc """
  Compiles a Sequence into a list of {animation_name, animation_config} pairs.
  """
  def compile_sequence(%Sequence{type: :sequence, animations: animations}) do
    animations
    |> Enum.with_index()
    |> Enum.map(fn {animation, index} ->
      animation_name = :"sequence_#{index}_#{animation.name}"
      {animation_name, compile_animation(animation)}
    end)
  end

  def compile_sequence(%Sequence{type: :parallel, animations: animations}) do
    animations
    |> Enum.with_index()
    |> Enum.map(fn {animation, index} ->
      animation_name = :"parallel_#{index}_#{animation.name}"
      {animation_name, compile_animation(animation)}
    end)
  end

  @doc """
  Compiles an Animation struct into a Framework config map.
  """
  def compile_animation(%Animation{type: animation_type, params: params}) do
    case animation_type do
      type when type in [:opacity, :scale, :rotate] ->
        Map.merge(%{type: :generic, target_path: [type]}, params)

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
        Map.merge(%{type: :particle_system}, params)

      :glow ->
        Map.merge(%{type: :generic, target_path: [:glow_intensity]}, params)

      :delay ->
        %{
          type: :delay,
          duration: params.duration,
          from: 0,
          to: 0,
          target_path: [:_delay]
        }

      other_type ->
        Map.merge(%{type: other_type}, params)
    end
  end

  def compile_animation(%Sequence{} = nested_sequence) do
    compiled_animations = compile_sequence(nested_sequence)
    %{type: :nested_sequence, animations: compiled_animations}
  end

  @doc """
  Calculates the total duration of a sequence in milliseconds.
  """
  def calculate_sequence_duration(%Sequence{animations: animations}) do
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
