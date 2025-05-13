defmodule Raxol.UI.Components.Input.TextFieldTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Input.TextField
  alias Raxol.Core.Renderer.Element

  defp create_state(props \\ %{}) do
    {:ok, state} = TextField.init(props)
    state
  end

  describe "theming, style, and lifecycle" do
    test "applies style and theme props to text field" do
      theme = %{text_field: %{border: "2px solid #00ff00", color: "#123456"}}
      style = %{border_radius: "8px", color: "#654321"}
      state = create_state(%{value: "Styled", theme: theme, style: style})
      rendered = TextField.render(state, %{theme: theme})
      assert %Element{attributes: %{style: merged}} = rendered
      IO.inspect(merged.border, label: "merged.border")
      assert merged.border.style in [:solid, :none, "solid", "none"]
      assert merged.color == "#654321"
    end

    test "mount/1 and unmount/1 return state unchanged" do
      state = create_state(%{value: "foo"})
      assert TextField.mount(state) == state
      assert TextField.unmount(state) == state
    end
  end

  describe "render/2" do
    test "renders value and placeholder" do
      state = create_state(%{value: "Hello"})
      rendered = TextField.render(state, %{theme: {}})
      IO.inspect(rendered.children, label: "children for value")
      [text_elem] = rendered.children
      assert text_elem.tag == :text
      assert text_elem.content == "Hello"

      state2 = create_state(%{value: "", placeholder: "Type here"})
      rendered2 = TextField.render(state2, %{theme: {}})
      IO.inspect(rendered2.children, label: "children for placeholder")
      [text_elem] = rendered2.children
      assert text_elem.tag == :text
      assert text_elem.content == "Type here"
      assert text_elem.attributes[:color] == "#888"
      assert :italic in (text_elem.attributes[:text_decoration] || [])
    end

    test "renders masked value if secret is true" do
      state = create_state(%{value: "secret", secret: true})
      rendered = TextField.render(state, %{theme: {}})
      IO.inspect(rendered.children, label: "children for masked value")
      [text_elem] = rendered.children
      assert text_elem.tag == :text
      assert text_elem.content == "******"
    end
  end
end
