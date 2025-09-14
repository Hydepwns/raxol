defmodule Examples.SvelteCounter do
  @moduledoc """
  A simple counter component demonstrating Svelte-style patterns in Raxol.

  Features:
  - Reactive state management
  - Reactive computed values
  - Event handling
  - Compile-time optimization

  Usage:
    terminal = Raxol.Terminal.new()
    counter = Examples.SvelteCounter.mount(terminal)
  """

  use Raxol.Svelte.Component, optimize: :compile_time
  use Raxol.Svelte.Reactive

  # State variables
  state(:count, 0)
  state(:step, 1)
  state(:name, "World")

  # Reactive computed values (like Svelte's derived stores)
  reactive :doubled do
    @count * 2
  end

  reactive :tripled do
    @doubled + @count
  end

  reactive :greeting do
    "Hello, #{@name}!"
  end

  # Reactive statements (like Svelte's $: declarations)
  reactive_block do
    # These run automatically when dependencies change
    reactive_stmt(is_even = rem(@count, 2) == 0)

    reactive_stmt(
      magnitude =
        cond do
          @count < 0 -> "negative"
          @count == 0 -> "zero"
          @count < 10 -> "small"
          @count < 100 -> "medium"
          true -> "large"
        end
    )

    reactive_stmt(
      status_message =
        "Count is #{magnitude} and #{if is_even, do: "even", else: "odd"}"
    )

    # Side effects
    reactive_stmt(
      if @count > 10 do
        IO.puts("Warning: Count is getting high!")
      end
    )
  end

  # Event handlers
  def increment do
    update_state(:count, &(&1 + get_state(:step)))
  end

  def decrement do
    update_state(:count, &(&1 - get_state(:step)))
  end

  def reset do
    set_state(:count, 0)
  end

  def set_step(new_step) do
    set_state(:step, new_step)
  end

  def set_name(new_name) do
    set_state(:name, new_name)
  end

  # Render function with template (compile-time optimized)
  def render(assigns) do
    ~H"""
    <Box padding={2} border="double" title="Svelte Counter">
      <Text color="blue" bold>{@greeting}</Text>
      <Text>Count: {@count}</Text>
      <Text>Doubled: {@doubled}</Text>
      <Text>Tripled: {@tripled}</Text>
      <Text color={if @count < 0, do: "red", else: "green"}>{status_message}</Text>
      
      <Row spacing={1}>
        <Button on_click={&decrement/0}>-{@step}</Button>
        <Button on_click={&increment/0}>+{@step}</Button>
        <Button on_click={&reset/0}>Reset</Button>
      </Row>
      
      <Row spacing={1}>
        <Text>Step:</Text>
        <Button on_click={fn -> set_step(1) end} active={@step == 1}>1</Button>
        <Button on_click={fn -> set_step(5) end} active={@step == 5}>5</Button>
        <Button on_click={fn -> set_step(10) end} active={@step == 10}>10</Button>
      </Row>
      
      <TextInput 
        value={@name} 
        placeholder="Enter your name"
        on_change={&set_name/1}
      />
    </Box>
    """
  end
end
