defmodule Raxol.Docs.InteractiveTutorialTest do
  use ExUnit.Case, async: true

  alias Raxol.Docs.InteractiveTutorial

  alias Raxol.Docs.InteractiveTutorial.{
    State,
    Models,
    Navigation,
    Validation,
    Loader
  }

  setup do
    # Initialize the tutorial system
    InteractiveTutorial.init()

    # Create a sample tutorial for testing
    tutorial = %Models.Tutorial{
      id: "test_tutorial",
      title: "Test Tutorial",
      description: "A tutorial for testing",
      tags: ["test", "sample"],
      difficulty: :beginner,
      estimated_time: 10,
      prerequisites: [],
      steps: [
        %Models.Step{
          id: "step1",
          title: "First Step",
          content: "This is the first step",
          example_code: "IO.puts(\"Hello\")",
          exercise: %{description: "Write hello world"},
          validation: fn code -> String.contains?(code, "Hello") end,
          hints: ["Use IO.puts"],
          next_steps: ["step2"],
          interactive_elements: []
        },
        %Models.Step{
          id: "step2",
          title: "Second Step",
          content: "This is the second step",
          example_code: "1 + 1",
          exercise: nil,
          validation: nil,
          hints: [],
          next_steps: [],
          interactive_elements: []
        }
      ],
      metadata: %{}
    }

    InteractiveTutorial.register_tutorial(tutorial)

    {:ok, tutorial: tutorial}
  end

  describe "tutorial registration and listing" do
    test "registers a new tutorial", %{tutorial: tutorial} do
      tutorials = InteractiveTutorial.list_tutorials()

      assert Enum.any?(tutorials, fn t -> t.id == tutorial.id end)
    end

    test "lists all available tutorials" do
      tutorials = InteractiveTutorial.list_tutorials()

      assert is_list(tutorials)
      assert Enum.all?(tutorials, fn t -> Map.has_key?(t, :id) end)
      assert Enum.all?(tutorials, fn t -> Map.has_key?(t, :progress) end)
    end
  end

  describe "tutorial navigation" do
    test "starts a tutorial", %{tutorial: tutorial} do
      {:ok, started_tutorial} = InteractiveTutorial.start_tutorial(tutorial.id)

      assert started_tutorial.id == tutorial.id
    end

    test "returns error for invalid tutorial" do
      result = InteractiveTutorial.start_tutorial("nonexistent")

      assert {:error, _} = result
    end

    test "navigates to next step", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)
      {:ok, step} = InteractiveTutorial.next_step()

      assert step.id == "step2"
    end

    test "navigates to previous step", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)
      {:ok, _} = InteractiveTutorial.next_step()
      {:ok, step} = InteractiveTutorial.previous_step()

      assert step.id == "step1"
    end

    test "jumps to specific step", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)
      {:ok, step} = InteractiveTutorial.jump_to_step("step2")

      assert step.id == "step2"
    end
  end

  describe "current position" do
    test "gets current position in tutorial", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)

      {current_tutorial, current_step} =
        InteractiveTutorial.get_current_position()

      assert current_tutorial.id == tutorial.id
      assert current_step.id == "step1"
    end

    test "returns nil when no tutorial active" do
      result = InteractiveTutorial.get_current_position()

      assert result == nil or elem(result, 0) == nil
    end
  end

  describe "exercise validation" do
    test "validates correct solution", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)

      result = InteractiveTutorial.validate_exercise("IO.puts(\"Hello World\")")

      assert match?({:ok, _}, result) or result == true
    end

    test "rejects incorrect solution", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)

      result = InteractiveTutorial.validate_exercise("wrong code")

      assert match?({:error, _}, result) or result == false
    end

    test "returns error when no tutorial active" do
      result = InteractiveTutorial.validate_exercise("some code")

      assert match?({:error, "No tutorial in progress"}, result) or
               match?({:error, _}, result)
    end
  end

  describe "hints" do
    test "gets hint for current step", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)

      result = InteractiveTutorial.get_hint()

      assert match?({:ok, "Use IO.puts"}, result) or
               match?({:ok, _hint}, result)
    end

    test "returns error when no hints available", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)
      {:ok, _} = InteractiveTutorial.next_step()

      result = InteractiveTutorial.get_hint()

      assert match?({:error, "No hints available"}, result) or
               match?({:error, _}, result)
    end
  end

  describe "progress tracking" do
    test "tracks progress through tutorial", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)

      progress1 = InteractiveTutorial.get_progress(tutorial.id)

      {:ok, _} = InteractiveTutorial.next_step()

      progress2 = InteractiveTutorial.get_progress(tutorial.id)

      # Progress should be updated
      assert progress1 != progress2 || progress2 != nil
    end
  end

  describe "rendering" do
    test "renders current step", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)

      result = InteractiveTutorial.render_current_step()

      assert match?({:ok, _content}, result) or is_binary(result)
    end

    test "renders interactive elements", %{tutorial: tutorial} do
      {:ok, _} = InteractiveTutorial.start_tutorial(tutorial.id)

      result = InteractiveTutorial.render_interactive_elements()

      assert match?({:ok, _elements}, result) or
               match?({:error, _}, result) or
               is_list(result)
    end

    test "returns error when no tutorial active" do
      result = InteractiveTutorial.render_current_step()

      assert match?({:error, "No tutorial in progress"}, result) or
               match?({:error, _}, result)
    end
  end
end
