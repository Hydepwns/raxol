# Swarm Cluster Demo
#
# Demonstrates the distributed swarm subsystem running on a single node.
# In production, nodes discover each other via libcluster and sync
# automatically. This demo shows the APIs without requiring a cluster.
#
# What you'll learn:
#   - TacticalOverlay: CRDT-backed shared state for entities and waypoints
#   - LWWRegister: Last-Writer-Wins semantics -- latest timestamp wins on merge
#   - ORSet: Observed-Remove Set -- add-wins semantics across nodes
#   - Topology: seniority-based commander election, role management
#   - Overlay events: subscribe to state changes for reactive updates
#
# Usage:
#   mix run examples/swarm/cluster_demo.exs

alias Raxol.Swarm.{TacticalOverlay, Topology}
alias Raxol.Swarm.CRDT.{LWWRegister, ORSet}

IO.puts("=== Raxol Swarm Demo ===\n")

# ---- 1. Start the swarm supervisor ----
# This boots: NodeMonitor, CommsManager, Topology, TacticalOverlay
# Discovery is skipped (no discovery opts = single-node mode)

{:ok, _sup} = Raxol.Swarm.Supervisor.start_link()
IO.puts("[sup] Swarm supervisor started (single-node mode)")

# ---- 2. Check our topology role ----
# On a single node, we're always the commander

role = Topology.get_role()
{:ok, commander} = Topology.get_commander()
count = Topology.node_count()
IO.puts("[topology] Role: #{role}, Commander: #{commander}, Nodes: #{count}")

# ---- 3. Subscribe to overlay changes ----

TacticalOverlay.subscribe()
IO.puts("[overlay] Subscribed to tactical overlay events")

# ---- 4. Create some entities (LWW registers) ----

TacticalOverlay.update_entity(:alpha, %{
  position: {10.0, 20.0, 0.0},
  heading: 45.0,
  status: :active
})

TacticalOverlay.update_entity(:bravo, %{
  position: {30.0, 15.0, 0.0},
  heading: 180.0,
  status: :active
})

IO.puts("[overlay] Created entities :alpha and :bravo")

# ---- 5. Add waypoints (OR-Set) ----

TacticalOverlay.add_waypoint(%{
  id: "rally_point",
  position: {50.0, 50.0, 0.0},
  label: "Rally Point Alpha"
})

TacticalOverlay.add_waypoint(%{
  id: "extraction",
  position: {80.0, 10.0, 0.0},
  label: "Extraction Zone"
})

IO.puts("[overlay] Added 2 waypoints")

# Small pause to let GenServer process casts
Process.sleep(100)

# ---- 6. Query the overlay state ----

entities = TacticalOverlay.get_all_entities()
waypoints = TacticalOverlay.get_all_waypoints()

IO.puts("\n--- Current State ---")
IO.puts("Entities (#{length(entities)}):")

for entity <- entities do
  IO.puts(
    "  #{entity.id}: position=#{inspect(entity.position)}, status=#{entity.status}"
  )
end

IO.puts("Waypoints (#{length(waypoints)}):")

for wp <- waypoints do
  IO.puts("  #{wp.id}: #{wp.label} at #{inspect(wp.position)}")
end

# ---- 7. Update an entity and remove a waypoint ----

TacticalOverlay.update_entity(:alpha, %{
  position: {15.0, 25.0, 0.0},
  heading: 90.0,
  status: :damaged
})

TacticalOverlay.remove_waypoint("rally_point")
IO.puts("\n[overlay] Moved :alpha, removed rally_point waypoint")

Process.sleep(100)

# ---- 8. Show updated state ----

entities = TacticalOverlay.get_all_entities()
waypoints = TacticalOverlay.get_all_waypoints()

IO.puts("\n--- Updated State ---")
IO.puts("Entities (#{length(entities)}):")

for entity <- entities do
  IO.puts(
    "  #{entity.id}: position=#{inspect(entity.position)}, status=#{entity.status}"
  )
end

IO.puts("Waypoints (#{length(waypoints)}):")

for wp <- waypoints do
  IO.puts("  #{wp.id}: #{wp.label} at #{inspect(wp.position)}")
end

# ---- 9. Show pure CRDT operations ----
# CRDTs are pure data structures (no GenServer). They can be created,
# modified, and merged without any process coordination.

IO.puts("\n--- Pure CRDT Demo ---")

# LWW Register: last writer wins -- when two nodes write concurrently,
# the one with the later timestamp is kept after merge.
reg_a = LWWRegister.new("node_a_says_hello")
Process.sleep(1)
reg_b = LWWRegister.new("node_b_says_goodbye")

merged = LWWRegister.merge(reg_a, reg_b)

IO.puts(
  "LWW merge: #{inspect(LWWRegister.value(merged))} (latest timestamp wins)"
)

# OR-Set: add-wins semantics. If one node adds "bravo" while another
# removes it, the add wins after merge. Each add gets a unique tag.
set = ORSet.new()
set = ORSet.add(set, "alpha")
set = ORSet.add(set, "bravo")
set = ORSet.add(set, "charlie")
set = ORSet.remove(set, "bravo")

IO.puts(
  "OR-Set members: #{inspect(ORSet.to_list(set))} (size: #{ORSet.size(set)})"
)

# Simulate merge from another node
remote_set = ORSet.new() |> ORSet.add("delta") |> ORSet.add("bravo")
merged_set = ORSet.merge(set, remote_set)
IO.puts("After merge with remote: #{inspect(ORSet.to_list(merged_set))}")

# ---- 10. Drain overlay event messages ----

IO.puts("\n--- Overlay Events Received ---")

receive_events = fn receive_events ->
  receive do
    {:overlay_event, event} ->
      IO.puts("  #{inspect(event)}")
      receive_events.(receive_events)
  after
    100 -> :done
  end
end

receive_events.(receive_events)

IO.puts("\n=== Done ===")
