defmodule Raxol.Core.Runtime.SubscriptionTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Subscription

  describe "new/2" do
    test "creates a new subscription with given type and data" do
      sub = Subscription.new(:interval, %{interval: 1000, message: :tick})

      assert %Subscription{
               type: :interval,
               data: %{interval: 1000, message: :tick}
             } = sub
    end
  end

  describe "interval/2" do
    test "creates an interval subscription with default options" do
      sub = Subscription.interval(1000, :tick)
      assert %Subscription{type: :interval} = sub

      assert %{
               interval: 1000,
               message: :tick,
               start_immediately: false,
               jitter: 0
             } = sub.data
    end

    test "creates an interval subscription with custom options" do
      sub =
        Subscription.interval(1000, :tick, start_immediately: true, jitter: 100)

      assert %Subscription{type: :interval} = sub

      assert %{
               interval: 1000,
               message: :tick,
               start_immediately: true,
               jitter: 100
             } = sub.data
    end

    test "validates interval is positive" do
      assert_raise FunctionClauseError, fn ->
        Subscription.interval(0, :tick)
      end

      assert_raise FunctionClauseError, fn ->
        Subscription.interval(-1000, :tick)
      end
    end
  end

  describe "events/1" do
    test "creates an events subscription" do
      events = [:key_press, :mouse_click]
      sub = Subscription.events(events)
      assert %Subscription{type: :events, data: ^events} = sub
    end

    test "requires event types to be a list" do
      assert_raise FunctionClauseError, fn ->
        Subscription.events(:key_press)
      end
    end
  end

  describe "file_watch/2" do
    test "creates a file watch subscription with default events" do
      sub = Subscription.file_watch("test.txt")
      assert %Subscription{type: :file_watch} = sub
      assert %{path: "test.txt", events: [:modify]} = sub.data
    end

    test "creates a file watch subscription with custom events" do
      events = [:modify, :delete, :create]
      sub = Subscription.file_watch("test.txt", events)
      assert %Subscription{type: :file_watch} = sub
      assert %{path: "test.txt", events: ^events} = sub.data
    end

    test "requires events to be a list" do
      assert_raise FunctionClauseError, fn ->
        Subscription.file_watch("test.txt", :modify)
      end
    end
  end

  describe "custom/2" do
    test "creates a custom subscription" do
      module = MyEventSource
      args = %{config: :value}
      sub = Subscription.custom(module, args)
      assert %Subscription{type: :custom} = sub
      assert %{module: ^module, args: ^args} = sub.data
    end
  end

  describe "start/2" do
    setup do
      context = %{pid: self()}
      {:ok, context: context}
    end

    test "starts an interval subscription", %{context: context} do
      sub = Subscription.interval(50, :tick, start_immediately: true)
      assert {:ok, {:interval, _timer_ref}} = Subscription.start(sub, context)

      # Verify immediate message
      assert_receive {:subscription, :tick}, 100

      # Verify interval message
      assert_receive {:subscription, :tick}, 100
    end

    test "starts an events subscription", %{context: context} do
      sub = Subscription.events([:test_event])
      assert {:ok, {:events, _id}} = Subscription.start(sub, context)
    end

    test "starts a file watch subscription", %{context: context} do
      sub = Subscription.file_watch("test.txt")
      assert {:ok, {:file_watch, pid}} = Subscription.start(sub, context)
      assert is_pid(pid)
    end
  end

  describe "stop/1" do
    setup do
      context = %{pid: self()}
      {:ok, context: context}
    end

    test "stops an interval subscription", %{context: context} do
      sub = Subscription.interval(50, :tick)
      {:ok, sub_id} = Subscription.start(sub, context)
      assert :ok = Subscription.stop(sub_id)
    end

    test "returns error for invalid subscription id" do
      assert {:error, :invalid_subscription} = Subscription.stop(:invalid)
    end
  end
end
