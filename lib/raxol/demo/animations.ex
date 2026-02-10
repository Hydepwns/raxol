defmodule Raxol.Demo.Animations do
  @moduledoc """
  Animated demos for the terminal showcase.
  Supports both SSH (direct IO) and web (message-based) output.
  """

  alias Raxol.Demo.{Particles, GameOfLife, TextFormation}

  @spinner_dots ~w(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  @spinner_circle ~w(◐ ◓ ◑ ◒)
  @spinner_bounce ~w(▁ ▃ ▄ ▅ ▆ ▇ █ ▇ ▆ ▅ ▄ ▃)

  @frame_delay 33
  @default_width 80
  @default_height 24

  @tagline "Terminal Application Framework"

  @doc """
  Run the combined demo showcase (~55 seconds).
  """
  def run_showcase(target) do
    {width, height} = get_dimensions(target)
    out(target, "\e[?25l")
    out(target, "\e[2J\e[H")

    scene_opening_particles(target, width, height)
    scene_logo_reveal(target, width, height)
    scene_spinner_fireworks(target, width, height)
    scene_progress_bars(target, width, height)
    scene_game_of_life(target, width, height)
    scene_color_cascade(target, width, height)
    scene_grand_finale(target, width, height)

    out(target, "\e[?25h")
  end

  defp get_dimensions({:web, _pid, cols, rows}), do: {cols, rows}
  defp get_dimensions({:web, _pid}), do: {@default_width, @default_height}

  defp get_dimensions(_device) do
    case :io.columns() do
      {:ok, cols} ->
        case :io.rows() do
          {:ok, rows} -> {cols, rows}
          _ -> {cols, @default_height}
        end

      _ ->
        {@default_width, @default_height}
    end
  end

  @doc """
  Run the full animation showcase (legacy).
  """
  def run_all(target) do
    out(target, "\e[1;35m━━━ Live Animations ━━━\e[0m\r\n\r\n")

    out(target, "\e[1mSpinner:\e[0m\r\n")
    run_spinner(target, 2500)

    out(target, "\r\n\e[1mProgress Bar:\e[0m")
    run_progress(target, 2000)

    out(target, "\r\n\e[1mTyping Effect:\e[0m")
    run_typing(target)

    out(target, "\r\n\e[1mRainbow Wave:\e[0m")
    run_rainbow(target, 2000)

    out(target, "\r\n\e[32m✓\e[0m Animation demo complete!\r\n")
  end

  # ==========================================================================
  # SHOWCASE SCENES
  # ==========================================================================

  defp scene_opening_particles(target, width, height) do
    # ~5 seconds: Rising sparkles converging to center with spiral effect
    frames = div(5000, @frame_delay)
    center_x = div(width, 2)
    center_y = min(8, div(height, 3))

    particles =
      Enum.reduce(1..frames, [], fn frame, particles ->
        new =
          if frame < frames - 30 do
            for _ <- 1..3 do
              x = :rand.uniform(width - 1)

              Particles.create_with_trail(x * 1.0, (height - 2) * 1.0,
                vx: (:rand.uniform() - 0.5) * 0.5,
                vy: -0.3 - :rand.uniform() * 0.5,
                char: Enum.random(~w(* . + ' `)),
                color: Enum.random([51, 50, 49, 44, 45, 255, 254, 253]),
                life: 30 + :rand.uniform(40)
              )
            end
          else
            []
          end

        converge_start = frames - 40

        particles =
          (particles ++ new)
          |> Enum.map(fn p ->
            dx = center_x - p.x
            dy = center_y - p.y
            dist = :math.sqrt(dx * dx + dy * dy)

            if frame > converge_start and dist > 3 do
              # Apply spiral convergence
              apply_spiral_force(p, center_x, center_y, 0.03)
            else
              p
            end
          end)
          |> Enum.map(
            &Particles.update_with_trail(&1, gravity: 0, friction: 1.0)
          )
          |> Particles.prune()
          |> Enum.take(80)

        out(target, "\e[2J\e[H")
        out(target, Particles.render_with_trails(particles, width, height))
        Process.sleep(@frame_delay)

        particles
      end)

    # Flash before explosion
    flash_screen(target, :white, 2, width, height)

    # Quick explosion before logo
    explosion_particles =
      for _ <- 1..30 do
        Particles.create_sized_explosion(center_x * 1.0, center_y * 1.0)
      end

    run_particle_burst(
      target,
      particles ++ explosion_particles,
      15,
      width,
      height,
      []
    )
  end

  defp scene_logo_reveal(target, width, height) do
    # ~8 seconds: Particles form RAXOL, shimmer, then reveal solid text
    out(target, "\e[2J\e[H")
    center_x = div(width, 2)
    center_y = min(8, div(height, 3))

    # Phase 1: Particles converge to form RAXOL (~3 seconds)
    particles =
      TextFormation.create_formation_particles(
        "RAXOL",
        center_x,
        center_y,
        width,
        height
      )

    converge_frames = 90

    particles =
      Enum.reduce(1..converge_frames, particles, fn _frame, particles ->
        particles =
          particles
          |> Enum.map(&TextFormation.update_toward_target/1)

        out(target, "\e[2J\e[H")
        out(target, TextFormation.render(particles, width, height))
        Process.sleep(@frame_delay)

        particles
      end)

    # Phase 2: Hold formation with shimmer/jitter (~2.5 seconds)
    shimmer_frames = 50

    for frame <- 1..shimmer_frames do
      # Pulsing intensity using sine wave
      intensity = 0.5 + 0.5 * :math.sin(frame * 0.2)

      particles =
        particles
        |> Enum.map(fn p ->
          p = TextFormation.update_with_jitter(p)
          # Vary color based on intensity
          color =
            if :rand.uniform() < intensity * 0.3 do
              Particles.palette_color(:white)
            else
              Particles.palette_color(:cyan)
            end

          %{p | color: color}
        end)

      out(target, "\e[2J\e[H")
      out(target, TextFormation.render(particles, width, height))
      Process.sleep(50)
    end

    # Flash before solid reveal
    flash_screen(target, :cyan, 2, width, height)

    # Phase 3: Replace with solid text
    out(target, "\e[2J\e[H")
    logo_x = div(width - String.length("RAXOL"), 2)
    out(target, "\e[#{center_y};#{logo_x}H\e[1;36mRAXOL\e[0m")

    # Explode particles outward
    explosion_particles = TextFormation.explode_formation(particles)

    run_particle_burst(target, explosion_particles, 20, width, height,
      preserve_text: true,
      text_y: center_y
    )

    # Type out tagline
    tagline_x = div(width - String.length(@tagline), 2)
    tagline_y = center_y + 2
    out(target, "\e[#{tagline_y};#{tagline_x}H")

    for char <- String.graphemes(@tagline) do
      out(target, "\e[2m#{char}\e[0m")
      Process.sleep(30)
    end

    Process.sleep(500)
  end

  defp scene_spinner_fireworks(target, width, height) do
    # ~10 seconds: Multiple spinners that explode into particles on completion
    # Transition fade from previous scene
    transition_fade(target, 10)

    out(target, "\e[2J\e[H")
    out(target, "\e[1;35m━━━ Loading Components ━━━\e[0m\r\n\r\n")

    spinners = [
      {5, "Core Runtime", @spinner_dots, Particles.palette_color(:cyan)},
      {7, "UI Framework", @spinner_circle, Particles.palette_color(:magenta)},
      {9, "Event System", @spinner_bounce, Particles.palette_color(:gold)}
    ]

    for {y, label, frames, color} <- spinners do
      out(target, "\e[#{y};3H\e[0m#{label}")
      out(target, "\e[#{y};25H")

      spin_duration = 2000 + :rand.uniform(1000)
      iterations = div(spin_duration, 80)
      accel_start = round(iterations * 0.8)

      for i <- 0..iterations do
        frame = Enum.at(frames, rem(i, length(frames)))
        out(target, "\e[#{y};25H\e[38;5;#{color}m#{frame}\e[0m")

        # Accelerate in final 20%: 80ms -> 20ms
        delay =
          if i >= accel_start do
            progress = (i - accel_start) / (iterations - accel_start)
            round(80 - 60 * progress)
          else
            80
          end

        Process.sleep(delay)
      end

      # Flash before checkmark
      flash_screen(target, :white, 1, width, height)

      # Mark complete
      out(target, "\e[#{y};25H\e[32m✓\e[0m")

      # Sized explosion at spinner position
      particles =
        for _ <- 1..25 do
          Particles.create_sized_explosion(25.0, y * 1.0)
        end

      run_particle_burst(target, particles, 20, width, height,
        preserve_text: true,
        text_y: 1..10
      )
    end

    Process.sleep(300)
  end

  defp scene_progress_bars(target, width, height) do
    # ~10 seconds: Progress bars with particle trails
    out(target, "\e[2J\e[H")
    out(target, "\e[1;35m━━━ Processing ━━━\e[0m\r\n\r\n")

    bars = [
      {5, "Compiling", 45, Particles.palette_color(:cyan)},
      {7, "Optimizing", 35, Particles.palette_color(:magenta)},
      {9, "Finalizing", 25, Particles.palette_color(:gold)}
    ]

    for {y, label, _bar_width, _color} <- bars do
      out(target, "\e[#{y};3H#{label}")
    end

    bar_width = min(40, width - 30)
    bar_start = 16
    steps = 100
    step_delay = 30

    particles = []

    particles =
      Enum.reduce(0..steps, particles, fn step, particles ->
        for {y, _label, speed, color} <- bars do
          progress = min(100, div(step * speed, 10))
          filled = div(progress * bar_width, 100)

          bar =
            "\e[38;5;#{color}m" <>
              String.duplicate("█", filled) <>
              "\e[90m" <>
              String.duplicate("░", bar_width - filled) <>
              "\e[0m"

          out(target, "\e[#{y};#{bar_start}H#{bar} #{progress}%  ")

          if progress < 100 and :rand.uniform() > 0.6 do
            [Particles.create_trail((bar_start + filled) * 1.0, y * 1.0, color)]
          else
            []
          end
        end
        |> List.flatten()
        |> then(fn new_particles ->
          updated =
            (particles ++ new_particles)
            |> Enum.map(&Particles.update(&1, gravity: 0.02))
            |> Particles.prune()
            |> Enum.take(100)

          out(target, Particles.render(updated, width, height))
          Process.sleep(step_delay)
          updated
        end)
      end)

    # Completion burst
    for {y, _label, _speed, color} <- bars do
      explosion =
        for _ <- 1..15 do
          Particles.create_explosion((bar_start + bar_width) * 1.0, y * 1.0)
          |> Map.put(:color, color)
        end

      run_particle_burst(target, particles ++ explosion, 15, width, height,
        preserve_text: true,
        text_y: 1..10
      )
    end

    Process.sleep(300)
  end

  defp scene_game_of_life(target, width, height) do
    # ~15 seconds: Conway's Game of Life with age-based colors
    out(target, "\e[2J\e[H")
    out(target, "\e[1;35m━━━ Game of Life ━━━\e[0m\r\n")

    gol_width = min(60, width - 10)
    gol_height = min(18, height - 6)
    offset_x = div(width - gol_width, 2)
    offset_y = 3

    grid = GameOfLife.create_r_pentomino(gol_width, gol_height)

    # Run simulation
    grid =
      Enum.reduce(1..150, grid, fn i, grid ->
        delay = if i < 50, do: 80, else: if(i < 100, do: 50, else: 30)

        out(target, "\e[#{offset_y};#{offset_x}H")
        rendered = GameOfLife.render(grid, gol_width, gol_height)

        for {line, idx} <- Enum.with_index(String.split(rendered, "\r\n")) do
          out(target, "\e[#{offset_y + idx};#{offset_x}H#{line}")
        end

        pop = GameOfLife.population(grid)

        out(
          target,
          "\e[#{offset_y + gol_height + 1};#{offset_x}H\e[2mGeneration: #{i}  Population: #{pop}  \e[0m"
        )

        Process.sleep(delay)
        GameOfLife.step(grid, gol_width, gol_height)
      end)

    # Explode remaining cells into particles
    live_cells = GameOfLife.live_cells(grid)

    particles =
      Enum.flat_map(live_cells, fn {x, y} ->
        for _ <- 1..2 do
          Particles.create_explosion((offset_x + x) * 1.0, (offset_y + y) * 1.0)
        end
      end)
      |> Enum.take(200)

    run_particle_burst(target, particles, 30, width, height, [])
  end

  defp scene_color_cascade(target, width, height) do
    # ~8 seconds: Rainbow particles raining with sine wave motion
    # Transition fade from previous scene
    transition_fade(target, 10)

    out(target, "\e[2J\e[H")

    frames = div(8000, @frame_delay)
    particles = []

    Enum.reduce(1..frames, particles, fn frame, particles ->
      new =
        if frame < frames - 30 do
          for _ <- 1..4 do
            x = :rand.uniform(width - 1)
            hue = rem(frame * 5 + x * 3, 360)
            color = hue_to_256(hue)
            # Add phase based on x position for wave pattern
            phase = x * 0.3
            Particles.create_rain_with_phase(x * 1.0, 0.0, color, phase)
          end
        else
          []
        end

      wave_x = rem(frame * 2, width)

      new =
        if frame < frames - 20 do
          wave_particle =
            Particles.create(wave_x * 1.0, (height - 3) * 1.0,
              vx: 0,
              vy: -0.5,
              char: "█",
              color: hue_to_256(rem(frame * 8, 360)),
              life: 20
            )

          [wave_particle | new]
        else
          new
        end

      particles =
        (particles ++ new)
        |> Enum.map(fn p ->
          # Apply sine wave force based on phase
          phase = Map.get(p, :phase, 0)
          wave_force = :math.sin(p.y * 0.2 + phase) * 0.15
          p = %{p | vx: p.vx + wave_force}
          Particles.update(p, gravity: 0.03)
        end)
        |> Particles.prune()
        |> Enum.take(180)

      out(target, "\e[2J\e[H")
      out(target, Particles.render(particles, width, height))
      Process.sleep(@frame_delay)

      particles
    end)
  end

  defp scene_grand_finale(target, width, height) do
    # ~8 seconds: Rockets, ring bursts, cascading explosions, final message
    # Transition fade from previous scene
    transition_fade(target, 15)

    center_x = div(width, 2)
    center_y = div(height, 2)

    # Phase 1: Launch 5 rockets from bottom
    rockets =
      for i <- 1..5 do
        x = div(width, 6) * i
        target_y = 4 + :rand.uniform(4)

        Particles.create_rocket(x * 1.0, (height - 2) * 1.0,
          target_y: target_y,
          color: Particles.palette_color(Enum.random([:cyan, :magenta, :gold]))
        )
      end

    # Animate rockets rising with trails
    {_exploded_rockets, all_explosions} =
      Enum.reduce(1..40, {rockets, []}, fn _frame, {rockets, explosions} ->
        {rockets, new_explosions} =
          rockets
          |> Enum.map(fn r ->
            updated = Particles.update_with_trail(r, gravity: 0, friction: 1.0)

            # Check if rocket should explode
            if updated.life <= 1 do
              {nil, create_rocket_explosion(updated.x, updated.y)}
            else
              {updated, []}
            end
          end)
          |> Enum.unzip()

        rockets = Enum.reject(rockets, &is_nil/1)
        new_explosions = List.flatten(new_explosions)

        # Update existing explosions with cascade
        {explosions, children} =
          explosions
          |> Enum.map(&Particles.update_cascade(&1, gravity: 0.05))
          |> Enum.unzip()

        explosions = List.flatten([explosions | children])
        explosions = Particles.prune(explosions)

        all_particles = rockets ++ new_explosions ++ explosions

        out(target, "\e[2J\e[H")

        out(
          target,
          Particles.render_with_trails(
            Enum.take(all_particles, 200),
            width,
            height
          )
        )

        Process.sleep(@frame_delay)

        {rockets, Particles.prune(explosions ++ new_explosions)}
      end)

    # Phase 2: Ring bursts in 3 colors
    ring_colors = [
      Particles.palette_color(:cyan),
      Particles.palette_color(:magenta),
      Particles.palette_color(:gold)
    ]

    ring_particles =
      ring_colors
      |> Enum.with_index()
      |> Enum.flat_map(fn {color, idx} ->
        Process.sleep(150)

        Particles.create_ring_burst(center_x * 1.0, center_y * 1.0, 20,
          speed: 1.2 + idx * 0.4,
          color: color,
          life: 30
        )
      end)

    combined = all_explosions ++ ring_particles

    # Animate rings expanding
    Enum.reduce(1..35, combined, fn _frame, particles ->
      particles =
        particles
        |> Enum.map(&Particles.update_with_trail(&1, gravity: 0.02))
        |> Particles.prune()
        |> Enum.take(200)

      out(target, "\e[2J\e[H")
      out(target, Particles.render_with_trails(particles, width, height))
      Process.sleep(@frame_delay)

      particles
    end)

    # Phase 3: Screen flash and final message
    flash_screen(target, :white, 3, width, height)

    out(target, "\e[2J\e[H")
    message = "Built with Raxol"
    msg_x = div(width - String.length(message), 2)
    msg_y = div(height, 2)

    for i <- 1..5 do
      brightness = div(255 * i, 5)

      out(
        target,
        "\e[#{msg_y};#{msg_x}H\e[38;2;#{brightness};#{brightness};#{brightness}m#{message}\e[0m"
      )

      Process.sleep(100)
    end

    out(
      target,
      "\e[#{msg_y + 2};#{div(width - 14, 2)}H\e[2mhttps://raxol.io\e[0m"
    )

    Process.sleep(1500)
    out(target, "\e[2J\e[H")
    out(target, "\e[32m✓\e[0m Demo complete!\r\n")
  end

  defp create_rocket_explosion(x, y) do
    # Create cascading explosion (generation 2 = will spawn children)
    for _ <- 1..15 do
      Particles.create_cascade_explosion(x, y, 2)
    end
  end

  # ==========================================================================
  # PARTICLE HELPERS
  # ==========================================================================

  defp run_particle_burst(target, particles, frames, width, height, opts) do
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

  # Brief full-screen color flash effect
  defp flash_screen(target, color, frames, width, height) do
    color_code =
      case color do
        :white -> "48;5;255"
        :cyan -> "48;5;51"
        :magenta -> "48;5;201"
        :gold -> "48;5;220"
        _ -> "48;5;255"
      end

    for _ <- 1..frames do
      # Fill screen with color
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

  # Gradual dim before scene transition
  defp transition_fade(target, frames) do
    for i <- 1..frames do
      # Progressively dim with darker grey
      grey = 255 - div(255 * i, frames)
      out(target, "\e[38;2;#{grey};#{grey};#{grey}m")
      Process.sleep(30)
    end

    out(target, "\e[0m")
  end

  # Apply spiral convergence force to particle
  defp apply_spiral_force(particle, center_x, center_y, strength) do
    dx = center_x - particle.x
    dy = center_y - particle.y
    dist = :math.sqrt(dx * dx + dy * dy)

    if dist > 1 do
      # Normalize direction
      nx = dx / dist
      ny = dy / dist

      # Tangential component (perpendicular to radial)
      tx = -ny
      ty = nx

      # Combined force: radial + tangential
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

  defp hue_to_256(hue) do
    # Map hue (0-360) to ANSI 256 color cube
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

  # ==========================================================================
  # LEGACY ANIMATION FUNCTIONS
  # ==========================================================================

  def run_spinner(target, duration_ms \\ 3000) do
    frames = @spinner_dots
    frame_delay = 80
    iterations = div(duration_ms, frame_delay)

    out(target, "\e[?25l")
    out(target, "  Loading ")

    for i <- 0..iterations do
      frame = Enum.at(frames, rem(i, length(frames)))
      out(target, "\e[s\e[32m#{frame}\e[0m\e[u")
      Process.sleep(frame_delay)
    end

    out(target, "\e[32m✓\e[0m Done!\r\n")
    out(target, "\e[?25h")
  end

  def run_progress(target, duration_ms \\ 3000) do
    width = 30
    steps = 50
    delay = div(duration_ms, steps)

    out(target, "\e[?25l\r\n")

    for i <- 0..steps do
      progress = div(i * 100, steps)
      filled = div(i * width, steps)
      empty = width - filled

      bar =
        "\e[32m" <>
          String.duplicate("█", filled) <>
          "\e[90m" <>
          String.duplicate("░", empty) <>
          "\e[0m"

      out(target, "\r  #{bar} #{progress}%")
      Process.sleep(delay)
    end

    out(target, "\r\n\e[?25h")
  end

  def run_typing(target, text \\ "Hello, world! Welcome to Raxol.") do
    out(target, "\r\n  \e[32m>\e[0m ")

    for char <- String.graphemes(text) do
      out(target, char)

      delay =
        case char do
          " " -> 50
          "." -> 300
          "!" -> 300
          "," -> 150
          _ -> 30 + :rand.uniform(50)
        end

      Process.sleep(delay)
    end

    for _ <- 1..4 do
      out(target, "\e[5m▌\e[0m")
      Process.sleep(300)
      out(target, "\b \b")
      Process.sleep(300)
    end

    out(target, "\r\n")
  end

  def run_rainbow(target, duration_ms \\ 3000) do
    width = 40
    frame_delay = 50
    iterations = div(duration_ms, frame_delay)

    out(target, "\e[?25l\r\n")

    for i <- 0..iterations do
      line =
        for j <- 0..(width - 1) do
          hue = rem(i * 8 + j * 6, 360)
          {r, g, b} = hsl_to_rgb(hue, 1.0, 0.5)
          "\e[48;2;#{r};#{g};#{b}m \e[0m"
        end
        |> Enum.join("")

      out(target, "\r  #{line}")
      Process.sleep(frame_delay)
    end

    out(target, "\r\n\e[?25h")
  end

  # ==========================================================================
  # OUTPUT AND COLOR HELPERS
  # ==========================================================================

  defp out(device, data) when is_pid(device) or is_atom(device) do
    IO.write(device, data)
  end

  defp out({:web, pid}, data) do
    send(pid, {:animation_output, data})
  end

  defp out({:web, pid, _cols, _rows}, data) do
    send(pid, {:animation_output, data})
  end

  defp hsl_to_rgb(h, s, l) do
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

    {
      round((r1 + m) * 255),
      round((g1 + m) * 255),
      round((b1 + m) * 255)
    }
  end

  defp float_mod(a, b), do: a - Float.floor(a / b) * b
end
