defmodule Raxol.MCP.Test.Assertions do
  @moduledoc """
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
  """

  alias Raxol.MCP.Test

  @doc """
  Asserts a widget with the given ID exists in the current view tree.

  Optionally takes a predicate function to check widget properties.

      assert_widget(session, "search_input")
      assert_widget(session, "counter", fn w -> w[:content] == "5" end)
  """
  defmacro assert_widget(session, widget_id, predicate \\ nil) do
    predicate_check =
      if predicate do
        quote do
          predicate_fn = unquote(predicate)

          ExUnit.Assertions.assert(
            predicate_fn.(widget),
            "Widget '#{widget_id}' did not match predicate. Widget: #{inspect(widget)}"
          )
        end
      end

    quote do
      session = unquote(session)
      widget_id = unquote(widget_id)
      widget = Test.get_widget(session, widget_id)

      ExUnit.Assertions.assert(
        widget != nil,
        "Expected widget '#{widget_id}' to exist in view tree, but it was not found. " <>
          "Widgets: #{inspect(Test.get_structured_widgets(session) |> collect_ids())}"
      )

      unquote(predicate_check)

      session
    end
  end

  @doc """
  Asserts a widget with the given ID does NOT exist in the view tree.

      refute_widget(session, "deleted_item")
  """
  defmacro refute_widget(session, widget_id) do
    quote do
      session = unquote(session)
      widget_id = unquote(widget_id)
      widget = Test.get_widget(session, widget_id)

      ExUnit.Assertions.refute(
        widget != nil,
        "Expected widget '#{widget_id}' not to exist, but found: #{inspect(widget)}"
      )

      session
    end
  end

  @doc """
  Asserts a tool with the given name is available in the MCP registry.

      assert_tool_available(session, "search_input.type_into")
  """
  defmacro assert_tool_available(session, tool_name) do
    quote do
      session = unquote(session)
      tool_name = unquote(tool_name)
      tools = Test.get_tools(session)
      names = Enum.map(tools, & &1[:name])

      ExUnit.Assertions.assert(
        tool_name in names,
        "Expected tool '#{tool_name}' to be available. " <>
          "Registered tools: #{inspect(names)}"
      )

      session
    end
  end

  @doc """
  Asserts a tool is NOT available in the MCP registry.

      refute_tool_available(session, "disabled_btn.click")
  """
  defmacro refute_tool_available(session, tool_name) do
    quote do
      session = unquote(session)
      tool_name = unquote(tool_name)
      tools = Test.get_tools(session)
      names = Enum.map(tools, & &1[:name])

      ExUnit.Assertions.refute(
        tool_name in names,
        "Expected tool '#{tool_name}' not to be available, but it was found."
      )

      session
    end
  end

  @doc """
  Asserts the model matches a predicate function.

      assert_model(session, fn model -> model.count == 5 end)
  """
  defmacro assert_model(session, predicate) do
    quote do
      session = unquote(session)
      model = Test.get_model(session)

      ExUnit.Assertions.assert(
        unquote(predicate).(model),
        "Model did not match predicate. Model: #{inspect(model)}"
      )

      session
    end
  end

  @doc """
  Asserts the text screenshot contains the given string.

      assert_screenshot_contains(session, "Welcome")
  """
  defmacro assert_screenshot_contains(session, text) do
    quote do
      session = unquote(session)
      screenshot = Test.screenshot(session)

      ExUnit.Assertions.assert(
        String.contains?(screenshot, unquote(text)),
        "Expected screenshot to contain #{inspect(unquote(text))}.\n" <>
          "Screenshot:\n#{screenshot}"
      )

      session
    end
  end

  @doc """
  Asserts the structured widget tree matches an expected shape.

  The expected value is a list of maps with `:type` and optionally `:id`.
  Uses subset matching -- each expected widget must appear somewhere
  in the actual tree.

      assert_screenshot_matches(session, [
        %{type: :button, id: "submit"},
        %{type: :text_input, id: "name"}
      ])
  """
  defmacro assert_screenshot_matches(session, expected) do
    quote do
      session = unquote(session)
      actual = Test.get_structured_widgets(session)
      expected = unquote(expected)

      for expected_widget <- expected do
        found =
          find_matching_widget(
            actual,
            expected_widget[:type],
            expected_widget[:id]
          )

        ExUnit.Assertions.assert(
          found != nil,
          "Expected widget #{inspect(expected_widget)} not found in tree. " <>
            "Actual: #{inspect(actual)}"
        )
      end

      session
    end
  end

  @doc """
  Asserts that exactly N tools are registered.

      assert_tool_count(session, 5)
  """
  defmacro assert_tool_count(session, count) do
    quote do
      session = unquote(session)
      tools = Test.get_tools(session)
      actual_count = length(tools)
      expected = unquote(count)

      ExUnit.Assertions.assert(
        actual_count == expected,
        "Expected #{expected} tools, got #{actual_count}. " <>
          "Tools: #{inspect(Enum.map(tools, & &1[:name]))}"
      )

      session
    end
  end

  # -- Helper functions (not macros, used inside macro expansions) -------------

  @doc false
  def find_matching_widget(widgets, type, id) when is_list(widgets) do
    Enum.find_value(widgets, fn widget ->
      type_matches = type == nil or widget[:type] == type
      id_matches = id == nil or to_string(widget[:id]) == to_string(id)

      cond do
        type_matches and id_matches ->
          widget

        is_list(widget[:children]) ->
          find_matching_widget(widget[:children], type, id)

        true ->
          nil
      end
    end)
  end

  def find_matching_widget(_, _, _), do: nil

  @doc false
  def collect_ids(widgets) when is_list(widgets) do
    Enum.flat_map(widgets, fn widget ->
      own = if widget[:id], do: [widget[:id]], else: []
      children = collect_ids(widget[:children] || [])
      own ++ children
    end)
  end

  def collect_ids(_), do: []
end
