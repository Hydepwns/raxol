defmodule Raxol.Docs.InteractiveTutorial.Renderer do
  @moduledoc """
  Handles rendering of interactive tutorial content.
  """

  alias Raxol.Docs.InteractiveTutorial.Models.{Tutorial, Step}

  @doc """
  Renders a tutorial's content.
  """
  def render_tutorial(%Tutorial{} = tutorial) do
    content =
      [
        render_title(tutorial),
        render_description(tutorial),
        render_metadata(tutorial),
        render_steps(tutorial)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    {:ok, content}
  end

  @doc """
  Renders a single step's content.
  """
  def render_step(%Step{} = step) do
    content =
      [
        render_step_title(step),
        render_step_content(step),
        render_example_code(step),
        render_exercise(step),
        render_hints(step)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    {:ok, content}
  end

  @doc """
  Renders interactive elements for a step.
  """
  def render_interactive_elements(%Step{} = step) do
    elements =
      step.interactive_elements
      |> Enum.map(&render_interactive_element/1)
      |> Enum.reject(&is_nil/1)

    {:ok, elements}
  end

  # Private rendering functions

  defp render_title(%Tutorial{title: title}) do
    "# #{title}"
  end

  defp render_description(%Tutorial{description: description}) do
    description
  end

  defp render_metadata(%Tutorial{} = tutorial) do
    metadata =
      [
        render_difficulty(tutorial),
        render_estimated_time(tutorial),
        render_prerequisites(tutorial),
        render_tags(tutorial)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    if metadata != "", do: "## Metadata\n#{metadata}", else: nil
  end

  defp render_difficulty(%Tutorial{difficulty: difficulty}) do
    "**Difficulty:** #{String.capitalize(to_string(difficulty))}"
  end

  defp render_estimated_time(%Tutorial{estimated_time: time})
       when is_integer(time) do
    "**Estimated Time:** #{time} minutes"
  end

  defp render_estimated_time(_), do: nil

  defp render_prerequisites(%Tutorial{prerequisites: []}), do: nil

  defp render_prerequisites(%Tutorial{prerequisites: prereqs}) do
    "**Prerequisites:**\n" <>
      Enum.map_join(prereqs, "\n", &"* #{&1}")
  end

  defp render_tags(%Tutorial{tags: []}), do: nil

  defp render_tags(%Tutorial{tags: tags}) do
    "**Tags:** " <> Enum.join(tags, ", ")
  end

  defp render_steps(%Tutorial{steps: steps}) do
    steps
    |> Enum.map(&render_step/1)
    |> Enum.join("\n\n---\n\n")
  end

  defp render_step_title(%Step{title: title}) do
    "## #{title}"
  end

  defp render_step_content(%Step{content: content}) do
    content
  end

  defp render_example_code(%Step{example_code: nil}), do: nil

  defp render_example_code(%Step{example_code: code}) do
    "### Example Code\n```elixir\n#{code}\n```"
  end

  defp render_exercise(%Step{exercise: nil}), do: nil

  defp render_exercise(%Step{exercise: exercise}) do
    "### Exercise\n#{exercise.description}"
  end

  defp render_hints(%Step{hints: []}), do: nil

  defp render_hints(%Step{hints: hints}) do
    ("### Hints\n" <>
       Enum.with_index(hints, 1))
    |> Enum.map_join("\n", fn {hint, index} -> "#{index}. #{hint}" end)
  end

  defp render_interactive_element(%{type: :code_editor} = element) do
    %{
      type: :code_editor,
      code: element.code || "",
      language: element.language || "elixir",
      theme: element.theme || "monokai",
      read_only: element.read_only || false
    }
  end

  defp render_interactive_element(%{type: :multiple_choice} = element) do
    %{
      type: :multiple_choice,
      question: element.question,
      options: element.options,
      selected: element.selected || nil
    }
  end

  defp render_interactive_element(%{type: :text_input} = element) do
    %{
      type: :text_input,
      placeholder: element.placeholder || "",
      value: element.value || "",
      multiline: element.multiline || false
    }
  end

  defp render_interactive_element(_), do: nil
end
