defmodule Raxol.PlaygroundTest do
  use ExUnit.Case, async: true

  alias Raxol.Playground

  setup do
    # Start the Playground with the registered name it expects
    {:ok, pid} = start_supervised({Playground, [name: Playground]})

    {:ok, playground: pid}
  end

  describe "catalog operations" do
    test "gets component catalog" do
      catalog = Playground.get_catalog()

      assert is_list(catalog)
      assert length(catalog) > 0

      # Check that each component has required fields
      for component <- catalog do
        assert Map.has_key?(component, :id)
        assert Map.has_key?(component, :name)
        assert Map.has_key?(component, :category)
        assert Map.has_key?(component, :description)
      end
    end

    test "catalog contains expected component categories" do
      catalog = Playground.get_catalog()

      categories = Enum.map(catalog, & &1.category) |> Enum.uniq()

      expected_categories = [
        :text,
        :input,
        :interactive,
        :layout,
        :data,
        :special
      ]

      for category <- expected_categories do
        assert category in categories, "Missing category: #{category}"
      end
    end
  end

  describe "component selection" do
    test "selects a valid component" do
      {:ok, preview} = Playground.select_component("button")

      assert is_binary(preview)
      # Default button label
      assert String.contains?(preview, "Click Me")
    end

    test "returns error for invalid component" do
      {:error, reason} = Playground.select_component("nonexistent")

      assert reason == "Component not found"
    end
  end

  describe "property updates" do
    test "updates component properties" do
      {:ok, _} = Playground.select_component("text")
      {:ok, preview} = Playground.update_props(%{content: "Updated text"})

      assert String.contains?(preview, "Updated text")
    end

    test "returns error when no component selected" do
      {:error, reason} = Playground.update_props(%{content: "test"})

      assert reason == "No component selected"
    end
  end

  describe "theme switching" do
    test "switches theme" do
      {:ok, _} = Playground.select_component("button")
      result = Playground.switch_theme(:dark)

      assert match?({:ok, _}, result) or result == :ok
    end
  end

  describe "code export" do
    test "exports component code" do
      {:ok, _} = Playground.select_component("button")

      {:ok, _} =
        Playground.update_props(%{label: "Test Button", variant: :primary})

      {:ok, code} = Playground.export_code()

      assert is_binary(code)
      assert String.contains?(code, "defmodule")
      assert String.contains?(code, "Button.render")
      assert String.contains?(code, "Test Button")
    end

    test "returns error when no component selected for export" do
      {:error, reason} = Playground.export_code()

      assert reason == "No component selected"
    end
  end

  describe "preview generation" do
    test "generates preview for selected component" do
      {:ok, _} = Playground.select_component("text")
      {:ok, preview} = Playground.get_preview()

      assert is_binary(preview)
    end

    test "refreshes preview" do
      {:ok, _} = Playground.select_component("progress_bar")
      {:ok, preview1} = Playground.get_preview()
      {:ok, preview2} = Playground.refresh_preview()

      # Both should be valid previews
      assert is_binary(preview1)
      assert is_binary(preview2)
    end
  end
end
