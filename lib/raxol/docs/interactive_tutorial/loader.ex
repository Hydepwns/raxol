defmodule Raxol.Docs.InteractiveTutorial.Loader do
  @moduledoc """
  Handles loading and parsing of tutorials from markdown files.
  """

  alias Raxol.Docs.InteractiveTutorial.Models.{Tutorial, Step}
  alias YamlElixir

  @doc """
  Loads all tutorials from the specified directory.
  """
  def load_tutorials_from_markdown(dir_path) do
    dir_path
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.map(&load_tutorial/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Loads a single tutorial from a markdown file.
  """
  def load_tutorial(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, front_matter, markdown} <- extract_front_matter(content),
         {:ok, tutorial} <- parse_front_matter(front_matter),
         steps <- parse_steps(markdown) do
      %{tutorial | steps: steps}
    else
      _ -> nil
    end
  end

  @doc """
  Extracts YAML front matter from markdown content.
  """
  def extract_front_matter(content) do
    case Regex.run(~r/^---\n(.*?)\n---\n(.*)/s, content) do
      [_, front_matter, markdown] -> {:ok, front_matter, markdown}
      _ -> {:error, "Invalid front matter format"}
    end
  end

  @doc """
  Parses YAML front matter into a Tutorial struct.
  """
  def parse_front_matter(front_matter) do
    case YamlElixir.read_from_string(front_matter) do
      {:ok, data} ->
        tutorial = %Tutorial{
          id: data["id"],
          title: data["title"],
          description: data["description"],
          tags: data["tags"] || [],
          difficulty: String.to_existing_atom(data["difficulty"]),
          estimated_time: data["estimated_time"],
          prerequisites: data["prerequisites"] || [],
          steps: [],
          metadata: data["metadata"] || %{}
        }

        {:ok, tutorial}

      _ ->
        {:error, "Failed to parse YAML"}
    end
  end

  @doc """
  Parses markdown content into a list of Step structs.
  """
  def parse_steps(markdown) do
    markdown
    |> String.split(~r/^##\s+/m)
    # Skip the first empty split
    |> Enum.drop(1)
    |> Enum.map(&parse_step/1)
  end

  @doc """
  Parses a single step from markdown content.
  """
  def parse_step(step_content) do
    [title | content_parts] = String.split(step_content, "\n", parts: 2)
    content = List.first(content_parts) || ""

    # Extract step ID from title
    id =
      title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    # Extract example code if present
    {example_code, content} = extract_example_code(content)

    # Extract exercise if present
    {exercise, content} = extract_exercise(content)

    # Extract hints if present
    hints = extract_hints(content)

    %Step{
      id: id,
      title: String.trim(title),
      content: String.trim(content),
      example_code: example_code,
      exercise: exercise,
      # To be implemented
      validation: nil,
      hints: hints,
      # To be determined during parsing
      next_steps: [],
      # To be extracted from content
      interactive_elements: []
    }
  end

  defp extract_example_code(content) do
    case Regex.run(~r/```elixir\n(.*?)\n```/s, content) do
      [_, code] ->
        {String.trim(code),
         String.replace(content, ~r/```elixir\n.*?\n```/s, "")}

      _ ->
        {nil, content}
    end
  end

  defp extract_exercise(content) do
    case Regex.run(~r/### Exercise\n(.*?)(?=###|\z)/s, content) do
      [_, exercise] ->
        {parse_exercise(exercise),
         String.replace(content, ~r/### Exercise\n.*?(?=###|\z)/s, "")}

      _ ->
        {nil, content}
    end
  end

  defp parse_exercise(exercise_content) do
    # Basic exercise parsing - can be expanded based on needs
    %{
      description: String.trim(exercise_content),
      # Default type
      type: :code,
      # To be implemented
      validation: nil
    }
  end

  defp extract_hints(content) do
    case Regex.run(~r/### Hints\n(.*?)(?=###|\z)/s, content) do
      [_, hints] ->
        hints
        |> String.split(~r/^\d+\.\s+/m)
        |> Enum.drop(1)
        |> Enum.map(&String.trim/1)

      _ ->
        []
    end
  end
end
