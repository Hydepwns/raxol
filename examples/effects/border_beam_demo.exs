# Border Beam Demo
#
# Interactive demo of the BorderBeam effect -- an animated glow
# that orbits around a panel's border, inspired by border-beam.
#
# What you'll learn:
#   - BorderBeam effect: new/1, set_bounds/2, update/2, apply/2
#   - Color variants: colorful, mono, ocean, sunset
#   - Size presets: full, compact, line
#   - Active/inactive toggle with fade transitions
#   - How effects integrate with the TEA render loop
#
# Usage:
#   mix run examples/effects/border_beam_demo.exs
#
# Controls:
#   1-4     = switch color variant (colorful, mono, ocean, sunset)
#   s/f     = slower / faster orbit
#   z/x     = size preset (full -> compact -> line)
#   space   = toggle active (with fade)
#   q       = quit

defmodule BorderBeamDemo do
  use Raxol.Core.Runtime.Application

  alias Raxol.Effects.BorderBeam

  @variants [:colorful, :mono, :ocean, :sunset]
  @sizes [:full, :compact, :line]
  @panel_bounds %{x: 4, y: 2, width: 40, height: 12}

  @impl true
  def init(_context) do
    beam =
      BorderBeam.new(
        color_variant: :colorful,
        duration_ms: 2000,
        strength: 0.9
      )
      |> BorderBeam.set_bounds(@panel_bounds)

    %{
      beam: beam,
      variant_idx: 0,
      size_idx: 0,
      duration_ms: 2000,
      tick_ref: nil
    }
  end

  @impl true
  def update(message, model) do
    case message do
      :tick ->
        beam = BorderBeam.update(model.beam)
        {%{model | beam: beam}, []}

      # Variant switching: 1-4
      %{type: :key, data: %{key: :char, char: "1"}} ->
        {switch_variant(model, 0), []}

      %{type: :key, data: %{key: :char, char: "2"}} ->
        {switch_variant(model, 1), []}

      %{type: :key, data: %{key: :char, char: "3"}} ->
        {switch_variant(model, 2), []}

      %{type: :key, data: %{key: :char, char: "4"}} ->
        {switch_variant(model, 3), []}

      # Speed: s=slower, f=faster
      %{type: :key, data: %{key: :char, char: "s"}} ->
        new_dur = min(model.duration_ms + 500, 5000)
        beam = BorderBeam.update_config(model.beam, duration_ms: new_dur)
        {%{model | beam: beam, duration_ms: new_dur}, []}

      %{type: :key, data: %{key: :char, char: "f"}} ->
        new_dur = max(model.duration_ms - 500, 500)
        beam = BorderBeam.update_config(model.beam, duration_ms: new_dur)
        {%{model | beam: beam, duration_ms: new_dur}, []}

      # Size: z/x cycle through sizes
      %{type: :key, data: %{key: :char, char: "z"}} ->
        new_idx = rem(model.size_idx + 1, length(@sizes))
        size = Enum.at(@sizes, new_idx)
        beam = BorderBeam.update_config(model.beam, size: size)
        {%{model | beam: beam, size_idx: new_idx}, []}

      %{type: :key, data: %{key: :char, char: "x"}} ->
        new_idx = rem(model.size_idx - 1 + length(@sizes), length(@sizes))
        size = Enum.at(@sizes, new_idx)
        beam = BorderBeam.update_config(model.beam, size: size)
        {%{model | beam: beam, size_idx: new_idx}, []}

      # Toggle active
      %{type: :key, data: %{key: :char, char: " "}} ->
        beam = BorderBeam.set_active(model.beam, !model.beam.active)
        {%{model | beam: beam}, []}

      # Quit
      %{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [command(:quit)]}

      %{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {model, [command(:quit)]}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    variant_name = Enum.at(@variants, model.variant_idx) |> Atom.to_string()
    size_name = Enum.at(@sizes, model.size_idx) |> Atom.to_string()
    active_str = if model.beam.active, do: "ON", else: "OFF"

    column do
      text(" Border Beam Demo", style: [:bold])
      text("")

      panel(
        id: "beam-panel",
        border: :rounded,
        title: " #{variant_name} "
      ) do
        column do
          text("")
          text("  Variant: #{variant_name} (1-4)")
          text("  Size:    #{size_name} (z/x)")
          text("  Speed:   #{model.duration_ms}ms (s/f)")
          text("  Active:  #{active_str} (space)")
          text("")
          text("  Press q to quit")
          text("")
        end
      end

      text("")

      text(" Controls: 1-4=variant  s/f=speed  z/x=size  space=toggle  q=quit",
        style: [:dim]
      )
    end
  end

  defp switch_variant(model, idx) do
    variant = Enum.at(@variants, idx)
    beam = BorderBeam.update_config(model.beam, color_variant: variant)
    %{model | beam: beam, variant_idx: idx}
  end
end

# Start with a 30 FPS tick
Raxol.start_link(BorderBeamDemo, tick_rate: 33)
