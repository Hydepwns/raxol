# Documentation Consolidation Plan

## Current Issues
- 107 markdown files with significant overlap
- Multiple "getting started" guides
- Duplicated API information across files
- Nested guide structure too deep (guides/*/*)
- Terminal emulation docs scattered across 15+ files

## Consolidation Strategy

### Phase 1: Merge Redundant Content

1. **Single Getting Started**
   - Keep: `docs/getting-started.md` (main)
   - Remove: Duplicate installation/setup sections from other files
   - Move: Framework-specific setup to API reference

2. **Unified API Reference**
   - Keep: `docs/api-reference.md`
   - Merge: Component API docs from `docs/components/api/`
   - Remove: API snippets from guides

3. **Terminal Documentation**
   - Create: `docs/terminal.md` (single comprehensive guide)
   - Merge: 14 files from `docs/guides/terminal/`
   - Keep only unique implementation details

4. **Architecture**
   - Keep: `docs/ARCHITECTURE.md` (high-level)
   - Keep: `docs/adr/` (decision records)
   - Remove: Redundant architecture docs in guides

### Phase 2: Flatten Structure

From:
```
docs/
├── guides/
│   ├── accessibility/  (6 files)
│   ├── architecture/   (15 files)
│   ├── components/     (4 files)
│   ├── terminal/       (14 files)
│   └── ...
```

To:
```
docs/
├── getting-started.md
├── api-reference.md
├── architecture.md
├── terminal.md
├── components.md
├── performance.md
├── security.md
├── adr/             (keep as-is)
└── examples/        (keep interactive examples)
```

### Phase 3: Content Guidelines

Each doc should be:
- **Single Purpose**: One topic per file
- **Self-Contained**: No need to jump between files
- **Concise**: Remove repetition, keep essential info
- **Scannable**: Use clear headers, code blocks, lists
- **DRY**: Reference other docs, don't duplicate

## Files to Remove/Merge

### Immediate Removals (empty or redundant)
- `docs/tutorials/` subdirectories (empty)
- Duplicate installation guides
- Multiple README files in subdirectories

### Merge Candidates
- `guides/terminal/*` → `terminal.md`
- `guides/components/*` → `components.md`
- `guides/accessibility/*` → `accessibility.md`
- `guides/performance/*` → `performance.md`

## Expected Result
- From 107 files → ~20 files
- Clear navigation structure
- No duplicate content
- Faster to find information