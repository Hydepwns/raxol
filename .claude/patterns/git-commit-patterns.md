# Git Commit Patterns and Guidelines

## Context: History Cleanup (2025-09-03)

We cleaned up 1,038 commits that had overly verbose, "sensationalist" commit messages. Many commits exceeded 1000+ lines of changes with messages containing hundreds of lines of statistics and details.

## Anti-Patterns to Avoid

### ❌ Bad Patterns We Fixed

1. **Sprint-style mega commits**
   ```
   feat(sprint7-9): Complete functional programming transformation
   
   Sprint 7-9 comprehensive refactoring achieving enterprise-grade functional patterns:
   
   SPRINT 7: GenServer Architecture (100% Complete)
   - Eliminated all 253 Process.get/put calls
   - Converted 30+ modules to supervised GenServers
   [... 300+ more lines of statistics ...]
   ```

2. **Excessive statistics in commit messages**
   ```
   - 100% Process.get/put elimination
   - 97.4% cond statement elimination
   - 8.1% if statement reduction
   - 58.3% try/catch elimination
   ```

3. **Bundling unrelated changes**
   - Mixing refactors, bug fixes, and features in one commit
   - 27,000+ line changes in single commits

## ✅ Good Commit Patterns

### Commit Message Format
```
<type>: <description> (50 chars max)

[optional body - 72 chars per line max]
```

### Types
- `feat`: New feature
- `fix`: Bug fix  
- `perf`: Performance improvement
- `refactor`: Code restructuring
- `docs`: Documentation only
- `test`: Test additions/changes
- `chore`: Maintenance tasks

### Examples of Good Messages

**Instead of:**
```
feat(sprint7-9): Complete functional programming transformation
[300+ lines of details about Process.get/put elimination, GenServer conversion, etc.]
```

**Use:**
```
feat: Complete functional programming refactor

Converted to GenServer architecture and improved pattern matching.
```

**Instead of:**
```
fix: Resolve compilation issues with NIF loading and build system and fix property tests and improve test infrastructure
```

**Use separate commits:**
```
fix: Resolve NIF loading issue
fix: Update build system configuration  
test: Improve property test infrastructure
```

## Commit Size Guidelines

### Atomic Commits
- One logical change per commit
- If you can't describe it in 50 chars, it's probably too big
- Break large features into smaller, logical commits

### Line Changes
- Aim for < 500 lines per commit
- If > 1000 lines, strongly consider splitting
- Massive refactors should be a series of commits, not one

## Working Practices

### During Development

1. **Commit frequently with clear messages**
   ```bash
   git add lib/specific/file.ex
   git commit -m "refactor: Extract validation logic to helper"
   ```

2. **Use interactive rebase to clean up before pushing**
   ```bash
   git rebase -i HEAD~5
   # Squash related commits
   # Reword messages to be concise
   ```

3. **Never use sprint-style bundling**
   - Don't accumulate weeks of work into one commit
   - Don't include statistics in commit messages
   - Focus on WHAT changed, not HOW MUCH

### Before Major Pushes

Review your commits:
```bash
# Check commit messages aren't too long
git log --oneline -10

# Check for commits with huge changes
git log --stat --oneline | grep -E "[0-9]{4,}"
```

## Memory Rules for AI Assistant

When helping with commits:

1. **Keep commit messages under 72 characters** for the first line
2. **Split complex work** into logical, atomic commits
3. **Avoid statistics** in commit messages
4. **Focus on intent**, not implementation details
5. **Suggest commit splitting** when changes exceed 500 lines
6. **Never create "sprint" commits** that bundle multiple features

## Cleanup Tools

If history gets messy again:

### Quick consolidation of recent commits
```bash
# Squash last N commits
git reset --soft HEAD~N
git commit -m "feat: Clear, concise description"
```

### Message cleanup without changing history
```bash
git filter-branch --msg-filter 'head -1 | cut -c1-72' HEAD~20..HEAD
```

### Interactive cleanup
```bash
git rebase -i --root
# Mark commits to squash/fixup
# Rewrite messages to be concise
```

## Prevention Strategies

1. **Set up commit hooks** to check message length
2. **Use conventional commits** format
3. **Review before pushing** with `git log --stat`
4. **Break work into smaller PRs** instead of mega-commits
5. **Focus on clarity over completeness** in messages

## Learned Lessons

From our cleanup on 2025-09-03:
- Reduced 1,038 commits by consolidating verbose sprint commits
- Removed ~45,000 lines of excessive commit message content  
- Created cleaner history while preserving all code changes
- Branch protection prevented direct force-push, requiring workarounds

Remember: Git history is for humans. Make it readable, not exhaustive.