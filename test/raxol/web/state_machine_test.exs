defmodule Raxol.Web.StateMachineTest do
  use ExUnit.Case, async: true

  alias Raxol.Web.StateMachine
  alias Raxol.Web.StateMachine.Machine

  # Test state machine definition
  defmodule TestMachine do
    use Raxol.Web.StateMachine

    state :idle do
      on :start, to: :running
      on :configure, to: :configured
    end

    state :running do
      on :stop, to: :idle
      on :pause, to: :paused
      on :finish, to: :completed
    end

    state :paused do
      on :resume, to: :running
      on :stop, to: :idle
    end

    state :configured do
      on :start, to: :running
      on :reset, to: :idle
    end

    state :completed do
      on :restart, to: :idle
    end

    initial_state :idle
  end

  # Helper module for guard functions
  defmodule Guards do
    def has_key?(ctx), do: ctx[:has_key] == true
  end

  # State machine with guards
  defmodule GuardedMachine do
    use Raxol.Web.StateMachine

    state :locked do
      on :unlock, to: :unlocked, guard: &Raxol.Web.StateMachineTest.Guards.has_key?/1
      on :force, to: :broken
    end

    state :unlocked do
      on :lock, to: :locked
      on :open, to: :opened
    end

    state :opened do
      on :close, to: :unlocked
    end

    state :broken do
      on :repair, to: :locked
    end

    initial_state :locked
  end

  # Helper module for callback functions
  defmodule Callbacks do
    def action_called(ctx, _payload), do: Map.put(ctx, :action_called, true)
    def start_entered(ctx), do: Map.put(ctx, :start_entered, true)
    def start_exited(ctx), do: Map.put(ctx, :start_exited, true)
    def middle_entered(ctx), do: Map.put(ctx, :middle_entered, true)
    def middle_exited(ctx), do: Map.put(ctx, :middle_exited, true)
    def done_entered(ctx), do: Map.put(ctx, :done_entered, true)
  end

  # State machine with callbacks
  defmodule CallbackMachine do
    use Raxol.Web.StateMachine

    import Raxol.Web.StateMachine,
      only: [state: 2, on: 2, on_enter: 1, on_exit: 1, initial_state: 1]

    state :start do
      on :proceed, to: :middle, action: &Raxol.Web.StateMachineTest.Callbacks.action_called/2

      Raxol.Web.StateMachine.on_enter &Raxol.Web.StateMachineTest.Callbacks.start_entered/1
      Raxol.Web.StateMachine.on_exit &Raxol.Web.StateMachineTest.Callbacks.start_exited/1
    end

    state :middle do
      on :finish, to: :done

      Raxol.Web.StateMachine.on_enter &Raxol.Web.StateMachineTest.Callbacks.middle_entered/1
      Raxol.Web.StateMachine.on_exit &Raxol.Web.StateMachineTest.Callbacks.middle_exited/1
    end

    state :done do
      Raxol.Web.StateMachine.on_enter &Raxol.Web.StateMachineTest.Callbacks.done_entered/1
    end

    initial_state :start
  end

  describe "DSL definition" do
    test "list_states returns all defined states" do
      states = TestMachine.list_states()

      assert :idle in states
      assert :running in states
      assert :paused in states
      assert :configured in states
      assert :completed in states
    end

    test "get_initial_state returns initial state" do
      assert TestMachine.get_initial_state() == :idle
    end

    test "valid_state? checks state validity" do
      assert TestMachine.valid_state?(:idle) == true
      assert TestMachine.valid_state?(:running) == true
      assert TestMachine.valid_state?(:nonexistent) == false
    end

    test "get_state returns state definition" do
      state = TestMachine.get_state(:idle)

      assert state.name == :idle
      assert length(state.transitions) == 2
    end

    test "get_state returns nil for unknown state" do
      assert TestMachine.get_state(:nonexistent) == nil
    end
  end

  describe "new/2" do
    test "creates machine with initial state" do
      {:ok, machine} = TestMachine.new()

      assert machine.current_state == :idle
      assert machine.context == %{}
      assert machine.history == []
      assert is_integer(machine.started_at)
    end

    test "accepts initial context" do
      {:ok, machine} = TestMachine.new(initial_context: %{user: "test"})

      assert machine.context.user == "test"
    end

    test "accepts custom initial state" do
      {:ok, machine} = TestMachine.new(initial_state: :running)

      assert machine.current_state == :running
    end

    test "returns error for invalid initial state" do
      {:error, {:invalid_initial_state, :nonexistent}} =
        StateMachine.new(TestMachine, initial_state: :nonexistent)
    end
  end

  describe "send_event/3" do
    test "transitions to new state" do
      {:ok, machine} = TestMachine.new()

      {:ok, machine} = TestMachine.send_event(machine, :start)

      assert machine.current_state == :running
    end

    test "records transition in history" do
      {:ok, machine} = TestMachine.new()

      {:ok, machine} = TestMachine.send_event(machine, :start)
      {:ok, machine} = TestMachine.send_event(machine, :pause)

      history = StateMachine.get_history(machine)

      assert length(history) == 2
      assert Enum.at(history, 0) |> elem(0) == :idle
      assert Enum.at(history, 0) |> elem(1) == :start
      assert Enum.at(history, 1) |> elem(0) == :running
      assert Enum.at(history, 1) |> elem(1) == :pause
    end

    test "returns error for invalid transition" do
      {:ok, machine} = TestMachine.new()

      {:error, {:no_transition, :idle, :stop}} = TestMachine.send_event(machine, :stop)
    end

    test "multiple transitions" do
      {:ok, machine} = TestMachine.new()

      {:ok, machine} = TestMachine.send_event(machine, :start)
      assert machine.current_state == :running

      {:ok, machine} = TestMachine.send_event(machine, :pause)
      assert machine.current_state == :paused

      {:ok, machine} = TestMachine.send_event(machine, :resume)
      assert machine.current_state == :running

      {:ok, machine} = TestMachine.send_event(machine, :finish)
      assert machine.current_state == :completed
    end
  end

  describe "guards" do
    test "allows transition when guard passes" do
      {:ok, machine} = GuardedMachine.new(initial_context: %{has_key: true})

      {:ok, machine} = GuardedMachine.send_event(machine, :unlock)

      assert machine.current_state == :unlocked
    end

    test "blocks transition when guard fails" do
      {:ok, machine} = GuardedMachine.new(initial_context: %{has_key: false})

      {:error, {:no_transition, :locked, :unlock}} =
        GuardedMachine.send_event(machine, :unlock)
    end

    test "unguarded transitions work regardless of context" do
      {:ok, machine} = GuardedMachine.new()

      {:ok, machine} = GuardedMachine.send_event(machine, :force)

      assert machine.current_state == :broken
    end
  end

  describe "callbacks" do
    test "on_enter is called for initial state" do
      {:ok, machine} = CallbackMachine.new()

      assert machine.context.start_entered == true
    end

    test "on_exit is called when leaving state" do
      {:ok, machine} = CallbackMachine.new()

      {:ok, machine} = CallbackMachine.send_event(machine, :proceed)

      assert machine.context.start_exited == true
    end

    test "on_enter is called when entering new state" do
      {:ok, machine} = CallbackMachine.new()

      {:ok, machine} = CallbackMachine.send_event(machine, :proceed)

      assert machine.context.middle_entered == true
    end

    test "action is called during transition" do
      {:ok, machine} = CallbackMachine.new()

      {:ok, machine} = CallbackMachine.send_event(machine, :proceed)

      assert machine.context.action_called == true
    end

    test "full callback chain" do
      {:ok, machine} = CallbackMachine.new()

      {:ok, machine} = CallbackMachine.send_event(machine, :proceed)
      {:ok, machine} = CallbackMachine.send_event(machine, :finish)

      assert machine.context.start_entered == true
      assert machine.context.start_exited == true
      assert machine.context.middle_entered == true
      assert machine.context.middle_exited == true
      assert machine.context.done_entered == true
    end
  end

  describe "can_transition?/2" do
    test "returns true for valid transitions" do
      {:ok, machine} = TestMachine.new()

      assert TestMachine.can_transition?(machine, :start) == true
      assert TestMachine.can_transition?(machine, :configure) == true
    end

    test "returns false for invalid transitions" do
      {:ok, machine} = TestMachine.new()

      assert TestMachine.can_transition?(machine, :stop) == false
      assert TestMachine.can_transition?(machine, :pause) == false
    end

    test "respects guards" do
      {:ok, machine_with_key} = GuardedMachine.new(initial_context: %{has_key: true})
      {:ok, machine_without_key} = GuardedMachine.new(initial_context: %{has_key: false})

      assert GuardedMachine.can_transition?(machine_with_key, :unlock) == true
      assert GuardedMachine.can_transition?(machine_without_key, :unlock) == false
    end
  end

  describe "available_events/1" do
    test "returns events available from current state" do
      {:ok, machine} = TestMachine.new()

      events = StateMachine.available_events(machine)

      assert :start in events
      assert :configure in events
      assert length(events) == 2
    end

    test "returns unique events" do
      {:ok, machine} = TestMachine.new(initial_state: :paused)

      events = StateMachine.available_events(machine)

      assert :resume in events
      assert :stop in events
    end

    test "respects guards" do
      {:ok, machine} = GuardedMachine.new(initial_context: %{has_key: false})

      events = StateMachine.available_events(machine)

      # unlock is guarded and should not be available
      assert :force in events
      refute :unlock in events
    end
  end

  describe "current_state/1" do
    test "returns current state" do
      {:ok, machine} = TestMachine.new()

      assert StateMachine.current_state(machine) == :idle

      {:ok, machine} = TestMachine.send_event(machine, :start)

      assert StateMachine.current_state(machine) == :running
    end
  end

  describe "context management" do
    test "get_context returns context" do
      {:ok, machine} = TestMachine.new(initial_context: %{key: "value"})

      assert StateMachine.get_context(machine) == %{key: "value"}
    end

    test "set_context replaces context" do
      {:ok, machine} = TestMachine.new(initial_context: %{old: "data"})

      machine = StateMachine.set_context(machine, %{new: "data"})

      assert StateMachine.get_context(machine) == %{new: "data"}
    end

    test "update_context modifies context" do
      {:ok, machine} = TestMachine.new(initial_context: %{count: 0})

      machine = StateMachine.update_context(machine, fn ctx ->
        Map.put(ctx, :count, ctx.count + 1)
      end)

      assert StateMachine.get_context(machine).count == 1
    end
  end

  describe "get_history/1" do
    test "returns empty list initially" do
      {:ok, machine} = TestMachine.new()

      assert StateMachine.get_history(machine) == []
    end

    test "returns transitions in chronological order" do
      {:ok, machine} = TestMachine.new()

      {:ok, machine} = TestMachine.send_event(machine, :start)
      {:ok, machine} = TestMachine.send_event(machine, :pause)

      history = StateMachine.get_history(machine)

      assert length(history) == 2
      # First transition should be first in list
      {from1, event1, _time1} = Enum.at(history, 0)
      {from2, event2, _time2} = Enum.at(history, 1)

      assert from1 == :idle
      assert event1 == :start
      assert from2 == :running
      assert event2 == :pause
    end
  end

  describe "serialize/1 and deserialize/1" do
    test "round-trips machine state" do
      {:ok, machine} = TestMachine.new(initial_context: %{user: "test"})
      {:ok, machine} = TestMachine.send_event(machine, :start)

      binary = StateMachine.serialize(machine)
      {:ok, restored} = StateMachine.deserialize(binary)

      assert restored.current_state == :running
      assert restored.context.user == "test"
      assert length(restored.history) == 1
    end

    test "deserialize returns error for invalid data" do
      assert {:error, _} = StateMachine.deserialize("invalid")
    end
  end

  describe "Machine struct" do
    test "has correct structure" do
      {:ok, machine} = TestMachine.new()

      assert %Machine{} = machine
      assert machine.definition == TestMachine
      assert is_atom(machine.current_state)
      assert is_map(machine.context)
      assert is_list(machine.history)
      assert is_integer(machine.started_at)
    end
  end

  describe "module API delegation" do
    test "module delegates to StateMachine functions" do
      {:ok, machine} = TestMachine.new()

      # These should all work through the generated module functions
      assert TestMachine.current_state(machine) == :idle
      assert TestMachine.can_transition?(machine, :start) == true
      assert TestMachine.get_context(machine) == %{}

      machine = TestMachine.set_context(machine, %{foo: "bar"})
      assert TestMachine.get_context(machine) == %{foo: "bar"}
    end
  end
end
