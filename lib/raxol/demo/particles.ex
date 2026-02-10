defmodule Raxol.Demo.Particles do
  @moduledoc """
  Particle system for animated demo effects.
  Supports sparkles, explosions, trails, and floating elements.
  """

  @sparkle_chars ~w(* . + ' `)
  @star_chars ["*", ".", "+", "o"]
  @trail_chars ["█", "▓", "▒", "░"]

  # Size-based character sets
  @small_chars [".", "'", "`", ","]
  @medium_chars ["*", "+", "o", "x"]
  @large_chars ["@", "#", "O", "*"]

  # Afterimage trail characters (bright to dim)
  @afterimage_chars [".", "'", "`"]

  @cyan_palette [51, 50, 49, 44, 45]
  @magenta_palette [201, 200, 199, 164, 165]
  @gold_palette [220, 221, 222, 228, 229]
  @white_palette [255, 254, 253, 252, 251]
  @red_palette [196, 197, 198, 199, 200]

  @type particle :: map()

  @doc """
  Creates a new particle at the given position.
  """
  @spec create(float(), float(), keyword()) :: particle()
  def create(x, y, opts \\ []) do
    %{
      x: x,
      y: y,
      vx: Keyword.get(opts, :vx, (:rand.uniform() - 0.5) * 2),
      vy: Keyword.get(opts, :vy, -:rand.uniform() * 2),
      char: Keyword.get(opts, :char, Enum.random(@sparkle_chars)),
      color: Keyword.get(opts, :color, random_color()),
      life: Keyword.get(opts, :life, 20 + :rand.uniform(30)),
      history: Keyword.get(opts, :history, []),
      generation: Keyword.get(opts, :generation, 0),
      spawn_at_life: Keyword.get(opts, :spawn_at_life, 0)
    }
  end

  @doc """
  Creates a particle with size-based character selection.
  Size can be :small, :medium, or :large.
  """
  @spec create_sized(float(), float(), atom(), keyword()) :: particle()
  def create_sized(x, y, size, opts \\ []) do
    chars =
      case size do
        :small -> @small_chars
        :medium -> @medium_chars
        :large -> @large_chars
        _ -> @medium_chars
      end

    create(x, y, Keyword.put(opts, :char, Enum.random(chars)))
  end

  @doc """
  Creates a particle with trail tracking enabled.
  """
  @spec create_with_trail(float(), float(), keyword()) :: particle()
  def create_with_trail(x, y, opts \\ []) do
    create(x, y, Keyword.put(opts, :history, [{x, y}]))
  end

  @doc """
  Creates a sparkle particle (rising, fading).
  """
  @spec create_sparkle(float(), float()) :: particle()
  def create_sparkle(x, y) do
    create(x, y,
      vx: (:rand.uniform() - 0.5) * 0.5,
      vy: -0.3 - :rand.uniform() * 0.5,
      char: Enum.random(@sparkle_chars),
      color: Enum.random(@white_palette ++ @cyan_palette),
      life: 30 + :rand.uniform(40)
    )
  end

  @doc """
  Creates an explosion particle (radiates outward).
  """
  @spec create_explosion(float(), float()) :: particle()
  def create_explosion(x, y) do
    angle = :rand.uniform() * 2 * :math.pi()
    speed = 0.5 + :rand.uniform() * 1.5

    create(x, y,
      vx: :math.cos(angle) * speed,
      vy: :math.sin(angle) * speed * 0.5,
      char: Enum.random(@star_chars),
      color: Enum.random(@gold_palette ++ @magenta_palette),
      life: 15 + :rand.uniform(25)
    )
  end

  @doc """
  Creates an explosion particle with size distribution.
  70% small, 25% medium, 5% large.
  """
  @spec create_sized_explosion(float(), float()) :: particle()
  def create_sized_explosion(x, y) do
    size =
      case :rand.uniform(100) do
        n when n <= 70 -> :small
        n when n <= 95 -> :medium
        _ -> :large
      end

    angle = :rand.uniform() * 2 * :math.pi()
    speed = 0.5 + :rand.uniform() * 1.5

    create_sized(x, y, size,
      vx: :math.cos(angle) * speed,
      vy: :math.sin(angle) * speed * 0.5,
      color: Enum.random(@gold_palette ++ @magenta_palette),
      life: 15 + :rand.uniform(25)
    )
  end

  @doc """
  Creates a cascading explosion particle that spawns children.
  """
  @spec create_cascade_explosion(float(), float(), integer()) :: particle()
  def create_cascade_explosion(x, y, generation) do
    angle = :rand.uniform() * 2 * :math.pi()
    speed = 0.8 + :rand.uniform() * 1.2

    life = 20 + :rand.uniform(15)
    spawn_at = div(life, 2)

    create(x, y,
      vx: :math.cos(angle) * speed,
      vy: :math.sin(angle) * speed * 0.5,
      char: Enum.random(@star_chars),
      color: Enum.random(@gold_palette ++ @magenta_palette ++ @red_palette),
      life: life,
      generation: generation,
      spawn_at_life: spawn_at,
      history: [{x, y}]
    )
  end

  @doc """
  Creates a trail particle (slow fade, minimal movement).
  """
  @spec create_trail(float(), float(), non_neg_integer()) :: particle()
  def create_trail(x, y, color) do
    create(x, y,
      vx: 0,
      vy: 0,
      char: Enum.at(@trail_chars, :rand.uniform(4) - 1),
      color: color,
      life: 5 + :rand.uniform(10)
    )
  end

  @doc """
  Creates a rain particle (falls down).
  """
  @spec create_rain(float(), float(), non_neg_integer()) :: particle()
  def create_rain(x, y, color) do
    create(x, y,
      vx: (:rand.uniform() - 0.5) * 0.2,
      vy: 0.3 + :rand.uniform() * 0.3,
      char: Enum.random([".", "|", ":", "'"]),
      color: color,
      life: 40 + :rand.uniform(20)
    )
  end

  @doc """
  Creates a rain particle with phase for sine wave motion.
  """
  @spec create_rain_with_phase(float(), float(), non_neg_integer(), float()) ::
          particle()
  def create_rain_with_phase(x, y, color, phase) do
    p = create_rain(x, y, color)
    Map.put(p, :phase, phase)
  end

  @doc """
  Creates a ring of particles expanding outward.
  Y is compressed for terminal aspect ratio.
  """
  @spec create_ring_burst(float(), float(), integer(), keyword()) ::
          list(particle())
  def create_ring_burst(center_x, center_y, count \\ 24, opts \\ []) do
    speed = Keyword.get(opts, :speed, 1.5)
    color = Keyword.get(opts, :color, random_color())
    life = Keyword.get(opts, :life, 25)
    char = Keyword.get(opts, :char, "*")

    for i <- 0..(count - 1) do
      angle = i / count * 2 * :math.pi()

      create(center_x, center_y,
        vx: :math.cos(angle) * speed,
        vy: :math.sin(angle) * speed * 0.5,
        char: char,
        color: color,
        life: life + :rand.uniform(10),
        history: [{center_x, center_y}]
      )
    end
  end

  @doc """
  Creates a rising rocket particle with trail.
  """
  @spec create_rocket(float(), float(), keyword()) :: particle()
  def create_rocket(x, y, opts \\ []) do
    target_y = Keyword.get(opts, :target_y, 5)
    color = Keyword.get(opts, :color, random_color())

    create(x, y,
      vx: (:rand.uniform() - 0.5) * 0.3,
      vy: -1.2 - :rand.uniform() * 0.5,
      char: "|",
      color: color,
      life: round((y - target_y) * 1.2),
      history: [{x, y}]
    )
  end

  @doc """
  Updates a particle's position and life.
  """
  @spec update(particle(), keyword()) :: particle()
  def update(particle, opts \\ []) do
    gravity = Keyword.get(opts, :gravity, 0.05)
    friction = Keyword.get(opts, :friction, 0.98)

    %{
      particle
      | x: particle.x + particle.vx,
        y: particle.y + particle.vy,
        vx: particle.vx * friction,
        vy: particle.vy + gravity,
        life: particle.life - 1
    }
  end

  @doc """
  Updates particle without gravity (for floating effects).
  """
  @spec update_float(particle()) :: particle()
  def update_float(particle) do
    update(particle, gravity: 0, friction: 1.0)
  end

  @doc """
  Updates particle and maintains position history for trail effect.
  Keeps last 4 positions.
  """
  @spec update_with_trail(particle(), keyword()) :: particle()
  def update_with_trail(particle, opts \\ []) do
    history = Map.get(particle, :history, [])
    new_history = [{particle.x, particle.y} | Enum.take(history, 3)]

    particle
    |> update(opts)
    |> Map.put(:history, new_history)
  end

  @doc """
  Updates cascading particles and returns {updated_particle, spawned_children}.
  Call this when you need cascade behavior.
  """
  @spec update_cascade(particle(), keyword()) :: {particle(), list(particle())}
  def update_cascade(particle, opts \\ []) do
    updated = update_with_trail(particle, opts)
    generation = Map.get(particle, :generation, 0)
    spawn_at = Map.get(particle, :spawn_at_life, 0)

    children =
      if generation > 0 and updated.life == spawn_at do
        for _ <- 1..(3 + :rand.uniform(2)) do
          create_cascade_explosion(updated.x, updated.y, generation - 1)
        end
      else
        []
      end

    {updated, children}
  end

  @doc """
  Renders particles to a frame buffer, returns ANSI escape sequences.
  """
  @spec render(list(particle()), non_neg_integer(), non_neg_integer()) ::
          String.t()
  def render(particles, width, height) do
    particles
    |> Enum.filter(fn p ->
      p.life > 0 and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height
    end)
    |> Enum.map(fn p ->
      x = trunc(p.x) + 1
      y = trunc(p.y) + 1
      alpha = min(1.0, p.life / 20)
      color_code = if alpha > 0.5, do: p.color, else: dim_color(p.color)
      "\e[#{y};#{x}H\e[38;5;#{color_code}m#{p.char}\e[0m"
    end)
    |> Enum.join("")
  end

  @doc """
  Renders particles with their trail history.
  Trail chars fade from bright to dim.
  """
  @spec render_with_trails(
          list(particle()),
          non_neg_integer(),
          non_neg_integer()
        ) :: String.t()
  def render_with_trails(particles, width, height) do
    # First render trails, then particles on top
    trail_output =
      particles
      |> Enum.flat_map(fn p ->
        history = Map.get(p, :history, [])

        history
        |> Enum.with_index()
        |> Enum.map(fn {{hx, hy}, idx} ->
          if hx >= 0 and hx < width and hy >= 0 and hy < height do
            x = trunc(hx) + 1
            y = trunc(hy) + 1

            char =
              Enum.at(
                @afterimage_chars,
                min(idx, length(@afterimage_chars) - 1)
              )

            color = dim_color(dim_color(p.color))
            "\e[#{y};#{x}H\e[38;5;#{color}m#{char}\e[0m"
          else
            ""
          end
        end)
      end)
      |> Enum.join("")

    particle_output = render(particles, width, height)

    trail_output <> particle_output
  end

  @doc """
  Filters out dead particles.
  """
  @spec prune(list(particle())) :: list(particle())
  def prune(particles) do
    Enum.filter(particles, fn p -> p.life > 0 end)
  end

  @doc """
  Returns a random color from the available palettes.
  """
  @spec random_color() :: non_neg_integer()
  def random_color do
    Enum.random(
      @cyan_palette ++ @magenta_palette ++ @gold_palette ++ @white_palette
    )
  end

  @doc """
  Returns a random color from a specific palette.
  """
  @spec palette_color(atom()) :: non_neg_integer()
  def palette_color(:cyan), do: Enum.random(@cyan_palette)
  def palette_color(:magenta), do: Enum.random(@magenta_palette)
  def palette_color(:gold), do: Enum.random(@gold_palette)
  def palette_color(:white), do: Enum.random(@white_palette)
  def palette_color(:red), do: Enum.random(@red_palette)

  @doc """
  Converts hue (0-360) to an ANSI 256 color code.
  """
  @spec hue_to_color(integer()) :: non_neg_integer()
  def hue_to_color(hue) do
    case rem(div(hue, 60), 6) do
      0 -> 196
      1 -> 202
      2 -> 226
      3 -> 46
      4 -> 21
      _ -> 201
    end
  end

  defp dim_color(color) when color > 240, do: color - 3
  defp dim_color(color), do: max(232, color - 2)
end
