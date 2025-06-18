defmodule Raxol.Terminal.ANSI.DeviceStatus do
  @moduledoc """
  Handles terminal state queries and device status reports.
  This includes cursor position reports, device status reports,
  and terminal identification queries.
  """

  @type device_status :: %{
          cursor_position: {integer(), integer()},
          device_type: String.t(),
          version: String.t(),
          terminal_id: String.t(),
          features: MapSet.t()
        }

  @doc """
  Creates a new device status map with default values.
  """
  @spec new() :: device_status()
  def new do
    %{
      cursor_position: {1, 1},
      device_type: "VT100",
      version: "1.0.0",
      terminal_id: "00000000",
      features:
        MapSet.new([
          :advanced_video_option,
          :sixel_graphics,
          :mouse_support,
          :bracketed_paste,
          :focus_events,
          :alternate_screen
        ])
    }
  end

  @doc """
  Generates a cursor position report.
  """
  @spec cursor_position_report(device_status()) :: String.t()
  def cursor_position_report(%{cursor_position: {row, col}}) do
    "\e[#{row};#{col}R"
  end

  @doc """
  Generates a device status report.
  """
  @spec device_status_report(device_status(), :ok | :malfunction) :: String.t()
  def device_status_report(_status, report_type) do
    case report_type do
      :ok -> "\e[0n"
      :malfunction -> "\e[3n"
    end
  end

  @doc """
  Generates a primary device attributes report.
  """
  @spec primary_device_attributes(device_status()) :: String.t()
  def primary_device_attributes(%{device_type: _type, features: features}) do
    feature_codes = features_to_codes(features)
    "\e[?1;#{feature_codes}c"
  end

  @doc """
  Generates a secondary device attributes report.
  """
  @spec secondary_device_attributes(device_status()) :: String.t()
  def secondary_device_attributes(%{version: version}) do
    {major, minor, patch} = parse_version(version)
    "\e[>#{major};#{minor}#{patch};0c"
  end

  @doc """
  Generates a tertiary device attributes report.
  """
  @spec tertiary_device_attributes(device_status()) :: String.t()
  def tertiary_device_attributes(%{terminal_id: id}) do
    "\eP!|#{id}\e\\"
  end

  @doc """
  Generates a fourth device attributes report.
  """
  @spec fourth_device_attributes(device_status()) :: String.t()
  def fourth_device_attributes(%{device_type: type, version: version}) do
    "\eP>|#{type} #{version}\e\\"
  end

  @doc """
  Updates the cursor position in the device status.
  """
  @spec update_cursor_position(device_status(), {integer(), integer()}) ::
          device_status()
  def update_cursor_position(status, {row, col}) do
    %{status | cursor_position: {row, col}}
  end

  # Private helper functions

  defp features_to_codes(features) do
    codes = %{
      advanced_video_option: 2,
      sixel_graphics: 4,
      mouse_support: 8,
      bracketed_paste: 16,
      focus_events: 32,
      alternate_screen: 64
    }

    features
    |> Enum.map(&Map.get(codes, &1, 0))
    |> Enum.sum()
    |> to_string()
  end

  defp parse_version(version) do
    case String.split(version, ".") do
      [major, minor, patch] ->
        {String.to_integer(major), String.to_integer(minor),
         String.to_integer(patch)}

      _ ->
        # Default version if parsing fails
        {1, 0, 0}
    end
  end
end
