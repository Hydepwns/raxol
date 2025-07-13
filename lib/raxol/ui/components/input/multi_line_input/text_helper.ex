defmodule Raxol.UI.Components.Input.MultiLineInput.TextHelper do
  @moduledoc """
  Helper functions for text and line manipulation in MultiLineInput.
  This module now serves as a facade, delegating to specialized modules.
  """

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.TextOperations
  alias Raxol.UI.Components.Input.MultiLineInput.TextEditing
  alias Raxol.UI.Components.Input.MultiLineInput.TextUtils
  alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper
  require Raxol.Core.Runtime.Log

  # --- Public API - Delegates to specialized modules ---

  @doc """
  Splits the given text into lines, applying the specified wrapping mode (:none, :char, or :word).
  """
  def split_into_lines(text, width, wrap_mode) do
    TextUtils.split_into_lines(text, width, wrap_mode)
  end

  @doc """
  Splits the given text into lines and applies the provided wrapping function to each line.
  """
  def split_and_wrap(text, width, wrap_fun) do
    TextUtils.split_and_wrap(text, width, wrap_fun)
  end

  @doc """
  Converts a {row, col} tuple to a flat string index based on the provided lines.
  """
  def pos_to_index(text_lines, {row, col}) do
    TextUtils.pos_to_index(text_lines, {row, col})
  end

  @doc """
  Replaces text within a range (from start_pos_tuple to end_pos_tuple) with the given replacement string.
  Returns {new_full_text, replaced_text}.
  """
  def replace_text_range(lines_list, start_pos_tuple, end_pos_tuple, replacement) do
    TextOperations.replace_text_range(lines_list, start_pos_tuple, end_pos_tuple, replacement)
  end

  @doc """
  Inserts a character or codepoint at the current cursor position.
  """
  def insert_char(state, char_or_codepoint) do
    TextEditing.insert_char(state, char_or_codepoint)
  end

  @doc """
  Deletes the currently selected text in the state, updating lines and value.
  """
  def delete_selection(state) do
    TextEditing.delete_selection(state)
  end

  @doc """
  Handles backspace when no text is selected.
  """
  def handle_backspace_no_selection(state) do
    TextEditing.handle_backspace_no_selection(state)
  end

  @doc """
  Handles delete key when no text is selected.
  """
  def handle_delete_no_selection(state) do
    TextEditing.handle_delete_no_selection(state)
  end

  # --- Utility functions that are still needed here ---

  @doc """
  Clamps a value between min and max.
  """
  def clamp(value, min, max) do
    TextUtils.clamp(value, min, max)
  end

  @doc """
  Calculates the new cursor position after inserting text.
  """
  def calculate_new_position(row, col, inserted_text) do
    TextEditing.calculate_new_position(row, col, inserted_text)
  end

  @doc """
  Normalizes full text by joining lines with newlines if it's a list.
  """
  def normalize_full_text(full_text) do
    TextUtils.normalize_full_text(full_text)
  end

  @doc """
  Gets the part of a line after a given column position.
  """
  def get_after_part(line, end_col, line_length) do
    TextUtils.get_after_part(line, end_col, line_length)
  end
end
