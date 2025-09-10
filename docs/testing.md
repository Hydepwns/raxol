# Testing

Comprehensive testing for terminal applications.

## Quick Start

```bash
# Run all tests
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test

# Run specific test
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/my_test.exs

# Run with coverage
mix test --cover
```

## Test Helpers

### Terminal Testing

```elixir
defmodule MyTerminalTest do
  use Raxol.TerminalCase
  
  test "renders output correctly" do
    {:ok, term} = create_test_terminal(width: 80, height: 24)
    
    # Send input
    send_keys(term, "hello world")
    send_key(term, :enter)
    
    # Assert output
    assert screen_text(term) =~ "hello world"
    assert cursor_position(term) == {1, 0}
  end
  
  test "handles ANSI sequences" do
    {:ok, term} = create_test_terminal()
    
    write_ansi(term, "\e[31mRed Text\e[0m")
    
    assert cell_at(term, 0, 0).fg == :red
    assert screen_text(term) == "Red Text"
  end
end
```

### Component Testing

```elixir
defmodule MyComponentTest do
  use Raxol.ComponentCase
  
  test "renders correctly" do
    {:ok, component} = render_component(MyButton, 
      label: "Click me"
    )
    
    assert find_text(component) == "Click me"
    assert has_style?(component, :bold)
  end
  
  test "handles events" do
    {:ok, component} = render_component(Counter)
    
    # Simulate events
    component |> simulate_click()
    assert find_text(component) =~ "1"
    
    component |> simulate_key(:arrow_up)
    assert find_text(component) =~ "2"
  end
end
```

## Property Testing

```elixir
defmodule ParserPropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  
  property "parser handles any valid ANSI sequence" do
    check all sequence <- ansi_sequence_generator() do
      assert {:ok, _} = Raxol.Parser.parse(sequence)
    end
  end
  
  property "buffer maintains dimensions" do
    check all width <- integer(1..200),
              height <- integer(1..100),
              ops <- list_of(buffer_operation()) do
      
      buffer = Buffer.new(width, height)
      buffer = Enum.reduce(ops, buffer, &apply_op/2)
      
      assert Buffer.width(buffer) == width
      assert Buffer.height(buffer) == height
    end
  end
end
```

## Performance Testing

```elixir
defmodule PerformanceTest do
  use Raxol.PerformanceCase
  
  @tag :performance
  test "renders in under 1ms" do
    component = create_large_component()
    
    assert_performance fn ->
      Raxol.render(component)
    end, max_ms: 1
  end
  
  @tag :memory
  test "uses reasonable memory" do
    assert_memory fn ->
      Enum.map(1..1000, fn _ ->
        create_component()
      end)
    end, max_mb: 10
  end
end
```

## Integration Testing

```elixir
defmodule IntegrationTest do
  use Raxol.IntegrationCase
  
  @tag :integration
  test "full application flow" do
    # Start application
    {:ok, app} = start_app(MyApp)
    
    # Simulate user interaction
    app
    |> navigate_to(:main_menu)
    |> select_option("New Document")
    |> type_text("Hello, World!")
    |> press_key([:ctrl, :s])
    
    # Verify results
    assert file_exists?("document.txt")
    assert File.read!("document.txt") == "Hello, World!"
  end
end
```

## Mocking & Stubbing

```elixir
defmodule MockTest do
  use ExUnit.Case
  import Mox
  
  setup :verify_on_exit!
  
  test "handles API responses" do
    # Mock external service
    expect(HTTPMock, :get, fn url ->
      {:ok, %{body: "mocked response"}}
    end)
    
    result = MyComponent.fetch_data()
    assert result == "mocked response"
  end
  
  test "handles terminal operations" do
    # Stub terminal
    stub(TerminalMock, :write, fn _, text ->
      send(self(), {:written, text})
      :ok
    end)
    
    MyComponent.render()
    assert_received {:written, "expected output"}
  end
end
```

## Accessibility Testing

```elixir
defmodule A11yTest do
  use Raxol.AccessibilityCase
  
  test "meets WCAG standards" do
    component = render_component(MyForm)
    
    # Check structure
    assert all_inputs_labeled?(component)
    assert proper_heading_order?(component)
    
    # Check contrast
    assert meets_wcag_aa?(component)
    
    # Check keyboard nav
    assert fully_keyboard_accessible?(component)
  end
  
  test "works with screen reader" do
    with_screen_reader do
      component = render_component(MyButton)
      
      assert announces?("Button: Click me")
      simulate_click(component)
      assert announces?("Button pressed")
    end
  end
end
```

## Test Fixtures

```elixir
defmodule Fixtures do
  def sample_terminal_output do
    """
    Welcome to MyApp v1.0
    > help
    Available commands:
      help - Show this message
      exit - Quit application
    > 
    """
  end
  
  def complex_ansi_sequence do
    "\e[2J\e[H\e[31;1mError:\e[0m File not found"
  end
  
  def large_dataset do
    Enum.map(1..10_000, fn i ->
      %{id: i, name: "Item #{i}", value: :rand.uniform(100)}
    end)
  end
end
```

## Continuous Integration

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    env:
      SKIP_TERMBOX2_TESTS: true
      MIX_ENV: test
    
    steps:
    - uses: actions/checkout@v2
    - uses: erlef/setup-beam@v1
      with:
        elixir-version: '1.15.7'
        otp-version: '26.0'
    
    - run: mix deps.get
    - run: mix compile --warnings-as-errors
    - run: mix format --check-formatted
    - run: mix credo
    - run: mix test --cover
    - run: mix dialyzer
```

## Test Configuration

```elixir
# config/test.exs
config :raxol,
  terminal: [
    headless: true,
    mock_pty: true
  ],
  performance: [
    assertions: true,
    profiling: true
  ],
  security: [
    sandbox: true,
    audit: false
  ]

# test/test_helper.exs
ExUnit.configure(
  exclude: [:slow, :integration],
  capture_log: true,
  max_failures: 5
)

# Start test services
Raxol.Test.Setup.start()
```

## Coverage Reports

```bash
# Generate coverage
mix test --cover

# HTML report
mix coveralls.html

# Send to service
mix coveralls.github
```

## See Also

- [Development](DEVELOPMENT.md) - Development setup
- [CI/CD](ci.md) - Continuous integration
- [Examples](examples/) - Test examples