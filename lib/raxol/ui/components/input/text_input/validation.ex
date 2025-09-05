defmodule Raxol.UI.Components.Input.TextInput.Validation do
  @moduledoc """
  Handles input validation for the TextInput component.
  This includes length validation, pattern matching, and error message generation.
  """

  @doc """
  Validates the input value against the component's constraints.
  Returns a new state with any validation errors.
  """
  def validate_input(state) do
    error = get_validation_error(state)
    %{state | error: error}
  end

  defp get_validation_error(%{max_length: max_length, value: value} = state)
       when not is_nil(max_length) do
    if String.length(value) > max_length do
      "Maximum length is #{max_length} characters"
    else
      # Check other validations if max_length is ok
      check_other_validations(state)
    end
  end

  defp get_validation_error(%{pattern: pattern, value: value})
       when not is_nil(pattern) do
    if Regex.match?(~r/^#{pattern}$/, value) do
      nil
    else
      "Invalid input format"
    end
  end

  defp get_validation_error(_state), do: nil

  defp check_other_validations(%{pattern: pattern, value: value})
       when not is_nil(pattern) do
    if Regex.match?(~r/^#{pattern}$/, value) do
      nil
    else
      "Invalid input format"
    end
  end

  defp check_other_validations(_state), do: nil

  @doc """
  Checks if adding a character would exceed the maximum length.
  """
  def would_exceed_max_length?(state, char) when is_integer(char) do
    case state.max_length do
      nil -> false
      max -> String.length(state.value) >= max
    end
  end

  def would_exceed_max_length?(state, text) when is_binary(text) do
    case state.max_length do
      nil -> false
      max -> String.length(text) > max
    end
  end

  @doc """
  Validates a value against a pattern.
  Returns :ok if valid, {:error, reason} if invalid.
  """
  def validate_pattern(value, pattern) when is_binary(pattern) do
    if Regex.match?(~r/^#{pattern}$/, value) do
      :ok
    else
      {:error, "Invalid input format"}
    end
  end

  @doc """
  Validates a value's length against a maximum.
  Returns :ok if valid, {:error, reason} if invalid.
  """
  def validate_length(value, max_length)
      when is_integer(max_length) and max_length > 0 do
    if String.length(value) <= max_length do
      :ok
    else
      {:error, "Maximum length is #{max_length} characters"}
    end
  end
end
