# `Raxol.MCP.Test.Assertions`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/test/assertions.ex#L1)

ExUnit assertion macros for Raxol MCP tests.

All assertions are pipe-friendly -- they return the session on success,
so you can chain them:

    session
    |> click("btn")
    |> assert_tool_available("btn.click")
    |> assert_widget("status", fn w -> w[:content] == "done" end)

## Usage

    use ExUnit.Case
    import Raxol.MCP.Test
    import Raxol.MCP.Test.Assertions

# `assert_model`
*macro* 

Asserts the model matches a predicate function.

    assert_model(session, fn model -> model.count == 5 end)

# `assert_screenshot_contains`
*macro* 

Asserts the text screenshot contains the given string.

    assert_screenshot_contains(session, "Welcome")

# `assert_screenshot_matches`
*macro* 

Asserts the structured widget tree matches an expected shape.

The expected value is a list of maps with `:type` and optionally `:id`.
Uses subset matching -- each expected widget must appear somewhere
in the actual tree.

    assert_screenshot_matches(session, [
      %{type: :button, id: "submit"},
      %{type: :text_input, id: "name"}
    ])

# `assert_tool_available`
*macro* 

Asserts a tool with the given name is available in the MCP registry.

    assert_tool_available(session, "search_input.type_into")

# `assert_tool_count`
*macro* 

Asserts that exactly N tools are registered.

    assert_tool_count(session, 5)

# `assert_widget`
*macro* 

Asserts a widget with the given ID exists in the current view tree.

Optionally takes a predicate function to check widget properties.

    assert_widget(session, "search_input")
    assert_widget(session, "counter", fn w -> w[:content] == "5" end)

# `refute_tool_available`
*macro* 

Asserts a tool is NOT available in the MCP registry.

    refute_tool_available(session, "disabled_btn.click")

# `refute_widget`
*macro* 

Asserts a widget with the given ID does NOT exist in the view tree.

    refute_widget(session, "deleted_item")

---

*Consult [api-reference.md](api-reference.md) for complete listing*
