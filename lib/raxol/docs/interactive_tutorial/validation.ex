defmodule Raxol.Docs.InteractiveTutorial.Validation do
  import Raxol.Guards

  @moduledoc """
  Handles validation of tutorial exercises and user input.
  """

  alias Raxol.Docs.InteractiveTutorial.Models.Step

  @type validation_result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Validates a user's solution for an exercise.
  """
  def validate_solution(%Step{} = step, solution) when is_binary(solution) do
    cond do
      is_nil(step.exercise) ->
        {:error, "No exercise defined for this step"}

      is_function(step.validation, 1) ->
        # Use custom validation function if provided
        if step.validation.(solution) do
          {:ok, "Solution is correct!"}
        else
          {:error, "Solution is incorrect"}
        end

      true ->
        do_validate(step.exercise, solution)
    end
  end

  @doc """
  Validates a user's solution for an exercise with custom validation function.
  """
  def validate_solution(%Step{} = step, solution, validation_fn)
      when function?(validation_fn, 1) do
    case step.exercise do
      nil -> {:error, "No exercise defined for this step"}
      _exercise -> validation_fn.(solution)
    end
  end

  @doc """
  Checks if a solution matches the expected output.
  """
  def validate_output(solution, expected_output)
      when binary?(solution) and binary?(expected_output) do
    solution = String.trim(solution)
    expected = String.trim(expected_output)

    if solution == expected do
      {:ok, "Solution matches expected output"}
    else
      {:error, "Solution does not match expected output"}
    end
  end

  @doc """
  Validates code syntax.
  """
  def validate_syntax(code) when binary?(code) do
    try do
      Code.string_to_quoted!(code)
      {:ok, "Code syntax is valid"}
    rescue
      e in SyntaxError ->
        {:error, "Syntax error: #{e.description}"}
    end
  end

  @doc """
  Validates code execution.
  """
  def validate_execution(code) when binary?(code) do
    try do
      {result, _} = Code.eval_string(code)
      {:ok, "Code executed successfully", result}
    rescue
      e in RuntimeError ->
        {:error, "Runtime error: #{e.message}"}

      e in CompileError ->
        {:error, "Compilation error: #{e.description}"}
    end
  end

  # Private functions

  defp do_validate(%{type: :code} = exercise, solution) do
    with {:ok, _} <- validate_syntax(solution),
         {:ok, result} <- validate_execution(solution) do
      case exercise.validation do
        nil ->
          {:ok, "Code executed successfully"}

        validation_fn when function?(validation_fn, 1) ->
          validation_fn.(result)

        expected when binary?(expected) ->
          validate_output(to_string(result), expected)

        _ ->
          {:error, "Invalid validation configuration"}
      end
    end
  end

  defp do_validate(%{type: :text} = exercise, solution) do
    case exercise.validation do
      nil ->
        {:ok, "Text submitted successfully"}

      validation_fn when function?(validation_fn, 1) ->
        validation_fn.(solution)

      expected when binary?(expected) ->
        validate_output(solution, expected)

      _ ->
        {:error, "Invalid validation configuration"}
    end
  end

  defp do_validate(%{type: :multiple_choice} = exercise, solution) do
    case exercise.validation do
      nil ->
        {:error, "No validation configured for multiple choice"}

      correct_answer when binary?(correct_answer) ->
        if solution == correct_answer do
          {:ok, "Correct answer selected"}
        else
          {:error, "Incorrect answer selected"}
        end

      _ ->
        {:error, "Invalid validation configuration"}
    end
  end

  defp do_validate(_, _) do
    {:error, "Unsupported exercise type"}
  end
end
