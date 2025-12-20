defmodule Raxol.Web.StateMachine do
  @moduledoc """
  Type-safe state machine with compile-time validation.

  Provides a declarative DSL for defining finite state machines
  with automatic validation of transitions and guards.

  ## Features

  - Compile-time transition validation
  - Guard conditions on transitions
  - Entry/exit callbacks for states
  - Event-driven transitions
  - State persistence

  ## Example

      defmodule MyApp.SessionMachine do
        use Raxol.Web.StateMachine

        state :disconnected do
          on :connect, to: :connecting
        end

        state :connecting do
          on :connected, to: :authenticated, guard: &valid_credentials?/1
          on :failed, to: :disconnected
          on_enter &start_connection/1
          on_exit &cleanup/1
        end

        state :authenticated do
          on :disconnect, to: :disconnected
          on :timeout, to: :disconnected
        end

        initial_state :disconnected
      end

      # Usage
      {:ok, machine} = SessionMachine.new()
      {:ok, machine} = SessionMachine.send_event(machine, :connect)
  """

  defmodule Transition do
    @moduledoc false
    defstruct [:event, :from, :to, :guard, :action]
  end

  defmodule State do
    @moduledoc false
    defstruct [:name, :on_enter, :on_exit, :transitions]
  end

  defmodule Machine do
    @moduledoc """
    Runtime state machine instance.
    """
    defstruct [
      :definition,
      :current_state,
      :context,
      :history,
      :started_at
    ]

    @type t :: %__MODULE__{
            definition: module(),
            current_state: atom(),
            context: map(),
            history: [{atom(), atom(), integer()}],
            started_at: integer()
          }
  end

  # ============================================================================
  # DSL Macros
  # ============================================================================

  @doc """
  Import the state machine DSL into a module.
  """
  defmacro __using__(_opts) do
    quote do
      import Raxol.Web.StateMachine,
        only: [
          state: 2,
          on: 2,
          on_enter: 1,
          on_exit: 1,
          initial_state: 1
        ]

      Module.register_attribute(__MODULE__, :states, accumulate: true)
      Module.register_attribute(__MODULE__, :current_state_name, [])
      Module.register_attribute(__MODULE__, :current_state_transitions, [])
      Module.register_attribute(__MODULE__, :current_state_on_enter, [])
      Module.register_attribute(__MODULE__, :current_state_on_exit, [])
      Module.register_attribute(__MODULE__, :initial_state_name, [])

      @before_compile Raxol.Web.StateMachine
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    states = Module.get_attribute(env.module, :states, [])
    initial = Module.get_attribute(env.module, :initial_state_name)

    state_names = Enum.map(states, & &1.name)

    # Validate all transitions point to valid states
    all_transitions =
      Enum.flat_map(states, fn state ->
        Enum.map(state.transitions, fn t -> {state.name, t} end)
      end)

    invalid_transitions =
      Enum.filter(all_transitions, fn {_from, t} ->
        t.to not in state_names
      end)

    if not Enum.empty?(invalid_transitions) do
      raise CompileError,
        description:
          "Invalid transitions to unknown states: #{inspect(Enum.map(invalid_transitions, fn {from, t} -> "#{from} -> #{t.to}" end))}"
    end

    # Generate state lookup functions
    # The @states attribute already accumulates the State structs
    # We can read them directly at compile time in __before_compile__

    # Build a simple map from state name to index for lookup
    state_index =
      states |> Enum.with_index() |> Map.new(fn {s, i} -> {s.name, i} end)

    # Generate get_state functions that return the precomputed states
    state_functions =
      Enum.map(states, fn state ->
        # Index into the states list stored as @states
        idx = state_index[state.name]

        quote do
          def get_state(unquote(state.name)) do
            Enum.at(@states, unquote(idx))
          end
        end
      end)

    quote do
      unquote_splicing(state_functions)

      def get_state(_name), do: nil

      def get_initial_state, do: unquote(initial)

      def list_states, do: unquote(state_names)

      def valid_state?(state), do: state in unquote(state_names)

      def new(opts \\ []) do
        Raxol.Web.StateMachine.new(__MODULE__, opts)
      end

      def send_event(machine, event, payload \\ %{}) do
        Raxol.Web.StateMachine.send_event(machine, event, payload)
      end

      def can_transition?(machine, event) do
        Raxol.Web.StateMachine.can_transition?(machine, event)
      end

      def current_state(machine) do
        Raxol.Web.StateMachine.current_state(machine)
      end

      def get_context(machine) do
        Raxol.Web.StateMachine.get_context(machine)
      end

      def set_context(machine, context) do
        Raxol.Web.StateMachine.set_context(machine, context)
      end
    end
  end

  @doc """
  Define a state with its transitions and callbacks.

  ## Example

      state :idle do
        on :start, to: :running
        on_enter &log_entry/1
      end
  """
  defmacro state(name, do: block) do
    quote do
      @current_state_name unquote(name)
      Module.delete_attribute(__MODULE__, :current_state_transitions)
      Module.register_attribute(__MODULE__, :current_state_transitions, [])
      @current_state_transitions []
      @current_state_on_enter nil
      @current_state_on_exit nil

      unquote(block)

      @states %Raxol.Web.StateMachine.State{
        name: unquote(name),
        transitions:
          @current_state_transitions |> List.flatten() |> Enum.reverse(),
        on_enter: @current_state_on_enter,
        on_exit: @current_state_on_exit
      }
    end
  end

  @doc """
  Define a transition on an event.

  ## Options

    - `:to` - Target state (required)
    - `:guard` - Guard function that must return true
    - `:action` - Action to execute on transition

  ## Example

      on :submit, to: :processing, guard: &valid?/1
  """
  defmacro on(event, opts) do
    to = Keyword.fetch!(opts, :to)
    guard = Keyword.get(opts, :guard)
    action = Keyword.get(opts, :action)

    quote do
      @current_state_transitions [
        %Raxol.Web.StateMachine.Transition{
          event: unquote(event),
          from: @current_state_name,
          to: unquote(to),
          guard: unquote(guard),
          action: unquote(action)
        }
        | @current_state_transitions
      ]
    end
  end

  @doc """
  Set the entry callback for the current state.
  """
  defmacro on_enter(callback) do
    quote do
      @current_state_on_enter unquote(callback)
    end
  end

  @doc """
  Set the exit callback for the current state.
  """
  defmacro on_exit(callback) do
    quote do
      @current_state_on_exit unquote(callback)
    end
  end

  @doc """
  Set the initial state for the machine.
  """
  defmacro initial_state(name) do
    quote do
      @initial_state_name unquote(name)
    end
  end

  # ============================================================================
  # Runtime API
  # ============================================================================

  @doc """
  Create a new state machine instance.

  ## Options

    - `:initial_context` - Initial context data
    - `:initial_state` - Override initial state

  ## Example

      {:ok, machine} = StateMachine.new(MyMachine, initial_context: %{user: user})
  """
  @spec new(module(), keyword()) :: {:ok, Machine.t()} | {:error, term()}
  def new(definition, opts \\ []) do
    initial_state =
      Keyword.get(opts, :initial_state, definition.get_initial_state())

    initial_context = Keyword.get(opts, :initial_context, %{})

    unless definition.valid_state?(initial_state) do
      {:error, {:invalid_initial_state, initial_state}}
    else
      machine = %Machine{
        definition: definition,
        current_state: initial_state,
        context: initial_context,
        history: [],
        started_at: System.monotonic_time(:millisecond)
      }

      # Execute on_enter for initial state
      state_def = definition.get_state(initial_state)

      machine =
        if state_def && state_def.on_enter do
          execute_callback(state_def.on_enter, machine)
        else
          machine
        end

      {:ok, machine}
    end
  end

  @doc """
  Send an event to the state machine.

  ## Example

      {:ok, machine} = StateMachine.send_event(machine, :submit, %{data: data})
  """
  @spec send_event(Machine.t(), atom(), map()) ::
          {:ok, Machine.t()} | {:error, term()}
  def send_event(%Machine{} = machine, event, payload \\ %{}) do
    definition = machine.definition
    current_state = machine.current_state
    state_def = definition.get_state(current_state)

    # Find matching transition
    transition =
      Enum.find(state_def.transitions, fn t ->
        t.event == event && check_guard(t.guard, machine, payload)
      end)

    case transition do
      nil ->
        {:error, {:no_transition, current_state, event}}

      %Transition{to: target_state, action: action} ->
        # Execute on_exit for current state
        machine =
          if state_def.on_exit do
            execute_callback(state_def.on_exit, machine)
          else
            machine
          end

        # Execute transition action
        machine =
          if action do
            execute_callback(action, machine, payload)
          else
            machine
          end

        # Update state
        machine = %{
          machine
          | current_state: target_state,
            history: [
              {current_state, event, System.monotonic_time(:millisecond)}
              | machine.history
            ]
        }

        # Execute on_enter for new state
        target_state_def = definition.get_state(target_state)

        machine =
          if target_state_def && target_state_def.on_enter do
            execute_callback(target_state_def.on_enter, machine)
          else
            machine
          end

        {:ok, machine}
    end
  end

  @doc """
  Check if a transition is possible for the given event.

  ## Example

      true = StateMachine.can_transition?(machine, :submit)
  """
  @spec can_transition?(Machine.t(), atom()) :: boolean()
  def can_transition?(%Machine{} = machine, event) do
    definition = machine.definition
    state_def = definition.get_state(machine.current_state)

    Enum.any?(state_def.transitions, fn t ->
      t.event == event && check_guard(t.guard, machine, %{})
    end)
  end

  @doc """
  Get available events from the current state.

  ## Example

      events = StateMachine.available_events(machine)
  """
  @spec available_events(Machine.t()) :: [atom()]
  def available_events(%Machine{} = machine) do
    definition = machine.definition
    state_def = definition.get_state(machine.current_state)

    state_def.transitions
    |> Enum.filter(fn t -> check_guard(t.guard, machine, %{}) end)
    |> Enum.map(& &1.event)
    |> Enum.uniq()
  end

  @doc """
  Get the current state.
  """
  @spec current_state(Machine.t()) :: atom()
  def current_state(%Machine{current_state: state}), do: state

  @doc """
  Get the context data.
  """
  @spec get_context(Machine.t()) :: map()
  def get_context(%Machine{context: context}), do: context

  @doc """
  Set the context data.
  """
  @spec set_context(Machine.t(), map()) :: Machine.t()
  def set_context(%Machine{} = machine, context) when is_map(context) do
    %{machine | context: context}
  end

  @doc """
  Update the context data.
  """
  @spec update_context(Machine.t(), (map() -> map())) :: Machine.t()
  def update_context(%Machine{} = machine, update_fn)
      when is_function(update_fn, 1) do
    %{machine | context: update_fn.(machine.context)}
  end

  @doc """
  Get the transition history.
  """
  @spec get_history(Machine.t()) :: [{atom(), atom(), integer()}]
  def get_history(%Machine{history: history}), do: Enum.reverse(history)

  @doc """
  Serialize the machine state.
  """
  @spec serialize(Machine.t()) :: binary()
  def serialize(%Machine{} = machine) do
    data = %{
      definition: machine.definition,
      current_state: machine.current_state,
      context: machine.context,
      history: machine.history,
      started_at: machine.started_at
    }

    :erlang.term_to_binary(data)
  end

  @doc """
  Deserialize a machine state.
  """
  @spec deserialize(binary()) :: {:ok, Machine.t()} | {:error, term()}
  def deserialize(binary) when is_binary(binary) do
    data = :erlang.binary_to_term(binary, [:safe])

    machine = %Machine{
      definition: data.definition,
      current_state: data.current_state,
      context: data.context,
      history: data.history,
      started_at: data.started_at
    }

    {:ok, machine}
  rescue
    e -> {:error, e}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp check_guard(nil, _machine, _payload), do: true

  defp check_guard(guard_fn, machine, _payload) when is_function(guard_fn, 1) do
    guard_fn.(machine.context)
  end

  defp check_guard(guard_fn, machine, payload) when is_function(guard_fn, 2) do
    guard_fn.(machine.context, payload)
  end

  defp execute_callback(callback, machine) when is_function(callback, 1) do
    case callback.(machine.context) do
      {:ok, new_context} when is_map(new_context) ->
        %{machine | context: new_context}

      new_context when is_map(new_context) ->
        %{machine | context: new_context}

      _ ->
        machine
    end
  end

  defp execute_callback(_, machine), do: machine

  defp execute_callback(callback, machine, payload)
       when is_function(callback, 2) do
    case callback.(machine.context, payload) do
      {:ok, new_context} when is_map(new_context) ->
        %{machine | context: new_context}

      new_context when is_map(new_context) ->
        %{machine | context: new_context}

      _ ->
        machine
    end
  end

  defp execute_callback(_, machine, _), do: machine
end
