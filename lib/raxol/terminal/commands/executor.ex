defmodule Raxol.Terminal.Commands.Executor do
  @moduledoc false

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Parser
  alias Raxol.Terminal.Commands.CSIHandlers
  alias Raxol.Terminal.Commands.OSCHandlers
  alias Raxol.Terminal.Commands.DCSHandlers
  require Raxol.Core.Runtime.Log

  @basic_commands [?m, ?H, ?r, ?J, ?K]
  @cursor_commands [?A, ?B, ?C, ?D, ?E, ?F, ?G, ?d]
  @screen_commands [?L, ?M, ?P, ?@, ?S, ?T, ?X]
  @device_commands [?c, ?n, ?s, ?u, ?t]
  @scs_commands [?(, ?), ?*, ?+]

  @command_map %{
    basic: &CSIHandlers.handle_basic_command/3,
    cursor: &CSIHandlers.handle_cursor_command/3,
    screen: &CSIHandlers.handle_screen_command/3,
    device: &CSIHandlers.handle_device_command/4,
    mode: &CSIHandlers.handle_h_or_l/4,
    scs: &CSIHandlers.handle_scs/3,
    deccusr: &CSIHandlers.handle_q_deccusr/2
  }

  @command_types %{
    basic: @basic_commands,
    cursor: @cursor_commands,
    screen: @screen_commands,
    device: @device_commands,
    scs: @scs_commands
  }

  @spec execute_csi_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer()
        ) :: Emulator.t()
  def execute_csi_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte
      ) do
    Raxol.Core.Runtime.Log.debug(
      "[Executor.execute_csi_command] BEFORE: scroll_region=#{inspect(emulator.scroll_region)}, final_byte=#{inspect(final_byte)}"
    )

    params = Parser.parse_params(params_buffer)

    result =
      dispatch_csi_command(
        emulator,
        params,
        intermediates_buffer,
        final_byte,
        params_buffer
      )

    log_and_return_result(result, final_byte)
  end

  defp dispatch_csi_command(
         emulator,
         params,
         intermediates_buffer,
         final_byte,
         params_buffer
       ) do
    case get_command_type(final_byte, intermediates_buffer) do
      {:ok, type} ->
        apply_handler(
          type,
          emulator,
          params,
          intermediates_buffer,
          final_byte,
          params_buffer
        )

      :unknown ->
        log_unknown_csi(final_byte)
        {:error, :unhandled_csi, emulator}
    end
  end

  defp get_command_type(final_byte, intermediates_buffer) do
    cond do
      final_byte == ?q and intermediates_buffer == " " -> {:ok, :deccusr}
      final_byte in [?h, ?l] -> {:ok, :mode}
      true -> find_command_type(final_byte)
    end
  end

  defp find_command_type(final_byte) do
    Enum.find_value(@command_types, :unknown, fn {type, commands} ->
      if final_byte in commands, do: {:ok, type}
    end)
  end

  defp apply_handler(
         :basic,
         emulator,
         params,
         _intermediates,
         final_byte,
         _params_buffer
       ),
       do: @command_map.basic.(emulator, params, final_byte)

  defp apply_handler(
         :mode,
         emulator,
         params,
         intermediates,
         final_byte,
         _params_buffer
       ),
       do: @command_map.mode.(emulator, params, intermediates, final_byte)

  defp apply_handler(
         :device,
         emulator,
         params,
         intermediates,
         final_byte,
         _params_buffer
       ),
       do: @command_map.device.(emulator, params, intermediates, final_byte)

  defp apply_handler(
         :scs,
         emulator,
         _params,
         _intermediates,
         final_byte,
         params_buffer
       ),
       do: @command_map.scs.(emulator, params_buffer, final_byte)

  defp apply_handler(
         :deccusr,
         emulator,
         params,
         _intermediates,
         _final_byte,
         _params_buffer
       ),
       do: @command_map.deccusr.(emulator, params)

  defp apply_handler(
         :cursor,
         emulator,
         params,
         _intermediates,
         final_byte,
         _params_buffer
       ),
       do: @command_map.cursor.(emulator, params, final_byte)

  defp apply_handler(
         :screen,
         emulator,
         params,
         _intermediates,
         final_byte,
         _params_buffer
       ),
       do: @command_map.screen.(emulator, params, final_byte)

  defp log_and_return_result(result, final_byte) do
    case result do
      {:ok, new_emulator} ->
        log_after_execution(new_emulator, final_byte)
        new_emulator

      {:error, _reason, new_emulator} ->
        log_after_execution(new_emulator, final_byte)
        new_emulator
    end
  end

  defp log_unknown_csi(final_byte) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Unknown CSI command: #{inspect(final_byte)}",
      %{}
    )
  end

  defp log_after_execution(emulator, final_byte) do
    Raxol.Core.Runtime.Log.debug(
      "[Executor.execute_csi_command] AFTER: scroll_region=#{inspect(emulator.scroll_region)}, final_byte=#{inspect(final_byte)}"
    )
  end

  @spec execute_osc_command(Emulator.t(), String.t()) :: Emulator.t()
  def execute_osc_command(emulator, command_string) do
    Raxol.Core.Runtime.Log.debug(
      "Executing OSC command: #{inspect(command_string)}"
    )

    handle_osc_command(emulator, command_string)
  end

  defp handle_osc_command(emulator, command_string) do
    with [ps_str, pt] <- String.split(command_string, ";", parts: 2),
         {ps_code, ""} <- Integer.parse(ps_str) do
      dispatch_osc_command(emulator, ps_code, pt)
    else
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "OSC: Unexpected command format: \"#{command_string}\"",
          %{}
        )

        {:error, :malformed_osc, emulator}
    end
  end

  defp dispatch_osc_command(emulator, ps_code, pt) do
    OSCHandlers.handle(emulator, ps_code, pt)
  end

  @spec execute_dcs_command(
          Emulator.t(),
          String.t(),
          String.t(),
          String.t()
        ) :: Emulator.t()
  def execute_dcs_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        data_string
      ) do
    Raxol.Core.Runtime.Log.debug(
      "Executing DCS command: #{inspect(data_string)}"
    )

    handle_dcs_command(
      emulator,
      params_buffer,
      intermediates_buffer,
      data_string
    )
  end

  defp handle_dcs_command(
         emulator,
         params_buffer,
         intermediates_buffer,
         data_string
       ) do
    case intermediates_buffer do
      "" ->
        DCSHandlers.handle_dcs(emulator, params_buffer, data_string)

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "DCS: Unhandled intermediate: \"#{intermediates_buffer}\"",
          %{}
        )

        {:error, :unhandled_dcs, emulator}
    end
  end
end
