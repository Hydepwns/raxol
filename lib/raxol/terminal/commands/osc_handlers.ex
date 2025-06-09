defmodule Raxol.Terminal.Commands.OSCHandlers do
  @moduledoc """
  Handles the execution logic for specific OSC commands.

  Functions are called by `Raxol.Terminal.Commands.Executor` after initial parsing.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.System.Clipboard
  require Raxol.Core.Runtime.Log

  @doc """
  Handles OSC 1 (Set Icon Name)
  """
  @spec handle_1(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_1(emulator, pt) do
    Raxol.Core.Runtime.Log.debug("OSC 1: Set Icon Name to '#{pt}'")
    {:ok, %{emulator | icon_name: pt}}
  end

  @doc """
  Handles OSC 0 (Set Icon Name and Window Title) or OSC 2 (Set Window Title)
  """
  @spec handle_0_or_2(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_0_or_2(emulator, pt) do
    Raxol.Core.Runtime.Log.debug(
      "OSC 0/2: Set Window Title and Icon Name to '#{pt}'"
    )

    {:ok, %{emulator | window_title: pt, icon_name: pt}}
  end

  @doc """
  Handles OSC 4 (Set/Query Color Palette).

  Format: OSC 4 ; c ; spec ST
  - c: Color index (0-255)
  - spec: Color specification or "?" for query

  Color specifications supported:
  - rgb:RRRR/GGGG/BBBB (hex, 1-4 digits per component)
  - #RRGGBB (hex, 2 digits per component)
  - #RGB (hex, 1 digit per component)
  - #RRGGBBAA (hex with alpha, 2 digits per component)
  - rgb(r,g,b) (decimal, 0-255)
  - rgb(r%,g%,b%) (percentage, 0-100%)

  Returns:
  - For set: Updated emulator with new color in palette
  - For query: Emulator with response in output_buffer
  """
  @spec handle_4(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_4(emulator, pt) do
    case parse_osc4(emulator, pt) do
      {:ok, emu} -> {:ok, emu}
      {:error, reason, emu} -> {:error, reason, emu}
      emu when is_map(emu) -> {:ok, emu}
    end
  end

  @doc "Handles OSC 7 (Set/Query Current Working Directory URL) and stores it in emulator state."
  @spec handle_7(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_7(emulator, pt) do
    uri = pt
    Raxol.Core.Runtime.Log.info("OSC 7: Reported CWD: #{uri}")
    {:ok, %{emulator | cwd: uri}}
  end

  @doc "Handles OSC 8 (Hyperlink) and stores hyperlink state in emulator."
  @spec handle_8(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_8(emulator, pt) do
    case String.split(pt, ";", parts: 2) do
      [params_str, uri] ->
        Raxol.Core.Runtime.Log.debug(
          "OSC 8: Hyperlink: URI='#{uri}', Params='#{params_str}'"
        )

        {:ok, %{emulator | current_hyperlink: %{uri: uri, params: params_str}}}

      [uri] ->
        Raxol.Core.Runtime.Log.debug(
          "OSC 8: Hyperlink: URI='#{uri}', No Params"
        )

        {:ok, %{emulator | current_hyperlink: %{uri: uri, params: nil}}}

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Malformed OSC 8 sequence: PT='#{pt}'",
          %{}
        )

        {:error, :malformed_osc_8, emulator}
    end
  end

  @doc "Handles OSC 52 (Set/Query Clipboard Data) with selection clarification."
  @spec handle_52(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_52(emulator, pt) do
    case String.split(pt, ";", parts: 2) do
      [selection_char, data_base64]
      when selection_char in ["c", "p"] and data_base64 != "?" ->
        case Base.decode64(data_base64) do
          {:ok, data_str} ->
            Raxol.Core.Runtime.Log.debug(
              "OSC 52: Set Clipboard (#{selection_char}): '#{data_str}'"
            )

            # Only system clipboard is supported; both 'c' and 'p' map to Clipboard.copy
            Clipboard.copy(data_str)
            {:ok, emulator}

          :error ->
            Raxol.Core.Runtime.Log.warning_with_context(
              "OSC 52: Failed to decode base64 data: '#{data_base64}'",
              %{}
            )

            {:error, :decode_base64_failed, emulator}
        end

      [selection_char, "?"] when selection_char in ["c", "p"] ->
        Raxol.Core.Runtime.Log.debug(
          "OSC 52: Query Clipboard (#{selection_char})"
        )

        case Clipboard.paste() do
          {:ok, content} ->
            response_data = Base.encode64(content)
            response = "\e]52;#{selection_char};#{response_data}\e\\"

            Raxol.Core.Runtime.Log.debug(
              "OSC 52: Response: #{inspect(response)}"
            )

            {:ok,
             %{emulator | output_buffer: emulator.output_buffer <> response}}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.warning_with_context(
              "OSC 52: Failed to get clipboard: #{inspect(reason)}",
              %{}
            )

            {:error, :clipboard_paste_failed, emulator}
        end

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Malformed OSC 52 sequence: PT='#{pt}'",
          %{}
        )

        {:error, :malformed_osc_52, emulator}
    end
  end

  # --- OSC 4 Helpers (Moved from Executor) ---

  @spec parse_osc4(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  defp parse_osc4(emulator, pt) do
    case String.split(pt, ";", parts: 2) do
      [c_str, spec_or_query] ->
        case Integer.parse(c_str) do
          {color_index, ""} when color_index >= 0 and color_index <= 255 ->
            case handle_osc4_color(emulator, color_index, spec_or_query) do
              {:ok, emu} -> {:ok, emu}
              {:error, reason, emu} -> {:error, reason, emu}
              emu when is_map(emu) -> {:ok, emu}
            end

          _ ->
            Raxol.Core.Runtime.Log.warning_with_context(
              "OSC 4: Invalid color index '#{c_str}'",
              %{}
            )

            {:error, :invalid_color_index, emulator}
        end

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "OSC 4: Malformed parameter string '#{pt}'",
          %{}
        )

        {:error, :malformed_osc4_param, emulator}
    end
  end

  @spec handle_osc4_color(Emulator.t(), integer(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  defp handle_osc4_color(emulator, color_index, "?") do
    Raxol.Core.Runtime.Log.debug("OSC 4: Query color index #{color_index}")
    # Query dynamic palette, then fallback to default_palette if not set
    case get_palette_color(emulator.color_palette, color_index) ||
           (emulator.default_palette &&
              get_palette_color(emulator.default_palette, color_index)) do
      {:ok, {r, g, b}} ->
        r_scaled = Integer.to_string(div(r * 65_535, 255), 16)
        g_scaled = Integer.to_string(div(g * 65_535, 255), 16)
        b_scaled = Integer.to_string(div(b * 65_535, 255), 16)
        spec_response = "rgb:#{r_scaled}/#{g_scaled}/#{b_scaled}"
        response_str = "\e]4;#{color_index};#{spec_response}\e\\"

        Raxol.Core.Runtime.Log.debug(
          "OSC 4: Response: #{inspect(response_str)}"
        )

        {:ok,
         %{emulator | output_buffer: emulator.output_buffer <> response_str}}

      _ ->
        {:error, :invalid_color_index, emulator}
    end
  end

  defp handle_osc4_color(emulator, color_index, spec) do
    # Set color
    case parse_color_spec(spec) do
      {:ok, {r, g, b}} ->
        Raxol.Core.Runtime.Log.debug(
          "OSC 4: Set color index #{color_index} to {#{r}, #{g}, #{b}}"
        )

        new_palette = Map.put(emulator.color_palette, color_index, {r, g, b})
        {:ok, %{emulator | color_palette: new_palette}}

      {:error, _reason} ->
        Raxol.Core.Runtime
        {:error, :invalid_color_spec, emulator}
    end
  end

  # Helper for safe palette access
  defp get_palette_color(palette, index)
       when is_integer(index) and index >= 0 and index <= 255 do
    case Map.get(palette, index) do
      nil -> {:error, :invalid_color_index}
      color -> {:ok, color}
    end
  end

  defp get_palette_color(_palette, _index), do: {:error, :invalid_color_index}

  @spec parse_color_spec(String.t()) ::
          {:ok, {r :: integer, g :: integer, b :: integer}}
          | {:error, String.t()}
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

          _ ->
            {:error, "invalid rgb: format"}
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

      # #RRGGBBAA (hex with alpha, 2 digits per component)
      String.starts_with?(spec, "#") and byte_size(spec) == 9 ->
        r_hex = String.slice(spec, 1..2)
        g_hex = String.slice(spec, 3..4)
        b_hex = String.slice(spec, 5..6)
        # Ignore alpha channel for now
        _a_hex = String.slice(spec, 7..8)

        with {r, ""} <- Integer.parse(r_hex, 16),
             {g, ""} <- Integer.parse(g_hex, 16),
             {b, ""} <- Integer.parse(b_hex, 16) do
          {:ok, {r, g, b}}
        else
          _ -> {:error, "invalid #RRGGBBAA hex value(s)"}
        end

      # rgb(r,g,b) (decimal, 0-255)
      String.match?(spec, ~r/^rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)$/) ->
        case Regex.run(~r/rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/, spec,
               capture: :all_but_first
             ) do
          [r_str, g_str, b_str] ->
            with {r, ""} <- Integer.parse(r_str),
                 {g, ""} <- Integer.parse(g_str),
                 {b, ""} <- Integer.parse(b_str),
                 true <- r >= 0 and r <= 255,
                 true <- g >= 0 and g <= 255,
                 true <- b >= 0 and b <= 255 do
              {:ok, {r, g, b}}
            else
              _ -> {:error, "rgb() values must be between 0 and 255"}
            end

          _ ->
            {:error, "invalid rgb() format"}
        end

      # rgb(r%,g%,b%) (percentage, 0-100%)
      String.match?(spec, ~r/^rgb\(\s*\d+%\s*,\s*\d+%\s*,\s*\d+%\s*\)$/) ->
        case Regex.run(~r/rgb\(\s*(\d+)%\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)/, spec,
               capture: :all_but_first
             ) do
          [r_str, g_str, b_str] ->
            with {r_pct, ""} <- Integer.parse(r_str),
                 {g_pct, ""} <- Integer.parse(g_str),
                 {b_pct, ""} <- Integer.parse(b_str),
                 true <- r_pct >= 0 and r_pct <= 100,
                 true <- g_pct >= 0 and g_pct <= 100,
                 true <- b_pct >= 0 and b_pct <= 100 do
              r = round(r_pct * 255 / 100)
              g = round(g_pct * 255 / 100)
              b = round(b_pct * 255 / 100)
              {:ok, {r, g, b}}
            else
              _ -> {:error, "rgb() percentage values must be between 0 and 100"}
            end

          _ ->
            {:error, "invalid rgb() percentage format"}
        end

      true ->
        {:error, "unsupported color format"}
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
          scaled_val = round(val * 255 / 65_535)
          # Alternative: simple bit shift approximation?
          # scaled_val = val >>> (len * 4 - 8) # if len > 2 ?
          {:ok, max(0, min(255, scaled_val))}

        _ ->
          :error
      end
    else
      :error
    end
  end
end
