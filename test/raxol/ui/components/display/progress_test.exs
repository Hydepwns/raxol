defmodule Raxol.UI.Components.Display.ProgressTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Display.Progress
  alias Raxol.Test.TestHelper

  defp default_context, do: %{}

  defp init_component(props \\ %{}) do
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

    test "clamps progress value to valid range" do
      # Test with value below range
      below = Progress.init(%{progress: -0.5})
      assert below.progress == 0.0

      # Test with value above range
      above = Progress.init(%{progress: 1.5})
      assert above.progress == 1.0
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
      state = init_component(%{progress: 0.75, width: 20, show_percentage: true})
      elements = Progress.render(state, context)
      assert Enum.any?(elements, fn el -> is_map(el) && el.content == " 75%" end)
    end

    test "renders label when provided", %{context: context} do
      state = init_component(%{progress: 0.3, width: 20, label: "Downloading..."})
      elements = Progress.render(state, context)
      assert Enum.any?(elements, fn el -> is_map(el) && String.contains?(el.content || "", "Downloading...") end)
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
  end
end
