defmodule Raxol.System.DeltaUpdaterTest do
  # Enable async for Mox
  use ExUnit.Case, async: true
  import Mox

  alias Raxol.System.DeltaUpdater
  alias Raxol.System.DeltaUpdaterSystemAdapterBehaviour

  # Define the mock for the adapter behaviour
  Mox.defmock(DeltaUpdaterSystemAdapterMock,
    for: DeltaUpdaterSystemAdapterBehaviour
  )

  describe "check_delta_availability/1" do
    # Add Mox verification
    setup :verify_on_exit!

    setup do
      # Configure the application to use our mock adapter
      Application.put_env(
        :raxol,
        :system_adapter,
        DeltaUpdaterSystemAdapterMock
      )

      :ok
    end

    test ~c"returns delta info when delta is available" do
      # Mock the adapter behaviour
      DeltaUpdaterSystemAdapterMock
      |> expect(:http_get, fn url ->
        if url == "https://api.github.com/repos/raxol/raxol/releases" do
          body = """
          [
            {
              "tag_name": "v1.2.0",
              "assets": [
                {
                  "name": "raxol-1.2.0-macos.tar.gz",
                  "size": 15000000,
                  "browser_download_url": "https://github.com/username/raxol/releases/download/v1.2.0/raxol-1.2.0-macos.tar.gz"
                },
                {
                  "name": "raxol-delta-1.1.0-1.2.0-macos.bin",
                  "size": 1500000,
                  "browser_download_url": "https://github.com/username/raxol/releases/download/v1.2.0/raxol-delta-1.1.0-1.2.0-macos.bin"
                }
              ]
            }
          ]
          """

          {:ok, body}
        else
          {:error, :unexpected_url}
        end
      end)

      # Test with a version that has delta available
      result = DeltaUpdater.check_delta_availability("1.2.0")

      assert match?({:ok, _}, result)
      {:ok, delta_info} = result
      assert delta_info.delta_size == 1_500_000
      assert delta_info.full_size == 15_000_000
      assert delta_info.savings_percent == 90
    end

    test ~c"returns error when delta is not available" do
      # Mock the adapter behaviour
      DeltaUpdaterSystemAdapterMock
      |> expect(:http_get, fn url ->
        if url == "https://api.github.com/repos/raxol/raxol/releases" do
          body = """
          [
            {
              "tag_name": "v1.3.0",
              "assets": [
                {
                  "name": "raxol-1.3.0-macos.tar.gz",
                  "size": 16000000,
                  "browser_download_url": "https://github.com/username/raxol/releases/download/v1.3.0/raxol-1.3.0-macos.tar.gz"
                },
                {
                  "name": "raxol-1.3.0-linux.tar.gz",
                  "size": 15000000,
                  "browser_download_url": "https://github.com/username/raxol/releases/download/v1.3.0/raxol-1.3.0-linux.tar.gz"
                }
              ]
            }
          ]
          """

          {:ok, body}
        else
          {:error, :unexpected_url}
        end
      end)

      # Test with a version that doesn't have delta available
      result = DeltaUpdater.check_delta_availability("1.3.0")

      assert match?({:error, _}, result)
    end
  end

  # NOTE: We don't test apply_delta_update in unit tests since it requires
  # actual execution of system commands and file operations. Integration tests
  # would be more appropriate for that functionality.
end
