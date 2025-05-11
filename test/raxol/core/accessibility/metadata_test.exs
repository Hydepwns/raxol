defmodule Raxol.Core.Accessibility.MetadataTest do
  use Raxol.DataCase, async: false
  import Mox

  alias Raxol.Core.Accessibility
  alias Raxol.Core.AccessibilityTestHelper, as: Helper

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Raxol.Core.I18n.init()
    :ok
  end

  describe "Element Metadata" do
    test "register_element_metadata/2 and get_element_metadata/1 registers and retrieves element metadata" do
      metadata = %{label: "Search Button", hint: "Click to search"}
      :ok = Accessibility.register_element_metadata("search_button", metadata)
      retrieved = Accessibility.get_element_metadata("search_button")
      assert retrieved == metadata
    end

    test "register_element_metadata/2 and get_element_metadata/1 returns nil for unknown elements" do
      assert Accessibility.get_element_metadata("unknown_button") == nil
    end

    test "register_element_metadata/2 overwrites existing metadata" do
      initial_metadata = %{label: "Old Label"}
      updated_metadata = %{label: "New Label"}

      :ok = Accessibility.register_element_metadata("test_button", initial_metadata)
      :ok = Accessibility.register_element_metadata("test_button", updated_metadata)

      retrieved = Accessibility.get_element_metadata("test_button")
      assert retrieved == updated_metadata
    end

    test "register_element_metadata/2 handles empty metadata" do
      :ok = Accessibility.register_element_metadata("empty_button", %{})
      retrieved = Accessibility.get_element_metadata("empty_button")
      assert retrieved == %{}
    end
  end

  describe "Component Styles" do
    test "get_component_style/1 returns empty map for unknown component type" do
      assert Accessibility.get_component_style(:unknown) == %{}
    end

    test "get_component_style/1 returns component style when available" do
      style = %{background: :blue, foreground: :white}
      Accessibility.register_component_style(:button, style)
      assert Accessibility.get_component_style(:button) == style
    end

    test "register_component_style/2 overwrites existing styles" do
      initial_style = %{background: :red}
      updated_style = %{background: :blue}

      Accessibility.register_component_style(:button, initial_style)
      Accessibility.register_component_style(:button, updated_style)

      assert Accessibility.get_component_style(:button) == updated_style
    end

    test "register_component_style/2 handles empty styles" do
      Accessibility.register_component_style(:button, %{})
      assert Accessibility.get_component_style(:button) == %{}
    end
  end
end
