defmodule Raxol.Core.Terminal.OSC.Handlers.ColorPaletteTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Terminal.OSC.Handlers.ColorPalette
  alias Raxol.Core.Terminal.State

  describe "handle/2" do
    test "sets color with rgb: format" do
      state = %State{palette: %{}}
      result = ColorPalette.handle("4;1;rgb:255/0/0", state)
      assert {:ok, new_state} = result
      assert new_state.palette[1] == {255, 0, 0}
    end

    test "sets color with #RRGGBB format" do
      state = %State{palette: %{}}
      result = ColorPalette.handle("4;1;#FF0000", state)
      assert {:ok, new_state} = result
      assert new_state.palette[1] == {255, 0, 0}
    end

    test "sets color with #RGB format" do
      state = %State{palette: %{}}
      result = ColorPalette.handle("4;1;#F00", state)
      assert {:ok, new_state} = result
      assert new_state.palette[1] == {255, 0, 0}
    end

    test "sets color with rgb(r,g,b) format" do
      state = %State{palette: %{}}
      result = ColorPalette.handle("4;1;rgb(255,0,0)", state)
      assert {:ok, new_state} = result
      assert new_state.palette[1] == {255, 0, 0}
    end

    test "sets color with rgb(r%,g%,b%) format" do
      state = %State{palette: %{}}
      result = ColorPalette.handle("4;1;rgb(100%,0%,0%)", state)
      assert {:ok, new_state} = result
      assert new_state.palette[1] == {255, 0, 0}
    end

    test "queries existing color" do
      state = %State{palette: %{1 => {255, 0, 0}}}
      result = ColorPalette.handle("4;1;?", state)
      assert {:ok, ^state, response} = result
      assert response == "4;1;rgb:FFFF/0000/0000"
    end

    test "returns error for invalid color index" do
      state = %State{palette: %{}}
      result = ColorPalette.handle("4;256;rgb:255/0/0", state)
      assert {:error, {:invalid_index, "256"}} = result
    end

    test "returns error for invalid color format" do
      state = %State{palette: %{}}
      result = ColorPalette.handle("4;1;invalid", state)
      assert {:error, {:invalid_color, "unsupported color format"}} = result
    end

    test "returns error for malformed command" do
      state = %State{palette: %{}}
      result = ColorPalette.handle("4;invalid", state)
      assert {:error, :invalid_format} = result
    end

    test "handles query for non-existent color" do
      state = %State{palette: %{}}
      result = ColorPalette.handle("4;1;?", state)
      assert {:error, {:invalid_index, 1}} = result
    end
  end
end
