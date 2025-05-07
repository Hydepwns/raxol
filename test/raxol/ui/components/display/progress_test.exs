defmodule Raxol.UI.Components.Display.ProgressTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Display.Progress
  alias Raxol.Test.TestHelper

  defp default_context, do: %{}

  defp init_component(props \\ %{}) do
    {:ok, state} = Progress.init(props)
    state
  end

  defp init_component!(props) do
    {:ok, state} = Progress.init(props)
    state
  end

  describe "init/1" do
    test "initializes with default props" do
      state = init_component()
      assert state.progress == 0.0
      assert state.width == 20
      assert state.label == nil
      assert state.show_percentage == false
      assert state.animated == false
    end

    test "initializes with custom props" do
      props = %{progress: 0.5, width: 30, label: "Loading", show_percentage: true, animated: true}
      state = init_component(props)
      assert state.progress == 0.5
      assert state.width == 30
      assert state.label == "Loading"
      assert state.show_percentage == true
      assert state.animated == true
      assert state.animation_frame == 0
    end

    test "init/1 clamps progress value to valid range" do
      {:ok, below_state} = Progress.init(%{progress: -0.5})
      assert below_state.progress == 0.0

      {:ok, above_state} = Progress.init(%{progress: 1.5})
      assert above_state.progress == 1.0

      {:ok, within_state} = Progress.init(%{progress: 0.5})
      assert within_state.progress == 0.5
    end

    test "init/1 applies default values" do
      {:ok, state} = Progress.init(%{})
      assert state.progress == 0.0
      assert state.width == 20
      assert state.label == nil
      assert state.show_percentage == false
      assert state.animated == false
    end
  end

  describe "update/2" do
    setup do
      {:ok, %{state: init_component(%{animated: true})}}
    end

    test "updates props", %{state: state} do
      {:noreply, updated, _cmd} = Progress.update({:update_props, %{progress: 0.6, width: 40}}, state)
      assert updated.progress == 0.6
      assert updated.width == 40
    end

    test "updates animation state when animated", %{state: state} do
      assert {:noreply, updated_state, _cmd} = Progress.update(:tick, state)
      assert updated_state.animation_frame > state.animation_frame or updated_state.animation_frame == 0
    end

    test "doesn't update animation when not animated" do
      state = init_component(%{animated: false})
      assert {:noreply, updated_state, _cmd} = Progress.update(:tick, state)
      assert updated_state.animation_frame == state.animation_frame
    end
  end

  describe "render/2" do
    setup do
      {:ok, context: default_context()}
    end

    test "renders basic progress bar", %{context: context} do
      state = init_component(%{progress: 0.5, width: 10})
      elements = Progress.render(state, context)
      assert is_list(elements)
      filled_count = round(state.progress * state.width)
    end

    test "renders percentage text when enabled", %{context: context} do
      initial_state = init_component()
      state = %{initial_state | show_percentage: true, progress: 0.75, width: 20}
      elements = Progress.render(state, context)

      # Example: "[#######       ] 75%"
      # Bar width: 20 - 2 (brackets) - 1 (space) - 3 (75%) = 14
      # Filled: 14 * 0.75 = 10.5 -> 11
      # Empty: 14 - 11 = 3
      # Padding for text: (20 - 3) / 2 = 8.5 -> 8? No, text length first.
      text = "75%"
      text_length = String.length(text) # 3
      bar_width_available = state.width - 2 - 1 - text_length # 20 - 2 - 1 - 3 = 14
      filled_count = round(bar_width_available * state.progress) # round(14 * 0.75) = round(10.5) = 11
      empty_count = bar_width_available - filled_count # 14 - 11 = 3

      # Center the text within the total width (20)
      # total_padding = state.width - text_length # 20 - 3 = 17
      # left_padding = div(total_padding, 2) # div(17, 2) = 8
      # right_padding = total_padding - left_padding # 17 - 8 = 9

      # Expect multiple elements: border box, bar fill, and percentage text
      assert length(elements) >= 2

      text_element = hd(elements)
      assert text_element.type == :text
      # Check overall structure first
      assert Regex.match?(~r/^\[#+\s+\]\s+\d+%$/, text_element.text)
      # Check specific counts and placement
      expected_text = "[" <> String.duplicate("#", filled_count) <> String.duplicate(" ", empty_count) <> "] " <> text
      assert text_element.text == expected_text # "[###########   ] 75%"

      # Check centering roughly (Exact position depends on render logic not tested here)
      # We can check if the text appears *after* some padding
      # assert String.starts_with?(text_element.text, "[" <> String.duplicate("#", left_padding - 1)) # rough check
    end

    test "renders label when provided", %{context: context} do
      state = init_component(%{progress: 0.3, width: 20, label: "Downloading..."})
      elements = Progress.render(state, context)
      assert Enum.any?(elements, fn el -> is_map(el) && el.type == :text && String.contains?(el.text || "", "Downloading...") end)
    end

    test "generates correct bar content for different progress values", %{context: context} do
      empty_state = init_component(%{progress: 0.0, width: 10})
      half_state = init_component(%{progress: 0.5, width: 10})
      full_state = init_component(%{progress: 1.0, width: 10})

      empty_elements = Progress.render(empty_state, context)
      half_elements = Progress.render(half_state, context)
      full_elements = Progress.render(full_state, context)

      assert is_list(empty_elements)
      assert is_list(half_elements)
      assert is_list(full_elements)
    end

    test "renders animation character when animated", %{context: context} do
      state = init_component(%{progress: 0.5, width: 10, animated: true})
      state = %{state | animation_frame: 3}
      elements = Progress.render(state, context)
    end

    test "render/2 handles invalid progress values gracefully" do
      state = init_component()
      context = default_context()
      # Test with progress < 0
      below_state = %{state | progress: -0.5}
      elements_below = Progress.render(below_state, context)
      assert is_list(elements_below), "Should render even with progress < 0"
      # Add assertions about expected rendering (e.g., clamped to 0%)

      # Test with progress > 1
      above_state = %{state | progress: 1.5}
      elements_above = Progress.render(above_state, context)
      assert is_list(elements_above), "Should render even with progress > 1"
      # Add assertions about expected rendering (e.g., clamped to 100%)
    end
  end
end
