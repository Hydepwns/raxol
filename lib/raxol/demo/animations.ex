defmodule Raxol.Demo.Animations do
  @moduledoc """
  Animated demos for the terminal showcase.
  Supports both SSH (direct IO) and web (message-based) output.
  """

  alias Raxol.Demo.{
    Effects,
    GameOfLife,
    Particles,
    TextFormation
  }

  @compile {:no_warn_undefined, [Raxol.Demo.Effects]}

  @spinner_dots ~w(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  @spinner_circle ~w(◐ ◓ ◑ ◒)
  @spinner_bounce ~w(▁ ▃ ▄ ▅ ▆ ▇ █ ▇ ▆ ▅ ▄ ▃)

  @frame_delay 33
  @default_width Raxol.Constants.default_terminal_width()
  @default_height Raxol.Constants.default_terminal_height()

  @tagline "Terminal Application Framework"

  @doc "Run the combined demo showcase (~55 seconds)."
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

  @doc "Run the full animation showcase (legacy)."
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
    frames = div(5000, @frame_delay)
    center_x = div(width, 2)
    center_y = min(8, div(height, 3))

    particles =
      Enum.reduce(1..frames, [], fn frame, particles ->
        new = opening_new_particles(frame, frames, width, height)
        converge_start = frames - 40

        particles =
          (particles ++ new)
          |> Enum.map(
            &maybe_apply_spiral(&1, frame, converge_start, center_x, center_y)
          )
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

    opening_explosion(target, particles, center_x, center_y, width, height)
  end

  defp opening_new_particles(frame, frames, width, height) do
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
  end

  defp maybe_apply_spiral(particle, frame, converge_start, center_x, center_y) do
    if frame > converge_start do
      Effects.apply_spiral_force(particle, center_x, center_y, 0.03)
    else
      particle
    end
  end

  defp opening_explosion(target, particles, center_x, center_y, width, height) do
    Effects.flash_screen(target, :white, 2, width, height)

    explosion_particles =
      for _ <- 1..30 do
        Particles.create_sized_explosion(center_x * 1.0, center_y * 1.0)
      end

    Effects.run_particle_burst(
      target,
      particles ++ explosion_particles,
      15,
      width,
      height,
      []
    )
  end

  defp scene_logo_reveal(target, width, height) do
    out(target, "\e[2J\e[H")
    center_x = div(width, 2)
    center_y = min(8, div(height, 3))

    particles = logo_converge(target, center_x, center_y, width, height)
    _ = logo_shimmer(target, particles, width, height)

    Effects.flash_screen(target, :cyan, 2, width, height)

    out(target, "\e[2J\e[H")
    logo_x = div(width - String.length("RAXOL"), 2)
    out(target, "\e[#{center_y};#{logo_x}H\e[1;36mRAXOL\e[0m")

    explosion_particles = TextFormation.explode_formation(particles)

    Effects.run_particle_burst(target, explosion_particles, 20, width, height,
      preserve_text: true,
      text_y: center_y
    )

    logo_type_tagline(target, center_y, width)
  end

  defp logo_converge(target, center_x, center_y, width, height) do
    particles =
      TextFormation.create_formation_particles(
        "RAXOL",
        center_x,
        center_y,
        width,
        height
      )

    converge_frames = 90

    Enum.reduce(1..converge_frames, particles, fn _frame, particles ->
      particles = Enum.map(particles, &TextFormation.update_toward_target/1)
      out(target, "\e[2J\e[H")
      out(target, TextFormation.render(particles, width, height))
      Process.sleep(@frame_delay)
      particles
    end)
  end

  defp logo_shimmer(target, particles, width, height) do
    shimmer_frames = 50

    for frame <- 1..shimmer_frames do
      intensity = 0.5 + 0.5 * :math.sin(frame * 0.2)

      particles =
        Enum.map(particles, fn p ->
          p = TextFormation.update_with_jitter(p)
          color = shimmer_color(intensity)
          %{p | color: color}
        end)

      out(target, "\e[2J\e[H")
      out(target, TextFormation.render(particles, width, height))
      Process.sleep(50)
    end
  end

  defp shimmer_color(intensity) do
    if :rand.uniform() < intensity * 0.3 do
      Particles.palette_color(:white)
    else
      Particles.palette_color(:cyan)
    end
  end

  defp logo_type_tagline(target, center_y, width) do
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
    Effects.transition_fade(target, 10)

    out(target, "\e[2J\e[H")
    out(target, "\e[1;35m━━━ Loading Components ━━━\e[0m\r\n\r\n")

    spinners = [
      {5, "Core Runtime", @spinner_dots, Particles.palette_color(:cyan)},
      {7, "UI Framework", @spinner_circle, Particles.palette_color(:magenta)},
      {9, "Event System", @spinner_bounce, Particles.palette_color(:gold)}
    ]

    for {y, label, frames, color} <- spinners do
      run_single_spinner(target, y, label, frames, color, width, height)
    end

    Process.sleep(300)
  end

  defp run_single_spinner(target, y, label, frames, color, width, height) do
    out(target, "\e[#{y};3H\e[0m#{label}")
    out(target, "\e[#{y};25H")

    spin_duration = 2000 + :rand.uniform(1000)
    iterations = div(spin_duration, 80)
    accel_start = round(iterations * 0.8)

    for i <- 0..iterations do
      frame = Enum.at(frames, rem(i, length(frames)))
      out(target, "\e[#{y};25H\e[38;5;#{color}m#{frame}\e[0m")
      delay = spinner_delay(i, accel_start, iterations)
      Process.sleep(delay)
    end

    Effects.flash_screen(target, :white, 1, width, height)
    out(target, "\e[#{y};25H\e[32m✓\e[0m")

    particles =
      for _ <- 1..25 do
        Particles.create_sized_explosion(25.0, y * 1.0)
      end

    Effects.run_particle_burst(target, particles, 20, width, height,
      preserve_text: true,
      text_y: 1..10
    )
  end

  defp spinner_delay(i, accel_start, iterations) do
    if i >= accel_start do
      progress = (i - accel_start) / (iterations - accel_start)
      round(80 - 60 * progress)
    else
      80
    end
  end

  defp scene_progress_bars(target, width, height) do
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

    particles =
      Enum.reduce(0..steps, [], fn step, particles ->
        new_particles =
          progress_step_particles(target, bars, step, bar_width, bar_start)

        update_progress_particles(
          target,
          particles,
          new_particles,
          width,
          height,
          step_delay
        )
      end)

    _ =
      progress_bars_explode(
        target,
        bars,
        particles,
        bar_start,
        bar_width,
        width,
        height
      )

    Process.sleep(300)
  end

  defp progress_step_particles(target, bars, step, bar_width, bar_start) do
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

      maybe_trail_particle(progress, bar_start, filled, y, color)
    end
    |> List.flatten()
  end

  defp maybe_trail_particle(progress, bar_start, filled, y, color) do
    if progress < 100 and :rand.uniform() > 0.6 do
      [Particles.create_trail((bar_start + filled) * 1.0, y * 1.0, color)]
    else
      []
    end
  end

  defp update_progress_particles(
         target,
         particles,
         new_particles,
         width,
         height,
         step_delay
       ) do
    updated =
      (particles ++ new_particles)
      |> Enum.map(&Particles.update(&1, gravity: 0.02))
      |> Particles.prune()
      |> Enum.take(100)

    out(target, Particles.render(updated, width, height))
    Process.sleep(step_delay)
    updated
  end

  defp progress_bars_explode(
         target,
         bars,
         particles,
         bar_start,
         bar_width,
         width,
         height
       ) do
    for {y, _label, _speed, color} <- bars do
      explosion =
        for _ <- 1..15 do
          Particles.create_explosion((bar_start + bar_width) * 1.0, y * 1.0)
          |> Map.put(:color, color)
        end

      Effects.run_particle_burst(
        target,
        particles ++ explosion,
        15,
        width,
        height,
        preserve_text: true,
        text_y: 1..10
      )
    end
  end

  defp scene_game_of_life(target, width, height) do
    out(target, "\e[2J\e[H")
    out(target, "\e[1;35m━━━ Game of Life ━━━\e[0m\r\n")

    gol_width = min(60, width - 10)
    gol_height = min(18, height - 6)
    offset_x = div(width - gol_width, 2)
    offset_y = 3

    grid = GameOfLife.create_r_pentomino(gol_width, gol_height)

    grid =
      Enum.reduce(1..150, grid, fn i, grid ->
        gol_render_frame(
          target,
          grid,
          i,
          gol_width,
          gol_height,
          offset_x,
          offset_y
        )
      end)

    gol_explode(target, grid, offset_x, offset_y, width, height)
  end

  defp gol_render_frame(
         target,
         grid,
         i,
         gol_width,
         gol_height,
         offset_x,
         offset_y
       ) do
    delay = gol_delay(i)
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
  end

  defp gol_delay(i) when i < 50, do: 80
  defp gol_delay(i) when i < 100, do: 50
  defp gol_delay(_i), do: 30

  defp gol_explode(target, grid, offset_x, offset_y, width, height) do
    live_cells = GameOfLife.live_cells(grid)

    particles =
      Enum.flat_map(live_cells, fn {x, y} ->
        for _ <- 1..2 do
          Particles.create_explosion((offset_x + x) * 1.0, (offset_y + y) * 1.0)
        end
      end)
      |> Enum.take(200)

    Effects.run_particle_burst(target, particles, 30, width, height, [])
  end

  defp scene_color_cascade(target, width, height) do
    Effects.transition_fade(target, 10)
    out(target, "\e[2J\e[H")

    frames = div(8000, @frame_delay)

    Enum.reduce(1..frames, [], fn frame, particles ->
      new = cascade_rain_particles(frame, frames, width)
      new = cascade_wave_particle(frame, frames, width, height, new)

      particles =
        (particles ++ new)
        |> Enum.map(&apply_wave_force/1)
        |> Particles.prune()
        |> Enum.take(180)

      out(target, "\e[2J\e[H")
      out(target, Particles.render(particles, width, height))
      Process.sleep(@frame_delay)

      particles
    end)
  end

  defp cascade_rain_particles(frame, frames, width) do
    if frame < frames - 30 do
      for _ <- 1..4 do
        x = :rand.uniform(width - 1)
        hue = rem(frame * 5 + x * 3, 360)
        color = Effects.hue_to_256(hue)
        phase = x * 0.3
        Particles.create_rain_with_phase(x * 1.0, 0.0, color, phase)
      end
    else
      []
    end
  end

  defp cascade_wave_particle(frame, frames, width, height, new) do
    if frame < frames - 20 do
      wave_x = rem(frame * 2, width)

      wave_particle =
        Particles.create(wave_x * 1.0, (height - 3) * 1.0,
          vx: 0,
          vy: -0.5,
          char: "█",
          color: Effects.hue_to_256(rem(frame * 8, 360)),
          life: 20
        )

      [wave_particle | new]
    else
      new
    end
  end

  defp apply_wave_force(p) do
    phase = Map.get(p, :phase, 0)
    wave_force = :math.sin(p.y * 0.2 + phase) * 0.15
    p = %{p | vx: p.vx + wave_force}
    Particles.update(p, gravity: 0.03)
  end

  defp scene_grand_finale(target, width, height) do
    Effects.transition_fade(target, 15)

    center_x = div(width, 2)
    center_y = div(height, 2)

    rockets = create_finale_rockets(width, height)

    {_exploded_rockets, all_explosions} =
      Enum.reduce(1..40, {rockets, []}, fn _frame, {rockets, explosions} ->
        finale_step(target, rockets, explosions, width, height)
      end)

    ring_particles = create_ring_bursts(center_x, center_y)
    finale_ring_animation(target, all_explosions, ring_particles, width, height)

    Effects.flash_screen(target, :white, 3, width, height)
    finale_message(target, width, height)
  end

  defp create_finale_rockets(width, height) do
    for i <- 1..5 do
      x = div(width, 6) * i
      target_y = 4 + :rand.uniform(4)

      Particles.create_rocket(x * 1.0, (height - 2) * 1.0,
        target_y: target_y,
        color: Particles.palette_color(Enum.random([:cyan, :magenta, :gold]))
      )
    end
  end

  defp finale_step(target, rockets, explosions, width, height) do
    {rockets, new_explosions} =
      rockets
      |> Enum.map(&update_rocket/1)
      |> Enum.unzip()

    rockets = Enum.reject(rockets, &is_nil/1)
    new_explosions = List.flatten(new_explosions)

    explosions = update_explosions(explosions)
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
  end

  defp update_rocket(r) do
    updated = Particles.update_with_trail(r, gravity: 0, friction: 1.0)

    if updated.life <= 1 do
      {nil, Effects.create_rocket_explosion(updated.x, updated.y)}
    else
      {updated, []}
    end
  end

  defp update_explosions(explosions) do
    {explosions, children} =
      explosions
      |> Enum.map(&Particles.update_cascade(&1, gravity: 0.05))
      |> Enum.unzip()

    explosions = List.flatten([explosions | children])
    Particles.prune(explosions)
  end

  defp create_ring_bursts(center_x, center_y) do
    ring_colors = [
      Particles.palette_color(:cyan),
      Particles.palette_color(:magenta),
      Particles.palette_color(:gold)
    ]

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
  end

  defp finale_ring_animation(
         target,
         all_explosions,
         ring_particles,
         width,
         height
       ) do
    combined = all_explosions ++ ring_particles

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
  end

  defp finale_message(target, width, height) do
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

  # ==========================================================================
  # INDIVIDUAL ANIMATION FUNCTIONS
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
          {r, g, b} = Effects.hsl_to_rgb(hue, 1.0, 0.5)
          "\e[48;2;#{r};#{g};#{b}m \e[0m"
        end
        |> Enum.join("")

      out(target, "\r  #{line}")
      Process.sleep(frame_delay)
    end

    out(target, "\r\n\e[?25h")
  end

  # ==========================================================================
  # OUTPUT HELPER
  # ==========================================================================

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

  defp out(device, data), do: Effects.out(device, data)
end
