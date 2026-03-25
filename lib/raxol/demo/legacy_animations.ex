defmodule Raxol.Demo.LegacyAnimations do
  @moduledoc """
  Legacy animation functions (spinner, progress bar, typing effect, rainbow wave).
  Extracted from `Raxol.Demo.Animations` for file-size reduction.
  """

  alias Raxol.Demo.Effects

  @spinner_dots ~w(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

  @doc "Run all legacy animations sequentially."
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

  defp out(device, data), do: Effects.out(device, data)
end
