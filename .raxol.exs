# Raxol Pre-commit Configuration
# This file configures the behavior of mix raxol.pre_commit

[
  pre_commit: [
    # Which checks to run by default
    checks: [:format, :compile, :credo, :tests, :security],
    # Optional advanced checks (can be slow)
    # checks: [:format, :compile, :credo, :tests, :security, :dialyzer],

    # Run checks in parallel for speed
    parallel: true,

    # Continue running all checks even if one fails
    fail_fast: false,

    # Auto-fix issues when possible
    auto_fix: [:format],

    # Timeout for test execution (in milliseconds)
    test_timeout: 10_000,

    # Paths to ignore during checks
    ignore_paths: ["deps/", "_build/", "priv/static/", ".raxol_cache/"],

    # Per-check configuration
    check_config: [
      format: [
        # Additional formatter options can go here
      ],
      tests: [
        # Increase timeout for tests
        timeout: 15_000,
        max_failures: 20,
        # Exclude these tags by default
        exclude_tags: ["slow", "integration", "docker"]
      ],
      credo: [
        # Run in strict mode
        strict: false,
        # Check all files, not just staged
        all: false
      ],
      compile: [
        # Compile with warnings as errors
        warnings_as_errors: true
      ],
      dialyzer: [
        # Build PLT for dependencies
        build_plt: false,
        # Check only changed files by default
        all: false
      ],
      security: [
        # Run full security scan
        full: false,
        # Auto-fix permissions
        fix: false
      ]
    ]
  ]
]
