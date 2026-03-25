defmodule Raxol.Swarm.CommsManagerTest do
  use ExUnit.Case, async: false

  alias Raxol.Swarm.CommsManager

  setup do
    name = :"comms_#{System.unique_integer([:positive])}"
    {:ok, pid} = CommsManager.start_link(name: name, flush_interval_ms: 60_000)
    %{comms: name, pid: pid}
  end

  describe "link quality" do
    test "unknown node reports disconnected", %{comms: comms} do
      assert :disconnected = CommsManager.get_link_quality(comms, :unknown@host)
    end

    test "update_link sets quality based on RTT", %{comms: comms} do
      CommsManager.update_link(comms, :fast@host, 5.0)
      Process.sleep(10)
      assert :excellent = CommsManager.get_link_quality(comms, :fast@host)

      CommsManager.update_link(comms, :slow@host, 150.0)
      Process.sleep(10)
      assert :degraded = CommsManager.get_link_quality(comms, :slow@host)
    end

    test "mark_disconnected sets quality", %{comms: comms} do
      CommsManager.update_link(comms, :node@host, 5.0)
      Process.sleep(10)
      assert :excellent = CommsManager.get_link_quality(comms, :node@host)

      CommsManager.mark_disconnected(comms, :node@host)
      Process.sleep(10)
      assert :disconnected = CommsManager.get_link_quality(comms, :node@host)
    end

    test "get_all_links returns quality map", %{comms: comms} do
      CommsManager.update_link(comms, :a@host, 5.0)
      CommsManager.update_link(comms, :b@host, 100.0)
      Process.sleep(10)

      links = CommsManager.get_all_links(comms)
      assert links[:a@host] == :excellent
      assert links[:b@host] == :degraded
    end
  end

  describe "message routing" do
    test "rejects messages to disconnected nodes", %{comms: comms} do
      CommsManager.mark_disconnected(comms, :dead@host)
      Process.sleep(10)

      assert {:error, :disconnected} =
               CommsManager.send_msg(comms, :dead@host, "hello", :normal)
    end

    test "accepts messages to known good nodes", %{comms: comms} do
      CommsManager.update_link(comms, :good@host, 5.0)
      Process.sleep(10)

      assert :ok = CommsManager.send_msg(comms, :good@host, "hello", :normal)
    end

    test "drops low-priority messages on degraded links", %{comms: comms} do
      CommsManager.update_link(comms, :slow@host, 150.0)
      Process.sleep(10)

      # Normal should go through on degraded
      assert :ok = CommsManager.send_msg(comms, :slow@host, "important", :normal)
      # Low should be dropped on degraded
      assert :ok = CommsManager.send_msg(comms, :slow@host, "whatever", :low)
    end

    test "critical messages always go through on poor links", %{comms: comms} do
      CommsManager.update_link(comms, :bad@host, 500.0)
      Process.sleep(10)

      assert :ok = CommsManager.send_msg(comms, :bad@host, "alert!", :critical)
    end
  end

  describe "RTT classification" do
    test "classifies RTT thresholds correctly", %{comms: comms} do
      thresholds = [
        {5.0, :excellent},
        {30.0, :good},
        {100.0, :degraded},
        {500.0, :poor},
        {2000.0, :disconnected}
      ]

      for {rtt, expected} <- thresholds do
        node = :"node_#{rtt}@host" |> to_string() |> String.to_atom()
        CommsManager.update_link(comms, node, rtt)
        Process.sleep(10)
        assert CommsManager.get_link_quality(comms, node) == expected,
               "RTT #{rtt}ms should be #{expected}"
      end
    end
  end
end
