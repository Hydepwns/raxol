defmodule Raxol.Property.UIComponentTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Raxol.UI.Components.{Button, TextInput}
  alias Raxol.UI.Layout.{Flexbox, Grid}
  alias Raxol.UI.State.Store, as: Store

  describe "Button component properties" do
    property "button renders with any valid text" do
      check all(
              text <- string(:printable, min_length: 1, max_length: 50),
              enabled <- boolean(),
              max_runs: 500
            ) do
        button = Button.new(text, disabled: !enabled)

        # Should have valid structure
        assert button.label == text
        assert button.disabled == !enabled

        # Should render without error
        rendered = Button.render(button)
        assert %Raxol.Core.Renderer.Element{} = rendered
        assert rendered.content == text
      end
    end

    @tag :skip
    property "button click handling is deterministic" do
      check all(
              clicks <- integer(0..100),
              max_runs: 200
            ) do
        counter = :counters.new(1, [])

        button =
          Button.new(
            text: "Click me",
            on_click: fn -> :counters.add(counter, 1, 1) end
          )

        # Click multiple times
        for _ <- 1..clicks do
          Button.handle_click(button)
        end

        # Counter should match clicks
        assert :counters.get(counter, 1) == clicks
      end
    end

    @tag :skip
    property "button styling properties are preserved" do
      check all(
              color <- rgb_color_generator(),
              padding <- integer(0..20),
              margin <- integer(0..20),
              max_runs: 500
            ) do
        button =
          Button.new("Styled",
            style: %{
              color: color,
              padding: padding,
              margin: margin
            }
          )

        assert button.style.color == color
        assert button.style.padding == padding
        assert button.style.margin == margin
      end
    end
  end

  describe "TextInput component properties" do
    property "text input handles any valid input" do
      check all(
              initial <- string(:printable, max_length: 100),
              typed <- string(:printable, max_length: 50),
              max_runs: 500
            ) do
        input = TextInput.new(value: initial)

        # Type additional text
        updated = TextInput.handle_input(input, typed)

        # Should contain both initial and typed
        assert String.contains?(updated.value, initial)
        assert String.contains?(updated.value, typed)
      end
    end

    property "text input respects max_length constraint" do
      check all(
              max_length <- integer(1..100),
              text <-
                string(:printable, min_length: max_length + 1, max_length: 200),
              max_runs: 500
            ) do
        input = TextInput.new(value: "", max_length: max_length)

        # Try to input text longer than max
        updated = TextInput.handle_input(input, text)

        # Should be truncated to max_length
        assert String.length(updated.value) <= max_length
      end
    end

    property "text input validation is consistent" do
      check all(
              text <- string(:alphanumeric, max_length: 50),
              max_runs: 500
            ) do
        # Numeric validator
        validator = fn value -> Regex.match?(~r/^\d*$/, value) end

        input = TextInput.new(value: "", validation: validator)
        updated = TextInput.handle_input(input, text)

        # Should only contain digits or be empty
        assert Regex.match?(~r/^[\d]*$/, updated.value)
      end
    end

    @tag :skip
    property "cursor position stays within bounds" do
      check all(
              text <- string(:printable, min_length: 1, max_length: 100),
              cursor_moves <-
                list_of(cursor_movement_generator(), max_length: 50),
              max_runs: 500
            ) do
        input = TextInput.new(value: text)

        final =
          Enum.reduce(cursor_moves, input, fn move, acc ->
            TextInput.handle_cursor(acc, move)
          end)

        # Cursor should be within text bounds
        assert final.cursor_position >= 0
        assert final.cursor_position <= String.length(text)
      end
    end
  end

  describe "Flexbox layout properties" do
    property "flexbox maintains child order" do
      check all(
              children <-
                list_of(integer(1..100), min_length: 1, max_length: 20),
              max_runs: 500
            ) do
        layout =
          Flexbox.new(children: Enum.map(children, &create_test_component/1))

        # Children should maintain order
        rendered_ids = layout.children |> Enum.map(& &1.id)
        assert rendered_ids == children
      end
    end

    property "flexbox respects size constraints" do
      check all(
              width <- integer(10..1000),
              height <- integer(10..1000),
              children_count <- integer(1..10),
              max_runs: 500
            ) do
        children = for i <- 1..children_count, do: create_test_component(i)

        layout =
          Flexbox.new(
            width: width,
            height: height,
            children: children
          )

        {:ok, rendered} = Flexbox.render(layout)

        # Total size should not exceed container
        assert rendered.layout.width <= width
        assert rendered.layout.height <= height
      end
    end

    @tag :skip
    property "flex properties distribute space correctly" do
      check all(
              flex_values <-
                list_of(integer(0..10), min_length: 2, max_length: 5),
              container_size <- integer(100..1000),
              max_runs: 500
            ) do
        children =
          Enum.map(flex_values, fn flex ->
            %{id: flex, flex: flex}
          end)

        layout =
          Flexbox.new(
            width: container_size,
            direction: :row,
            children: children
          )

        rendered = Flexbox.calculate_layout(layout)

        # Total allocated space should equal container size
        total = Enum.sum(Enum.map(rendered.children, & &1.width))
        assert_in_delta(total, container_size, 1.0)
      end
    end
  end

  describe "Grid layout properties" do
    property "grid places items in correct cells" do
      check all(
              rows <- integer(1..10),
              cols <- integer(1..10),
              items <-
                list_of(grid_item_generator(rows, cols),
                  max_length: rows * cols
                ),
              max_runs: 500
            ) do
        grid =
          Grid.new(
            rows: rows,
            columns: cols,
            children: items
          )

        {:ok, rendered} = Grid.render(grid)

        # Each item should be in valid cell
        Enum.each(rendered.children, fn child ->
          assert child.row in 1..rows
          assert child.column in 1..cols
        end)
      end
    end

    property "grid respects gap spacing" do
      check all(
              gap <- integer(0..20),
              rows <- integer(2..5),
              cols <- integer(2..5),
              max_runs: 500
            ) do
        grid =
          Grid.new(
            rows: rows,
            columns: cols,
            gap: gap
          )

        {:ok, layout} = Grid.calculate_spacing(grid)

        # Total gaps should be correct
        horizontal_gaps = (cols - 1) * gap
        vertical_gaps = (rows - 1) * gap

        assert layout.total_gap_width == horizontal_gaps
        assert layout.total_gap_height == vertical_gaps
      end
    end
  end

  describe "State Store properties" do
    @tag :skip
    property "store updates are atomic" do
      check all(
              initial <- map_of(atom(:alphanumeric), integer()),
              updates <- list_of(store_update_generator(), max_length: 100),
              max_runs: 200
            ) do
        # Use unique store name to avoid conflicts
        store_name =
          String.to_atom("store_#{System.unique_integer([:positive])}")

        {:ok, store} =
          Store.start_link(name: store_name, initial_state: initial)

        # Apply all updates
        Enum.each(updates, fn {key, value} ->
          Store.update(store, key, value)
        end)

        # Final state should reflect all updates
        final_state = Store.get_state(store)

        Enum.each(updates, fn {key, value} ->
          assert Map.get(final_state, key) == value
        end)
      end
    end

    @tag :skip
    property "store subscriptions receive all updates" do
      check all(
              updates <-
                list_of(store_update_generator(), min_length: 1, max_length: 50),
              max_runs: 200
            ) do
        # Use unique store name to avoid conflicts
        store_name =
          String.to_atom("store_#{System.unique_integer([:positive])}")

        {:ok, store} = Store.start_link(name: store_name)
        received = :ets.new(:received, [:set, :public])

        # Subscribe to updates
        Store.subscribe(store, fn state ->
          :ets.insert(received, {:update, state})
        end)

        # Apply updates
        Enum.each(updates, fn {key, value} ->
          Store.update(store, key, value)
        end)

        # Should have received all updates
        all_received = :ets.tab2list(received)
        assert length(all_received) == length(updates)
      end
    end

    @tag :skip
    property "store handles concurrent updates safely" do
      check all(
              update_count <- integer(10..100),
              max_runs: 100
            ) do
        # Use unique store name to avoid conflicts
        store_name =
          String.to_atom("store_#{System.unique_integer([:positive])}")

        {:ok, store} =
          Store.start_link(name: store_name, initial_state: %{counter: 0})

        # Spawn concurrent updaters
        tasks =
          for _i <- 1..update_count do
            Task.async(fn ->
              Store.update(store, :counter, fn count -> count + 1 end)
            end)
          end

        # Wait for all updates
        Task.await_many(tasks)

        # Counter should equal update count
        final_state = Store.get_state(store)
        assert final_state.counter == update_count
      end
    end
  end

  describe "Component composition properties" do
    property "nested components maintain hierarchy" do
      check all(
              depth <- integer(1..5),
              breadth <- integer(1..5),
              max_runs: 200
            ) do
        root = create_nested_component(depth, breadth)

        # Verify depth
        actual_depth = measure_depth(root)
        assert actual_depth == depth

        # Verify total nodes
        total_nodes = count_nodes(root)
        expected = calculate_tree_size(depth, breadth)
        assert total_nodes == expected
      end
    end

    property "component lifecycle hooks execute in order" do
      check all(
              hook_count <- integer(1..10),
              max_runs: 200
            ) do
        order = :ets.new(:order, [:ordered_set, :public])

        hooks =
          for i <- 1..hook_count do
            fn -> :ets.insert(order, {i, :executed}) end
          end

        component = %{
          mount: Enum.take(hooks, div(hook_count, 3)),
          update: Enum.slice(hooks, div(hook_count, 3), div(hook_count, 3)),
          unmount: Enum.drop(hooks, 2 * div(hook_count, 3))
        }

        # Execute lifecycle
        execute_lifecycle(component)

        # Verify order
        executed = :ets.tab2list(order) |> Enum.map(&elem(&1, 0))
        assert executed == Enum.sort(executed)
      end
    end
  end

  # Generator helpers

  defp rgb_color_generator do
    gen all(
          r <- integer(0..255),
          g <- integer(0..255),
          b <- integer(0..255)
        ) do
      %{r: r, g: g, b: b}
    end
  end

  defp cursor_movement_generator do
    member_of([:left, :right, :home, :end, :delete, :backspace])
  end

  defp grid_item_generator(max_row, max_col) do
    gen all(
          row <- integer(1..max_row),
          col <- integer(1..max_col)
        ) do
      %{row: row, column: col, content: "Item"}
    end
  end

  defp store_update_generator do
    gen all(
          key <- atom(:alphanumeric),
          value <- one_of([integer(), string(:alphanumeric), boolean()])
        ) do
      {key, value}
    end
  end

  # Helper functions

  defp create_test_component(id) do
    %{id: id, type: :test_component}
  end

  defp create_nested_component(1, _breadth), do: %{children: []}

  defp create_nested_component(depth, breadth) do
    children =
      for _ <- 1..breadth do
        create_nested_component(depth - 1, breadth)
      end

    %{children: children}
  end

  defp measure_depth(%{children: []}), do: 1

  defp measure_depth(%{children: children}) do
    1 + Enum.max(Enum.map(children, &measure_depth/1))
  end

  defp count_nodes(%{children: []}), do: 1

  defp count_nodes(%{children: children}) do
    1 + Enum.sum(Enum.map(children, &count_nodes/1))
  end

  defp calculate_tree_size(depth, breadth) do
    # Geometric series: (breadth^depth - 1) / (breadth - 1)
    if breadth == 1 do
      depth
    else
      # Use proper integer arithmetic - convert float result to integer
      numerator = round(:math.pow(breadth, depth)) - 1
      div(numerator, breadth - 1)
    end
  end

  defp execute_lifecycle(component) do
    Enum.each(component.mount || [], & &1.())
    Enum.each(component.update || [], & &1.())
    Enum.each(component.unmount || [], & &1.())
  end
end
