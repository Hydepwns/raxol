defmodule Raxol.UI.Rendering.TreeDiffer do
  @moduledoc """
  Provides functions to compute the difference (diff) between two UI trees.
  This module is responsible for identifying changes, additions, removals,
  and reordering of nodes, supporting both keyed and non-keyed children.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Computes the minimal set of changes (diff) between two UI trees.

  Returns:
    * :no_change if trees are identical
    * {:replace, new_tree} if the root node differs significantly
    * {:update, path, changes} for subtree updates. `path` is a list of indices
      to the parent node, and `changes` describes the modifications to its children
      (either as indexed diffs or keyed operations).

  The `path` in `{:update, path, changes}` always refers to the parent node whose
  children have changed. For keyed children, the recursive diffs for individual
  children (e.g., in `{:key_update, key, child_diff}`) will have their own paths
  relative to that child (i.e., starting with `[]` if the child itself is the root
  of that sub-diff).
  """
  @spec diff_trees(old_tree :: map() | nil, new_tree :: map() | nil) ::
          :no_change
          | {:replace, map()}
          | {:update, [integer()], any()}
  def diff_trees(old_tree, new_tree), do: do_diff_trees(old_tree, new_tree, [])

  defp do_diff_trees(nil, nil, _path), do: :no_change
  defp do_diff_trees(nil, new, _path), do: {:replace, new}
  defp do_diff_trees(_old, nil, _path), do: {:replace, nil}
  defp do_diff_trees(old, new, _path) when old == new, do: {:unchanged, old}
  defp do_diff_trees(old, new, _path) when old != new, do: {:replace, new}
end
