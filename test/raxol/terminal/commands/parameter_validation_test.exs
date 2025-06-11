defmodule Raxol.Terminal.Commands.ParameterValidationTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.ParameterValidation

  setup do
    emulator = Raxol.Terminal.Emulator.new(10, 10)
    {:ok, emulator: emulator}
  end

  describe "validate_coordinates/2" do
    test "returns valid coordinates within bounds", %{emulator: emulator} do
      assert ParameterValidation.validate_coordinates(emulator, [5, 5]) ==
               {5, 5}

      assert ParameterValidation.validate_coordinates(emulator, [0, 0]) ==
               {0, 0}

      assert ParameterValidation.validate_coordinates(emulator, [9, 9]) ==
               {9, 9}
    end

    test "clamps coordinates to screen bounds", %{emulator: emulator} do
      assert ParameterValidation.validate_coordinates(emulator, [-1, -1]) ==
               {0, 0}

      assert ParameterValidation.validate_coordinates(emulator, [10, 10]) ==
               {9, 9}

      assert ParameterValidation.validate_coordinates(emulator, [100, 100]) ==
               {9, 9}
    end

    test "handles missing parameters", %{emulator: emulator} do
      assert ParameterValidation.validate_coordinates(emulator, []) == {0, 0}

      assert ParameterValidation.validate_coordinates(emulator, [nil, nil]) ==
               {0, 0}
    end

    test "handles invalid parameters", %{emulator: emulator} do
      assert ParameterValidation.validate_coordinates(emulator, [
               "invalid",
               "invalid"
             ]) == {0, 0}

      assert ParameterValidation.validate_coordinates(emulator, [
               :invalid,
               :invalid
             ]) == {0, 0}
    end
  end

  describe "validate_count/2" do
    test "returns valid count within bounds", %{emulator: emulator} do
      # Test counts within valid range
      assert ParameterValidation.validate_count(emulator, [5]) == 5
      assert ParameterValidation.validate_count(emulator, [1]) == 1
      assert ParameterValidation.validate_count(emulator, [10]) == 10
    end

    test "clamps count to valid range", %{emulator: emulator} do
      # Test counts outside valid range
      assert ParameterValidation.validate_count(emulator, [-1]) == 1
      assert ParameterValidation.validate_count(emulator, [0]) == 1
      assert ParameterValidation.validate_count(emulator, [100]) == 10
    end

    test "handles missing parameters", %{emulator: emulator} do
      # Test with missing parameters (should default to 1)
      assert ParameterValidation.validate_count(emulator, []) == 1
      assert ParameterValidation.validate_count(emulator, [nil]) == 1
    end

    test "handles invalid parameters", %{emulator: emulator} do
      # Test with invalid parameters (should default to 1)
      assert ParameterValidation.validate_count(emulator, ["invalid"]) == 1
      assert ParameterValidation.validate_count(emulator, [:invalid]) == 1
    end
  end

  describe "validate_mode/1" do
    test "returns valid mode values", %{emulator: _emulator} do
      # Test valid mode values
      assert ParameterValidation.validate_mode([0]) == 0
      assert ParameterValidation.validate_mode([1]) == 1
      assert ParameterValidation.validate_mode([2]) == 2
    end

    test "handles missing parameters", %{emulator: _emulator} do
      # Test with missing parameters (should default to 0)
      assert ParameterValidation.validate_mode([]) == 0
      assert ParameterValidation.validate_mode([nil]) == 0
    end

    test "handles invalid parameters", %{emulator: _emulator} do
      # Test with invalid parameters (should default to 0)
      assert ParameterValidation.validate_mode(["invalid"]) == 0
      assert ParameterValidation.validate_mode([:invalid]) == 0
      assert ParameterValidation.validate_mode([-1]) == 0
      assert ParameterValidation.validate_mode([3]) == 0
    end
  end

  describe "validate_color/1" do
    test "returns valid color values", %{emulator: _emulator} do
      # Test valid color values
      assert ParameterValidation.validate_color([0]) == 0
      assert ParameterValidation.validate_color([7]) == 7
      assert ParameterValidation.validate_color([8]) == 8
      assert ParameterValidation.validate_color([15]) == 15
      assert ParameterValidation.validate_color([16]) == 16
      assert ParameterValidation.validate_color([255]) == 255
    end

    test "clamps color values to valid range", %{emulator: _emulator} do
      # Test color values outside valid range
      assert ParameterValidation.validate_color([-1]) == 0
      assert ParameterValidation.validate_color([256]) == 255
    end

    test "handles missing parameters", %{emulator: _emulator} do
      # Test with missing parameters (should default to 0)
      assert ParameterValidation.validate_color([]) == 0
      assert ParameterValidation.validate_color([nil]) == 0
    end

    test "handles invalid parameters", %{emulator: _emulator} do
      # Test with invalid parameters (should default to 0)
      assert ParameterValidation.validate_color(["invalid"]) == 0
      assert ParameterValidation.validate_color([:invalid]) == 0
    end
  end

  describe "validate_boolean/1" do
    test "returns valid boolean values", %{emulator: _emulator} do
      # Test valid boolean values
      assert ParameterValidation.validate_boolean([0]) == false
      assert ParameterValidation.validate_boolean([1]) == true
    end

    test "handles missing parameters", %{emulator: _emulator} do
      # Test with missing parameters (should default to true)
      assert ParameterValidation.validate_boolean([]) == true
      assert ParameterValidation.validate_boolean([nil]) == true
    end

    test "handles invalid parameters", %{emulator: _emulator} do
      # Test with invalid parameters (should default to true)
      assert ParameterValidation.validate_boolean(["invalid"]) == true
      assert ParameterValidation.validate_boolean([:invalid]) == true
      assert ParameterValidation.validate_boolean([-1]) == true
      assert ParameterValidation.validate_boolean([2]) == true
    end
  end

  describe "normalize_parameters/2" do
    test "normalizes parameters to expected length", %{emulator: _emulator} do
      # Test parameter normalization
      assert ParameterValidation.normalize_parameters([1, 2, 3], 5) == [
               1,
               2,
               3,
               nil,
               nil
             ]

      assert ParameterValidation.normalize_parameters([1], 3) == [1, nil, nil]
      assert ParameterValidation.normalize_parameters([], 2) == [nil, nil]
    end

    test "truncates parameters if longer than expected", %{emulator: _emulator} do
      # Test parameter truncation
      assert ParameterValidation.normalize_parameters([1, 2, 3, 4, 5], 3) == [
               1,
               2,
               3
             ]
    end

    test "handles empty parameters", %{emulator: _emulator} do
      # Test with empty parameters
      assert ParameterValidation.normalize_parameters([], 0) == []
      assert ParameterValidation.normalize_parameters([], 3) == [nil, nil, nil]
    end
  end

  describe "validate_range/3" do
    test "returns valid values within range", %{emulator: emulator} do
      # Test values within range
      assert ParameterValidation.validate_range([5], 0, 10) == 5
      assert ParameterValidation.validate_range([0], 0, 10) == 0
      assert ParameterValidation.validate_range([10], 0, 10) == 10
    end

    test "clamps values to range", %{emulator: emulator} do
      # Test values outside range
      assert ParameterValidation.validate_range([-1], 0, 10) == 0
      assert ParameterValidation.validate_range([11], 0, 10) == 10
    end

    test "handles missing parameters", %{emulator: emulator} do
      # Test with missing parameters (should default to min)
      assert ParameterValidation.validate_range([], 0, 10) == 0
      assert ParameterValidation.validate_range([nil], 0, 10) == 0
    end

    test "handles invalid parameters", %{emulator: emulator} do
      # Test with invalid parameters (should default to min)
      assert ParameterValidation.validate_range(["invalid"], 0, 10) == 0
      assert ParameterValidation.validate_range([:invalid], 0, 10) == 0
    end
  end
end
