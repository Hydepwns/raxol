defmodule Raxol.Components.Progress.SpinnerTest do
  use ExUnit.Case
  alias Raxol.Components.Progress.Spinner
  alias Raxol.Core.Events.Event

  describe "init/1" do
    test "initializes with default values when no props provided" do
      state = Spinner.init(%{})
      assert state.style == :dots
      assert state.frames == ~w(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
      assert state.frame_index == 0
      assert state.colors == [:white]
      assert state.color_index == 0
      assert state.speed == 80
      assert state.text == nil
      assert state.text_position == :right
      assert is_integer(state.last_update)
    end

    test "initializes with provided values" do
      props = %{
        style: :line,
        colors: [:red, :blue],
        speed: 100,
        text: "Loading",
        text_position: :left
      }

      state = Spinner.init(props)
      assert state.style == :line
      assert state.frames == ~w(| / - \\)
      assert state.frame_index == 0
      assert state.colors == [:red, :blue]
      assert state.color_index == 0
      assert state.speed == 100
      assert state.text == "Loading"
      assert state.text_position == :left
    end

    test "initializes with custom frames" do
      props = %{
        style: :custom,
        frames: ["A", "B", "C"]
      }

      state = Spinner.init(props)
      assert state.style == :custom
      assert state.frames == ["A", "B", "C"]
    end
  end

  describe "update/2" do
    setup do
      state =
        Spinner.init(%{
          style: :line,
          colors: [:red, :blue],
          speed: 100
        })

      {:ok, state: state}
    end

    test "advances frame on tick after speed interval", %{state: state} do
      # Set last_update to simulate elapsed time
      state = %{state | last_update: System.monotonic_time(:millisecond) - 200}

      new_state = Spinner.update(:tick, state)
      assert new_state.frame_index == 1
      assert new_state.color_index == 1
      assert new_state.last_update > state.last_update
    end

    test "doesn't advance frame if speed interval hasn't elapsed", %{
      state: state
    } do
      # Set last_update to recent time
      state = %{state | last_update: System.monotonic_time(:millisecond)}

      new_state = Spinner.update(:tick, state)
      assert new_state.frame_index == 0
      assert new_state.color_index == 0
      assert new_state.last_update == state.last_update
    end

    test "resets frame and color indices", %{state: state} do
      state = %{state | frame_index: 2, color_index: 1}

      new_state = Spinner.update(:reset, state)
      assert new_state.frame_index == 0
      assert new_state.color_index == 0
    end

    test "sets text", %{state: state} do
      new_state = Spinner.update({:set_text, "Loading"}, state)
      assert new_state.text == "Loading"
    end

    test "sets style", %{state: state} do
      new_state = Spinner.update({:set_style, :bounce}, state)
      assert new_state.style == :bounce
      assert new_state.frames == ~w(⠁ ⠂ ⠄ ⠂)
      assert new_state.frame_index == 0
    end

    test "sets custom frames", %{state: state} do
      new_state = Spinner.update({:set_custom_frames, ["A", "B", "C"]}, state)
      assert new_state.style == :custom
      assert new_state.frames == ["A", "B", "C"]
      assert new_state.frame_index == 0
    end

    test "sets colors", %{state: state} do
      new_state = Spinner.update({:set_colors, [:green, :yellow]}, state)
      assert new_state.colors == [:green, :yellow]
      assert new_state.color_index == 0
    end

    test "sets speed", %{state: state} do
      new_state = Spinner.update({:set_speed, 200}, state)
      assert new_state.speed == 200
    end
  end

  describe "handle_event/2" do
    test "handles frame events" do
      # Set speed to 0 to ensure tick happens
      state = Spinner.init(%{speed: 0})
      event = %Event{type: :frame}

      {new_state, _} = Spinner.handle_event(event, state)
      assert new_state.frame_index == 1
    end

    test "ignores other events" do
      state = Spinner.init(%{})
      event = Event.key("x")

      {new_state, _} = Spinner.handle_event(event, state)
      assert new_state == state
    end
  end

  describe "helper functions" do
    test "loading/1 creates default loading spinner" do
      state = Spinner.loading()
      assert state.style == :dots
      assert state.text == "Loading"
      assert state.colors == [:white]
    end

    test "processing/1 creates processing spinner" do
      state = Spinner.processing("Working")
      assert state.style == :dots
      assert state.text == "Working"
      assert state.colors == [:blue, :cyan, :green]
      assert state.speed == 100
    end

    test "saving/1 creates saving spinner" do
      state = Spinner.saving()
      assert state.style == :pulse
      assert state.text == "Saving"
      assert state.colors == [:yellow, :green]
      assert state.speed == 500
    end

    test "error/1 creates error spinner" do
      state = Spinner.error("Failed")
      assert state.style == :pulse
      assert state.text == "Failed"
      assert state.colors == [:red]
      assert state.speed == 1000
    end
  end
end
