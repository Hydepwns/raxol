defmodule Raxol.Demo.Effects do
  @moduledoc """
  Reusable visual effect helpers for demo animations.

  Provides particle burst, screen flash, scene transition,
  spiral force, and color conversion utilities.
  """

  alias Raxol.Demo.Particles

  @frame_delay 33

  @doc "Runs a burst animation for the given particles over N frames."
  def run_particle_burst(target, particles, frames, width, height, opts) do
    preserve = Keyword.get(opts, :preserve_text, false)

    Enum.reduce(1..frames, particles, fn _frame, particles ->
      particles =
        particles
        |> Enum.map(&Particles.update/1)
        |> Particles.prune()

      unless preserve do
        out(target, "\e[2J\e[H")
      end

      out(target, Particles.render(particles, width, height))
      Process.sleep(@frame_delay)

      particles
    end)
  end

  @doc "Fills the screen with a solid color for N frames (flash effect)."
  def flash_screen(target, color, frames, width, height) do
    color_code =
      case color do
        :white -> "48;5;255"
        :cyan -> "48;5;51"
      end

    for _ <- 1..frames do
      out(target, "\e[2J\e[H")

      for y <- 1..height do
        out(
          target,
          "\e[#{y};1H\e[#{color_code}m#{String.duplicate(" ", width)}\e[0m"
        )
      end

      Process.sleep(30)
    end

    out(target, "\e[2J\e[H")
  end

  @doc "Gradually dims the screen before a scene transition."
  def transition_fade(target, frames) do
    for i <- 1..frames do
      grey = 255 - div(255 * i, frames)
      out(target, "\e[38;2;#{grey};#{grey};#{grey}m")
      Process.sleep(30)
    end

    out(target, "\e[0m")
  end

  @doc "Applies spiral convergence force to a particle."
  def apply_spiral_force(particle, center_x, center_y, strength) do
    dx = center_x - particle.x
    dy = center_y - particle.y
    dist = :math.sqrt(dx * dx + dy * dy)

    if dist > 1 do
      nx = dx / dist
      ny = dy / dist
      tx = -ny
      ty = nx

      radial_strength = strength * 1.5
      tangential_strength = strength * 0.8

      %{
        particle
        | vx: particle.vx + nx * radial_strength + tx * tangential_strength,
          vy: particle.vy + ny * radial_strength + ty * tangential_strength
      }
    else
      particle
    end
  end

  @doc "Maps a hue value (0-360) to an ANSI 256-color index."
  def hue_to_256(hue) do
    case rem(div(hue, 30), 12) do
      0 -> 196
      1 -> 202
      2 -> 208
      3 -> 214
      4 -> 220
      5 -> 226
      6 -> 46
      7 -> 48
      8 -> 51
      9 -> 45
      10 -> 39
      _ -> 201
    end
  end

  @doc "Converts HSL to RGB tuple {r, g, b} with values 0-255."
  def hsl_to_rgb(h, s, l) do
    c = (1 - abs(2 * l - 1)) * s
    h_prime = h / 60
    x = c * (1 - abs(float_mod(h_prime, 2) - 1))
    m = l - c / 2

    {r1, g1, b1} =
      case trunc(h_prime) do
        0 -> {c, x, 0.0}
        1 -> {x, c, 0.0}
        2 -> {0.0, c, x}
        3 -> {0.0, x, c}
        4 -> {x, 0.0, c}
        _ -> {c, 0.0, x}
      end

    {round((r1 + m) * 255), round((g1 + m) * 255), round((b1 + m) * 255)}
  end

  @doc "Creates a cascading rocket explosion at the given position."
  def create_rocket_explosion(x, y) do
    for _ <- 1..15 do
      Particles.create_cascade_explosion(x, y, 2)
    end
  end

  @doc "Writes data to a target device (IO, PID, or web tuple)."
  def out(device, data) when is_pid(device) or is_atom(device) do
    IO.write(device, data)
  end

  def out({:web, pid}, data) do
    send(pid, {:animation_output, data})
  end

  def out({:web, pid, _cols, _rows}, data) do
    send(pid, {:animation_output, data})
  end

  # --- Private ---

  defp float_mod(a, b), do: a - Float.floor(a / b) * b
end
