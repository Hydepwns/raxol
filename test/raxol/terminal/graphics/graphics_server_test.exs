defmodule Raxol.Terminal.Graphics.UnifiedGraphicsTest do
  use ExUnit.Case
  alias Raxol.Terminal.Graphics.UnifiedGraphics

  setup do
    {:ok, _pid} = UnifiedGraphics.start_link()
    :ok
  end

  describe "graphics creation" do
    test ~c"creates graphics context with default configuration" do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()

      assert {:ok, graphics_state} =
               UnifiedGraphics.get_graphics_state(graphics_id)

      assert graphics_state.config.width == 800
      assert graphics_state.config.height == 600
      assert graphics_state.config.format == :rgba
    end

    test ~c"creates graphics context with custom configuration" do
      config = %{
        width: 1024,
        height: 768,
        format: :rgb,
        compression: :zlib,
        quality: 85
      }

      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics(config)

      assert {:ok, graphics_state} =
               UnifiedGraphics.get_graphics_state(graphics_id)

      assert graphics_state.config.width == 1024
      assert graphics_state.config.height == 768
      assert graphics_state.config.format == :rgb
      assert graphics_state.config.compression == :zlib
      assert graphics_state.config.quality == 85
    end

    test ~c"first graphics context becomes active" do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      assert {:ok, active_id} = UnifiedGraphics.get_active_graphics()
      assert graphics_id == active_id
    end
  end

  describe "graphics management" do
    test ~c"gets list of all graphics contexts" do
      assert {:ok, graphics1} = UnifiedGraphics.create_graphics()
      assert {:ok, graphics2} = UnifiedGraphics.create_graphics()
      assert {:ok, graphics3} = UnifiedGraphics.create_graphics()

      graphics = UnifiedGraphics.get_graphics()
      assert length(graphics) == 3
      assert graphics1 in graphics
      assert graphics2 in graphics
      assert graphics3 in graphics
    end

    test ~c"sets active graphics context" do
      assert {:ok, _graphics1} = UnifiedGraphics.create_graphics()
      assert {:ok, graphics2} = UnifiedGraphics.create_graphics()

      assert :ok = UnifiedGraphics.set_active_graphics(graphics2)
      assert {:ok, active_id} = UnifiedGraphics.get_active_graphics()
      assert active_id == graphics2
    end

    test ~c"handles non-existent graphics context" do
      assert {:error, :graphics_not_found} =
               UnifiedGraphics.set_active_graphics(999)

      assert {:error, :graphics_not_found} =
               UnifiedGraphics.get_graphics_state(999)
    end
  end

  describe "graphics operations" do
    test ~c"renders graphics data" do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      data = <<0, 0, 0, 255, 255, 255, 255, 255>>
      assert :ok = UnifiedGraphics.render_graphics(graphics_id, data)

      assert {:ok, graphics_state} =
               UnifiedGraphics.get_graphics_state(graphics_id)

      assert graphics_state.buffer == data
    end

    test ~c"clears graphics context" do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      data = <<0, 0, 0, 255, 255, 255, 255, 255>>
      assert :ok = UnifiedGraphics.render_graphics(graphics_id, data)
      assert :ok = UnifiedGraphics.clear_graphics(graphics_id)

      assert {:ok, graphics_state} =
               UnifiedGraphics.get_graphics_state(graphics_id)

      assert graphics_state.buffer == <<>>
    end

    test ~c"closes graphics context" do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()
      assert :ok = UnifiedGraphics.close_graphics(graphics_id)

      assert {:error, :graphics_not_found} =
               UnifiedGraphics.get_graphics_state(graphics_id)
    end

    test ~c"closing active graphics updates active graphics" do
      assert {:ok, graphics1} = UnifiedGraphics.create_graphics()
      assert {:ok, graphics2} = UnifiedGraphics.create_graphics()

      assert :ok = UnifiedGraphics.set_active_graphics(graphics1)
      assert :ok = UnifiedGraphics.close_graphics(graphics1)
      assert {:ok, active_id} = UnifiedGraphics.get_active_graphics()
      assert active_id == graphics2
    end
  end

  describe "graphics configuration" do
    test ~c"updates graphics configuration" do
      assert {:ok, graphics_id} = UnifiedGraphics.create_graphics()

      new_config = %{
        width: 1280,
        height: 720,
        format: :grayscale
      }

      assert :ok =
               UnifiedGraphics.update_graphics_config(graphics_id, new_config)

      assert {:ok, graphics_state} =
               UnifiedGraphics.get_graphics_state(graphics_id)

      assert graphics_state.config.width == 1280
      assert graphics_state.config.height == 720
      assert graphics_state.config.format == :grayscale
    end

    test ~c"updates graphics manager configuration" do
      config = %{
        max_graphics: 5,
        default_width: 1024,
        default_height: 768,
        default_format: :rgb,
        default_compression: :lz4,
        default_quality: 95
      }

      assert :ok = UnifiedGraphics.update_config(config)
    end
  end

  describe "cleanup" do
    test ~c"cleans up all graphics contexts" do
      assert {:ok, _graphics1} = UnifiedGraphics.create_graphics()
      assert {:ok, _graphics2} = UnifiedGraphics.create_graphics()

      assert :ok = UnifiedGraphics.cleanup()
      assert UnifiedGraphics.get_graphics() == []

      assert {:error, :no_active_graphics} =
               UnifiedGraphics.get_active_graphics()
    end
  end

  describe "error handling" do
    test ~c"handles invalid graphics operations" do
      assert {:error, :graphics_not_found} =
               UnifiedGraphics.set_active_graphics(999)

      assert {:error, :graphics_not_found} =
               UnifiedGraphics.get_graphics_state(999)

      assert {:error, :graphics_not_found} =
               UnifiedGraphics.update_graphics_config(999, %{})

      assert {:error, :graphics_not_found} = UnifiedGraphics.close_graphics(999)

      assert {:error, :graphics_not_found} =
               UnifiedGraphics.render_graphics(999, <<>>)

      assert {:error, :graphics_not_found} = UnifiedGraphics.clear_graphics(999)
    end
  end
end
