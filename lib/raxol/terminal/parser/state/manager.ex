defmodule Raxol.Terminal.Parser.State.Manager do
  @moduledoc """
  Manages the state of the terminal parser, including escape sequences,
  control sequences, and parser modes.
  """

  defstruct [
    :state,
    :params,
    :intermediate,
    :ignore,
    :osc_buffer,
    :dcs_buffer,
    :apc_buffer,
    :pm_buffer,
    :sos_buffer,
    :string_buffer,
    :string_terminator,
    :string_flags,
    :string_parser_state
  ]

  @type parser_state :: :ground | :escape | :csi_entry | :csi_param | :csi_intermediate | :csi_ignore
                      | :osc_string | :dcs_entry | :dcs_param | :dcs_intermediate | :dcs_passthrough
                      | :apc_string | :pm_string | :sos_string | :string

  @type params :: [non_neg_integer()]
  @type intermediate :: [non_neg_integer()]
  @type string_flags :: %{String.t() => boolean()}

  @type t :: %__MODULE__{
    state: parser_state(),
    params: params(),
    intermediate: intermediate(),
    ignore: boolean(),
    osc_buffer: String.t(),
    dcs_buffer: String.t(),
    apc_buffer: String.t(),
    pm_buffer: String.t(),
    sos_buffer: String.t(),
    string_buffer: String.t(),
    string_terminator: non_neg_integer() | nil,
    string_flags: string_flags(),
    string_parser_state: parser_state() | nil
  }

  # Constants for character ranges
  @c0_range 0x00..0x1F
  @c1_range 0x80..0x9F
  @printable_range 0x20..0x7E
  @extended_range 0xA0..0xFF

  # Special characters
  @esc 0x1B
  @bel 0x07
  @st 0x9C
  @osc 0x9D
  @pm 0x9E
  @apc 0x9F
  @csi 0x9B
  @dcs 0x90

  @doc """
  Creates a new parser state manager instance.
  """
  def new do
    %__MODULE__{
      state: :ground,
      params: [],
      intermediate: [],
      ignore: false,
      osc_buffer: "",
      dcs_buffer: "",
      apc_buffer: "",
      pm_buffer: "",
      sos_buffer: "",
      string_buffer: "",
      string_terminator: nil,
      string_flags: %{},
      string_parser_state: nil
    }
  end

  @doc """
  Processes a single character and updates the parser state accordingly.
  """
  def process_char(%__MODULE__{} = manager, char) when is_integer(char) do
    case manager.state do
      :ground -> process_ground_state(manager, char)
      :escape -> process_escape_state(manager, char)
      :csi_entry -> process_csi_entry_state(manager, char)
      :csi_param -> process_csi_param_state(manager, char)
      :csi_intermediate -> process_csi_intermediate_state(manager, char)
      :csi_ignore -> process_csi_ignore_state(manager, char)
      :osc_string -> process_osc_string_state(manager, char)
      :dcs_entry -> process_dcs_entry_state(manager, char)
      :dcs_param -> process_dcs_param_state(manager, char)
      :dcs_intermediate -> process_dcs_intermediate_state(manager, char)
      :dcs_passthrough -> process_dcs_passthrough_state(manager, char)
      :apc_string -> process_apc_string_state(manager, char)
      :pm_string -> process_pm_string_state(manager, char)
      :sos_string -> process_sos_string_state(manager, char)
      :string -> process_string_state(manager, char)
    end
  end

  # State processing functions

  defp process_ground_state(manager, char) do
    cond do
      char in @c0_range -> handle_c0_control(manager, char)
      char in @c1_range -> handle_c1_control(manager, char)
      char in @printable_range -> handle_printable(manager, char)
      char in @extended_range -> handle_extended(manager, char)
      true -> manager
    end
  end

  defp process_escape_state(manager, char) do
    cond do
      char in @c0_range -> handle_c0_control(manager, char)
      char in @c1_range -> handle_c1_control(manager, char)
      char in @printable_range -> handle_escape_printable(manager, char)
      char in @extended_range -> handle_escape_extended(manager, char)
      true -> manager
    end
  end

  defp process_csi_entry_state(manager, char) do
    cond do
      char in 0x30..0x3F -> set_state(manager, :csi_param)
      char in 0x20..0x2F -> set_state(manager, :csi_intermediate)
      char in 0x40..0x7E -> set_state(manager, :ground)
      true -> set_state(manager, :csi_ignore)
    end
  end

  defp process_csi_param_state(manager, char) do
    cond do
      char in 0x30..0x3F -> manager
      char in 0x20..0x2F -> set_state(manager, :csi_intermediate)
      char in 0x40..0x7E -> set_state(manager, :ground)
      true -> set_state(manager, :csi_ignore)
    end
  end

  defp process_csi_intermediate_state(manager, char) do
    cond do
      char in 0x20..0x2F -> manager
      char in 0x40..0x7E -> set_state(manager, :ground)
      true -> set_state(manager, :csi_ignore)
    end
  end

  defp process_csi_ignore_state(manager, char) do
    if char in 0x40..0x7E do
      set_state(manager, :ground)
    else
      manager
    end
  end

  defp process_osc_string_state(manager, char) do
    if char == @bel or char == @st do
      set_state(manager, :ground)
    else
      set_osc_buffer(manager, manager.osc_buffer <> <<char>>)
    end
  end

  defp process_dcs_entry_state(manager, char) do
    cond do
      char in 0x30..0x3F -> set_state(manager, :dcs_param)
      char in 0x20..0x2F -> set_state(manager, :dcs_intermediate)
      char in 0x40..0x7E -> set_state(manager, :dcs_passthrough)
      true -> set_state(manager, :ground)
    end
  end

  defp process_dcs_param_state(manager, char) do
    cond do
      char in 0x30..0x3F -> manager
      char in 0x20..0x2F -> set_state(manager, :dcs_intermediate)
      char in 0x40..0x7E -> set_state(manager, :dcs_passthrough)
      true -> set_state(manager, :ground)
    end
  end

  defp process_dcs_intermediate_state(manager, char) do
    cond do
      char in 0x20..0x2F -> manager
      char in 0x40..0x7E -> set_state(manager, :dcs_passthrough)
      true -> set_state(manager, :ground)
    end
  end

  defp process_dcs_passthrough_state(manager, char) do
    if char == @st do
      set_state(manager, :ground)
    else
      set_dcs_buffer(manager, manager.dcs_buffer <> <<char>>)
    end
  end

  defp process_apc_string_state(manager, char) do
    if char == @bel or char == @st do
      set_state(manager, :ground)
    else
      set_apc_buffer(manager, manager.apc_buffer <> <<char>>)
    end
  end

  defp process_pm_string_state(manager, char) do
    if char == @bel or char == @st do
      set_state(manager, :ground)
    else
      set_pm_buffer(manager, manager.pm_buffer <> <<char>>)
    end
  end

  defp process_sos_string_state(manager, char) do
    if char == @bel or char == @st do
      set_state(manager, :ground)
    else
      set_sos_buffer(manager, manager.sos_buffer <> <<char>>)
    end
  end

  defp process_string_state(manager, char) do
    if char == manager.string_terminator do
      set_state(manager, :ground)
    else
      set_string_buffer(manager, manager.string_buffer <> <<char>>)
    end
  end

  # Helper functions for handling different character types

  defp handle_c0_control(manager, char) do
    case char do
      @esc -> set_state(manager, :escape)
      @bel -> manager
      @st -> manager
      _ -> manager
    end
  end

  defp handle_c1_control(manager, char) do
    case char do
      @osc -> set_state(manager, :osc_string)
      @pm -> set_state(manager, :pm_string)
      @apc -> set_state(manager, :apc_string)
      @csi -> set_state(manager, :csi_entry)
      @dcs -> set_state(manager, :dcs_entry)
      _ -> manager
    end
  end

  defp handle_printable(manager, _char) do
    manager
  end

  defp handle_extended(manager, _char) do
    manager
  end

  defp handle_escape_printable(manager, char) do
    case char do
      _ when char in 0x30..0x7E -> set_state(manager, :ground)
      _ -> manager
    end
  end

  defp handle_escape_extended(manager, _char) do
    set_state(manager, :ground)
  end

  @doc """
  Gets the current parser state.
  """
  def get_state(%__MODULE__{} = manager) do
    manager.state
  end

  @doc """
  Sets the parser state.
  """
  def set_state(%__MODULE__{} = manager, state) when state in [
    :ground, :escape, :csi_entry, :csi_param, :csi_intermediate, :csi_ignore,
    :osc_string, :dcs_entry, :dcs_param, :dcs_intermediate, :dcs_passthrough,
    :apc_string, :pm_string, :sos_string, :string
  ] do
    %{manager | state: state}
  end

  @doc """
  Gets the current parameters.
  """
  def get_params(%__MODULE__{} = manager) do
    manager.params
  end

  @doc """
  Sets the parameters.
  """
  def set_params(%__MODULE__{} = manager, params) when is_list(params) do
    %{manager | params: params}
  end

  @doc """
  Gets the current intermediate characters.
  """
  def get_intermediate(%__MODULE__{} = manager) do
    manager.intermediate
  end

  @doc """
  Sets the intermediate characters.
  """
  def set_intermediate(%__MODULE__{} = manager, intermediate) when is_list(intermediate) do
    %{manager | intermediate: intermediate}
  end

  @doc """
  Checks if the parser is in ignore mode.
  """
  def ignore?(%__MODULE__{} = manager) do
    manager.ignore
  end

  @doc """
  Sets the ignore mode.
  """
  def set_ignore(%__MODULE__{} = manager, ignore) when is_boolean(ignore) do
    %{manager | ignore: ignore}
  end

  @doc """
  Gets the OSC buffer content.
  """
  def get_osc_buffer(%__MODULE__{} = manager) do
    manager.osc_buffer
  end

  @doc """
  Sets the OSC buffer content.
  """
  def set_osc_buffer(%__MODULE__{} = manager, content) when is_binary(content) do
    %{manager | osc_buffer: content}
  end

  @doc """
  Gets the DCS buffer content.
  """
  def get_dcs_buffer(%__MODULE__{} = manager) do
    manager.dcs_buffer
  end

  @doc """
  Sets the DCS buffer content.
  """
  def set_dcs_buffer(%__MODULE__{} = manager, content) when is_binary(content) do
    %{manager | dcs_buffer: content}
  end

  @doc """
  Gets the APC buffer content.
  """
  def get_apc_buffer(%__MODULE__{} = manager) do
    manager.apc_buffer
  end

  @doc """
  Sets the APC buffer content.
  """
  def set_apc_buffer(%__MODULE__{} = manager, content) when is_binary(content) do
    %{manager | apc_buffer: content}
  end

  @doc """
  Gets the PM buffer content.
  """
  def get_pm_buffer(%__MODULE__{} = manager) do
    manager.pm_buffer
  end

  @doc """
  Sets the PM buffer content.
  """
  def set_pm_buffer(%__MODULE__{} = manager, content) when is_binary(content) do
    %{manager | pm_buffer: content}
  end

  @doc """
  Gets the SOS buffer content.
  """
  def get_sos_buffer(%__MODULE__{} = manager) do
    manager.sos_buffer
  end

  @doc """
  Sets the SOS buffer content.
  """
  def set_sos_buffer(%__MODULE__{} = manager, content) when is_binary(content) do
    %{manager | sos_buffer: content}
  end

  @doc """
  Gets the string buffer content.
  """
  def get_string_buffer(%__MODULE__{} = manager) do
    manager.string_buffer
  end

  @doc """
  Sets the string buffer content.
  """
  def set_string_buffer(%__MODULE__{} = manager, content) when is_binary(content) do
    %{manager | string_buffer: content}
  end

  @doc """
  Gets the string terminator.
  """
  def get_string_terminator(%__MODULE__{} = manager) do
    manager.string_terminator
  end

  @doc """
  Sets the string terminator.
  """
  def set_string_terminator(%__MODULE__{} = manager, terminator) when is_integer(terminator) do
    %{manager | string_terminator: terminator}
  end

  @doc """
  Gets the string flags.
  """
  def get_string_flags(%__MODULE__{} = manager) do
    manager.string_flags
  end

  @doc """
  Sets the string flags.
  """
  def set_string_flags(%__MODULE__{} = manager, flags) when is_map(flags) do
    %{manager | string_flags: flags}
  end

  @doc """
  Gets the string parser state.
  """
  def get_string_parser_state(%__MODULE__{} = manager) do
    manager.string_parser_state
  end

  @doc """
  Sets the string parser state.
  """
  def set_string_parser_state(%__MODULE__{} = manager, state) when state in [
    :ground, :escape, :csi_entry, :csi_param, :csi_intermediate, :csi_ignore,
    :osc_string, :dcs_entry, :dcs_param, :dcs_intermediate, :dcs_passthrough,
    :apc_string, :pm_string, :sos_string, :string
  ] do
    %{manager | string_parser_state: state}
  end

  @doc """
  Clears all string buffers.
  """
  def clear_string_buffers(%__MODULE__{} = manager) do
    %{manager |
      osc_buffer: "",
      dcs_buffer: "",
      apc_buffer: "",
      pm_buffer: "",
      sos_buffer: "",
      string_buffer: "",
      string_terminator: nil,
      string_flags: %{},
      string_parser_state: nil
    }
  end

  @doc """
  Resets the parser state manager to its initial state.
  """
  def reset(%__MODULE__{} = manager) do
    new()
  end
end
