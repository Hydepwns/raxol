# defmodule Raxol.Core.Runtime.DebugTest do
#   use ExUnit.Case, async: true
#   use ExUnit.CaptureLog
#
#   alias Raxol.Core.Runtime.Debug
#
#   # Define a mock application module for state context
#   defmodule TestApp do
#     defstruct name: "TestApp"
#   end
#
#   # Helper to create a basic state map for testing
#   defp create_test_state(opts \\ []) do
#     default_model = %{
#       counter: 10,
#       user: %{name: "Test User", password: "secret123"},
#       settings: %{theme: "dark", public_preference: true},
#       api_token: "abcdef123456"
#     }
#     default_metrics = %{start_time: 1_746_304_248_788, frame_count: 600, render_times: [10, 12, 15, 8, 9], last_render_time: 10}
#
#     Map.merge(%{
#       app_name: :test_app,
#       app_module: TestApp,
#       model: default_model,
#       debug_mode: true,
#       environment: :terminal,
#       width: 100,
#       height: 50,
#       fps: 60,
#       uptime: 120,
#       metrics: default_metrics,
#       screen_buffer: %{
#         width: 100,
#         height: 50,
#         cells: %{{0, 0} => %{char: "A", fg: :white, bg: :black}}
#       }
#     }, Map.new(opts))
#   end
#
#   describe "init_metrics/1" do
#     test 'initializes metrics in the state' do
#       state = create_test_state(metrics: nil)
#       new_state = Debug.init_metrics(state)
#
#       assert is_map(new_state.metrics)
#       assert Map.has_key?(new_state.metrics, :start_time)
#       assert new_state.metrics.frame_count == 0
#       assert new_state.metrics.render_times == []
#       assert new_state.metrics.last_render_time == 0
#     end
#
#     test 'does not overwrite existing metrics' do
#       initial_metrics = %{
#         start_time: 123,
#         frame_count: 10,
#         render_times: [5],
#         last_render_time: 5
#       }
#       state = create_test_state(metrics: initial_metrics)
#       new_state = Debug.init_metrics(state)
#
#       assert new_state.metrics == initial_metrics
#     end
#   end
#
#   describe "format_state_for_debug/1" do
#     test 'formats state correctly for debugging' do
#       state = create_test_state()
#       formatted = Debug.format_state_for_debug(state)
#
#       assert is_binary(formatted)
#       # Basic checks for presence of keys
#       assert formatted =~ "app_name: :test_app"
#       assert formatted =~ "width: 100"
#       assert formatted =~ "height: 50"
#       assert formatted =~ "fps: 60"
#       assert formatted =~ "uptime: 120"
#       assert formatted =~ "environment: :terminal"
#       assert formatted =~ "debug_mode: true"
#       # Check for model presence
#       assert formatted =~ "model: %{"
#       # Check for metrics presence
#       assert formatted =~ "metrics: %{"
#       # Check for buffer info (size, not full content)
#       assert formatted =~ "screen_buffer: %{width: 100, height: 50}"
#       # Ensure sensitive fields from model are redacted
#       refute formatted =~ "secret123"
#       refute formatted =~ "abcdef123456"
#       # Ensure public preference is kept
#       assert formatted =~ "public_preference: true"
#     end
#
#     test 'handles state without metrics' do
#       state = create_test_state(metrics: nil)
#       formatted = Debug.format_state_for_debug(state)
#       assert is_binary(formatted)
#       refute formatted =~ "metrics:"
#     end
#
#     test 'handles state without model' do
#       state = create_test_state(model: nil)
#       formatted = Debug.format_state_for_debug(state)
#       assert is_binary(formatted)
#       refute formatted =~ "model:"
#     end
#   end
#
#   describe "redact_sensitive_data/1" do
#     test 'redacts common sensitive keys' do
#       data = %{
#         user: "admin",
#         password: "password123",
#         token: "secret_token",
#         api_key: "key_live_abcdef",
#         secret: "my_secret",
#         non_sensitive: "visible"
#       }
#       redacted = Debug.redact_sensitive_data(data)
#
#       assert redacted.user == "admin"
#       assert redacted.password == "[REDACTED]"
#       assert redacted.token == "[REDACTED]"
#       assert redacted.api_key == "[REDACTED]"
#       assert redacted.secret == "[REDACTED]"
#       assert redacted.non_sensitive == "visible"
#     end
#
#     test 'handles nested maps' do
#       data = %{
#         config: %{
#           db_pass: "db_secret",
#           host: "localhost"
#         },
#         credentials: %{
#           auth_token: "auth123"
#         }
#       }
#       redacted = Debug.redact_sensitive_data(data)
#
#       assert redacted.config.db_pass == "[REDACTED]"
#       assert redacted.config.host == "localhost"
#       assert redacted.credentials.auth_token == "[REDACTED]"
#     end
#
#     test 'handles lists' do
#       data = [%{password: "pass1"}, %{secret: "sec2"}]
#       redacted = Debug.redact_sensitive_data(data)
#
#       assert redacted == [%{password: "[REDACTED]"}, %{secret: "[REDACTED]"}]
#     end
#
#     test 'does not redact non-map/list structures' do
#       data = "just a string"
#       assert Debug.redact_sensitive_data(data) == data
#
#       data_tuple = {:password, "pass"}
#       assert Debug.redact_sensitive_data(data_tuple) == data_tuple
#     end
#   end
#
#   describe "log/4" do
#     test 'logs message with level and state context' do
#       state = create_test_state()
#       log_output = capture_log(fn ->
#         Debug.log(state, :info, "Test log message")
#       end)
#
#       assert log_output =~ "[info]" # Log level
#       assert log_output =~ "Test log message" # Message content
#       # Check for some state context (keys, not sensitive values)
#       assert log_output =~ "app_name: :test_app"
#       assert log_output =~ "width: 100"
#       refute log_output =~ "secret123" # Ensure redaction
#     end
#
#     test 'includes metadata in log' do
#       state = create_test_state()
#       metadata = [custom_field: "custom_value"]
#       log_output = capture_log(fn ->
#         Debug.log(state, :info, "Message with metadata", metadata)
#       end)
#
#       assert log_output =~ "[info]" # Log level
#       assert log_output =~ "Message with metadata" # Message content
#       # Check for state context
#       assert log_output =~ "app_name: :test_app"
#       # Check for metadata
#       assert log_output =~ inspect(metadata)
#       refute log_output =~ "secret123" # Ensure redaction
#     end
#
#     test 'does not log if debug_mode is false' do
#       state = create_test_state(debug_mode: false)
#       log_output = capture_log(fn ->
#         Debug.log(state, :info, "Should not appear")
#       end)
#
#       assert log_output == ""
#     end
#   end
#
#   describe "record_render/2" do
#     test 'updates metrics with render time and increments frame count' do
#       state = create_test_state()
#       initial_metrics = state.metrics
#       render_time_us = 15_000 # 15ms
#
#       new_state = Debug.record_render(state, render_time_us)
#       new_metrics = new_state.metrics
#
#       assert new_metrics.frame_count == initial_metrics.frame_count + 1
#       assert new_metrics.last_render_time == render_time_us
#       assert List.last(new_metrics.render_times) == render_time_us
#       assert length(new_metrics.render_times) == length(initial_metrics.render_times) + 1
#     end
#
#     test 'keeps only last N render times' do
#       # Simulate state with max render times already recorded
#       max_times = Application.get_env(:raxol, :debug_max_render_times, 100)
#       initial_render_times = Enum.to_list(1..max_times)
#       state = create_test_state(
#         metrics: %{
#           render_times: initial_render_times,
#           frame_count: max_times,
#           start_time: 0,
#           last_render_time: max_times
#         }
#       )
#
#       render_time_us = 1000
#       new_state = Debug.record_render(state, render_time_us)
#       new_metrics = new_state.metrics
#
#       assert length(new_metrics.render_times) == max_times
#       assert List.last(new_metrics.render_times) == render_time_us
#       # Assert the oldest time (1) was removed
#       refute 1 in new_metrics.render_times
#       # Assert a time slightly newer than the oldest (e.g., 2) is still present
#       assert 2 in new_metrics.render_times
#     end
#
#     test 'does nothing when metrics not initialized' do
#       state = create_test_state(metrics: nil)
#       # Ensure no error is raised
#       result = Debug.record_render(state, 10)
#       # State should be unchanged
#       assert result == state
#     end
#   end
#
#   describe "get_debug_info/1" do
#     test 'returns formatted debug information string' do
#       state = create_test_state()
#       info = Debug.get_debug_info(state)
#
#       assert is_binary(info)
#       # Check for key sections
#       assert info =~ "--- State ---"
#       assert info =~ "--- Metrics ---"
#       assert info =~ "Avg Render Time:"
#       assert info =~ "FPS:"
#       # Check for state content (non-sensitive)
#       assert info =~ "app_name: :test_app"
#       refute info =~ "secret123"
#     end
#
#     test 'handles state without metrics gracefully' do
#       state = create_test_state(metrics: nil)
#       info = Debug.get_debug_info(state)
#
#       assert is_binary(info)
#       assert info =~ "--- State ---"
#       refute info =~ "--- Metrics ---"
#     end
#
#     test 'calculates FPS correctly' do
#       # Simulate 1 second elapsed, 60 frames
#       start_time = System.monotonic_time() - 1_000_000_000 # 1 second ago in ns
#       state = create_test_state(
#         metrics: %{
#           start_time: start_time,
#           frame_count: 60,
#           render_times: [],
#           last_render_time: 0
#         }
#       )
#       info = Debug.get_debug_info(state)
#
#       assert info =~ "FPS: 60.00"
#     end
#
#     test 'calculates Avg Render Time correctly' do
#       render_times = [10_000, 20_000, 30_000] # 10ms, 20ms, 30ms
#       state = create_test_state(
#         metrics: %{
#           start_time: 0,
#           frame_count: 3,
#           render_times: render_times,
#           last_render_time: 30_000
#         }
#       )
#       info = Debug.get_debug_info(state)
#
#       assert info =~ "Avg Render Time: 20.00 ms"
#     end
#   end
# end
