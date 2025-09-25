defmodule Raxol.Benchmark.StatisticalAnalyzer do
  @moduledoc """
  Advanced statistical analysis for benchmark results.
  Provides percentiles, distributions, outlier detection, and statistical significance testing.
  """

  @percentiles [50, 75, 90, 95, 99, 99.9]

  @doc """
  Perform comprehensive statistical analysis on benchmark results.
  """
  def analyze(results) when is_list(results) do
    sorted = Enum.sort(results)
    count = length(results)

    %{
      count: count,
      mean: calculate_mean(results),
      median: calculate_median(sorted),
      mode: calculate_mode(results),
      std_dev: calculate_std_dev(results),
      variance: calculate_variance(results),
      min: List.first(sorted),
      max: List.last(sorted),
      range: List.last(sorted) - List.first(sorted),
      percentiles: calculate_percentiles(sorted),
      iqr: calculate_iqr(sorted),
      outliers: detect_outliers(sorted),
      distribution: analyze_distribution(results),
      confidence_intervals: calculate_confidence_intervals(results),
      coefficient_of_variation: calculate_cv(results),
      skewness: calculate_skewness(results),
      kurtosis: calculate_kurtosis(results),
      histogram: generate_histogram(results)
    }
  end

  @doc """
  Calculate all standard percentiles (P50, P75, P90, P95, P99, P99.9).
  """
  def calculate_percentiles(sorted_data) do
    @percentiles
    |> Enum.map(fn p ->
      {:"p#{p}", calculate_percentile(sorted_data, p)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Calculate a specific percentile value.
  """
  def calculate_percentile(sorted_data, percentile) do
    count = length(sorted_data)

    cond do
      count == 0 ->
        nil

      count == 1 ->
        List.first(sorted_data)

      true ->
        # Using the linear interpolation method
        k = (count - 1) * (percentile / 100)
        f = :erlang.floor(k)
        c = :erlang.ceil(k)

        f_int = trunc(f)
        c_int = trunc(c)

        if f_int == c_int do
          Enum.at(sorted_data, f_int)
        else
          d0 = Enum.at(sorted_data, f_int) * (c - k)
          d1 = Enum.at(sorted_data, c_int) * (k - f)
          d0 + d1
        end
    end
  end

  @doc """
  Detect outliers using the IQR (Interquartile Range) method.
  """
  def detect_outliers(sorted_data) do
    q1 = calculate_percentile(sorted_data, 25)
    q3 = calculate_percentile(sorted_data, 75)
    iqr = q3 - q1

    lower_fence = q1 - 1.5 * iqr
    upper_fence = q3 + 1.5 * iqr

    outliers =
      sorted_data
      |> Enum.filter(fn x -> x < lower_fence or x > upper_fence end)

    %{
      method: :iqr,
      lower_fence: lower_fence,
      upper_fence: upper_fence,
      outliers: outliers,
      outlier_count: length(outliers),
      outlier_percentage: length(outliers) / length(sorted_data) * 100
    }
  end

  @doc """
  Detect outliers using MAD (Median Absolute Deviation) method.
  """
  def detect_outliers_mad(data, threshold \\ 3) do
    median = calculate_median(Enum.sort(data))
    deviations = Enum.map(data, fn x -> abs(x - median) end)
    mad = calculate_median(Enum.sort(deviations))

    # MAD scaling factor for normal distribution
    scaling_factor = 1.4826

    outliers =
      data
      |> Enum.filter(fn x ->
        abs(x - median) > threshold * mad * scaling_factor
      end)

    %{
      method: :mad,
      median: median,
      mad: mad,
      threshold: threshold,
      outliers: outliers,
      outlier_count: length(outliers),
      outlier_percentage: length(outliers) / length(data) * 100
    }
  end

  @doc """
  Perform statistical significance testing (t-test).
  """
  def t_test(sample1, sample2, opts \\ []) do
    type = Keyword.get(opts, :type, :two_tailed)
    paired = Keyword.get(opts, :paired, false)

    if paired do
      paired_t_test(sample1, sample2, type)
    else
      independent_t_test(sample1, sample2, type)
    end
  end

  @doc """
  Perform Mann-Whitney U test (non-parametric).
  """
  def mann_whitney_u_test(sample1, sample2) do
    combined =
      Enum.concat(sample1, sample2)
      |> Enum.with_index()
      |> Enum.sort_by(&elem(&1, 0))

    # Assign ranks
    ranked = assign_ranks(combined)

    # Calculate U statistics
    n1 = length(sample1)
    n2 = length(sample2)

    r1 =
      ranked
      |> Enum.filter(fn {_val, idx, _rank} -> idx < n1 end)
      |> Enum.map(fn {_val, _idx, rank} -> rank end)
      |> Enum.sum()

    u1 = r1 - n1 * (n1 + 1) / 2
    u2 = n1 * n2 - u1

    # Calculate z-score for large samples
    mean_u = n1 * n2 / 2
    std_u = :math.sqrt(n1 * n2 * (n1 + n2 + 1) / 12)
    z = (min(u1, u2) - mean_u) / std_u

    %{
      u1: u1,
      u2: u2,
      u_statistic: min(u1, u2),
      z_score: z,
      p_value: calculate_p_value(z, :two_tailed)
    }
  end

  @doc """
  Calculate confidence intervals using bootstrap method.
  """
  def calculate_confidence_intervals(
        data,
        confidence_level \\ 0.95,
        iterations \\ 1000
      ) do
    bootstrap_means =
      for _ <- 1..iterations do
        sample =
          Enum.map(1..length(data), fn _ ->
            Enum.random(data)
          end)

        calculate_mean(sample)
      end
      |> Enum.sort()

    alpha = (1 - confidence_level) / 2
    lower_idx = round(alpha * iterations)
    upper_idx = round((1 - alpha) * iterations)

    %{
      confidence_level: confidence_level,
      mean: calculate_mean(data),
      lower_bound: Enum.at(bootstrap_means, lower_idx),
      upper_bound: Enum.at(bootstrap_means, upper_idx),
      margin_of_error:
        (Enum.at(bootstrap_means, upper_idx) -
           Enum.at(bootstrap_means, lower_idx)) / 2
    }
  end

  @doc """
  Analyze the distribution of data.
  """
  def analyze_distribution(data) do
    mean = calculate_mean(data)
    median = calculate_median(Enum.sort(data))
    _mode = calculate_mode(data)
    skewness = calculate_skewness(data)
    kurtosis = calculate_kurtosis(data)

    distribution_type =
      cond do
        abs(skewness) < 0.5 and abs(kurtosis - 3) < 0.5 ->
          :normal

        skewness > 1 ->
          :right_skewed

        skewness < -1 ->
          :left_skewed

        kurtosis > 4 ->
          :heavy_tailed

        kurtosis < 2 ->
          :light_tailed

        true ->
          :unknown
      end

    %{
      type: distribution_type,
      skewness: skewness,
      kurtosis: kurtosis,
      mean_median_ratio: mean / median,
      normality_test: jarque_bera_test(data)
    }
  end

  @doc """
  Generate histogram data for visualization.
  """
  def generate_histogram(data, bins \\ 20) do
    min_val = Enum.min(data)
    max_val = Enum.max(data)
    range = max_val - min_val
    bin_width = range / bins

    histogram =
      0..(bins - 1)
      |> Enum.map(fn i ->
        lower = min_val + i * bin_width
        upper = min_val + (i + 1) * bin_width

        count =
          Enum.count(data, fn x ->
            if i == bins - 1 do
              x >= lower and x <= upper
            else
              x >= lower and x < upper
            end
          end)

        %{
          bin: i,
          lower_bound: Float.round(lower, 2),
          upper_bound: Float.round(upper, 2),
          count: count,
          frequency: count / length(data)
        }
      end)

    %{
      bins: bins,
      bin_width: bin_width,
      data: histogram
    }
  end

  # Private helper functions

  defp calculate_mean([]), do: nil

  defp calculate_mean(data) do
    Enum.sum(data) / length(data)
  end

  defp calculate_median([]), do: nil

  defp calculate_median(sorted_data) do
    count = length(sorted_data)
    middle = div(count, 2)

    if rem(count, 2) == 0 do
      (Enum.at(sorted_data, middle - 1) + Enum.at(sorted_data, middle)) / 2
    else
      Enum.at(sorted_data, middle)
    end
  end

  defp calculate_mode(data) do
    frequencies =
      data
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_val, freq} -> -freq end)

    case frequencies do
      [] -> nil
      [{val, _freq} | _] -> val
    end
  end

  defp calculate_variance([]), do: nil

  defp calculate_variance(data) do
    mean = calculate_mean(data)

    sum_sq_diff =
      Enum.reduce(data, 0, fn x, acc ->
        acc + :math.pow(x - mean, 2)
      end)

    sum_sq_diff / length(data)
  end

  defp calculate_std_dev(data) do
    variance = calculate_variance(data)
    if variance, do: :math.sqrt(variance), else: nil
  end

  defp calculate_iqr(sorted_data) do
    q1 = calculate_percentile(sorted_data, 25)
    q3 = calculate_percentile(sorted_data, 75)
    q3 - q1
  end

  defp calculate_cv(data) do
    mean = calculate_mean(data)
    std_dev = calculate_std_dev(data)

    if abs(mean) > 1.0e-10 and std_dev do
      std_dev / abs(mean) * 100
    else
      nil
    end
  end

  defp calculate_skewness(data) do
    n = length(data)
    mean = calculate_mean(data)
    std_dev = calculate_std_dev(data)

    if abs(std_dev) < 1.0e-10 or n < 3 do
      0
    else
      sum_cubed =
        Enum.reduce(data, 0, fn x, acc ->
          acc + :math.pow((x - mean) / std_dev, 3)
        end)

      n / ((n - 1) * (n - 2)) * sum_cubed
    end
  end

  defp calculate_kurtosis(data) do
    n = length(data)
    mean = calculate_mean(data)
    std_dev = calculate_std_dev(data)

    if abs(std_dev) < 1.0e-10 or n < 4 do
      # Normal distribution kurtosis
      3
    else
      sum_fourth =
        Enum.reduce(data, 0, fn x, acc ->
          acc + :math.pow((x - mean) / std_dev, 4)
        end)

      factor1 = n * (n + 1) / ((n - 1) * (n - 2) * (n - 3))
      factor2 = 3 * :math.pow(n - 1, 2) / ((n - 2) * (n - 3))

      factor1 * sum_fourth - factor2
    end
  end

  defp independent_t_test(sample1, sample2, type) do
    n1 = length(sample1)
    n2 = length(sample2)
    mean1 = calculate_mean(sample1)
    mean2 = calculate_mean(sample2)
    var1 = calculate_variance(sample1)
    var2 = calculate_variance(sample2)

    # Pooled standard deviation
    pooled_var = ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2)
    pooled_std = :math.sqrt(pooled_var)

    # Standard error
    se = pooled_std * :math.sqrt(1 / n1 + 1 / n2)

    # T statistic
    t_stat = (mean1 - mean2) / se

    # Degrees of freedom
    df = n1 + n2 - 2

    %{
      t_statistic: t_stat,
      degrees_of_freedom: df,
      p_value: calculate_p_value(t_stat, type),
      mean_difference: mean1 - mean2,
      standard_error: se,
      effect_size: cohens_d(sample1, sample2)
    }
  end

  defp paired_t_test(sample1, sample2, type) do
    if length(sample1) != length(sample2) do
      {:error, "Samples must have equal length for paired t-test"}
    else
      differences =
        Enum.zip(sample1, sample2)
        |> Enum.map(fn {x, y} -> x - y end)

      n = length(differences)
      mean_diff = calculate_mean(differences)
      std_diff = calculate_std_dev(differences)
      se = std_diff / :math.sqrt(n)
      t_stat = mean_diff / se
      df = n - 1

      %{
        t_statistic: t_stat,
        degrees_of_freedom: df,
        p_value: calculate_p_value(t_stat, type),
        mean_difference: mean_diff,
        standard_error: se
      }
    end
  end

  defp cohens_d(sample1, sample2) do
    mean1 = calculate_mean(sample1)
    mean2 = calculate_mean(sample2)
    n1 = length(sample1)
    n2 = length(sample2)
    var1 = calculate_variance(sample1)
    var2 = calculate_variance(sample2)

    pooled_std = :math.sqrt(((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2))

    (mean1 - mean2) / pooled_std
  end

  defp calculate_p_value(statistic, type) do
    # Simplified p-value calculation
    # In production, use a proper statistical library
    abs_stat = abs(statistic)

    p =
      cond do
        abs_stat < 1.96 -> 0.05
        abs_stat < 2.58 -> 0.01
        abs_stat < 3.29 -> 0.001
        true -> 0.0001
      end

    case type do
      :two_tailed -> p * 2
      _ -> p
    end
  end

  defp assign_ranks(sorted_data) do
    sorted_data
    |> Enum.chunk_by(&elem(&1, 0))
    |> Enum.flat_map(fn group ->
      avg_rank =
        (Enum.map(1..length(group), & &1) |> Enum.sum()) / length(group)

      Enum.map(group, fn {val, idx} ->
        {val, idx, avg_rank}
      end)
    end)
  end

  defp jarque_bera_test(data) do
    n = length(data)
    skewness = calculate_skewness(data)
    kurtosis = calculate_kurtosis(data)

    jb_statistic =
      n / 6 * (:math.pow(skewness, 2) + :math.pow(kurtosis - 3, 2) / 4)

    # Chi-square critical value with 2 degrees of freedom at 0.05 significance
    critical_value = 5.991

    %{
      statistic: jb_statistic,
      critical_value: critical_value,
      is_normal: jb_statistic < critical_value,
      p_value: if(jb_statistic < critical_value, do: ">0.05", else: "<0.05")
    }
  end
end
