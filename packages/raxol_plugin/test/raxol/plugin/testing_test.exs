defmodule Raxol.Plugin.TestingTest do
  use ExUnit.Case, async: true

  import Raxol.Plugin.Testing

  alias Raxol.Plugin.Test.SamplePlugin
  alias Raxol.Plugin.Test.CustomPlugin

  describe "setup_plugin/2" do
    test "returns {:ok, state} for valid plugin" do
      assert {:ok, state} = setup_plugin(SamplePlugin, %{x: 1})
      assert state.config == %{x: 1}
    end

    test "uses empty config by default" do
      assert {:ok, state} = setup_plugin(SamplePlugin)
      assert state.config == %{}
    end
  end

  describe "assert_handles_event/3" do
    test "returns event when plugin passes it through" do
      {:ok, state} = setup_plugin(SamplePlugin, %{})
      event = assert_handles_event(SamplePlugin, :test_event, state)
      assert event == :test_event
    end

    test "raises when plugin halts event" do
      {:ok, state} = setup_plugin(CustomPlugin, %{})

      assert_raise ExUnit.AssertionError, ~r/halted/, fn ->
        assert_handles_event(CustomPlugin, :blocked, state)
      end
    end
  end

  describe "assert_handles_command/4" do
    test "returns {new_state, result} on success" do
      {:ok, state} = setup_plugin(CustomPlugin, %{})
      {new_state, result} = assert_handles_command(CustomPlugin, :greet, ["Raxol"], state)
      assert result == "Hello, Raxol!"
      assert new_state == state
    end

    test "raises on command error" do
      {:ok, state} = setup_plugin(CustomPlugin, %{})

      assert_raise ExUnit.AssertionError, ~r/error/, fn ->
        assert_handles_command(CustomPlugin, :fail, [], state)
      end
    end
  end

  describe "simulate_lifecycle/2" do
    test "runs full lifecycle for default plugin" do
      steps = simulate_lifecycle(SamplePlugin, %{})
      assert length(steps) == 4
      assert {:init, {:ok, _}} = Enum.at(steps, 0)
      assert {:enable, {:ok, _}} = Enum.at(steps, 1)
      assert {:disable, {:ok, _}} = Enum.at(steps, 2)
      assert {:terminate, :ok} = Enum.at(steps, 3)
    end

    test "runs full lifecycle for custom plugin" do
      steps = simulate_lifecycle(CustomPlugin, %{})
      assert length(steps) == 4

      {:init, {:ok, state}} = Enum.at(steps, 0)
      assert state.enabled == false

      {:enable, {:ok, enabled}} = Enum.at(steps, 1)
      assert enabled.enabled == true

      {:disable, {:ok, disabled}} = Enum.at(steps, 2)
      assert disabled.enabled == false

      assert {:terminate, :cleaned_up} = Enum.at(steps, 3)
    end
  end

  describe "assert_halts_event/3" do
    test "returns :halt when plugin halts event" do
      {:ok, state} = setup_plugin(CustomPlugin, %{})
      assert :halt = assert_halts_event(CustomPlugin, :blocked, state)
    end

    test "raises when plugin passes event through" do
      {:ok, state} = setup_plugin(SamplePlugin, %{})

      assert_raise ExUnit.AssertionError, ~r/passed through/, fn ->
        assert_halts_event(SamplePlugin, :some_event, state)
      end
    end
  end
end
