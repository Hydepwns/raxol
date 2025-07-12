defmodule Raxol.Terminal.ScreenBufferBehaviour do
  @moduledoc """
  Defines the behaviour for screen buffer operations in the terminal.
  This module specifies the callbacks that must be implemented by any module
  that wants to act as a screen buffer.
  """

  @type t :: term()
  @type position :: {non_neg_integer(), non_neg_integer()}
  @type dimensions :: {non_neg_integer(), non_neg_integer()}
  @type style :: map() | nil
  @type color :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  @type charset :: atom()
  @type metric :: atom()
  @type metric_value :: number()
  @type metric_tags :: map()

  @callback new(width :: non_neg_integer(), height :: non_neg_integer()) :: t()
  @callback get_char(
              buffer :: t(),
              x :: non_neg_integer(),
              y :: non_neg_integer()
            ) :: String.t()
  @callback get_cell(
              buffer :: t(),
              x :: non_neg_integer(),
              y :: non_neg_integer()
            ) :: map()
  @callback write_char(
              buffer :: t(),
              x :: non_neg_integer(),
              y :: non_neg_integer(),
              char :: String.t(),
              style :: style()
            ) :: t()
  @callback write_string(
              buffer :: t(),
              x :: non_neg_integer(),
              y :: non_neg_integer(),
              string :: String.t(),
              style :: style()
            ) :: t()
  @callback get_dimensions(buffer :: t()) :: dimensions()
  @callback get_width(buffer :: t()) :: non_neg_integer()
  @callback get_height(buffer :: t()) :: non_neg_integer()

  @callback designate_charset(
              buffer :: t(),
              slot :: atom(),
              charset :: charset()
            ) :: t()
  @callback invoke_g_set(buffer :: t(), slot :: atom()) :: t()
  @callback get_current_g_set(buffer :: t()) :: atom()
  @callback get_designated_charset(buffer :: t(), slot :: atom()) :: charset()
  @callback reset_state(buffer :: t()) :: t()
  @callback apply_single_shift(buffer :: t(), slot :: atom()) :: t()
  @callback get_single_shift(buffer :: t()) :: atom()

  @callback get_style(buffer :: t()) :: style()
  @callback update_style(buffer :: t(), style :: style()) :: t()
  @callback set_attribute(buffer :: t(), attribute :: atom()) :: t()
  @callback reset_attribute(buffer :: t(), attribute :: atom()) :: t()
  @callback set_foreground(buffer :: t(), color :: color()) :: t()
  @callback set_background(buffer :: t(), color :: color()) :: t()
  @callback reset_all_attributes(buffer :: t()) :: t()
  @callback get_foreground(buffer :: t()) :: color()
  @callback get_background(buffer :: t()) :: color()
  @callback attribute_set?(buffer :: t(), attribute :: atom()) :: boolean()
  @callback get_set_attributes(buffer :: t()) :: [atom()]

  @callback get_state_stack(buffer :: t()) :: [map()]
  @callback update_state_stack(buffer :: t(), stack :: [map()]) :: t()
  @callback save_state(buffer :: t()) :: t()
  @callback restore_state(buffer :: t()) :: t()
  @callback has_saved_states?(buffer :: t()) :: boolean()
  @callback get_saved_states_count(buffer :: t()) :: non_neg_integer()
  @callback clear_saved_states(buffer :: t()) :: t()
  @callback get_current_state(buffer :: t()) :: map()
  @callback update_current_state(buffer :: t(), state :: map()) :: t()

  @callback write(buffer :: t(), data :: String.t()) :: t()
  @callback flush_output(buffer :: t()) :: t()
  @callback clear_output_buffer(buffer :: t()) :: t()
  @callback get_output_buffer(buffer :: t()) :: String.t()
  @callback enqueue_control_sequence(buffer :: t(), sequence :: String.t()) ::
              t()

  @callback empty?(cell :: map()) :: boolean()

  @callback get_metric_value(buffer :: t(), metric :: metric()) ::
              metric_value()
  @callback verify_metrics(buffer :: t(), metrics :: [metric()]) :: boolean()
  @callback collect_metrics(buffer :: t(), metrics :: [metric()]) :: map()
  @callback record_performance(
              buffer :: t(),
              metric :: metric(),
              value :: metric_value()
            ) :: t()
  @callback record_operation(
              buffer :: t(),
              operation :: atom(),
              value :: metric_value()
            ) :: t()
  @callback record_resource(
              buffer :: t(),
              resource :: atom(),
              value :: metric_value()
            ) :: t()
  @callback get_metrics_by_type(buffer :: t(), type :: atom()) :: [map()]
  @callback record_metric(
              buffer :: t(),
              metric :: metric(),
              value :: metric_value(),
              tags :: metric_tags()
            ) :: t()
  @callback get_metric(buffer :: t(), metric :: metric(), tags :: metric_tags()) ::
              metric_value()

  @callback handle_file_event(buffer :: t(), event :: map()) :: t()
  @callback handle_debounced_events(
              buffer :: t(),
              events :: [map()],
              timeout :: non_neg_integer()
            ) :: t()
  @callback cleanup_file_watching(buffer :: t()) :: t()

  @callback get_size(buffer :: t()) :: dimensions()
  @callback scroll_up(buffer :: t(), lines :: non_neg_integer()) :: t()
  @callback scroll_down(buffer :: t(), lines :: non_neg_integer()) :: t()
  @callback set_scroll_region(
              buffer :: t(),
              start_line :: non_neg_integer(),
              end_line :: non_neg_integer()
            ) :: t()
  @callback clear_scroll_region(buffer :: t()) :: t()
  @callback get_scroll_region_boundaries(buffer :: t()) ::
              {non_neg_integer(), non_neg_integer()}
  @callback get_scroll_position(buffer :: t()) :: non_neg_integer()

  @callback clear_screen(buffer :: t()) :: t()
  @callback clear_line(buffer :: t(), line :: non_neg_integer()) :: t()
  @callback mark_damaged(
              buffer :: t(),
              x :: non_neg_integer(),
              y :: non_neg_integer(),
              width :: non_neg_integer(),
              height :: non_neg_integer()
            ) :: t()
  @callback erase_from_cursor_to_end(buffer :: t()) :: t()
  @callback erase_from_start_to_cursor(buffer :: t()) :: t()
  @callback erase_all(buffer :: t()) :: t()
  @callback erase_all_with_scrollback(buffer :: t()) :: t()
  @callback erase_from_cursor_to_end_of_line(buffer :: t()) :: t()
  @callback erase_from_start_of_line_to_cursor(buffer :: t()) :: t()
  @callback erase_line(buffer :: t()) :: t()

  @callback handle_mode(buffer :: t(), mode :: atom(), value :: any()) :: t()

  @callback create_chart(buffer :: t(), data :: map(), options :: map()) :: t()

  @callback get_preferences() :: map()
  @callback set_preferences(preferences :: map()) :: :ok

  # --- System Operations ---
  @callback get_update_settings() :: map()

  # --- Cloud Operations ---
  @callback get_config() :: map()
  @callback set_config(config :: map()) :: :ok

  # --- Theme Operations ---
  @callback current_theme() :: map()
  @callback light_theme() :: map()

  # --- CSI Handler Operations ---
  @callback handle_csi_sequence(
              buffer :: t(),
              sequence :: String.t(),
              params :: [String.t()]
            ) :: t()
end
