defmodule Raxol.Docs.Searcher do
  @moduledoc """
  Advanced search engine for Raxol documentation and commands.

  Implements fuzzy search, ranking, and filtering algorithms optimized
  for developer documentation and API exploration.
  """

  @doc """
  Performs fuzzy search on a collection of commands/documents.

  Uses multiple scoring algorithms:
  - Exact match bonus
  - Prefix match bonus  
  - Substring match scoring
  - Acronym matching
  - Typo tolerance
  """
  def fuzzy_search(collection, query, limit \\ 25) do
    normalized_query = normalize_query(query)

    collection
    |> Enum.map_join(&score_item(&1, normalized_query))
    # Filter out very low scores
    |> Enum.filter(&(&1.score > 0.1))
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Search within a specific category.
  """
  def search_category(collection, query, category, limit \\ 25) do
    collection
    |> Enum.filter(&(&1.category == category))
    |> fuzzy_search(query, limit)
  end

  @doc """
  Search by tags with fuzzy matching.
  """
  def search_by_tags(collection, tag_query, limit \\ 25) do
    normalized_tag = normalize_query(tag_query)

    collection
    |> Enum.filter(fn item ->
      Enum.any?(item.tags || [], fn tag ->
        score_string(normalize_string(tag), normalized_tag) > 0.6
      end)
    end)
    |> Enum.take(limit)
    |> add_search_scores(0.8)
  end

  @doc """
  Multi-field search across title, description, and tags.
  """
  def multi_field_search(collection, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    boost_recent = Keyword.get(opts, :boost_recent, false)

    normalized_query = normalize_query(query)

    results =
      collection
      |> Enum.map(&score_multi_field(&1, normalized_query))
      |> Enum.filter(&(&1.score > 0.15))
      |> maybe_boost_recent(boost_recent)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(limit)

    results
  end

  # Private Functions

  defp score_item(item, normalized_query) do
    # Score multiple fields with different weights
    title_score =
      score_string(normalize_string(item.title), normalized_query) * 1.0

    desc_score =
      score_string(normalize_string(item.description), normalized_query) * 0.7

    # Tag scoring
    tag_score =
      case item.tags do
        nil ->
          0.0

        tags ->
          tags
          |> Enum.map(&score_string(normalize_string(&1), normalized_query))
          |> Enum.max([0.0])
          |> Kernel.*(0.5)
      end

    # Type-specific bonuses
    type_bonus = get_type_bonus(item, normalized_query)

    # Calculate final score
    total_score = title_score + desc_score + tag_score + type_bonus

    # Apply category-specific boosts
    category_boost = get_category_boost(item.category)
    final_score = total_score * category_boost

    Map.put(item, :score, final_score)
  end

  defp score_multi_field(item, normalized_query) do
    fields = [
      {item.title, 1.0},
      {item.description, 0.7},
      {item[:module] && inspect(item.module), 0.8},
      {item[:function] && Atom.to_string(item.function), 0.9}
    ]

    field_scores =
      for {field_value, weight} <- fields, field_value do
        score_string(normalize_string(field_value), normalized_query) * weight
      end

    total_score = Enum.sum(field_scores)
    Map.put(item, :score, total_score)
  end

  defp score_string(text, query) when is_binary(text) and is_binary(query) do
    cond do
      # Exact match - highest score
      text == query -> 1.0
      # Starts with query - high score
      String.starts_with?(text, query) -> 0.9
      # Contains query as substring - good score
      String.contains?(text, query) -> 0.7
      # Acronym match - decent score
      acronym_match?(text, query) -> 0.6
      # Fuzzy string distance - variable score
      true -> fuzzy_string_score(text, query)
    end
  end

  defp score_string(_, _), do: 0.0

  defp fuzzy_string_score(text, query) do
    # Implement a simple fuzzy scoring algorithm
    distance = jaro_winkler_distance(text, query)

    # Convert distance to score (0-1 range)
    if distance > 0.6, do: distance * 0.5, else: 0.0
  end

  defp jaro_winkler_distance(s1, s2) do
    # Simplified Jaro-Winkler implementation
    len1 = String.length(s1)
    len2 = String.length(s2)

    if len1 == 0 and len2 == 0 do
      1.0
    else
      max_distance = div(max(len1, len2), 2) - 1
      matches = count_matches(s1, s2, max(1, max_distance))

      if matches == 0 do
        0.0
      else
        transpositions = count_transpositions(s1, s2, max_distance)

        jaro =
          (matches / len1 + matches / len2 +
             (matches - transpositions) / matches) / 3.0

        # Winkler modification for common prefix
        prefix_length = common_prefix_length(s1, s2, 4)
        jaro + 0.1 * prefix_length * (1 - jaro)
      end
    end
  end

  defp count_matches(s1, s2, max_distance) do
    # Simplified match counting
    chars1 = String.graphemes(s1)
    chars2 = String.graphemes(s2)

    matches =
      for {c1, i1} <- Enum.with_index(chars1),
          {c2, i2} <- Enum.with_index(chars2),
          c1 == c2 and abs(i1 - i2) <= max_distance do
        true
      end

    length(matches)
  end

  defp count_transpositions(_s1, _s2, _max_distance) do
    # Simplified - just return 0 for now
    0
  end

  defp common_prefix_length(s1, s2, max_length) do
    chars1 = String.graphemes(s1)
    chars2 = String.graphemes(s2)

    pairs = Enum.zip(chars1, chars2)

    pairs
    |> Enum.take_while(fn {c1, c2} -> c1 == c2 end)
    |> length()
    |> min(max_length)
  end

  defp acronym_match?(text, query) do
    # Check if query could be an acronym of text
    words = String.split(text, ~r/[\s\._-]+/)

    if length(words) >= String.length(query) do
      acronym =
        words
        |> Enum.take(String.length(query))
        |> Enum.map_join("", &String.first/1)
        |> String.downcase()

      String.downcase(query) == acronym
    else
      false
    end
  end

  defp get_type_bonus(item, query) do
    case item.type do
      :function ->
        if String.contains?(query, "/"), do: 0.2, else: 0.0

      :component ->
        if String.contains?(query, "component"), do: 0.15, else: 0.0

      :mix_task ->
        if String.contains?(query, "mix"), do: 0.15, else: 0.0

      :example ->
        if String.contains?(query, "example"), do: 0.1, else: 0.0

      _ ->
        0.0
    end
  end

  defp get_category_boost(category) do
    case category do
      # API docs are frequently accessed
      :api -> 1.1
      :component -> 1.05
      :development -> 1.0
      :guide -> 0.95
      :example -> 0.9
      _ -> 1.0
    end
  end

  defp normalize_query(query) do
    query
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/[^\w\s\/]/, "")
  end

  defp normalize_string(nil), do: ""

  defp normalize_string(string) when is_binary(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp normalize_string(other), do: other |> inspect() |> normalize_string()

  defp add_search_scores(results, base_score) do
    Enum.map(results, &Map.put(&1, :score, base_score))
  end

  defp maybe_boost_recent(results, false), do: results

  defp maybe_boost_recent(results, true) do
    now = System.system_time(:second)
    week_seconds = 7 * 24 * 60 * 60

    Enum.map(results, fn item ->
      # Boost items that were recently accessed/updated
      recency_boost =
        case Map.get(item, :last_accessed) do
          nil -> 1.0
          timestamp when now - timestamp < week_seconds -> 1.1
          _ -> 1.0
        end

      %{item | score: item.score * recency_boost}
    end)
  end
end
