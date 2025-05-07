defmodule Raxol.Terminal.Commands.OSCHandlers do
  @moduledoc """
  Handles the execution logic for specific OSC commands.

  Functions are called by `Raxol.Terminal.Commands.Executor` after initial parsing.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.System.Clipboard
  require Logger

  @doc "Handles OSC 0 (Set Icon Name and Window Title) or OSC 2 (Set Window Title)"
  @spec handle_0_or_2(Emulator.t(), String.t()) :: Emulator.t()
  def handle_0_or_2(emulator, pt) do
    Logger.debug("OSC 0/2: Set Window Title to '#{pt}'")
    %{emulator | window_title: pt}
  end

  @doc "Handles OSC 4 (Set/Query Color Palette)"
  @spec handle_4(Emulator.t(), String.t()) :: Emulator.t()
  def handle_4(emulator, pt) do
    parse_osc4(emulator, pt)
  end

  @doc "Handles OSC 7 (Set/Query Current Working Directory URL)"
  @spec handle_7(Emulator.t(), String.t()) :: Emulator.t()
  def handle_7(emulator, pt) do
    # OSC 7: Current Working Directory
    # Pt format: file://hostname/path or just /path
    uri = pt
    Logger.info("OSC 7: Reported CWD: #{uri}")
    # TODO: Store CWD in state or emit event if needed?
    # For now, just acknowledge by logging.
    emulator
  end

  @doc "Handles OSC 8 (Hyperlink)"
  @spec handle_8(Emulator.t(), String.t()) :: Emulator.t()
  def handle_8(emulator, pt) do
    case String.split(pt, ";", parts: 2) do
      # We expect params;uri
      [params_str, uri] ->
        Logger.debug(
          "OSC 8: Hyperlink: URI='#{uri}', Params='#{params_str}'"
        )
        # TODO: Optionally parse params (e.g., id=...)
        # For now, just store the URI if needed for rendering later
        # %{emulator | current_hyperlink_url: uri}
        emulator # Not storing hyperlink state currently

      # Handle cases with missing params: OSC 8;;uri ST (common)
      # Or just uri without params: OSC 8;uri ST (allowed?)
      # Treat as just URI for now if only one part
      [uri] ->
          Logger.debug("OSC 8: Hyperlink: URI='#{uri}', No Params")
          emulator # Not storing hyperlink state currently

      # Handle malformed OSC 8
      _ ->
        Logger.warning("Malformed OSC 8 sequence: PT='#{pt}'")
        emulator
    end
  end

  @doc "Handles OSC 52 (Set/Query Clipboard Data)"
  @spec handle_52(Emulator.t(), String.t()) :: Emulator.t()
  def handle_52(emulator, pt) do
    case String.split(pt, ";", parts: 2) do
      # Set clipboard: "c;DATA_BASE64"
      [selection_char, data_base64] when selection_char in ["c", "p"] and data_base64 != "?" ->
        case Base.decode64(data_base64) do
          {:ok, data_str} ->
            Logger.debug("OSC 52: Set Clipboard (#{selection_char}): '#{data_str}'")
            # Use alias Raxol.System.Clipboard
            Clipboard.copy(data_str)
            # TODO: Need to decide which selection (p/c) Clipboard.put targets or if it needs options.
            emulator
          :error ->
            Logger.warning("OSC 52: Failed to decode base64 data: '#{data_base64}'")
            emulator
        end

      # Query clipboard: "c;?"
      [selection_char, "?"] when selection_char in ["c", "p"] ->
        Logger.debug("OSC 52: Query Clipboard (#{selection_char})")
        # TODO: Read from appropriate selection (p/c)
        # Use alias Raxol.System.Clipboard
        case Clipboard.paste() do
          {:ok, content} ->
            response_data = Base.encode64(content)
            response = "\e]52;#{selection_char};#{response_data}\e\\"
            Logger.debug("OSC 52: Response: #{inspect(response)}")
            %{emulator | output_buffer: emulator.output_buffer <> response}
          {:error, reason} ->
            Logger.warning("OSC 52: Failed to get clipboard: #{inspect(reason)}")
            emulator
        end

      _ ->
        Logger.warning("Malformed OSC 52 sequence: PT='#{pt}'")
        emulator
    end
  end


  # --- OSC 4 Helpers (Moved from Executor) ---

  @spec parse_osc4(Emulator.t(), String.t()) :: Emulator.t()
  defp parse_osc4(emulator, pt) do
    case String.split(pt, ";", parts: 2) do
      [c_str, spec_or_query] ->
        case Integer.parse(c_str) do
          {color_index, ""} when color_index >= 0 and color_index <= 255 ->
            handle_osc4_color(emulator, color_index, spec_or_query)
          _ ->
            Logger.warning("OSC 4: Invalid color index '#{c_str}'")
            emulator
        end
      _ ->
        Logger.warning("OSC 4: Malformed parameter string '#{pt}'")
        emulator
    end
  end

  @spec handle_osc4_color(Emulator.t(), integer(), String.t()) :: Emulator.t()
  defp handle_osc4_color(emulator, color_index, "?") do
    # Query color
    Logger.debug("OSC 4: Query color index #{color_index}")
    # TODO: Query default palette if not in dynamic map?
    # For now, default to black if not set.
    {r, g, b} = Map.get(emulator.color_palette, color_index, {0, 0, 0})

    # Format response as rgb:RRRR/GGGG/BBBB (adjust range if needed)
    # Assuming {r,g,b} are 0-255, xterm expects 0-65535, so scale up.
    r_scaled = Integer.to_string(div(r * 65535, 255), 16)
    g_scaled = Integer.to_string(div(g * 65535, 255), 16)
    b_scaled = Integer.to_string(div(b * 65535, 255), 16)
    spec_response = "rgb:#{r_scaled}/#{g_scaled}/#{b_scaled}"

    response_str = "\e]4;#{color_index};#{spec_response}\e\\"
    Logger.debug("OSC 4: Response: #{inspect(response_str)}")
    %{emulator | output_buffer: emulator.output_buffer <> response_str}
  end

  defp handle_osc4_color(emulator, color_index, spec) do
    # Set color
    case parse_color_spec(spec) do
      {:ok, {r, g, b}} ->
        Logger.debug("OSC 4: Set color index #{color_index} to {#{r}, #{g}, #{b}}")
        new_palette = Map.put(emulator.color_palette, color_index, {r, g, b})
        %{emulator | color_palette: new_palette}
      {:error, reason} ->
        Logger.warning("OSC 4: Invalid color spec '#{spec}': #{reason}")
        emulator
    end
  end

  @spec parse_color_spec(String.t()) :: {:ok, {r :: integer, g :: integer, b :: integer}} | {:error, String.t()}
  defp parse_color_spec(spec) do
    cond do
      # rgb:RR/GG/BB (hex, 1-4 digits per component)
      String.starts_with?(spec, "rgb:") ->
        case String.split(String.trim_leading(spec, "rgb:"), "/", parts: 3) do
          [r_hex, g_hex, b_hex] ->
            with {:ok, r} <- parse_hex_component(r_hex),
                 {:ok, g} <- parse_hex_component(g_hex),
                 {:ok, b} <- parse_hex_component(b_hex) do
              {:ok, {r, g, b}}
            else
              _ -> {:error, "invalid rgb: component(s)"}
            end
          _ -> {:error, "invalid rgb: format"}
        end

      # #RRGGBB (hex, 2 digits)
      String.starts_with?(spec, "#") and byte_size(spec) == 7 ->
        r_hex = String.slice(spec, 1..2)
        g_hex = String.slice(spec, 3..4)
        b_hex = String.slice(spec, 5..6)
        with {r, ""} <- Integer.parse(r_hex, 16),
             {g, ""} <- Integer.parse(g_hex, 16),
             {b, ""} <- Integer.parse(b_hex, 16) do
          {:ok, {r, g, b}}
        else
          _ -> {:error, "invalid #RRGGBB hex value(s)"}
        end

      # #RGB (hex, 1 digit - scale R*17, G*17, B*17)
      String.starts_with?(spec, "#") and byte_size(spec) == 4 ->
        r1 = String.slice(spec, 1..1)
        g1 = String.slice(spec, 2..2)
        b1 = String.slice(spec, 3..3)
        with {r, ""} <- Integer.parse(r1 <> r1, 16),
             {g, ""} <- Integer.parse(g1 <> g1, 16),
             {b, ""} <- Integer.parse(b1 <> b1, 16) do
          {:ok, {r, g, b}}
        else
          _ -> {:error, "invalid #RGB hex value(s)"}
        end

      true ->
        {:error, "unsupported format"}
    end
  end

  # Parses hex color component (1-4 digits), scales to 0-255
  @spec parse_hex_component(String.t()) :: {:ok, integer()} | :error
  defp parse_hex_component(hex_str) do
    len = byte_size(hex_str)
    if len >= 1 and len <= 4 do
      case Integer.parse(hex_str, 16) do
        {val, ""} ->
          # Scale to 0-255. Max value is 0xFFFF (65535).
          scaled_val = round(val * 255 / 65535)
          # Alternative: simple bit shift approximation?
          # scaled_val = val >>> (len * 4 - 8) # if len > 2 ?
          {:ok, max(0, min(255, scaled_val))}
        _ -> :error
      end
    else
      :error
    end
  end

end
