defmodule Raxol.Terminal.Graphics.ManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Graphics.Manager

  setup do
    manager = Manager.new()
    %{manager: manager}
  end

  describe "new/1" do
    test "creates a new graphics manager with default state", %{manager: manager} do
      assert map_size(manager.images) == 0
      assert map_size(manager.sixel_cache) == 0
      assert length(manager.pipeline) == 4
      assert manager.metrics.images_rendered == 0
      assert manager.metrics.sixels_processed == 0
      assert manager.metrics.cache_hits == 0
      assert manager.metrics.cache_misses == 0
      assert manager.metrics.pipeline_optimizations == 0
    end
  end

  describe "render_image/3" do
    test "renders a valid image", %{manager: manager} do
      image = %{
        width: 100,
        height: 100,
        pixels: generate_test_pixels(100, 100),
        format: :png,
        metadata: %{}
      }

      opts = %{
        scale: 1.0,
        dither: false,
        optimize: true,
        cache: true
      }

      assert {:ok, sixel_data, updated_manager} = Manager.render_image(manager, image, opts)
      assert sixel_data.width == 100
      assert sixel_data.height == 100
      assert is_list(sixel_data.colors)
      assert is_binary(sixel_data.data)
      assert updated_manager.metrics.images_rendered == 1
      assert updated_manager.metrics.cache_misses == 1
    end

    test "returns error for invalid image", %{manager: manager} do
      invalid_image = %{
        width: 100,
        height: 100
      }

      opts = %{
        scale: 1.0,
        dither: false,
        optimize: true,
        cache: true
      }

      assert {:error, :invalid_image} = Manager.render_image(manager, invalid_image, opts)
    end

    test "returns error for invalid options", %{manager: manager} do
      image = %{
        width: 100,
        height: 100,
        pixels: generate_test_pixels(100, 100),
        format: :png,
        metadata: %{}
      }

      invalid_opts = %{
        scale: 1.0
      }

      assert {:error, :invalid_opts} = Manager.render_image(manager, image, invalid_opts)
    end

    test "uses cached result for same image and options", %{manager: manager} do
      image = %{
        width: 100,
        height: 100,
        pixels: generate_test_pixels(100, 100),
        format: :png,
        metadata: %{}
      }

      opts = %{
        scale: 1.0,
        dither: false,
        optimize: true,
        cache: true
      }

      # First render
      {:ok, sixel_data, manager} = Manager.render_image(manager, image, opts)
      assert manager.metrics.cache_misses == 1

      # Second render with same image and options
      {:ok, cached_data, updated_manager} = Manager.render_image(manager, image, opts)
      assert cached_data == sixel_data
      assert updated_manager.metrics.cache_hits == 1
    end
  end

  describe "process_sixel/2" do
    test "processes valid sixel data", %{manager: manager} do
      sixel_data = %{
        width: 100,
        height: 100,
        colors: [
          %{r: 255, g: 0, b: 0, a: 1.0},
          %{r: 0, g: 255, b: 0, a: 1.0},
          %{r: 0, g: 0, b: 255, a: 1.0}
        ],
        data: <<0, 1, 2>>
      }

      assert {:ok, image, updated_manager} = Manager.process_sixel(manager, sixel_data)
      assert image.width == 100
      assert image.height == 100
      assert image.format == :sixel
      assert updated_manager.metrics.sixels_processed == 1
    end

    test "returns error for invalid sixel data", %{manager: manager} do
      invalid_sixel_data = %{
        width: 100,
        height: 100
      }

      assert {:error, :invalid_sixel_data} = Manager.process_sixel(manager, invalid_sixel_data)
    end
  end

  describe "optimize_pipeline/1" do
    test "optimizes the graphics pipeline", %{manager: manager} do
      assert {:ok, updated_manager} = Manager.optimize_pipeline(manager)
      assert length(updated_manager.pipeline) == 4
      assert updated_manager.metrics.pipeline_optimizations == 1
    end
  end

  describe "get_metrics/1" do
    test "returns current metrics", %{manager: manager} do
      metrics = Manager.get_metrics(manager)
      assert metrics.images_rendered == 0
      assert metrics.sixels_processed == 0
      assert metrics.cache_hits == 0
      assert metrics.cache_misses == 0
      assert metrics.pipeline_optimizations == 0
    end
  end

  # Helper functions

  defp generate_test_pixels(width, height) do
    for y <- 0..(height - 1) do
      for x <- 0..(width - 1) do
        %{
          r: rem(x * y, 256),
          g: rem(x + y, 256),
          b: rem(x - y, 256),
          a: 1.0
        }
      end
    end
  end
end
