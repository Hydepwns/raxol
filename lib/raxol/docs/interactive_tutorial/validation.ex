defmodule Raxol.Docs.InteractiveTutorial.Validation do
  @moduledoc """
  Handles validation of tutorial exercises and user input.
  """

  alias Raxol.Docs.InteractiveTutorial.Models.Step

  @type validation_result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Validates a user's solution for an exercise.
  """
  def validate_solution(%Step{} = step, solution) when is_binary(solution) do
    case {is_nil(step.exercise), is_function(step.validation, 1)} do
      {true, _} -> {:error, "No exercise defined for this step"}
      {false, true} -> validate_with_custom_function(step.validation, solution)
      {false, false} -> do_validate(step.exercise, solution)
    end
  end

  # Helper functions for pattern matching refactoring

  defp validate_with_custom_function(validation_fn, solution) do
    validate_solution_result(validation_fn.(solution))
  end

  defp validate_solution_result(true), do: {:ok, "Solution is correct!"}

  defp validate_solution_result(false), do: {:error, "Solution is incorrect"}

  defp validate_output_match(true), do: {:ok, "Solution matches expected output"}

  defp validate_output_match(false), do: {:error, "Solution does not match expected output"}

  defp validate_multiple_choice_answer(true), do: {:ok, "Correct answer selected"}

  defp validate_multiple_choice_answer(false), do: {:error, "Incorrect answer selected"}

  @doc """
  Validates a user's solution for an exercise with custom validation function.
  """
  def validate_solution(%Step{} = step, solution, validation_fn)
      when is_function(validation_fn, 1) do
    case step.exercise do
      nil -> {:error, "No exercise defined for this step"}
      _exercise -> validation_fn.(solution)
    end
  end

  @doc """
  Checks if a solution matches the expected output.
  """
  def validate_output(solution, expected_output)
      when is_binary(solution) and is_binary(expected_output) do
    solution = String.trim(solution)
    expected = String.trim(expected_output)

    validate_output_match(solution == expected)
  end

  @doc """
  Validates code syntax.
  """
  def validate_syntax(code) when is_binary(code) do
    case Raxol.Core.ErrorHandling.safe_call(fn -> Code.string_to_quoted!(code) end) do
      {:ok, _} ->
        {:ok, "Code syntax is valid"}

      {:error, %SyntaxError{description: description}} ->
        {:error, "Syntax error: #{description}"}

      {:error, _} ->
        {:error, "Syntax error: Invalid code"}
    end
  end

  @doc """
  Validates code execution.
  """
  def validate_execution(code) when is_binary(code) do
    case Raxol.Core.ErrorHandling.safe_call(fn -> Code.eval_string(code) end) do
      {:ok, {result, _}} ->
        {:ok, "Code executed successfully", result}

      {:error, %RuntimeError{message: message}} ->
        {:error, "Runtime error: #{message}"}

      {:error, %CompileError{description: description}} ->
        {:error, "Compilation error: #{description}"}

      {:error, _} ->
        {:error, "Code execution failed"}
    end
  end

  # Private functions

  defp do_validate(%{type: :code} = exercise, solution) do
    with {:ok, _} <- validate_syntax(solution),
         {:ok, result} <- validate_execution(solution) do
      case exercise.validation do
        nil ->
          {:ok, "Code executed successfully"}

        validation_fn when is_function(validation_fn, 1) ->
          validation_fn.(result)

        expected when is_binary(expected) ->
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

      validation_fn when is_function(validation_fn, 1) ->
        validation_fn.(solution)

      expected when is_binary(expected) ->
        validate_output(solution, expected)

      _ ->
        {:error, "Invalid validation configuration"}
    end
  end

  defp do_validate(%{type: :multiple_choice} = exercise, solution) do
    case exercise.validation do
      nil ->
        {:error, "No validation configured for multiple choice"}

      correct_answer when is_binary(correct_answer) ->
        validate_multiple_choice_answer(solution == correct_answer)

      _ ->
        {:error, "Invalid validation configuration"}
    end
  end

  defp do_validate(_, _) do
    {:error, "Unsupported exercise type"}
  end
end
