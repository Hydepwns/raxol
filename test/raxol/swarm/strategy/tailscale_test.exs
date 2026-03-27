defmodule Raxol.Swarm.Strategy.TailscaleTest do
  use ExUnit.Case, async: true

  alias Raxol.Swarm.Strategy.Tailscale

  @sample_status %{
    "Self" => %{
      "HostName" => "my-machine",
      "DNSName" => "my-machine.tailnet.ts.net.",
      "TailscaleIPs" => ["100.64.0.1", "fd7a:115c:a1e0::1"],
      "Tags" => ["tag:raxol"],
      "Online" => true
    },
    "Peer" => %{
      "nodekey:abc123" => %{
        "HostName" => "worker-1",
        "DNSName" => "worker-1.tailnet.ts.net.",
        "TailscaleIPs" => ["100.64.0.2", "fd7a:115c:a1e0::2"],
        "Tags" => ["tag:raxol"],
        "Online" => true
      },
      "nodekey:def456" => %{
        "HostName" => "worker-2",
        "DNSName" => "worker-2.tailnet.ts.net.",
        "TailscaleIPs" => ["100.64.0.3"],
        "Tags" => ["tag:raxol", "tag:gpu"],
        "Online" => true
      },
      "nodekey:ghi789" => %{
        "HostName" => "offline-box",
        "DNSName" => "offline-box.tailnet.ts.net.",
        "TailscaleIPs" => ["100.64.0.4"],
        "Tags" => [],
        "Online" => false
      },
      "nodekey:jkl012" => %{
        "HostName" => "untagged",
        "DNSName" => "untagged.tailnet.ts.net.",
        "TailscaleIPs" => ["100.64.0.5"],
        "Tags" => nil,
        "Online" => true
      }
    },
    "MagicDNSSuffix" => "tailnet.ts.net"
  }

  describe "extract_peers/1" do
    test "extracts peer list from status" do
      peers = Tailscale.extract_peers(@sample_status)
      assert length(peers) == 4
    end

    test "returns empty for missing Peer key" do
      assert Tailscale.extract_peers(%{}) == []
    end

    test "returns empty for nil" do
      assert Tailscale.extract_peers(nil) == []
    end
  end

  describe "filter_online/1" do
    test "keeps only online peers" do
      peers = Tailscale.extract_peers(@sample_status)
      online = Tailscale.filter_online(peers)
      assert length(online) == 3

      hostnames = Enum.map(online, & &1["HostName"]) |> Enum.sort()
      assert hostnames == ["untagged", "worker-1", "worker-2"]
    end
  end

  describe "filter_by_tag/2" do
    test "returns all peers when tag is nil" do
      peers = Tailscale.extract_peers(@sample_status) |> Tailscale.filter_online()
      filtered = Tailscale.filter_by_tag(peers, nil)
      assert length(filtered) == 3
    end

    test "filters by tag" do
      peers = Tailscale.extract_peers(@sample_status) |> Tailscale.filter_online()
      filtered = Tailscale.filter_by_tag(peers, "tag:raxol")
      assert length(filtered) == 2

      hostnames = Enum.map(filtered, & &1["HostName"]) |> Enum.sort()
      assert hostnames == ["worker-1", "worker-2"]
    end

    test "filters by specific tag" do
      peers = Tailscale.extract_peers(@sample_status) |> Tailscale.filter_online()
      filtered = Tailscale.filter_by_tag(peers, "tag:gpu")
      assert length(filtered) == 1
      assert hd(filtered)["HostName"] == "worker-2"
    end

    test "returns empty when no peers match tag" do
      peers = Tailscale.extract_peers(@sample_status) |> Tailscale.filter_online()
      filtered = Tailscale.filter_by_tag(peers, "tag:nonexistent")
      assert filtered == []
    end

    test "handles nil Tags field gracefully" do
      peers = [%{"HostName" => "nil-tags", "Tags" => nil, "Online" => true}]
      filtered = Tailscale.filter_by_tag(peers, "tag:raxol")
      assert filtered == []
    end
  end

  describe "peer_to_node/3" do
    test "constructs node name from IP" do
      peer = %{
        "TailscaleIPs" => ["100.64.0.2"],
        "DNSName" => "worker-1.tailnet.ts.net."
      }

      assert Tailscale.peer_to_node(peer, "raxol", false) == :"raxol@100.64.0.2"
    end

    test "constructs node name from DNS name" do
      peer = %{
        "TailscaleIPs" => ["100.64.0.2"],
        "DNSName" => "worker-1.tailnet.ts.net."
      }

      assert Tailscale.peer_to_node(peer, "raxol", true) == :"raxol@worker-1.tailnet.ts.net"
    end

    test "strips trailing dot from DNS name" do
      peer = %{"DNSName" => "host.ts.net.", "TailscaleIPs" => ["100.1.2.3"]}
      node = Tailscale.peer_to_node(peer, "app", true)
      refute String.ends_with?(Atom.to_string(node), ".")
    end

    test "uses first IP when multiple exist" do
      peer = %{
        "TailscaleIPs" => ["100.64.0.2", "fd7a:115c:a1e0::2"],
        "DNSName" => "worker.ts.net."
      }

      assert Tailscale.peer_to_node(peer, "raxol", false) == :"raxol@100.64.0.2"
    end
  end

  describe "full pipeline" do
    test "extract -> filter_online -> filter_by_tag -> peer_to_node" do
      nodes =
        @sample_status
        |> Tailscale.extract_peers()
        |> Tailscale.filter_online()
        |> Tailscale.filter_by_tag("tag:raxol")
        |> Enum.map(&Tailscale.peer_to_node(&1, "raxol", false))
        |> Enum.sort()

      assert nodes == [:"raxol@100.64.0.2", :"raxol@100.64.0.3"]
    end

    test "pipeline with DNS names" do
      nodes =
        @sample_status
        |> Tailscale.extract_peers()
        |> Tailscale.filter_online()
        |> Tailscale.filter_by_tag("tag:raxol")
        |> Enum.map(&Tailscale.peer_to_node(&1, "raxol", true))
        |> Enum.sort()

      assert nodes == [
               :"raxol@worker-1.tailnet.ts.net",
               :"raxol@worker-2.tailnet.ts.net"
             ]
    end

    test "pipeline with no tag filter returns all online" do
      nodes =
        @sample_status
        |> Tailscale.extract_peers()
        |> Tailscale.filter_online()
        |> Tailscale.filter_by_tag(nil)
        |> Enum.map(&Tailscale.peer_to_node(&1, "raxol", false))

      assert length(nodes) == 3
    end
  end

  describe "fetch_status/1" do
    test "returns error for nonexistent binary" do
      assert {:error, _} = Tailscale.fetch_status("/nonexistent/tailscale-fake")
    end
  end
end
