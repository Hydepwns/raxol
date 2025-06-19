defmodule Raxol.Terminal.EmulatorFactory do
  @moduledoc """
  Factory module for creating terminal emulator instances.
  This module is responsible for initializing and configuring new emulator instances.
  """

  alias Raxol.Terminal.{Emulator, ScreenManager, ParserStateManager}
  alias Raxol.Terminal.Emulator.Struct

  @doc """
  Creates a new terminal emulator with the given options.
  """
  @spec create(non_neg_integer(), non_neg_integer(), keyword()) :: Emulator.t()
  def create(width, height, opts) do
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts
    scrollback_limit = ScreenManager.parse_scrollback_limit(opts)
    {main_buffer, alt_buffer} = ScreenManager.initialize_buffers(width, height)

    %Struct{
      width: width,
      height: height,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alt_buffer,
      active_buffer_type: :main,
      scrollback_limit: scrollback_limit,
      memory_limit: opts[:memorylimit] || 1_000_000,
      max_command_history: opts[:max_command_history] || 100,
      plugin_manager: opts[:plugin_manager] || Core.new(),
      session_id: opts[:session_id],
      client_options: opts[:client_options] || %{},
      state: Raxol.Terminal.State.Manager.new(),
      command: Command.Manager.new(),
      window_title: nil,
      state_stack: [],
      last_col_exceeded: false,
      icon_name: nil,
      current_hyperlink_url: nil,
      parser_state: ParserStateManager.reset_parser_state(%Emulator{}),
      input_mode: :normal
    }
  end
end
