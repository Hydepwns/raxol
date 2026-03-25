defmodule Raxol.Demo.ParticlesTest do
  use ExUnit.Case, async: true

  alias Raxol.Demo.Particles

  describe "create/3" do
    test "creates particle at specified position" do
      particle = Particles.create(10.0, 20.0)

      assert particle.x == 10.0
      assert particle.y == 20.0
      assert is_float(particle.vx)
      assert is_float(particle.vy)
      assert is_binary(particle.char)
      assert is_integer(particle.color)
      assert is_integer(particle.life)
    end

    test "accepts velocity options" do
      particle = Particles.create(0.0, 0.0, vx: 1.5, vy: -2.0)

      assert particle.vx == 1.5
      assert particle.vy == -2.0
    end

    test "accepts char and color options" do
      particle = Particles.create(0.0, 0.0, char: "X", color: 196)

      assert particle.char == "X"
      assert particle.color == 196
    end

    test "accepts life option" do
      particle = Particles.create(0.0, 0.0, life: 100)

      assert particle.life == 100
    end
  end

  describe "create_sparkle/2" do
    test "creates rising sparkle particle" do
      particle = Particles.create_sparkle(10.0, 20.0)

      assert particle.x == 10.0
      assert particle.y == 20.0
      assert particle.vy < 0
      assert particle.life > 0
    end
  end

  describe "create_explosion/2" do
    test "creates outward-moving explosion particle" do
      particle = Particles.create_explosion(10.0, 10.0)

      assert particle.x == 10.0
      assert particle.y == 10.0
      assert particle.vx != 0 or particle.vy != 0
      assert particle.life > 0
    end
  end

  describe "create_trail/3" do
    test "creates stationary trail particle" do
      particle = Particles.create_trail(5.0, 5.0, 51)

      assert particle.x == 5.0
      assert particle.y == 5.0
      assert particle.vx == 0
      assert particle.vy == 0
      assert particle.color == 51
    end
  end

  describe "create_rain/3" do
    test "creates falling rain particle" do
      particle = Particles.create_rain(10.0, 0.0, 45)

      assert particle.x == 10.0
      assert particle.y == 0.0
      assert particle.vy > 0
      assert particle.color == 45
    end
  end

  describe "update/2" do
    test "updates position based on velocity" do
      particle = Particles.create(10.0, 10.0, vx: 1.0, vy: 0.0)
      updated = Particles.update(particle)

      assert updated.x > particle.x
      assert updated.life == particle.life - 1
    end

    test "applies gravity" do
      particle = Particles.create(0.0, 0.0, vx: 0.0, vy: 0.0)
      updated = Particles.update(particle)

      assert updated.vy > 0
    end

    test "accepts gravity option" do
      particle = Particles.create(0.0, 0.0, vx: 0.0, vy: 0.0)
      updated = Particles.update(particle, gravity: 0.5)

      assert updated.vy == 0.5
    end
  end

  describe "update_float/1" do
    test "updates without gravity" do
      particle = Particles.create(0.0, 0.0, vx: 0.0, vy: -1.0)
      updated = Particles.update_float(particle)

      assert updated.vy == -1.0
    end
  end

  describe "render/3" do
    test "returns ANSI escape sequences for visible particles" do
      particles = [
        Particles.create(5.0, 5.0, char: "*", color: 51, life: 30)
      ]

      output = Particles.render(particles, 80, 24)

      assert is_binary(output)
      assert output =~ "\e["
      assert output =~ "*"
    end

    test "filters out-of-bounds particles" do
      particles = [
        Particles.create(-5.0, 5.0, char: "X", life: 30),
        Particles.create(5.0, -5.0, char: "Y", life: 30),
        Particles.create(100.0, 5.0, char: "Z", life: 30)
      ]

      output = Particles.render(particles, 80, 24)

      refute output =~ "X"
      refute output =~ "Y"
      refute output =~ "Z"
    end

    test "filters dead particles" do
      particles = [
        Particles.create(5.0, 5.0, char: "D", life: 0)
      ]

      output = Particles.render(particles, 80, 24)

      refute output =~ "D"
    end
  end

  describe "prune/1" do
    test "removes dead particles" do
      particles = [
        Particles.create(0.0, 0.0, life: 10),
        Particles.create(0.0, 0.0, life: 0),
        Particles.create(0.0, 0.0, life: -5)
      ]

      pruned = Particles.prune(particles)

      assert length(pruned) == 1
    end
  end

  describe "random_color/0" do
    test "returns valid ANSI 256 color code" do
      color = Particles.random_color()

      assert is_integer(color)
      assert color >= 0
      assert color <= 255
    end
  end

  describe "palette_color/1" do
    test "returns color from cyan palette" do
      color = Particles.palette_color(:cyan)
      assert color in [51, 50, 49, 44, 45]
    end

    test "returns color from magenta palette" do
      color = Particles.palette_color(:magenta)
      assert color in [201, 200, 199, 164, 165]
    end

    test "returns color from gold palette" do
      color = Particles.palette_color(:gold)
      assert color in [220, 221, 222, 228, 229]
    end

    test "returns color from white palette" do
      color = Particles.palette_color(:white)
      assert color in [255, 254, 253, 252, 251]
    end
  end

  describe "hue_to_color/1" do
    test "maps hue to ANSI color" do
      assert Particles.hue_to_color(0) == 196
      assert Particles.hue_to_color(60) == 202
      assert Particles.hue_to_color(120) == 226
      assert Particles.hue_to_color(180) == 46
      assert Particles.hue_to_color(240) == 21
      assert Particles.hue_to_color(300) == 201
    end
  end
end
