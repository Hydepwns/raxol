defmodule Raxol.Symphony.Orchestrator.CandidateTest do
  use ExUnit.Case, async: true

  alias Raxol.Symphony.Config
  alias Raxol.Symphony.Issue
  alias Raxol.Symphony.Issue.Blocker
  alias Raxol.Symphony.Orchestrator.Candidate

  defp config(overrides \\ %{}) do
    base = %{
      tracker: %{
        kind: "memory",
        active_states: ["Todo", "In Progress"],
        terminal_states: ["Done", "Cancelled"]
      },
      agent: %{max_concurrent_agents: 3, max_concurrent_agents_by_state: %{}}
    }

    Config.from_workflow(%{
      config: deep_merge(base, overrides),
      prompt_template: ""
    })
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, fn
      _key, %{} = l, %{} = r -> deep_merge(l, r)
      _key, _l, r -> r
    end)
  end

  defp issue(opts) do
    defaults = %{
      id: opts[:id],
      identifier: opts[:identifier] || "MT-#{opts[:id]}",
      title: "T-#{opts[:id]}",
      state: opts[:state] || "Todo",
      priority: opts[:priority],
      created_at: opts[:created_at],
      blocked_by: opts[:blocked_by] || []
    }

    struct!(Issue, defaults)
  end

  describe "basic_eligibility/4" do
    test "active issue is eligible" do
      assert Candidate.basic_eligibility(
               issue(id: "a", state: "Todo"),
               config(),
               %{},
               MapSet.new()
             )
    end

    test "rejects already-running issue" do
      running = %{"a" => %{state: "In Progress"}}

      refute Candidate.basic_eligibility(
               issue(id: "a", state: "Todo"),
               config(),
               running,
               MapSet.new()
             )
    end

    test "rejects already-claimed issue" do
      refute Candidate.basic_eligibility(
               issue(id: "a", state: "Todo"),
               config(),
               %{},
               MapSet.new(["a"])
             )
    end

    test "rejects terminal-state issue" do
      refute Candidate.basic_eligibility(
               issue(id: "a", state: "Done"),
               config(),
               %{},
               MapSet.new()
             )
    end

    test "rejects non-active state" do
      refute Candidate.basic_eligibility(
               issue(id: "a", state: "Backlog"),
               config(),
               %{},
               MapSet.new()
             )
    end

    test "Todo with non-terminal blocker is rejected" do
      blockers = [%Blocker{id: "b", identifier: "MT-99", state: "In Progress"}]

      refute Candidate.basic_eligibility(
               issue(id: "a", state: "Todo", blocked_by: blockers),
               config(),
               %{},
               MapSet.new()
             )
    end

    test "Todo with all-terminal blockers is allowed" do
      blockers = [%Blocker{id: "b", identifier: "MT-99", state: "Done"}]

      assert Candidate.basic_eligibility(
               issue(id: "a", state: "Todo", blocked_by: blockers),
               config(),
               %{},
               MapSet.new()
             )
    end

    test "blocker rule does not apply to In Progress" do
      blockers = [%Blocker{id: "b", identifier: "MT-99", state: "In Progress"}]

      assert Candidate.basic_eligibility(
               issue(id: "a", state: "In Progress", blocked_by: blockers),
               config(),
               %{},
               MapSet.new()
             )
    end
  end

  describe "sort/1" do
    test "lower priority numbers first; nil priority last" do
      issues = [
        issue(id: "x", priority: 3, identifier: "MT-3"),
        issue(id: "y", priority: nil, identifier: "MT-9"),
        issue(id: "z", priority: 1, identifier: "MT-1")
      ]

      assert Candidate.sort(issues) |> Enum.map(& &1.identifier) == ["MT-1", "MT-3", "MT-9"]
    end

    test "ties broken by created_at oldest first" do
      newer = ~U[2026-01-02 00:00:00.000000Z]
      older = ~U[2026-01-01 00:00:00.000000Z]

      issues = [
        issue(id: "x", priority: 1, identifier: "MT-A", created_at: newer),
        issue(id: "y", priority: 1, identifier: "MT-B", created_at: older)
      ]

      assert Candidate.sort(issues) |> Enum.map(& &1.identifier) == ["MT-B", "MT-A"]
    end

    test "tie broken by identifier lexicographic" do
      issues = [
        issue(id: "x", priority: 2, identifier: "MT-9"),
        issue(id: "y", priority: 2, identifier: "MT-1")
      ]

      assert Candidate.sort(issues) |> Enum.map(& &1.identifier) == ["MT-1", "MT-9"]
    end
  end

  describe "apply_concurrency_slots/3" do
    test "respects global max" do
      issues = for i <- 1..5, do: issue(id: "i#{i}", priority: i)
      kept = Candidate.apply_concurrency_slots(issues, config(), %{})
      assert length(kept) == 3
    end

    test "subtracts already-running entries" do
      running = %{"r1" => %{state: "Todo"}, "r2" => %{state: "In Progress"}}
      issues = for i <- 1..5, do: issue(id: "i#{i}", priority: i)

      kept = Candidate.apply_concurrency_slots(issues, config(), running)
      assert length(kept) == 1
    end

    test "respects per-state cap when set" do
      cfg =
        config(%{
          agent: %{max_concurrent_agents: 5, max_concurrent_agents_by_state: %{"todo" => 2}}
        })

      issues = for i <- 1..4, do: issue(id: "t#{i}", priority: i, state: "Todo")
      kept = Candidate.apply_concurrency_slots(issues, cfg, %{})
      assert length(kept) == 2
    end

    test "per-state cap counts existing running issues in that state" do
      cfg =
        config(%{
          agent: %{max_concurrent_agents: 5, max_concurrent_agents_by_state: %{"todo" => 2}}
        })

      running = %{"r1" => %{state: "Todo"}}
      issues = for i <- 1..3, do: issue(id: "t#{i}", priority: i, state: "Todo")

      kept = Candidate.apply_concurrency_slots(issues, cfg, running)
      assert length(kept) == 1
    end
  end

  describe "eligible/4 -- end to end" do
    test "filters, sorts, and applies caps" do
      issues = [
        issue(id: "a", state: "Todo", priority: 3),
        issue(id: "b", state: "Done"),
        issue(id: "c", state: "Todo", priority: 1),
        issue(id: "d", state: "Todo", priority: 2),
        issue(id: "e", state: "Todo", priority: 4)
      ]

      kept = Candidate.eligible(issues, config(), %{}, MapSet.new())
      assert Enum.map(kept, & &1.id) == ["c", "d", "a"]
    end
  end
end
