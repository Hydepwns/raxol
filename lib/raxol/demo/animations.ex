defmodule Raxol.Demo.Animations do
  @moduledoc """
  Animated demos for the terminal showcase.
  Supports both SSH (direct IO) and web (message-based) output.
  """

  @spinner_dots ~w(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  # Reserved for future use
  @spinner_circle ~w(◐ ◓ ◑ ◒)
  @spinner_bounce ~w(▁ ▃ ▄ ▅ ▆ ▇ █ ▇ ▆ ▅ ▄ ▃)
  @spinner_arrow ~w(← ↖ ↑ ↗ → ↘ ↓ ↙)
  _ = {@spinner_circle, @spinner_bounce, @spinner_arrow}

  @doc """
  Run the full animation showcase.
  For SSH: pass an IO device
  For Web: pass {:web, pid} to send messages
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

  def run_spinner(target, duration_ms \\ 3000) do
    frames = @spinner_dots
    frame_delay = 80
    iterations = div(duration_ms, frame_delay)

    # Hide cursor
    out(target, "\e[?25l")
    out(target, "  Loading ")

    for i <- 0..iterations do
      frame = Enum.at(frames, rem(i, length(frames)))
      out(target, "\e[s\e[32m#{frame}\e[0m\e[u")
      Process.sleep(frame_delay)
    end

    out(target, "\e[32m✓\e[0m Done!\r\n")
    # Show cursor
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

    # Blinking cursor
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

  # Output helper - supports both IO device and web channel
  defp out(device, data) when is_pid(device) or is_atom(device) do
    IO.write(device, data)
  end

  defp out({:web, pid}, data) do
    send(pid, {:animation_output, data})
  end

  # Convert HSL to RGB
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
