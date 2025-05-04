# defmodule RaxolWeb.TerminalChannelTest do
#   use RaxolWeb.ChannelCase
#   use ExUnit.Case, async: false # Ensure tests run sequentially due to mocking
#
#   alias RaxolWeb.TerminalChannel
#   alias Raxol.Terminal.Emulator
#   alias Raxol.Core.Events.Event
#   # Mock the Emulator behaviour if needed, or use Meck if mocking specific functions
#
#   # Import Meck for function mocking
#   import Meck
#
#   # Ensure Meck is validated on exit
#   setup do
#     # Mock Raxol.Terminal.Emulator functions needed by the channel
#     :ok = Meck.new(Emulator, [:passthrough])
#     # Expect calls as needed, e.g.:
#     expect(Emulator, :new, fn _, _, _, _ -> {:ok, %Emulator{}} end)
#     expect(Emulator, :process_input, fn _emulator, _input -> {:ok, %Emulator{}} end)
#     expect(Emulator, :resize, fn _emulator, _width, _height -> %Emulator{} end)
#     expect(Emulator, :get_buffer_content, fn _emulator -> "buffer content" end)
#     expect(Emulator, :get_scrollback_content, fn _emulator -> "scrollback content" end)
#     expect(Emulator, :apply_theme, fn _emulator, _theme -> %Emulator{} end)
#
#     on_exit(fn ->
#       Meck.unload(Emulator)
#     end)
#
#     # Use the socket helper from ChannelCase
#     {:ok, socket} = socket(TerminalChannel, "user_socket:1", %{user_id: 1})
#     {:ok, socket: socket}
#   end
#
#   describe "join/3" do
#     test "joins the terminal channel successfully", %{socket: socket} do
#       {:ok, _reply, socket_assigned} = subscribe_and_join(socket, "terminal:lobby", %{})
#
#       assert socket_assigned.assigns[:emulator]
#       assert socket_assigned.assigns[:user_id] == 1
#       assert_broadcast "presence_diff", %{joins: %{}, leaves: %{}}
#     end
#
#     test "handles join error" do
#       # Simulate an error during Emulator.new by changing the expectation
#       Meck.new(Emulator, [:passthrough])
#       expect(Emulator, :new, fn _, _, _, _ -> {:error, :init_failed} end)
#       # Use the socket helper from ChannelCase
#       {:ok, socket} = socket(TerminalChannel, "user_socket:2", %{user_id: 2})
#
#       assert {:error, %{reason: "emulator_init_failed"}} == subscribe_and_join(socket, "terminal:lobby", %{})
#
#       Meck.unload(Emulator)
#     end
#   end
#
#   describe "handle_in/3" do
#     setup %{socket: socket} do
#       {:ok, _reply, socket_assigned} = subscribe_and_join(socket, "terminal:lobby", %{})
#       {:ok, socket: socket_assigned}
#     end
#
#     test "handles text input", %{socket: socket} do
#       Meck.expect(Emulator, :process_input, fn _emulator, input ->
#         assert input == "hello"
#         {:ok, %Emulator{}} # Return a mock emulator state
#       end)
#
#       {:noreply, _socket} = TerminalChannel.handle_in("input", %{"type" => "text", "data" => "hello"}, socket)
#       assert_broadcast "terminal_output", %{output: "buffer content"}
#       assert Meck.called(Emulator, :process_input, 1)
#     end
#
#     test "handles control characters", %{socket: socket} do
#       Meck.expect(Emulator, :process_input, fn _emulator, input ->
#         assert input == "\x03" # Example: Ctrl+C
#         {:ok, %Emulator{}} # Return a mock emulator state
#       end)
#
#       {:noreply, _socket} = TerminalChannel.handle_in("input", %{"type" => "control", "data" => "\x03"}, socket)
#       assert_broadcast "terminal_output", %{output: "buffer content"}
#       assert Meck.called(Emulator, :process_input, 1)
#     end
#
#     test "handles terminal resize", %{socket: socket} do
#       Meck.expect(Emulator, :resize, fn _emulator, width, height ->
#         assert width == 100
#         assert height == 30
#         %Emulator{} # Return mock emulator
#       end)
#
#       {:noreply, _socket} = TerminalChannel.handle_in("resize", %{"width" => 100, "height" => 30}, socket)
#       assert_broadcast "terminal_output", %{output: "buffer content"}
#       assert Meck.called(Emulator, :resize, 1)
#     end
#
#     test "handles scrolling", %{socket: socket} do
#       # This assumes scrolling might trigger a specific event or state change
#       # Mock the expected behavior of the emulator when scrolled
#       # For example, maybe it updates scrollback or affects buffer content
#       # For now, just expect get_scrollback_content to be called
#       Meck.expect(Emulator, :get_scrollback_content, fn _emulator -> "updated scrollback" end)
#
#       {:noreply, _socket} = TerminalChannel.handle_in("scroll", %{"delta" => -10}, socket)
#       # Assert broadcast might change depending on scroll implementation
#       assert_broadcast "terminal_scrollback", %{scrollback: "updated scrollback"}
#       assert Meck.called(Emulator, :get_scrollback_content, 1)
#     end
#
#     test "handles theme changes", %{socket: socket} do
#       Meck.expect(Emulator, :apply_theme, fn _emulator, theme ->
#         assert theme == "solarized_dark"
#         %Emulator{}
#       end)
#
#       {:noreply, _socket} = TerminalChannel.handle_in("set_theme", %{"theme" => "solarized_dark"}, socket)
#       assert_broadcast "terminal_output", %{output: "buffer content"}
#       assert Meck.called(Emulator, :apply_theme, 1)
#     end
#
#     test "handles invalid events" do
#       {:noreply, socket_after_invalid} = TerminalChannel.handle_in("invalid_event", %{}, socket)
#       # Assert no crash and socket remains unchanged
#       assert socket_after_invalid == socket
#     end
#   end
#
#   describe "terminate/2" do
#     setup %{socket: socket} do
#       {:ok, _reply, socket_assigned} = subscribe_and_join(socket, "terminal:lobby", %{})
#       {:ok, socket: socket_assigned}
#     end
#
#     test "cleans up on disconnect", %{socket: socket} do
#       # Mock any cleanup functions if the Emulator has them
#       # expect(Emulator, :cleanup, fn _emulator -> :ok end)
#
#       # Simulate channel termination
#       :ok = TerminalChannel.terminate(:shutdown, socket)
#
#       # Verify any cleanup expectations
#       # assert Meck.called(Emulator, :cleanup, 1)
#       # Assert presence is updated (if applicable)
#       # assert_broadcast "presence_diff", %{joins: %{}, leaves: %{"user_socket:1" => _}}
#     end
#   end
#
# end
