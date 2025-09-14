defmodule Examples.SvelteDemo do
  @moduledoc """
  Demo script showcasing Svelte-style patterns in Raxol.

  Run with: mix run examples/svelte_demo.ex
  """

  def run do
    IO.puts("\n=== Raxol Svelte-Style Demo ===\n")

    # Demo 1: Reactive Store
    IO.puts("1. Testing Reactive Store...")
    demo_reactive_store()

    # Demo 2: Component with Reactive State
    IO.puts("\n2. Testing Svelte-Style Component...")
    demo_svelte_component()

    # Demo 3: Todo App Features
    IO.puts("\n3. Testing Todo App Features...")
    demo_todo_app()

    IO.puts("\n=== Demo Complete ===")
  end

  defp demo_reactive_store do
    # Define a simple counter store
    defmodule DemoCounter do
      use Raxol.Svelte.Store

      store(:count, 0)
      store(:step, 1)

      derive(:doubled, fn %{count: c} -> c * 2 end)

      derive(:message, fn %{count: c, doubled: d} ->
        "Count: #{c}, Doubled: #{d}"
      end)
    end

    # Start the store
    {:ok, _pid} = DemoCounter.start_link()

    # Subscribe to changes
    DemoCounter.subscribe(:count, fn value ->
      IO.puts("  Count changed: #{value}")
    end)

    DemoCounter.subscribe(:message, fn value ->
      IO.puts("  Message: #{value}")
    end)

    # Test reactive updates
    IO.puts("  Initial values:")
    IO.puts("    Count: #{DemoCounter.get(:count)}")
    IO.puts("    Doubled: #{DemoCounter.get(:doubled)}")
    IO.puts("    Message: #{DemoCounter.get(:message)}")

    IO.puts("  Setting count to 5...")
    DemoCounter.set(:count, 5)
    # Let callbacks execute
    Process.sleep(100)

    IO.puts("  Updating count by +3...")
    DemoCounter.update(:count, &(&1 + 3))
    Process.sleep(100)

    IO.puts("  Final doubled value: #{DemoCounter.get(:doubled)}")

    # Stop the store
    GenServer.stop(DemoCounter)
  end

  defp demo_svelte_component do
    # Create a simple reactive component
    defmodule DemoReactiveComponent do
      use Raxol.Svelte.Component
      use Raxol.Svelte.Reactive

      state(:x, 5)
      state(:y, 10)

      reactive :sum do
        @x + @y
      end

      reactive :product do
        @x * @y
      end

      reactive_block do
        reactive_stmt(is_sum_even = rem(@x + @y, 2) == 0)

        reactive_stmt(
          magnitude =
            cond do
              @sum < 10 -> "small"
              @sum < 50 -> "medium"
              true -> "large"
            end
        )

        reactive_stmt(
          description =
            "Sum is #{magnitude} and #{if is_sum_even, do: "even", else: "odd"}"
        )
      end

      def demo_operations do
        IO.puts("  Initial state:")
        IO.puts("    X: #{get_state(:x)}, Y: #{get_state(:y)}")
        IO.puts("    Sum: #{get_state(:sum)}")
        IO.puts("    Product: #{get_state(:product)}")

        IO.puts("  Setting X to 7...")
        set_state(:x, 7)
        Process.sleep(50)

        IO.puts("    New sum: #{get_state(:sum)}")
        IO.puts("    New product: #{get_state(:product)}")

        IO.puts("  Setting Y to 3...")
        set_state(:y, 3)
        Process.sleep(50)

        IO.puts("    Final sum: #{get_state(:sum)}")
        IO.puts("    Final product: #{get_state(:product)}")
      end

      def render(_assigns) do
        # Mock render for demo
        "Component rendered"
      end
    end

    # Create a mock terminal
    mock_terminal = %{buffer: "mock"}

    # Mount component
    component = DemoReactiveComponent.mount(mock_terminal)

    # Run demo operations
    GenServer.call(component, {:demo_operations})

    # Clean up
    DemoReactiveComponent.unmount(component)
  end

  defp demo_todo_app do
    IO.puts("  Todo App Demo (Architecture Overview):")

    IO.puts("    ✓ Reactive state management")
    IO.puts("    ✓ Derived computed values")
    IO.puts("    ✓ Two-way data binding")
    IO.puts("    ✓ Conditional rendering")
    IO.puts("    ✓ Array operations")
    IO.puts("    ✓ Event handling")

    # Demonstrate the data flow concepts
    todos = [
      %{id: "1", text: "Learn Raxol", completed: false},
      %{id: "2", text: "Build something cool", completed: false},
      %{id: "3", text: "Share with community", completed: true}
    ]

    IO.puts("  Sample todo state:")
    IO.puts("    Total: #{length(todos)}")
    IO.puts("    Active: #{Enum.count(todos, fn t -> !t.completed end)}")
    IO.puts("    Completed: #{Enum.count(todos, fn t -> t.completed end)}")

    IO.puts(
      "  Reactive derivations would automatically update when todos change"
    )

    IO.puts("  Template would re-render only affected parts")
  end
end

# For running as a script
if __MODULE__ == Examples.SvelteDemo do
  Examples.SvelteDemo.run()
end
