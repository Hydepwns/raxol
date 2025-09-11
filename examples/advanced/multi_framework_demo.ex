defmodule Examples.MultiFrameworkDemo do
  @moduledoc """
  Demo showing all UI frameworks working together in a single application.

  This demonstrates React, Svelte, LiveView, and HEEx components
  all coexisting in the same terminal application.
  """

  use Raxol.UI, framework: :react

  def run do
    IO.puts("\n=== Multi-Framework Raxol Demo ===")
    IO.puts("Showing React, Svelte, LiveView, and HEEx all working together\n")

    # Create components using different frameworks
    react_counter = create_react_counter()
    svelte_dashboard = create_svelte_dashboard()
    liveview_chat = create_liveview_chat()
    heex_profile = create_heex_profile()

    IO.puts("✅ Created React counter component")
    IO.puts("✅ Created Svelte dashboard component")
    IO.puts("✅ Created LiveView chat component")
    IO.puts("✅ Created HEEx profile component")

    IO.puts("\n=== Framework Comparison ===")
    show_framework_comparison()

    IO.puts("\n=== Universal Features Demo ===")
    show_universal_features()
  end

  defp create_react_counter do
    quote do
      defmodule ReactCounter do
        use Raxol.UI, framework: :react

        def render(assigns) do
          ~H"""
          <Box padding={2} border="single" title="React Counter">
            <Text>React-style component</Text>
            <Text>Count: {@count}</Text>
            <Button on_click={@increment}>+</Button>
            <Button on_click={@decrement}>-</Button>
          </Box>
          """
        end
      end
    end
  end

  defp create_svelte_dashboard do
    quote do
      defmodule SvelteDashboard do
        use Raxol.UI, framework: :svelte

        state(:users, 0)
        state(:revenue, 1000)

        reactive :growth_rate do
          (@revenue / 1000 - 1) * 100
        end

        def render(assigns) do
          ~H"""
          <Box padding={2} border="double" title="Svelte Dashboard">
            <Text>Reactive Svelte component</Text>
            <Text>Users: {@users}</Text>
            <Text>Revenue: ${@revenue}</Text>
            <Text color="green">Growth: {@growth_rate}%</Text>
          </Box>
          """
        end
      end
    end
  end

  defp create_liveview_chat do
    quote do
      defmodule LiveViewChat do
        use Raxol.UI, framework: :liveview

        def mount(_params, _session, socket) do
          {:ok,
           assign(socket,
             messages: [],
             current_message: "",
             users_online: 5
           )}
        end

        def handle_event("send_message", %{"message" => msg}, socket) do
          new_messages = socket.assigns.messages ++ [msg]

          {:noreply,
           assign(socket, messages: new_messages, current_message: "")}
        end

        def render(assigns) do
          ~H"""
          <Box padding={2} border="rounded" title="LiveView Chat">
            <Text>Phoenix LiveView component</Text>
            <Text>Users online: {@users_online}</Text>
            <Text>Messages: {length(@messages)}</Text>
            <Input 
              value={@current_message} 
              phx-change="update_message" 
              phx-submit="send_message" 
            />
          </Box>
          """
        end
      end
    end
  end

  defp create_heex_profile do
    quote do
      defmodule HEExProfile do
        use Raxol.UI, framework: :heex

        def render(assigns) do
          ~H"""
          <.terminal_box padding={2} border="thick" title="HEEx Profile">
            <.terminal_text bold>HEEx Template Component</.terminal_text>
            
            <.terminal_list items={@skills} class="skills-list">
              <:item :let={skill}>
                <.terminal_text color="blue"><%= skill %></.terminal_text>
              </:item>
            </.terminal_list>
            
            <.terminal_button variant="primary" phx-click="edit_profile">
              Edit Profile
            </.terminal_button>
          </.terminal_box>
          """
        end
      end
    end
  end

  defp show_framework_comparison do
    IO.puts(
      "┌─────────────┬──────────────┬─────────────────┬─────────────────┐"
    )

    IO.puts(
      "│ Framework   │ Paradigm     │ Best For        │ Learning Curve  │"
    )

    IO.puts(
      "├─────────────┼──────────────┼─────────────────┼─────────────────┤"
    )

    IO.puts(
      "│ React       │ Virtual DOM  │ Familiar APIs   │ Easy            │"
    )

    IO.puts(
      "│ Svelte      │ Reactive     │ Performance     │ Medium          │"
    )

    IO.puts(
      "│ LiveView    │ Server-side  │ Real-time apps  │ Easy            │"
    )

    IO.puts(
      "│ HEEx        │ Templates    │ Simple UIs      │ Very Easy       │"
    )

    IO.puts(
      "│ Raw         │ Direct       │ Maximum control │ Hard            │"
    )

    IO.puts(
      "└─────────────┴──────────────┴─────────────────┴─────────────────┘"
    )
  end

  defp show_universal_features do
    IO.puts("Universal features work across ALL frameworks:")
    IO.puts("  • Actions system (use:tooltip, use:draggable, etc.)")
    IO.puts("  • Transitions & animations (fade, scale, slide)")
    IO.puts("  • Context API (theme, auth, user preferences)")
    IO.puts("  • Slot system (component composition)")
    IO.puts("  • Event handling (keyboard, mouse, custom events)")
    IO.puts("  • Theme system (colors, spacing, typography)")

    IO.puts("\nExample usage in ANY framework:")

    IO.puts("""
      # Universal actions work everywhere
      <Button use:tooltip="Help text" use:keyboard_shortcut="ctrl+s">
        Save
      </Button>
      
      # Universal transitions work everywhere
      <Modal in:fade={{duration: 300}} out:scale={{start: 0.9}}>
        Content
      </Modal>
      
      # Universal context works everywhere
      theme = use_context(:theme)
      <Text color={theme.colors.primary}>Themed text</Text>
    """)
  end
end

# Run the demo
if __MODULE__ == Examples.MultiFrameworkDemo do
  Examples.MultiFrameworkDemo.run()
end
