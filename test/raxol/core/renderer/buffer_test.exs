defmodule Raxol.Core.Renderer.BufferTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.Buffer

  describe "new/3" do
    test "creates a new buffer with default FPS" do
      buffer = Buffer.new(80, 24)
      assert buffer.fps == 60
      assert buffer.front_buffer.size == {80, 24}
      assert buffer.back_buffer.size == {80, 24}
      assert map_size(buffer.front_buffer.cells) == 0
      assert map_size(buffer.back_buffer.cells) == 0
    end

    test "creates a buffer with custom FPS" do
      buffer = Buffer.new(80, 24, 30)
      assert buffer.fps == 30
    end
  end

  describe "put_cell/4" do
    setup do
      {:ok, buffer: Buffer.new(10, 5)}
    end

    test "adds a cell to the back buffer", %{buffer: buffer} do
      buffer = Buffer.put_cell(buffer, {0, 0}, "a")
      assert get_in(buffer.back_buffer.cells, [{0, 0}]).char == "a"
      assert MapSet.member?(buffer.back_buffer.damage, {0, 0})
    end

    test "ignores cells outside buffer bounds", %{buffer: buffer} do
      buffer = Buffer.put_cell(buffer, {10, 5}, "x")
      assert map_size(buffer.back_buffer.cells) == 0
    end

    test "applies cell styles", %{buffer: buffer} do
      buffer =
        Buffer.put_cell(buffer, {0, 0}, "a",
          fg: :red,
          bg: :blue,
          style: [:bold]
        )

      cell = get_in(buffer.back_buffer.cells, [{0, 0}])
      assert cell.fg == :red
      assert cell.bg == :blue
      assert cell.style == [:bold]
    end
  end

  describe "clear/1" do
    test "clears all cells and marks entire buffer as damaged" do
      buffer =
        Buffer.new(2, 2)
        |> Buffer.put_cell({0, 0}, "a")
        |> Buffer.put_cell({1, 1}, "b")
        |> Buffer.clear()

      assert map_size(buffer.back_buffer.cells) == 0
      # 2x2 buffer
      assert MapSet.size(buffer.back_buffer.damage) == 4
    end
  end

  describe "swap_buffers/1" do
    setup do
      buffer =
        Buffer.new(2, 2, 60)
        |> Buffer.put_cell({0, 0}, "a")

      {:ok, buffer: buffer}
    end

    test "swaps buffers when enough time has passed", %{buffer: buffer} do
      # Simulate time passing
      buffer = %{buffer | last_frame_time: 0}
      {new_buffer, should_render} = Buffer.swap_buffers(buffer)

      assert should_render == true
      assert get_in(new_buffer.front_buffer.cells, [{0, 0}]).char == "a"
      assert map_size(new_buffer.back_buffer.cells) == 0
    end

    test "doesn't swap when not enough time has passed", %{buffer: buffer} do
      # Set last frame time to now
      now = System.monotonic_time(:millisecond)
      buffer = %{buffer | last_frame_time: now}
      {new_buffer, should_render} = Buffer.swap_buffers(buffer)

      assert should_render == false
      assert buffer == new_buffer
    end
  end

  describe "get_damage/1" do
    test "returns list of damaged cells" do
      buffer =
        Buffer.new(2, 2)
        |> Buffer.put_cell({0, 0}, "a")
        |> Buffer.put_cell({1, 1}, "b")

      # Swap buffers to move cells to front buffer
      buffer = %{buffer | last_frame_time: 0}
      {buffer, _} = Buffer.swap_buffers(buffer)

      damage = Buffer.get_damage(buffer)
      assert length(damage) == 2

      assert Enum.any?(damage, fn {{x, y}, cell} ->
               x == 0 and y == 0 and cell.char == "a"
             end)

      assert Enum.any?(damage, fn {{x, y}, cell} ->
               x == 1 and y == 1 and cell.char == "b"
             end)
    end
  end

  describe "resize/3" do
    test "preserves content when growing buffer" do
      buffer =
        Buffer.new(2, 2)
        |> Buffer.put_cell({0, 0}, "a")
        |> Buffer.resize(3, 3)

      assert get_in(buffer.back_buffer.cells, [{0, 0}]).char == "a"
      assert buffer.back_buffer.size == {3, 3}
    end

    test "marks cells as damaged when shrinking buffer" do
      buffer =
        Buffer.new(3, 3)
        |> Buffer.put_cell({2, 2}, "a")
        |> Buffer.resize(2, 2)

      assert map_size(buffer.back_buffer.cells) == 0
      assert MapSet.member?(buffer.back_buffer.damage, {2, 2})
    end
  end
end
