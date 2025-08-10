defmodule Raxol.Playground.CatalogTest do
  use ExUnit.Case, async: true

  alias Raxol.Playground.Catalog

  describe "catalog operations" do
    test "loads components" do
      catalog = Catalog.load_components()

      assert is_list(catalog)
      # Should have a good selection of components
      assert length(catalog) > 10
    end

    test "each component has required fields" do
      catalog = Catalog.load_components()

      for component <- catalog do
        assert Map.has_key?(component, :id)
        assert Map.has_key?(component, :name)
        assert Map.has_key?(component, :category)
        assert Map.has_key?(component, :description)
        assert Map.has_key?(component, :module)
        assert Map.has_key?(component, :default_props)
        assert Map.has_key?(component, :prop_types)
        assert Map.has_key?(component, :examples)

        # Check data types
        assert is_binary(component.id)
        assert is_binary(component.name)
        assert is_atom(component.category)
        assert is_binary(component.description)
        assert is_atom(component.module)
        assert is_map(component.default_props)
        assert is_map(component.prop_types)
        assert is_list(component.examples)
      end
    end

    test "gets component by ID" do
      catalog = Catalog.load_components()

      button_component = Catalog.get_component(catalog, "button")

      assert button_component != nil
      assert button_component.id == "button"
      assert button_component.name == "Button"
      assert button_component.category == :interactive
    end

    test "returns nil for invalid component ID" do
      catalog = Catalog.load_components()

      result = Catalog.get_component(catalog, "nonexistent")

      assert result == nil
    end

    test "filters by category" do
      catalog = Catalog.load_components()

      text_components = Catalog.filter_by_category(catalog, :text)

      assert is_list(text_components)
      assert length(text_components) > 0

      for component <- text_components do
        assert component.category == :text
      end
    end

    test "gets all categories" do
      catalog = Catalog.load_components()

      categories = Catalog.get_categories(catalog)

      assert is_list(categories)
      assert :text in categories
      assert :input in categories
      assert :interactive in categories
      assert :layout in categories
      assert :data in categories
    end

    test "searches components" do
      catalog = Catalog.load_components()

      # Search by name
      button_results = Catalog.search(catalog, "button")
      assert length(button_results) > 0
      assert Enum.any?(button_results, &(&1.id == "button"))

      # Search by description
      text_results = Catalog.search(catalog, "text")
      assert length(text_results) > 0

      # Case insensitive search
      upper_results = Catalog.search(catalog, "BUTTON")
      assert length(upper_results) > 0
    end
  end

  describe "component examples" do
    test "each component has examples" do
      catalog = Catalog.load_components()

      for component <- catalog do
        assert is_list(component.examples)

        for example <- component.examples do
          assert Map.has_key?(example, :name)
          assert Map.has_key?(example, :props)
          assert is_binary(example.name)
          assert is_map(example.props)
        end
      end
    end

    test "button component has proper examples" do
      catalog = Catalog.load_components()
      button = Catalog.get_component(catalog, "button")

      assert length(button.examples) >= 3

      # Check for expected button variants
      example_names = Enum.map(button.examples, & &1.name)
      assert "Primary Button" in example_names
      assert "Secondary Button" in example_names
      assert "Danger Button" in example_names
    end
  end

  describe "component properties" do
    test "components have proper prop types" do
      catalog = Catalog.load_components()

      for component <- catalog do
        for {prop, type} <- component.prop_types do
          assert is_atom(prop)

          assert type in [
                   :string,
                   :integer,
                   :number,
                   :boolean,
                   :atom,
                   :list,
                   :map,
                   :any
                 ]
        end
      end
    end

    test "text input has expected properties" do
      catalog = Catalog.load_components()
      text_input = Catalog.get_component(catalog, "text_input")

      assert text_input.prop_types[:value] == :string
      assert text_input.prop_types[:placeholder] == :string
      assert text_input.prop_types[:width] == :integer
      assert text_input.prop_types[:disabled] == :boolean
    end
  end
end
