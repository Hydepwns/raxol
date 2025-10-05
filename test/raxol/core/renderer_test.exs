defmodule Raxol.Core.RendererTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.{Buffer, Renderer}

  describe "render_to_string/1" do
    test "renders empty buffer" do
      buffer = Buffer.create_blank_buffer(10, 3)
      output = Renderer.render_to_string(buffer)
      assert is_binary(output)
    end

    test "renders buffer with content" do
      buffer = Buffer.create_blank_buffer(10, 3)
      buffer = Buffer.write_at(buffer, 0, 0, "Hello")
      output = Renderer.render_to_string(buffer)
      assert String.contains?(output, "Hello")
    end

    test "completes within performance target" do
      buffer = Buffer.create_blank_buffer(80, 24)

      {time_us, _result} =
        :timer.tc(fn ->
          Renderer.render_to_string(buffer)
        end)

      # Should complete in < 1ms (1000 microseconds)
      assert time_us < 1000
    end
  end

  describe "render_diff/2" do
    test "returns empty list for identical buffers" do
      buffer1 = Buffer.create_blank_buffer(10, 3)
      buffer2 = Buffer.create_blank_buffer(10, 3)

      diff = Renderer.render_diff(buffer1, buffer2)
      assert diff == []
    end

    test "detects single cell change" do
      buffer1 = Buffer.create_blank_buffer(10, 3)
      buffer2 = Buffer.write_at(buffer1, 5, 2, "X")

      diff = Renderer.render_diff(buffer1, buffer2)
      assert length(diff) == 1

      change = List.first(diff)
      assert change.x == 5
      assert change.y == 2
    end

    test "detects multiple changes" do
      buffer1 = Buffer.create_blank_buffer(10, 3)

      buffer2 =
        buffer1
        |> Buffer.write_at(0, 0, "Hello")
        |> Buffer.write_at(0, 1, "World")

      diff = Renderer.render_diff(buffer1, buffer2)
      assert length(diff) > 0
    end

    test "completes within performance target" do
      buffer1 = Buffer.create_blank_buffer(80, 24)
      buffer2 = Buffer.write_at(buffer1, 40, 12, "Test")

      {time_us, _result} =
        :timer.tc(fn ->
          Renderer.render_diff(buffer1, buffer2)
        end)

      # Should complete in < 2ms (2000 microseconds)
      assert time_us < 2000
    end

    test "detects style changes without char changes" do
      buffer1 = Buffer.create_blank_buffer(10, 3)
      buffer1 = Buffer.write_at(buffer1, 0, 0, "Test")

      buffer2 = Buffer.set_cell(buffer1, 0, 0, "T", %{bold: true})

      diff = Renderer.render_diff(buffer1, buffer2)
      assert length(diff) == 1
      assert List.first(diff).style == %{bold: true}
    end

    test "handles dimension changes" do
      buffer1 = Buffer.create_blank_buffer(10, 3)
      buffer2 = Buffer.create_blank_buffer(20, 5)

      diff = Renderer.render_diff(buffer1, buffer2)
      # Should return all cells when dimensions change
      assert length(diff) == 20 * 5
    end

    test "preserves cell order in diff" do
      buffer1 = Buffer.create_blank_buffer(10, 3)

      buffer2 =
        buffer1
        |> Buffer.write_at(2, 1, "A")
        |> Buffer.write_at(5, 1, "B")
        |> Buffer.write_at(8, 1, "C")

      diff = Renderer.render_diff(buffer1, buffer2)

      # Changes should be in order (top to bottom, left to right)
      positions = Enum.map(diff, fn change -> {change.x, change.y} end)
      assert positions == [{2, 1}, {5, 1}, {8, 1}]
    end
  end
end
