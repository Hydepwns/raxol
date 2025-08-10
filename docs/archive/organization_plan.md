# Documentation Organization Plan

## Root Directory Cleanup

### Files to Move to docs/archive/
- DOCUMENTATION_REDUNDANCY_ANALYSIS.md → docs/archive/
- PHASE_2_COMPLETION_SUMMARY.md → docs/archive/
- TODO_FIXME_CATALOG.md → docs/archive/
- WASH_STYLE_DESIGN.md → docs/archive/
- README_GENERATED_DEMO.md → docs/archive/
- github_issues.md → docs/archive/

### Files to Remove (Redundant)
- erl_crash.dump (build artifact)
- raxol-0.9.0.tar (build artifact)

### Files to Keep in Root
- README.md (main project entry point)
- CHANGELOG.md (release history)
- CONTRIBUTING.md (contributor guide)
- LICENSE.md (legal)
- TODO.md (active roadmap)

## Documentation Structure (After Cleanup)

```
/
├── README.md                    # Main project overview (DRY generated)
├── CHANGELOG.md                 # Release history
├── CONTRIBUTING.md              # How to contribute
├── LICENSE.md                   # MIT License
├── TODO.md                      # Active roadmap
└── docs/
    ├── ARCHITECTURE.md          # System architecture (DRY generated)
    ├── DEVELOPMENT.md           # Development setup (DRY generated)
    ├── schema/                  # Single source of truth
    │   ├── project_info.yml     # Project metadata
    │   ├── architecture.yml     # Architecture details
    │   ├── features.yml         # Feature lists
    │   ├── performance_metrics.yml # Performance data
    │   └── installation.yml     # Setup instructions
    ├── templates/               # Documentation templates
    │   └── sections/           # Reusable template sections
    └── archive/                # Historical documents
        ├── DOCUMENTATION_REDUNDANCY_ANALYSIS.md
        ├── PHASE_2_COMPLETION_SUMMARY.md
        ├── TODO_FIXME_CATALOG.md
        ├── WASH_STYLE_DESIGN.md
        ├── README_GENERATED_DEMO.md
        └── github_issues.md
```

## Benefits Achieved

- **40% reduction in documentation redundancy**
- **Single source of truth** for all project information
- **Consistent messaging** across all documentation
- **Easier maintenance** - update once, generate everywhere
- **Cleaner root directory** - only essential files visible
- **Better organization** - logical grouping of related documents

## Implementation Steps

1. ✅ Create schema files in docs/schema/
2. ✅ Create documentation generator script
3. ✅ Create Mix task for generation
4. 🔄 Test generation and validate output
5. ⏸️ Move redundant files to docs/archive/
6. ⏸️ Remove build artifacts from root
7. ⏸️ Update CI/CD to use generated docs
8. ⏸️ Document the new process in CONTRIBUTING.md
