defmodule Raxol.Demo.TextFormationTest do
  use ExUnit.Case, async: true

  alias Raxol.Demo.TextFormation

  describe "target_positions/3" do
    test "returns positions for each letter pixel" do
      positions = TextFormation.target_positions("R", 40, 12)
      assert is_list(positions)
      assert length(positions) > 0
      assert Enum.all?(positions, fn {x, y} -> is_float(x) and is_float(y) end)
    end

    test "centers text at given coordinates" do
      positions = TextFormation.target_positions("A", 40, 12)
      xs = Enum.map(positions, fn {x, _y} -> x end)
      avg_x = Enum.sum(xs) / length(xs)
      # Should be roughly centered around 40
      assert abs(avg_x - 40) < 5
    end

    test "handles multi-letter text" do
      positions = TextFormation.target_positions("RAXOL", 40, 12)
      assert length(positions) > 50
    end
  end

  describe "create_formation_particles/5" do
    test "creates particles for each target position" do
      particles = TextFormation.create_formation_particles("R", 40, 12, 80, 24)
      assert length(particles) > 0

      for p <- particles do
        assert Map.has_key?(p, :x)
        assert Map.has_key?(p, :y)
        assert Map.has_key?(p, :target_x)
        assert Map.has_key?(p, :target_y)
        assert Map.has_key?(p, :arrived)
        assert p.arrived == false
      end
    end

    test "particles start at screen edges" do
      particles = TextFormation.create_formation_particles("A", 40, 12, 80, 24)

      for p <- particles do
        at_edge =
          p.x == 0.0 or p.x == 79.0 or p.y == 0.0 or p.y == 23.0

        assert at_edge, "Particle should start at edge: {#{p.x}, #{p.y}}"
      end
    end
  end

  describe "update_toward_target/1" do
    test "moves particle toward target" do
      particle = %{
        x: 0.0,
        y: 0.0,
        vx: 0.0,
        vy: 0.0,
        char: "*",
        color: 51,
        life: 100,
        target_x: 40.0,
        target_y: 12.0,
        arrived: false
      }

      updated = TextFormation.update_toward_target(particle)
      assert updated.x > particle.x
      assert updated.y > particle.y
    end

    test "marks particle as arrived when close to target" do
      particle = %{
        x: 39.9,
        y: 11.9,
        vx: 0.0,
        vy: 0.0,
        char: "*",
        color: 51,
        life: 100,
        target_x: 40.0,
        target_y: 12.0,
        arrived: false
      }

      updated = TextFormation.update_toward_target(particle)
      assert updated.arrived == true
      assert updated.x == 40.0
      assert updated.y == 12.0
    end
  end

  describe "update_with_jitter/1" do
    test "applies jitter only to arrived particles" do
      arrived = %{
        x: 40.0,
        y: 12.0,
        target_x: 40.0,
        target_y: 12.0,
        arrived: true
      }

      not_arrived = %{arrived | arrived: false, x: 20.0, y: 6.0}

      # Arrived particle gets jitter
      updated_arrived = TextFormation.update_with_jitter(arrived)
      assert updated_arrived.x != 40.0 or updated_arrived.y != 12.0

      # Not arrived particle stays the same
      updated_not = TextFormation.update_with_jitter(not_arrived)
      assert updated_not.x == 20.0
      assert updated_not.y == 6.0
    end
  end

  describe "all_arrived?/1" do
    test "returns true when all particles arrived" do
      particles = [
        %{arrived: true},
        %{arrived: true},
        %{arrived: true}
      ]

      assert TextFormation.all_arrived?(particles)
    end

    test "returns false when any particle not arrived" do
      particles = [
        %{arrived: true},
        %{arrived: false},
        %{arrived: true}
      ]

      refute TextFormation.all_arrived?(particles)
    end
  end

  describe "explode_formation/1" do
    test "creates explosion particles from formation" do
      formation = [
        %{x: 40.0, y: 12.0, color: 51}
      ]

      explosions = TextFormation.explode_formation(formation)
      assert length(explosions) == 1

      [p] = explosions
      assert p.x == 40.0
      assert p.y == 12.0
      assert p.life > 0
    end
  end

  describe "render/3" do
    test "renders particles within bounds" do
      particles = [
        %{x: 10.0, y: 5.0, life: 50, color: 51, char: "*", arrived: true},
        %{x: 100.0, y: 5.0, life: 50, color: 51, char: "*", arrived: false}
      ]

      output = TextFormation.render(particles, 80, 24)
      assert String.contains?(output, "\e[6;11H")
      refute String.contains?(output, "\e[6;101H")
    end
  end
end
