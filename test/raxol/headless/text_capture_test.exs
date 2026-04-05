defmodule Raxol.Headless.TextCaptureTest do
  use ExUnit.Case, async: false

  alias Raxol.Headless.TextCapture
  alias Raxol.Terminal.ScreenBuffer

  describe "capture/1" do
    test "converts a buffer with written chars to text" do
      buffer =
        ScreenBuffer.new(10, 3)
        |> ScreenBuffer.write_char(0, 0, "H", nil)
        |> ScreenBuffer.write_char(1, 0, "i", nil)

      text = TextCapture.capture(buffer)
      assert String.starts_with?(text, "Hi")
    end

    test "trims trailing whitespace per line" do
      buffer =
        ScreenBuffer.new(20, 2)
        |> ScreenBuffer.write_char(0, 0, "A", nil)
        |> ScreenBuffer.write_char(0, 1, "B", nil)

      text = TextCapture.capture(buffer)
      lines = String.split(text, "\n")
      assert hd(lines) == "A"
      assert Enum.at(lines, 1) == "B"
    end

    test "trims trailing empty lines" do
      buffer =
        ScreenBuffer.new(10, 5)
        |> ScreenBuffer.write_char(0, 0, "X", nil)

      text = TextCapture.capture(buffer)
      refute String.ends_with?(text, "\n")
    end

    test "returns empty string for nil buffer" do
      assert TextCapture.capture(nil) == ""
    end

    test "returns empty string for blank buffer" do
      buffer = ScreenBuffer.new(5, 5)
      text = TextCapture.capture(buffer)
      assert text == ""
    end
  end
end
