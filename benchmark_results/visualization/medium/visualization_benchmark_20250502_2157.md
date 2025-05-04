# Visualization Performance Benchmark Results

**Date:** 2025-05-02 21:57:20

**Test Configuration:**
- Iterations per test: 5
- Cache Testing: true
- Memory Tracking: true

## Chart Performance

| Dataset Size | Avg Time (ms) | Min Time (ms) | Max Time (ms) | Std Dev |
|--------------|---------------|---------------|---------------|---------|
| 10 | 1.32 | 0.44 | 4.81 | 1.74 |
| 100 | 0.66 | 0.57 | 0.83 | 0.11 |
| 500 | 0.57 | 0.51 | 0.62 | 0.04 |
| 1000 | 0.62 | 0.59 | 0.65 | 0.03 |

## TreeMap Performance

| Dataset Size | Node Count | Avg Time (ms) | Min Time (ms) | Max Time (ms) | Std Dev |
|--------------|------------|---------------|---------------|---------------|---------|
| 10 | 11 | 2.56 | 1.19 | 7.96 | 2.7 |
| 100 | 111 | 1.27 | 1.19 | 1.53 | 0.13 |
| 500 | 556 | 1.24 | 1.17 | 1.42 | 0.09 |
| 1000 | 1111 | 1.34 | 1.22 | 1.46 | 0.1 |

## Cache Performance

Cache performance metrics demonstrate the effectiveness of the caching system:

- **Chart Cache Speedup:** 3.37x faster after initial render (average)
- **TreeMap Cache Speedup:** 2.37x faster after initial render (average)

This indicates that the caching system is effective.


## Memory Usage

*Memory data collection failed*

## Conclusions

- Both chart and treemap visualization components scale very efficiently with larger datasets.
