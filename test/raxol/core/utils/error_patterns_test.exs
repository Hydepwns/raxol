defmodule Raxol.Core.Utils.ErrorPatternsTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Utils.ErrorPatterns

  # ── with_error_handling/2 ──────────────────────────────────────────

  describe "with_error_handling/2" do
    test "wraps a plain return value in {:ok, _}" do
      assert {:ok, 42} = ErrorPatterns.with_error_handling(fn -> 42 end)
    end

    test "passes through {:ok, _} tuples unchanged" do
      assert {:ok, :hello} = ErrorPatterns.with_error_handling(fn -> {:ok, :hello} end)
    end

    test "passes through {:error, _} tuples unchanged" do
      assert {:error, :boom} = ErrorPatterns.with_error_handling(fn -> {:error, :boom} end)
    end

    test "catches exceptions and returns {:error, {:exception, _}}" do
      result = ErrorPatterns.with_error_handling(fn -> raise "kaboom" end, log_errors: false)
      assert {:error, {:exception, %RuntimeError{message: "kaboom"}}} = result
    end

    test "catches arithmetic errors" do
      result = ErrorPatterns.with_error_handling(fn -> 1 / 0 end, log_errors: false)
      assert {:error, {:exception, %ArithmeticError{}}} = result
    end

    test "includes context in log (no crash when context supplied)" do
      assert {:error, _} =
               ErrorPatterns.with_error_handling(
                 fn -> {:error, :nope} end,
                 context: "my_operation"
               )
    end

    test "suppresses logging when log_errors: false" do
      # Should not raise or crash when logging is disabled
      assert {:error, {:exception, _}} =
               ErrorPatterns.with_error_handling(
                 fn -> raise "silent" end,
                 log_errors: false
               )
    end

    test "wraps non-tuple return values (lists, maps, strings)" do
      assert {:ok, [1, 2]} = ErrorPatterns.with_error_handling(fn -> [1, 2] end)
      assert {:ok, %{a: 1}} = ErrorPatterns.with_error_handling(fn -> %{a: 1} end)
      assert {:ok, "text"} = ErrorPatterns.with_error_handling(fn -> "text" end)
    end

    test "wraps nil return" do
      assert {:ok, nil} = ErrorPatterns.with_error_handling(fn -> nil end)
    end
  end

  # ── validate_params/2 ─────────────────────────────────────────────

  describe "validate_params/2" do
    test "returns :ok when all required keys are present" do
      assert :ok = ErrorPatterns.validate_params(%{name: "a", age: 1}, [:name, :age])
    end

    test "returns :ok when params has extra keys beyond required" do
      assert :ok = ErrorPatterns.validate_params(%{a: 1, b: 2, c: 3}, [:a, :b])
    end

    test "returns :ok for empty required keys list" do
      assert :ok = ErrorPatterns.validate_params(%{anything: true}, [])
    end

    test "returns :ok for empty map with empty required keys" do
      assert :ok = ErrorPatterns.validate_params(%{}, [])
    end

    test "returns error with single missing key" do
      assert {:error, {:missing_params, [:email]}} =
               ErrorPatterns.validate_params(%{name: "a"}, [:name, :email])
    end

    test "returns error listing all missing keys" do
      result = ErrorPatterns.validate_params(%{}, [:x, :y, :z])
      assert {:error, {:missing_params, missing}} = result
      assert Enum.sort(missing) == [:x, :y, :z]
    end

    test "works with string keys" do
      assert :ok = ErrorPatterns.validate_params(%{"foo" => 1}, ["foo"])

      assert {:error, {:missing_params, ["bar"]}} =
               ErrorPatterns.validate_params(%{"foo" => 1}, ["foo", "bar"])
    end

    test "treats nil values as present (key exists)" do
      assert :ok = ErrorPatterns.validate_params(%{key: nil}, [:key])
    end
  end

  # ── init_with_validation/2 ─────────────────────────────────────────

  describe "init_with_validation/2" do
    test "returns {:ok, state} when validator succeeds" do
      validator = fn args -> {:ok, %{data: args}} end
      assert {:ok, %{data: :my_args}} = ErrorPatterns.init_with_validation(:my_args, validator)
    end

    test "returns {:stop, reason} when validator fails" do
      validator = fn _args -> {:error, :bad_config} end
      assert {:stop, :bad_config} = ErrorPatterns.init_with_validation(:anything, validator)
    end

    test "passes args through to the validator function" do
      validator = fn %{port: port} = args ->
        if port > 0, do: {:ok, args}, else: {:error, :invalid_port}
      end

      assert {:ok, %{port: 8080}} = ErrorPatterns.init_with_validation(%{port: 8080}, validator)
      assert {:stop, :invalid_port} = ErrorPatterns.init_with_validation(%{port: -1}, validator)
    end
  end

  # ── call_with_timeout/3 ───────────────────────────────────────────

  describe "call_with_timeout/3" do
    test "returns {:ok, reply} on successful GenServer.call" do
      {:ok, pid} = start_echo_server()
      assert {:ok, :pong} = ErrorPatterns.call_with_timeout(pid, :ping, 5000)
      GenServer.stop(pid)
    end

    test "wraps arbitrary reply values in {:ok, _}" do
      {:ok, pid} = start_echo_server()
      assert {:ok, :hello} = ErrorPatterns.call_with_timeout(pid, {:echo, :hello}, 5000)
      GenServer.stop(pid)
    end

    test "returns {:error, :timeout} when server is too slow" do
      {:ok, pid} = start_slow_server(2000)

      assert {:error, :timeout} = ErrorPatterns.call_with_timeout(pid, :slow, 50)

      # Clean up (the server is still alive, just slow)
      GenServer.stop(pid, :normal, 5000)
    end

    test "returns {:error, {:exit, _}} when server is dead" do
      {:ok, pid} = start_echo_server()
      GenServer.stop(pid)

      # Small sleep to ensure process is fully down
      Process.sleep(10)

      assert {:error, {:exit, _reason}} = ErrorPatterns.call_with_timeout(pid, :ping, 1000)
    end

    test "uses default timeout of 5000ms" do
      {:ok, pid} = start_echo_server()
      # Should succeed well within 5 seconds
      assert {:ok, :pong} = ErrorPatterns.call_with_timeout(pid, :ping)
      GenServer.stop(pid)
    end
  end

  # ── retry_with_backoff/2 ──────────────────────────────────────────

  describe "retry_with_backoff/2" do
    test "returns {:ok, _} immediately when function succeeds on first try" do
      assert {:ok, :done} = ErrorPatterns.retry_with_backoff(fn -> {:ok, :done} end)
    end

    test "retries until success within max_retries" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      func = fn ->
        n = Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)

        if n < 3 do
          {:error, :not_yet}
        else
          {:ok, :finally}
        end
      end

      result = ErrorPatterns.retry_with_backoff(func, max_retries: 5, base_delay: 10)
      assert {:ok, :finally} = result

      # Verify it took exactly 3 attempts
      assert Agent.get(counter, & &1) == 3

      Agent.stop(counter)
    end

    test "returns error after exhausting all retries" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      func = fn ->
        Agent.update(counter, &(&1 + 1))
        {:error, :always_fails}
      end

      result = ErrorPatterns.retry_with_backoff(func, max_retries: 3, base_delay: 10)
      assert {:error, :always_fails} = result

      # Should have been called exactly 3 times (initial + 2 retries)
      assert Agent.get(counter, & &1) == 3

      Agent.stop(counter)
    end

    test "returns {:error, :max_retries_exceeded} when max_retries is 0" do
      assert {:error, :max_retries_exceeded} =
               ErrorPatterns.retry_with_backoff(
                 fn -> {:ok, :should_not_run} end,
                 max_retries: 0
               )
    end

    test "preserves the last error reason on final failure" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      func = fn ->
        n = Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)
        {:error, :"attempt_#{n}"}
      end

      result = ErrorPatterns.retry_with_backoff(func, max_retries: 2, base_delay: 10)
      assert {:error, :attempt_2} = result

      Agent.stop(counter)
    end

    test "applies exponential backoff between retries" do
      {:ok, timestamps} = Agent.start_link(fn -> [] end)

      func = fn ->
        Agent.update(timestamps, fn ts -> [System.monotonic_time(:millisecond) | ts] end)
        {:error, :fail}
      end

      ErrorPatterns.retry_with_backoff(func, max_retries: 3, base_delay: 50)

      times = Agent.get(timestamps, &Enum.reverse/1)
      Agent.stop(timestamps)

      # We expect 3 attempts with delays: ~50ms (50*2^0), ~100ms (50*2^1)
      # The first attempt has no preceding delay, second has ~50ms, third has ~100ms
      [t1, t2, t3] = times
      gap1 = t2 - t1
      gap2 = t3 - t2

      # Allow generous tolerance for CI; just verify backoff ordering
      assert gap1 >= 30, "first gap #{gap1}ms should be >= 30ms (target 50ms)"
      assert gap2 >= 60, "second gap #{gap2}ms should be >= 60ms (target 100ms)"
      assert gap2 > gap1, "second gap should be larger than first (exponential)"
    end

    test "succeeds on the very last allowed attempt" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      func = fn ->
        n = Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)

        # Succeed on attempt 3 (the last one when max_retries: 3)
        if n == 3, do: {:ok, :last_chance}, else: {:error, :not_yet}
      end

      assert {:ok, :last_chance} =
               ErrorPatterns.retry_with_backoff(func, max_retries: 3, base_delay: 10)

      Agent.stop(counter)
    end
  end

  # ── with_cleanup/2 ────────────────────────────────────────────────

  describe "with_cleanup/2" do
    test "returns success without calling cleanup" do
      {:ok, flag} = Agent.start_link(fn -> false end)

      result =
        ErrorPatterns.with_cleanup(
          fn -> {:ok, :good} end,
          fn ->
            Agent.update(flag, fn _ -> true end)
            :ok
          end
        )

      assert {:ok, :good} = result
      refute Agent.get(flag, & &1), "cleanup should NOT be called on success"

      Agent.stop(flag)
    end

    test "calls cleanup and returns error on failure" do
      {:ok, flag} = Agent.start_link(fn -> false end)

      result =
        ErrorPatterns.with_cleanup(
          fn -> {:error, :broken} end,
          fn ->
            Agent.update(flag, fn _ -> true end)
            :ok
          end
        )

      assert {:error, :broken} = result
      assert Agent.get(flag, & &1), "cleanup SHOULD be called on error"

      Agent.stop(flag)
    end

    test "preserves the original error reason after cleanup" do
      result =
        ErrorPatterns.with_cleanup(
          fn -> {:error, {:complex, :reason, 123}} end,
          fn -> :ok end
        )

      assert {:error, {:complex, :reason, 123}} = result
    end

    test "cleanup is called exactly once on error" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      ErrorPatterns.with_cleanup(
        fn -> {:error, :oops} end,
        fn ->
          Agent.update(counter, &(&1 + 1))
          :ok
        end
      )

      assert Agent.get(counter, & &1) == 1
      Agent.stop(counter)
    end
  end

  # ── Test helpers ──────────────────────────────────────────────────

  defmodule EchoServer do
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, :ok, opts)
    end

    @impl true
    def init(:ok), do: {:ok, %{}}

    @impl true
    def handle_call(:ping, _from, state), do: {:reply, :pong, state}
    def handle_call({:echo, msg}, _from, state), do: {:reply, msg, state}
  end

  defmodule SlowServer do
    use GenServer

    def start_link(delay) do
      GenServer.start_link(__MODULE__, delay)
    end

    @impl true
    def init(delay), do: {:ok, %{delay: delay}}

    @impl true
    def handle_call(:slow, _from, %{delay: delay} = state) do
      Process.sleep(delay)
      {:reply, :done, state}
    end
  end

  defp start_echo_server do
    EchoServer.start_link()
  end

  defp start_slow_server(delay_ms) do
    SlowServer.start_link(delay_ms)
  end
end
