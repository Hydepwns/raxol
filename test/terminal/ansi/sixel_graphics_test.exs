defmodule Raxol.Terminal.ANSI.SixelGraphicsTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.SixelGraphics

  describe "new/0" do
    test "creates a new Sixel state with default values" do
      state = SixelGraphics.new()
      
      assert state.current_color == 0
      assert state.repeat_count == 1
      assert state.position == {0, 0}
      assert state.attributes.width == :normal
      assert state.attributes.height == :normal
      assert state.attributes.size == :normal
      assert state.image_data == ""
      assert map_size(state.palette) == 256
    end
  end

  describe "initialize_palette/0" do
    test "initializes the default Sixel color palette" do
      palette = SixelGraphics.initialize_palette()
      
      # Check standard 16 colors
      assert palette[0] == {0, 0, 0}       # Black
      assert palette[1] == {205, 0, 0}     # Red
      assert palette[2] == {0, 205, 0}     # Green
      assert palette[3] == {205, 205, 0}   # Yellow
      assert palette[4] == {0, 0, 238}     # Blue
      assert palette[5] == {205, 0, 205}   # Magenta
      assert palette[6] == {0, 205, 205}   # Cyan
      assert palette[7] == {229, 229, 229} # White
      assert palette[8] == {127, 127, 127} # Bright Black
      assert palette[9] == {255, 0, 0}     # Bright Red
      assert palette[10] == {0, 255, 0}    # Bright Green
      assert palette[11] == {255, 255, 0}  # Bright Yellow
      assert palette[12] == {92, 92, 255}  # Bright Blue
      assert palette[13] == {255, 0, 255}  # Bright Magenta
      assert palette[14] == {0, 255, 255}  # Bright Cyan
      assert palette[15] == {255, 255, 255} # Bright White

      # Check RGB cube colors
      assert palette[16] == {0, 0, 0}      # First RGB cube color
      assert palette[231] == {255, 255, 255} # Last RGB cube color

      # Check grayscale colors
      assert palette[232] == {8, 8, 8}     # First grayscale color
      assert palette[255] == {238, 238, 238} # Last grayscale color
    end
  end

  describe "process_sequence/2" do
    test "handles color setting" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[1q")
      
      assert new_state.current_color == 1
      assert response == ""
    end

    test "handles position setting" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[10;5p")
      
      assert new_state.position == {5, 10}
      assert response == ""
    end

    test "handles repeat count setting" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[5r")
      
      assert new_state.repeat_count == 5
      assert response == ""
    end

    test "handles attribute setting" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[1a")
      
      assert new_state.attributes.width == :double_width
      assert response == ""
    end

    test "handles background color setting" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[1b")
      
      assert new_state == state
      assert response == ""
    end

    test "handles foreground color setting" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[2c")
      
      assert new_state.current_color == 2
      assert response == ""
    end

    test "handles dimension setting" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[100;50d")
      
      assert new_state == state
      assert response == ""
    end

    test "handles scale setting" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[2s")
      
      assert new_state == state
      assert response == ""
    end

    test "handles transparency setting" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[128t")
      
      assert new_state == state
      assert response == ""
    end

    test "handles invalid sequence" do
      state = SixelGraphics.new()
      {new_state, response} = SixelGraphics.process_sequence(state, "\e[invalid")
      
      assert new_state == state
      assert response == ""
    end
  end

  describe "parse_sequence/1" do
    test "parses color setting sequence" do
      assert {:ok, :set_color, [1]} = SixelGraphics.parse_sequence("1q")
    end

    test "parses position setting sequence" do
      assert {:ok, :set_position, [10, 5]} = SixelGraphics.parse_sequence("10;5p")
    end

    test "parses repeat count sequence" do
      assert {:ok, :set_repeat, [5]} = SixelGraphics.parse_sequence("5r")
    end

    test "parses attribute setting sequence" do
      assert {:ok, :set_attribute, [1]} = SixelGraphics.parse_sequence("1a")
    end

    test "parses background color sequence" do
      assert {:ok, :set_background, [1]} = SixelGraphics.parse_sequence("1b")
    end

    test "parses foreground color sequence" do
      assert {:ok, :set_foreground, [2]} = SixelGraphics.parse_sequence("2c")
    end

    test "parses dimension setting sequence" do
      assert {:ok, :set_dimension, [100, 50]} = SixelGraphics.parse_sequence("100;50d")
    end

    test "parses scale setting sequence" do
      assert {:ok, :set_scale, [2]} = SixelGraphics.parse_sequence("2s")
    end

    test "parses transparency setting sequence" do
      assert {:ok, :set_transparency, [128]} = SixelGraphics.parse_sequence("128t")
    end

    test "parses invalid sequence" do
      assert :error = SixelGraphics.parse_sequence("invalid")
    end
  end

  describe "update_attributes/2" do
    test "updates width attribute" do
      attrs = %{width: :normal, height: :normal, size: :normal}
      new_attrs = SixelGraphics.update_attributes(attrs, 1)
      
      assert new_attrs.width == :double_width
      assert new_attrs.height == :normal
      assert new_attrs.size == :normal
    end

    test "updates height attribute" do
      attrs = %{width: :normal, height: :normal, size: :normal}
      new_attrs = SixelGraphics.update_attributes(attrs, 2)
      
      assert new_attrs.width == :normal
      assert new_attrs.height == :double_height
      assert new_attrs.size == :normal
    end

    test "updates size attribute" do
      attrs = %{width: :normal, height: :normal, size: :normal}
      new_attrs = SixelGraphics.update_attributes(attrs, 3)
      
      assert new_attrs.width == :double_width
      assert new_attrs.height == :double_height
      assert new_attrs.size == :double_size
    end

    test "handles invalid attribute code" do
      attrs = %{width: :normal, height: :normal, size: :normal}
      new_attrs = SixelGraphics.update_attributes(attrs, 4)
      
      assert new_attrs == attrs
    end
  end
end 