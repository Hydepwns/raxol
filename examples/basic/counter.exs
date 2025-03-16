# Counter Example
#
# A simple counter application demonstrating Raxol basics.
#
# Run with:
#   elixir examples/counter.exs

defmodule CounterExample do
  use Raxol.App
  
  @impl true
  def init(_) do
    %{count: 0}
  end
  
  @impl true
  def update(model, msg) do
    case msg do
      :increment -> %{model | count: model.count + 1}
      :decrement -> %{model | count: model.count - 1}
      :reset -> %{model | count: 0}
      _ -> model
    end
  end
  
  @impl true
  def render(model) do
    use Raxol.View
    
    view do
      panel title: "Counter Example" do
        row do
          column size: 12 do
            label content: "Count: #{model.count}"
          end
        end
        
        row do
          column size: 4 do
            button label: "Increment", on_click: :increment
          end
          column size: 4 do
            button label: "Reset", on_click: :reset
          end
          column size: 4 do
            button label: "Decrement", on_click: :decrement
          end
        end
        
        row do
          column size: 12 do
            label content: "Press 'q' to quit"
          end
        end
      end
    end
  end
end

# Run the example
Raxol.run(CounterExample, title: "Raxol Counter Example", quit_keys: [:q, :ctrl_c])
