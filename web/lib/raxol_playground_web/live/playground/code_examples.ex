defmodule RaxolPlaygroundWeb.Playground.CodeExamples do
  @moduledoc """
  Manages code examples for the Raxol playground.
  Loads examples from external files at compile time.
  """

  @examples_dir Path.join(:code.priv_dir(:raxol_playground), "playground_examples")

  # HEEx examples (main component code)
  @button_heex File.read!(Path.join(@examples_dir, "button_heex.ex"))
  @external_resource Path.join(@examples_dir, "button_heex.ex")

  @text_input_heex File.read!(Path.join(@examples_dir, "text_input_heex.ex"))
  @external_resource Path.join(@examples_dir, "text_input_heex.ex")

  @table_heex File.read!(Path.join(@examples_dir, "table_heex.ex"))
  @external_resource Path.join(@examples_dir, "table_heex.ex")

  @progress_heex File.read!(Path.join(@examples_dir, "progress_heex.ex"))
  @external_resource Path.join(@examples_dir, "progress_heex.ex")

  @modal_heex File.read!(Path.join(@examples_dir, "modal_heex.ex"))
  @external_resource Path.join(@examples_dir, "modal_heex.ex")

  @menu_heex File.read!(Path.join(@examples_dir, "menu_heex.ex"))
  @external_resource Path.join(@examples_dir, "menu_heex.ex")

  @generic_heex File.read!(Path.join(@examples_dir, "generic_heex.ex"))
  @external_resource Path.join(@examples_dir, "generic_heex.ex")

  # Framework-specific examples
  @menu_react File.read!(Path.join(@examples_dir, "menu_react.ex"))
  @external_resource Path.join(@examples_dir, "menu_react.ex")

  @menu_liveview File.read!(Path.join(@examples_dir, "menu_liveview.ex"))
  @external_resource Path.join(@examples_dir, "menu_liveview.ex")

  @menu_raw File.read!(Path.join(@examples_dir, "menu_raw.ex"))
  @external_resource Path.join(@examples_dir, "menu_raw.ex")

  @button_react File.read!(Path.join(@examples_dir, "button_react.ex"))
  @external_resource Path.join(@examples_dir, "button_react.ex")

  @button_liveview File.read!(Path.join(@examples_dir, "button_liveview.ex"))
  @external_resource Path.join(@examples_dir, "button_liveview.ex")

  @button_raw File.read!(Path.join(@examples_dir, "button_raw.ex"))
  @external_resource Path.join(@examples_dir, "button_raw.ex")

  @generic_react File.read!(Path.join(@examples_dir, "generic_react.ex"))
  @external_resource Path.join(@examples_dir, "generic_react.ex")

  @generic_liveview File.read!(Path.join(@examples_dir, "generic_liveview.ex"))
  @external_resource Path.join(@examples_dir, "generic_liveview.ex")

  @generic_raw File.read!(Path.join(@examples_dir, "generic_raw.ex"))
  @external_resource Path.join(@examples_dir, "generic_raw.ex")

  # Component definitions
  @components_json File.read!(Path.join(@examples_dir, "components.json"))
  @external_resource Path.join(@examples_dir, "components.json")

  @components_data Jason.decode!(@components_json)["components"]
                   |> Enum.map(fn c ->
                     %{
                       name: c["name"],
                       description: c["description"],
                       framework: c["framework"],
                       complexity: c["complexity"],
                       tags: c["tags"],
                       category: c["category"]
                     }
                   end)

  @doc """
  Returns the list of available components.
  """
  def list_components, do: @components_data

  @doc """
  Returns the default (HEEx) code example for a component.
  """
  def get_code(%{name: "Button"}), do: @button_heex
  def get_code(%{name: "TextInput"}), do: @text_input_heex
  def get_code(%{name: "Table"}), do: @table_heex
  def get_code(%{name: "Progress"}), do: @progress_heex
  def get_code(%{name: "Modal"}), do: @modal_heex
  def get_code(%{name: "Menu"}), do: @menu_heex
  def get_code(_), do: @generic_heex

  @doc """
  Returns framework-specific code example for a component.
  """
  def get_code_for_framework(%{name: "Menu"}, "react"), do: @menu_react
  def get_code_for_framework(%{name: "Menu"}, "liveview"), do: @menu_liveview
  def get_code_for_framework(%{name: "Menu"}, "raw"), do: @menu_raw
  def get_code_for_framework(%{name: "Button"}, "react"), do: @button_react
  def get_code_for_framework(%{name: "Button"}, "liveview"), do: @button_liveview
  def get_code_for_framework(%{name: "Button"}, "raw"), do: @button_raw
  def get_code_for_framework(_, "react"), do: @generic_react
  def get_code_for_framework(_, "liveview"), do: @generic_liveview
  def get_code_for_framework(_, "raw"), do: @generic_raw
  def get_code_for_framework(component, _), do: get_code(component)
end
