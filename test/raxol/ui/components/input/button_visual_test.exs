defmodule Raxol.UI.Components.Input.ButtonVisualTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.Button

  describe "visual tests for Button component" do
    test "renders default button" do
      # Create a simple button component
      button = Button.new(%{label: "Click Me"})

      # Test that the button has the expected structure
      assert button.label == "Click Me"
      assert button.id != nil
      assert button.disabled == false
      assert button.focused == false
      assert button.role == :default

      # Test that the button can be rendered (without going through the full visual pipeline)
      context = %{
        max_width: 80,
        max_height: 24,
        component_styles: %{
          button: %{
            active: "#3A8CC5",
            background: "#4A9CD5",
            foreground: "#FFFFFF",
            hover: "#5FB0E8"
          }
        }
      }

      rendered = Button.render(button, context)

      # Verify the rendered structure
      assert rendered.type == :button
      assert rendered.id == button.id
      assert rendered.attrs.label == "Click Me"
      assert rendered.attrs.width > 0
      assert rendered.attrs.height == 3
      assert rendered.attrs.disabled == false
      assert rendered.attrs.focused == false
      assert rendered.attrs.role == :default
      assert is_list(rendered.events)
    end

    test "renders focused button" do
      button = Button.new(%{label: "Focused", focused: true})

      context = %{
        max_width: 80,
        max_height: 24,
        component_styles: %{
          button: %{
            active: "#3A8CC5",
            background: "#4A9CD5",
            foreground: "#FFFFFF",
            hover: "#5FB0E8"
          }
        }
      }

      rendered = Button.render(button, context)

      # Verify focus indicators are added
      assert rendered.attrs.label == "> Focused <"
      assert rendered.attrs.focused == true
    end

    test "renders disabled button" do
      button = Button.new(%{label: "Disabled", disabled: true})

      context = %{
        max_width: 80,
        max_height: 24,
        component_styles: %{
          button: %{
            active: "#3A8CC5",
            background: "#4A9CD5",
            foreground: "#FFFFFF",
            hover: "#5FB0E8"
          }
        }
      }

      rendered = Button.render(button, context)

      # Verify disabled state
      assert rendered.attrs.disabled == true
    end

    test "renders button with custom role" do
      button = Button.new(%{label: "Primary", role: :primary})

      context = %{
        max_width: 80,
        max_height: 24,
        component_styles: %{
          button: %{
            active: "#3A8CC5",
            background: "#4A9CD5",
            foreground: "#FFFFFF",
            hover: "#5FB0E8"
          }
        }
      }

      rendered = Button.render(button, context)

      # Verify role is preserved
      assert rendered.attrs.role == :primary
    end
  end
end
