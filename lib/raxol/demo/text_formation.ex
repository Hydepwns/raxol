defmodule Raxol.Demo.TextFormation do
  @moduledoc """
  ASCII text particle formation for demo effects.
  Uses 5x7 bitmap font to create particle target positions.
  """

  alias Raxol.Demo.Particles

  # 5x7 bitmap font for uppercase letters
  # Each letter is 5 columns wide, 7 rows tall
  # 1 = pixel on, 0 = pixel off
  @font %{
    "R" => [
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 0],
      [1, 0, 1, 0, 0],
      [1, 0, 0, 1, 0],
      [1, 0, 0, 0, 1]
    ],
    "A" => [
      [0, 0, 1, 0, 0],
      [0, 1, 0, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1]
    ],
    "X" => [
      [1, 0, 0, 0, 1],
      [0, 1, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 1, 0],
      [1, 0, 0, 0, 1]
    ],
    "O" => [
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
    ],
    "L" => [
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 1]
    ]
  }

  @letter_width 5
  @letter_height 7
  @letter_spacing 2

  @type position :: {float(), float()}
  @type formation_particle :: %{
          x: float(),
          y: float(),
          vx: float(),
          vy: float(),
          char: String.t(),
          color: non_neg_integer(),
          life: integer(),
          target_x: float(),
          target_y: float(),
          arrived: boolean()
        }

  @doc """
  Returns target {x, y} positions for all pixels in the given text.
  Centered at the given screen coordinates.
  """
  @spec target_positions(String.t(), integer(), integer()) :: list(position())
  def target_positions(text, center_x, center_y) do
    letters = String.graphemes(String.upcase(text))

    total_width =
      length(letters) * @letter_width + (length(letters) - 1) * @letter_spacing

    start_x = center_x - div(total_width, 2)
    start_y = center_y - div(@letter_height, 2)

    letters
    |> Enum.with_index()
    |> Enum.flat_map(fn {letter, letter_idx} ->
      letter_offset = letter_idx * (@letter_width + @letter_spacing)
      bitmap = Map.get(@font, letter, @font["O"])

      bitmap
      |> Enum.with_index()
      |> Enum.flat_map(fn {row, row_idx} ->
        row
        |> Enum.with_index()
        |> Enum.filter(fn {pixel, _col_idx} -> pixel == 1 end)
        |> Enum.map(fn {_pixel, col_idx} ->
          {(start_x + letter_offset + col_idx) * 1.0, (start_y + row_idx) * 1.0}
        end)
      end)
    end)
  end

  @doc """
  Creates particles at screen edges with targets for text formation.
  """
  @spec create_formation_particles(
          String.t(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: list(formation_particle())
  def create_formation_particles(
        text,
        center_x,
        center_y,
        screen_width,
        screen_height
      ) do
    targets = target_positions(text, center_x, center_y)

    targets
    |> Enum.map(fn {target_x, target_y} ->
      {start_x, start_y} = random_edge_position(screen_width, screen_height)

      %{
        x: start_x,
        y: start_y,
        vx: 0.0,
        vy: 0.0,
        char: "*",
        color: Particles.palette_color(:cyan),
        life: 200,
        target_x: target_x,
        target_y: target_y,
        arrived: false
      }
    end)
  end

  @doc """
  Updates particles toward their targets using ease-out approach.
  """
  @spec update_toward_target(formation_particle()) :: formation_particle()
  def update_toward_target(particle) do
    dx = particle.target_x - particle.x
    dy = particle.target_y - particle.y
    dist = :math.sqrt(dx * dx + dy * dy)

    if dist < 0.5 do
      %{particle | x: particle.target_x, y: particle.target_y, arrived: true}
    else
      # Ease-out: faster when far, slower when close
      speed = min(dist * 0.15, 2.0)
      vx = dx / dist * speed
      vy = dy / dist * speed

      %{
        particle
        | x: particle.x + vx,
          y: particle.y + vy,
          vx: vx,
          vy: vy
      }
    end
  end

  @doc """
  Updates a formation particle with small jitter to create shimmer effect.
  Only applies to arrived particles.
  """
  @spec update_with_jitter(formation_particle()) :: formation_particle()
  def update_with_jitter(particle) do
    if particle.arrived do
      jitter_x = (:rand.uniform() - 0.5) * 0.3
      jitter_y = (:rand.uniform() - 0.5) * 0.3

      %{
        particle
        | x: particle.target_x + jitter_x,
          y: particle.target_y + jitter_y
      }
    else
      particle
    end
  end

  @doc """
  Creates explosion particles from formation particles (for dispersal).
  """
  @spec explode_formation(list(formation_particle())) ::
          list(Particles.particle())
  def explode_formation(particles) do
    Enum.map(particles, fn p ->
      angle = :rand.uniform() * 2 * :math.pi()
      speed = 1.0 + :rand.uniform() * 2.0

      Particles.create(p.x, p.y,
        vx: :math.cos(angle) * speed * 1.5,
        vy: :math.sin(angle) * speed * 0.7,
        char: Enum.random(["*", ".", "+", "o"]),
        color: p.color,
        life: 25 + :rand.uniform(15)
      )
    end)
  end

  @doc """
  Renders formation particles to ANSI escape sequences.
  """
  @spec render(list(formation_particle()), non_neg_integer(), non_neg_integer()) ::
          String.t()
  def render(particles, width, height) do
    particles
    |> Enum.filter(fn p ->
      p.life > 0 and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height
    end)
    |> Enum.map(fn p ->
      x = trunc(p.x) + 1
      y = trunc(p.y) + 1
      brightness = if p.arrived, do: "1;", else: ""
      "\e[#{y};#{x}H\e[#{brightness}38;5;#{p.color}m#{p.char}\e[0m"
    end)
    |> Enum.join("")
  end

  @doc """
  Checks if all particles have arrived at their targets.
  """
  @spec all_arrived?(list(formation_particle())) :: boolean()
  def all_arrived?(particles) do
    Enum.all?(particles, & &1.arrived)
  end

  defp random_edge_position(width, height) do
    case :rand.uniform(4) do
      1 -> {:rand.uniform(width - 1) * 1.0, 0.0}
      2 -> {:rand.uniform(width - 1) * 1.0, (height - 1) * 1.0}
      3 -> {0.0, :rand.uniform(height - 1) * 1.0}
      4 -> {(width - 1) * 1.0, :rand.uniform(height - 1) * 1.0}
    end
  end
end
