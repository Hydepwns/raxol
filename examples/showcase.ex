defmodule Raxol.Examples.Showcase do
  @moduledoc """
  Interactive component showcase demonstrating all Raxol components.

  Run with: mix raxol.examples showcase
  """

  use Raxol.Application

  alias Raxol.UI.Components.{
    Box,
    Text,
    Button,
    TextInput,
    Select,
    Table,
    ProgressBar,
    Tabs
  }

  @components [
    %{id: "text", name: "Text & Typography", icon: "📝"},
    %{id: "buttons", name: "Buttons", icon: "🔘"},
    %{id: "inputs", name: "Form Inputs", icon: "📋"},
    %{id: "layout", name: "Layout", icon: "📐"},
    %{id: "data", name: "Data Display", icon: "📊"},
    %{id: "feedback", name: "Feedback", icon: "💬"},
    %{id: "navigation", name: "Navigation", icon: "🧭"},
    %{id: "advanced", name: "Advanced", icon: "⚡"}
  ]

  @impl true
  def mount(_params, socket) do
    {:ok,
     socket
     |> assign(selected_component: "text")
     |> assign(theme: "dark")
     |> assign(demo_state: initial_demo_state())}
  end

  defp initial_demo_state do
    %{
      # Text demo
      text_style: "normal",

      # Button demo
      button_variant: "primary",
      button_clicks: 0,

      # Input demo
      text_value: "",
      select_value: nil,
      checkbox_value: false,
      radio_value: "option1",

      # Table demo
      table_data: generate_sample_data(),
      selected_row: nil,

      # Progress demo
      progress_value: 65,

      # Tabs demo
      active_tab: "overview"
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Screen title="Raxol Component Showcase">
      <Grid columns={12} height="100%">
        <!-- Sidebar -->
        <GridItem colSpan={3}>
          <ComponentSidebar
            components={@components}
            selected={@selected_component}
            onSelect="select_component"
          />
        </GridItem>
        
        <!-- Main Content -->
        <GridItem colSpan={9}>
          <Box padding={2} height="100%">
            <!-- Header -->
            <Stack direction="horizontal" justify="between" marginBottom={2}>
              <Heading level={1}>
                <%= get_component_title(@selected_component) %>
              </Heading>
              <ThemeToggle theme={@theme} onChange="toggle_theme" />
            </Stack>
            
            <!-- Component Demo -->
            <Box border="single" borderColor="gray.600" padding={2}>
              <%= render_component_demo(@selected_component, @demo_state, assigns) %>
            </Box>
            
            <!-- Code Example -->
            <Box marginTop={2}>
              <Heading level={3}>Example Code</Heading>
              <CodeBlock language="elixir">
                <%= get_component_code(@selected_component) %>
              </CodeBlock>
            </Box>
          </Box>
        </GridItem>
      </Grid>
    </Screen>
    """
  end

  # Component Demos

  defp render_component_demo("text", state, assigns) do
    ~H"""
    <Stack spacing={2}>
      <Text>Normal text</Text>
      <Text bold>Bold text</Text>
      <Text italic>Italic text</Text>
      <Text underline>Underlined text</Text>
      <Text strikethrough>Strikethrough text</Text>
      <Text color="cyan">Colored text</Text>
      <Text color="red" backgroundColor="yellow.100">Text with background</Text>
      <Text size="small">Small text</Text>
      <Text size="large">Large text</Text>
      
      <Divider />
      
      <Heading level={1}>Heading 1</Heading>
      <Heading level={2}>Heading 2</Heading>
      <Heading level={3}>Heading 3</Heading>
      
      <Divider />
      
      <Code>const example = "inline code";</Code>
      
      <CodeBlock language="javascript">
        function hello(name) {
          console.log(`Hello, ${name}!`);
        }
      </CodeBlock>
    </Stack>
    """
  end

  defp render_component_demo("buttons", state, assigns) do
    ~H"""
    <Stack spacing={3}>
      <Stack direction="horizontal" spacing={2}>
        <Button variant="primary" onClick="increment_clicks">
          Primary (<%= state.button_clicks %>)
        </Button>
        <Button variant="secondary">Secondary</Button>
        <Button variant="success">Success</Button>
        <Button variant="danger">Danger</Button>
        <Button variant="warning">Warning</Button>
      </Stack>
      
      <Stack direction="horizontal" spacing={2}>
        <Button size="small">Small</Button>
        <Button size="medium">Medium</Button>
        <Button size="large">Large</Button>
      </Stack>
      
      <Stack direction="horizontal" spacing={2}>
        <Button leftIcon="➕">Add Item</Button>
        <Button rightIcon="→">Continue</Button>
        <Button disabled>Disabled</Button>
        <Button loading>Loading</Button>
      </Stack>
      
      <ButtonGroup>
        <Button>First</Button>
        <Button>Second</Button>
        <Button>Third</Button>
      </ButtonGroup>
    </Stack>
    """
  end

  defp render_component_demo("inputs", state, assigns) do
    ~H"""
    <Stack spacing={3}>
      <!-- Text Input -->
      <FormField label="Text Input" helper="Enter some text">
        <TextInput
          value={state.text_value}
          onChange="update_text"
          placeholder="Type something..."
        />
      </FormField>
      
      <!-- Password Input -->
      <FormField label="Password">
        <TextInput
          type="password"
          placeholder="Enter password..."
        />
      </FormField>
      
      <!-- Text Area -->
      <FormField label="Text Area">
        <TextArea
          rows={4}
          placeholder="Enter multiple lines..."
        />
      </FormField>
      
      <!-- Select -->
      <FormField label="Select">
        <Select
          value={state.select_value}
          onChange="update_select"
          placeholder="Choose an option..."
          options={[
            %{value: "opt1", label: "Option 1"},
            %{value: "opt2", label: "Option 2"},
            %{value: "opt3", label: "Option 3"}
          ]}
        />
      </FormField>
      
      <!-- Checkbox -->
      <Checkbox
        checked={state.checkbox_value}
        onChange="toggle_checkbox"
      >
        Accept terms and conditions
      </Checkbox>
      
      <!-- Radio Group -->
      <RadioGroup
        value={state.radio_value}
        onChange="update_radio"
        options={[
          %{value: "option1", label: "Option 1"},
          %{value: "option2", label: "Option 2"},
          %{value: "option3", label: "Option 3"}
        ]}
      />
      
      <!-- Switch -->
      <Stack direction="horizontal" align="center" spacing={2}>
        <Text>Dark Mode</Text>
        <Switch checked={@theme == "dark"} onChange="toggle_theme" />
      </Stack>
    </Stack>
    """
  end

  defp render_component_demo("layout", _state, assigns) do
    ~H"""
    <Stack spacing={3}>
      <!-- Box Examples -->
      <Text bold>Box Component</Text>
      <Stack direction="horizontal" spacing={2}>
        <Box padding={2} border="single" borderColor="blue">
          Single Border
        </Box>
        <Box padding={2} border="double" borderColor="green">
          Double Border
        </Box>
        <Box padding={2} border="rounded" borderColor="purple">
          Rounded Border
        </Box>
      </Stack>
      
      <!-- Grid Layout -->
      <Text bold marginTop={2}>Grid Layout</Text>
      <Grid columns={4} gap={1}>
        <GridItem>
          <Box backgroundColor="blue.800" padding={1}>1</Box>
        </GridItem>
        <GridItem colSpan={2}>
          <Box backgroundColor="green.800" padding={1}>2 (span 2)</Box>
        </GridItem>
        <GridItem>
          <Box backgroundColor="red.800" padding={1}>3</Box>
        </GridItem>
        <GridItem colSpan={4}>
          <Box backgroundColor="purple.800" padding={1}>4 (full width)</Box>
        </GridItem>
      </Grid>
      
      <!-- Stack Layout -->
      <Text bold marginTop={2}>Stack Layout</Text>
      <Box border="single" padding={2}>
        <Stack spacing={1}>
          <Box backgroundColor="gray.700" padding={1}>Item 1</Box>
          <Box backgroundColor="gray.700" padding={1}>Item 2</Box>
          <Box backgroundColor="gray.700" padding={1}>Item 3</Box>
        </Stack>
      </Box>
      
      <!-- Spacer -->
      <Text bold marginTop={2}>Spacer Component</Text>
      <Stack direction="horizontal" border="single" padding={1}>
        <Text>Left</Text>
        <Spacer />
        <Text>Right</Text>
      </Stack>
    </Stack>
    """
  end

  defp render_component_demo("data", state, assigns) do
    ~H"""
    <Stack spacing={3}>
      <!-- Table -->
      <Text bold>Table Component</Text>
      <Table
        data={state.table_data}
        columns={[
          %{key: "id", label: "ID", width: 10},
          %{key: "name", label: "Name", width: 25},
          %{key: "status", label: "Status", width: 15},
          %{key: "progress", label: "Progress", width: 20}
        ]}
        onRowClick="select_row"
        selectedRow={state.selected_row}
        bordered
        striped
      />
      
      <!-- List -->
      <Text bold marginTop={2}>List Component</Text>
      <List>
        <ListItem>First item</ListItem>
        <ListItem>Second item with icon</ListItem>
        <ListItem selected>Selected item</ListItem>
        <ListItem>Fourth item</ListItem>
      </List>
      
      <!-- Progress Bar -->
      <Text bold marginTop={2}>Progress Bar</Text>
      <ProgressBar value={state.progress_value} max={100} showLabel color="green" />
      
      <!-- Stats -->
      <Text bold marginTop={2}>Stats Display</Text>
      <Grid columns={3} gap={2}>
        <Stat label="Total Users" value="1,234" change="+12%" />
        <Stat label="Revenue" value="$45.6K" change="+8%" />
        <Stat label="Active Sessions" value="89" change="-3%" />
      </Grid>
    </Stack>
    """
  end

  defp render_component_demo("feedback", _state, assigns) do
    ~H"""
    <Stack spacing={3}>
      <!-- Alerts -->
      <Alert variant="info">
        This is an informational alert message.
      </Alert>
      <Alert variant="success">
        Success! Your changes have been saved.
      </Alert>
      <Alert variant="warning">
        Warning: This action cannot be undone.
      </Alert>
      <Alert variant="error" dismissible>
        Error: Failed to connect to server.
      </Alert>
      
      <!-- Toast Messages -->
      <Button onClick="show_toast">Show Toast Message</Button>
      
      <!-- Modal Example -->
      <Button onClick="show_modal">Open Modal</Button>
      
      <!-- Loading States -->
      <Text bold marginTop={2}>Loading States</Text>
      <Stack direction="horizontal" spacing={3}>
        <Spinner size="small" />
        <Spinner size="medium" color="cyan" />
        <Spinner size="large" color="green" />
      </Stack>
      
      <!-- Skeleton -->
      <Text bold marginTop={2}>Skeleton Loading</Text>
      <Stack spacing={1}>
        <Skeleton width="100%" height={2} />
        <Skeleton width="75%" height={2} />
        <Skeleton width="50%" height={2} />
      </Stack>
    </Stack>
    """
  end

  defp render_component_demo("navigation", state, assigns) do
    ~H"""
    <Stack spacing={3}>
      <!-- Tabs -->
      <Tabs
        value={state.active_tab}
        onChange="change_tab"
        tabs={[
          %{id: "overview", label: "Overview"},
          %{id: "details", label: "Details"},
          %{id: "settings", label: "Settings"}
        ]}
      >
        <TabPanel value="overview">
          <Text>Overview content goes here...</Text>
        </TabPanel>
        <TabPanel value="details">
          <Text>Details content goes here...</Text>
        </TabPanel>
        <TabPanel value="settings">
          <Text>Settings content goes here...</Text>
        </TabPanel>
      </Tabs>
      
      <!-- Breadcrumbs -->
      <Breadcrumbs
        items={[
          %{label: "Home", href: "/"},
          %{label: "Components", href: "/components"},
          %{label: "Navigation", active: true}
        ]}
      />
      
      <!-- Pagination -->
      <Pagination
        currentPage={1}
        totalPages={10}
        onPageChange="change_page"
      />
      
      <!-- Menu -->
      <Text bold marginTop={2}>Menu Component</Text>
      <Menu>
        <MenuItem onClick="menu_action" icon="📁">Open File</MenuItem>
        <MenuItem onClick="menu_action" icon="💾">Save</MenuItem>
        <MenuDivider />
        <MenuItem onClick="menu_action" icon="⚙️">Settings</MenuItem>
        <MenuItem onClick="menu_action" icon="🚪" shortcut="Ctrl+Q">Exit</MenuItem>
      </Menu>
    </Stack>
    """
  end

  defp render_component_demo("advanced", _state, assigns) do
    ~H"""
    <Stack spacing={3}>
      <!-- Chart -->
      <Text bold>Chart Component</Text>
      <Chart
        type="bar"
        data={[
          %{label: "Mon", value: 12},
          %{label: "Tue", value: 19},
          %{label: "Wed", value: 15},
          %{label: "Thu", value: 25},
          %{label: "Fri", value: 22},
          %{label: "Sat", value: 18},
          %{label: "Sun", value: 10}
        ]}
        height={10}
        color="cyan"
        showValues
      />
      
      <!-- Tree View -->
      <Text bold marginTop={2}>Tree View</Text>
      <TreeView
        data={[
          %{
            id: "1",
            label: "src",
            children: [
              %{id: "1.1", label: "components"},
              %{id: "1.2", label: "utils"},
              %{id: "1.3", label: "styles"}
            ]
          },
          %{
            id: "2",
            label: "tests",
            children: [
              %{id: "2.1", label: "unit"},
              %{id: "2.2", label: "integration"}
            ]
          }
        ]}
        onSelect="select_tree_node"
      />
      
      <!-- Virtual List -->
      <Text bold marginTop={2}>Virtual List (10,000 items)</Text>
      <VirtualList
        items={Enum.map(1..10000, &"Item #{&1}")}
        height={10}
        itemHeight={1}
        renderItem={fn item -> 
          ~H"<Text><%= item %></Text>"
        end}
      />
      
      <!-- Markdown Renderer -->
      <Text bold marginTop={2}>Markdown Renderer</Text>
      <Markdown>
        # Markdown Support
        
        Raxol supports **bold**, *italic*, and `inline code`.
        
        - List item 1
        - List item 2
        
        > Blockquotes are also supported
      </Markdown>
    </Stack>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("select_component", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_component: id)}
  end

  @impl true
  def handle_event("toggle_theme", _, socket) do
    new_theme = if socket.assigns.theme == "dark", do: "light", else: "dark"
    {:noreply, assign(socket, theme: new_theme)}
  end

  @impl true
  def handle_event("increment_clicks", _, socket) do
    {:noreply, update_in(socket.assigns.demo_state.button_clicks, &(&1 + 1))}
  end

  @impl true
  def handle_event("update_text", %{"value" => value}, socket) do
    {:noreply, put_in(socket.assigns.demo_state.text_value, value)}
  end

  @impl true
  def handle_event("show_toast", _, socket) do
    Raxol.Toast.show("This is a toast message!", type: :success)
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_modal", _, socket) do
    Raxol.Modal.show(
      title: "Example Modal",
      content: "This is a modal dialog window.",
      buttons: [
        %{label: "Cancel", action: :close},
        %{label: "OK", action: :close, variant: :primary}
      ]
    )

    {:noreply, socket}
  end

  # Helper Functions

  defp get_component_title(id) do
    component = Enum.find(@components, &(&1.id == id))
    "#{component.icon} #{component.name}"
  end

  defp get_component_code("text") do
    """
    <Text bold color="cyan">
      Styled text with Raxol
    </Text>

    <Heading level={1}>
      Main Heading
    </Heading>

    <CodeBlock language="elixir">
      def hello, do: "world"
    </CodeBlock>
    """
  end

  defp get_component_code("buttons") do
    """
    <Button 
      variant="primary"
      onClick="handle_click"
      leftIcon="➕"
    >
      Add Item
    </Button>

    <ButtonGroup>
      <Button>Option 1</Button>
      <Button>Option 2</Button>
    </ButtonGroup>
    """
  end

  defp get_component_code(_), do: "# Example code for this component..."

  defp generate_sample_data do
    Enum.map(1..5, fn i ->
      %{
        id: i,
        name: "Item #{i}",
        status: Enum.random(["Active", "Pending", "Inactive"]),
        progress: :rand.uniform(100)
      }
    end)
  end
end

# Component: Sidebar
defmodule Raxol.Examples.Showcase.ComponentSidebar do
  use Raxol.Component

  prop(:components, {:list, :map}, required: true)
  prop(:selected, :string, required: true)
  prop(:onSelect, :string, required: true)

  @impl true
  def render(assigns) do
    ~H"""
    <Box padding={2} height="100%">
      <Heading level={2} marginBottom={2}>
        Components
      </Heading>
      <List>
        <%= for component <- @components do %>
          <ListItem
            key={component.id}
            selected={component.id == @selected}
            onClick={@onSelect}
            params={%{id: component.id}}
          >
            <Text>
              <%= component.icon %> <%= component.name %>
            </Text>
          </ListItem>
        <% end %>
      </List>
    </Box>
    """
  end
end

# Component: Theme Toggle
defmodule Raxol.Examples.Showcase.ThemeToggle do
  use Raxol.Component

  prop(:theme, :string, required: true)
  prop(:onChange, :string, required: true)

  @impl true
  def render(assigns) do
    ~H"""
    <Button
      variant="ghost"
      onClick={@onChange}
      title="Toggle theme"
    >
      <%= if @theme == "dark" do %>
        🌙 Dark
      <% else %>
        ☀️ Light
      <% end %>
    </Button>
    """
  end
end
