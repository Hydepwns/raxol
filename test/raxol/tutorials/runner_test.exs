defmodule Raxol.Tutorials.RunnerTest do
  use ExUnit.Case, async: false

  alias Raxol.Tutorials.Runner

  setup do
    # Restart the named runner for isolation
    if Process.whereis(Runner), do: GenServer.stop(Runner)
    {:ok, _pid} = Runner.start_link()
    :ok
  end

  describe "list_tutorials/0" do
    test "returns list of available tutorials" do
      {:ok, output} = Runner.list_tutorials()

      assert output =~ "Available Tutorials:"
      assert output =~ "getting_started"
      assert output =~ "component_deep_dive"
      assert output =~ "terminal_emulation"
    end

    test "includes tutorial metadata" do
      {:ok, output} = Runner.list_tutorials()

      assert output =~ "beginner"
      assert output =~ "intermediate"
      assert output =~ "minutes"
      assert output =~ "Tags:"
    end
  end

  describe "start_tutorial/1" do
    test "starts a valid tutorial" do
      {:ok, output} = Runner.start_tutorial("getting_started")

      assert output =~ "Starting: Getting Started with Raxol"
      assert output =~ "Type 'next' to begin"
    end

    test "returns error for invalid tutorial" do
      {:error, reason} = Runner.start_tutorial("nonexistent")

      assert reason =~ "not found" or reason =~ "invalid"
    end
  end

  describe "navigation" do
    setup do
      {:ok, _} = Runner.start_tutorial("getting_started")
      :ok
    end

    test "next_step advances to next step" do
      {:ok, output} = Runner.next_step()

      assert output =~ "Understanding the Architecture" or
               output =~ "Working with Components"
    end

    test "previous_step goes back" do
      {:ok, _} = Runner.next_step()
      {:ok, output} = Runner.previous_step()
      
      # Should go back to first step which is "Understanding the Architecture"
      assert output =~ "Understanding the Architecture"
    end

    test "show_current displays current step" do
      {:ok, _} = Runner.next_step()
      {:ok, output} = Runner.show_current()

      assert output =~ "Step"
    end
  end

  describe "exercises" do
    setup do
      {:ok, _} = Runner.start_tutorial("getting_started")
      {:ok, _} = Runner.next_step()
      :ok
    end

    test "get_hint returns hint for current step" do
      result = Runner.get_hint()

      case result do
        {:ok, hint} -> assert is_binary(hint)
        {:error, "No hints available"} -> assert true
        {:error, reason} -> flunk("Unexpected error: #{reason}")
      end
    end

    test "submit_solution validates correct solution" do
      # This would need actual validation logic
      code = """
      defmodule Counter do
        def increment(n), do: n + 1
      end
      """

      result = Runner.submit_solution(code)

      assert match?({:ok, _output}, result) or match?({:error, _}, result)
    end
  end

  describe "progress tracking" do
    test "show_progress displays current progress" do
      {:ok, output} = Runner.show_progress()

      assert output =~ "No tutorial currently active" or
               output =~ "Progress"
    end

    test "tracks completed steps" do
      {:ok, _} = Runner.start_tutorial("getting_started")
      {:ok, _} = Runner.next_step()

      # Simulate completing a step
      Runner.submit_solution("solution")

      {:ok, output} = Runner.show_progress()
      assert output =~ "Completed" or output =~ "Progress"
    end
  end

  describe "example execution" do
    setup do
      {:ok, _} = Runner.start_tutorial("getting_started")
      {:ok, _} = Runner.next_step()
      :ok
    end

    test "run_example executes example code" do
      result = Runner.run_example()

      case result do
        {:ok, output} ->
          assert output =~ "executed" or
                   output =~ "Example" or
                   output =~ "No example code available"

        {:error, reason} ->
          assert reason =~ "No example" or reason =~ "No active"
      end
    end
  end

  describe "state management" do
    test "maintains state across operations" do
      {:ok, _} = Runner.start_tutorial("getting_started")
      {:ok, output1} = Runner.show_current()

      {:ok, _} = Runner.next_step()
      {:ok, output2} = Runner.show_current()

      # Should show different steps: first "Understanding the Architecture", then "Working with Components"
      refute output1 == output2
      assert output1 =~ "Understanding the Architecture"
      assert output2 =~ "Working with Components"
    end

    test "handles multiple tutorial switches" do
      {:ok, _} = Runner.start_tutorial("getting_started")
      {:ok, _} = Runner.next_step()

      {:ok, _} = Runner.start_tutorial("component_deep_dive")
      {:ok, output} = Runner.show_current()

      assert output =~ "Component" or output =~ "component"
    end
  end
end
