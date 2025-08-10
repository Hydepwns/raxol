# An example that shows how to make a game with Raxol by using the canvas
# element.
#
# Usage:
#   elixir examples/snippets/advanced/snake.exs

defmodule Snake do
  # Use the correct Application behaviour and View DSL
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  alias Raxol.Core.Runtime.Events.Subscription
  alias Raxol.Core.Events.Event
  alias Raxol.Core.Commands.Command
  # Arrow key chars might vary by terminal, handle common patterns or codes if needed
  @up [:key_up]
  @down [:key_down]
  @left [:key_left]
  @right [:key_right]
  # Consider adding WASD or hjkl keys for wider compatibility
  @arrows @up ++ @down ++ @left ++ @right

  @initial_length 4

  @impl true
  def init(context) do
    Raxol.Core.Runtime.Log.debug("Snake: init/1 context: \#{inspect(context)}")

    # Assume context provides initial window dimensions if needed, or use defaults
    # Using fixed size for simplicity now, context inspection needed for dynamic size
    height = context[:height] || 20
    width = context[:width] || 40

    # Return :ok tuple
    {:ok,
     %{
       direction: :right,
       # Ensure coordinates start within bounds (e.g., 0-based)
       chain: Enum.map(@initial_length..1, fn x -> {x, 0} end),
       # Ensure food starts within bounds
       food: {7, 7},
       alive: true,
       # Adjust for potential border/padding
       height: height - 2,
       # Adjust for potential border/padding
       width: width - 2
     }}
  end

  @impl true
  def update(message, model) do
    Raxol.Core.Runtime.Log.debug("Snake: update/2 received message: \#{inspect(message)}")

    case message do
      # Use Event struct for key presses
      %Event{type: :key, data: %{key: key_name}} when key_name in @arrows ->
        new_dir = key_to_dir(key_name)
        # Return :ok tuple
        {:ok, %{model | direction: next_dir(model.direction, new_dir)}, []}

      # Handle quit keys
      %Event{type: :key, data: %{key: :char, char: "q"}} ->
        {:ok, model, [Command.new(:quit)]}

      %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {:ok, model, [Command.new(:quit)]}

      :tick ->
        new_model = move_snake(model)
        # Return :ok tuple
        {:ok, new_model, []}

      _ ->
        # Return :ok tuple
        {:ok, model, []}
    end
  end

  # Renamed from subscribe/1
  @impl true
  def subscriptions(%{alive: alive}) do
    Raxol.Core.Runtime.Log.debug("Snake: subscriptions/1 alive: \#{alive}")
    # Only subscribe to ticks if the game is active
    if alive do
      Subscription.interval(100, :tick)
    else
      Subscription.none()
    end
  end

  # Renamed from render/1
  @impl true
  def view(%{chain: chain} = model) do
    Raxol.Core.Runtime.Log.debug("Snake: view/1")
    score = length(chain) - @initial_length

    view do
      # Use box instead of panel
      box(
        title: "SNAKE (Move with Arrows) Score=#{score} | q/Ctrl+C to Quit",
        style: [[:height, :fill], [:padding, 0], [:border, :single]]
      ) do
        if model.alive do
          render_board(model)
        else
          # Center Game Over message
          box style: [
                [:height, :fill],
                [:width, :fill],
                [:align_items, :center],
                [:justify_content, :center]
              ] do
            text(content: "Game Over! Score: #{score}")
          end
        end
      end
    end
  end

  defp render_board(
         %{
           chain: [{head_x, head_y} | tail],
           food: {food_x, food_y}
         } = model
       ) do
    # Assuming canvas and its syntax is correct
    # Head is often different from tail segments
    head_cell = %{
      x: head_x,
      y: head_y,
      char: "@",
      style: %{color: :green, bg_color: :dark_green}
    }

    # Tail segments
    tail_cells =
      for {x, y} <- tail, do: %{x: x, y: y, char: "o", style: %{color: :green}}

    # Food
    food_cell = %{x: food_x, y: food_y, char: "X", style: %{color: :red}}

    canvas(
      height: model.height,
      width: model.width,
      cells: [food_cell, head_cell | tail_cells]
    )
  end

  defp move_snake(model) do
    # Tail used via model later
    [head | _tail] = model.chain
    next = next_link(head, model.direction)

    cond do
      not next_valid?(next, model) ->
        Raxol.Core.Runtime.Log.info(
          "Snake: Game Over - Collision detected at \#{inspect(next)}"
        )

        %{model | alive: false}

      next == model.food ->
        Raxol.Core.Runtime.Log.debug("Snake: Food eaten at \#{inspect(next)}")

        new_food =
          random_food(model.width - 1, model.height - 1, [next | model.chain])

        Raxol.Core.Runtime.Log.debug("Snake: New food at \#{inspect(new_food)}")
        # Grow snake by prepending head and keeping old tail
        %{model | chain: [next | model.chain], food: new_food}

      true ->
        # Move snake by prepending head and dropping last element of old chain
        %{model | chain: [next | Enum.drop(model.chain, -1)]}
    end
  end

  # Ensure new food doesn't spawn on the snake
  defp random_food(max_x, max_y, occupied) do
    food = {Enum.random(0..max_x), Enum.random(0..max_y)}

    if food in occupied do
      Raxol.Core.Runtime.Log.debug("Snake: Random food conflict, retrying...")
      random_food(max_x, max_y, occupied)
    else
      food
    end
  end

  # Map key names (atoms) to directions
  defp key_to_dir(:key_up), do: :up
  defp key_to_dir(:key_down), do: :down
  defp key_to_dir(:key_left), do: :left
  defp key_to_dir(:key_right), do: :right

  # Check bounds and self-collision
  defp next_valid?({x, y}, model)
       when x < 0 or y < 0 or x >= model.width or y >= model.height do
    false
  end

  defp next_valid?(next, %{chain: chain}), do: next not in chain

  # Prevent moving directly opposite
  defp next_dir(:up, :down), do: :up
  defp next_dir(:down, :up), do: :down
  defp next_dir(:left, :right), do: :left
  defp next_dir(:right, :left), do: :right
  defp next_dir(_current, new), do: new

  # Calculate next head position
  defp next_link({x, y}, :up), do: {x, y - 1}
  defp next_link({x, y}, :down), do: {x, y + 1}
  defp next_link({x, y}, :left), do: {x - 1, y}
  defp next_link({x, y}, :right), do: {x + 1, y}
end

Raxol.Core.Runtime.Log.info("Snake: Starting Raxol...")

{:ok, _pid} = Raxol.start_link(Snake, [])
Raxol.Core.Runtime.Log.info("Snake: Raxol started. Running...")
