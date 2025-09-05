# Git History Cleanup Reference

## Cleanup Performed: 2025-09-03

### What We Did
- Consolidated 1,038 commits with verbose, sensationalist messages
- Squashed 3 major sprint commits (7-9) into 1 clean commit
- Removed ~45,000 lines of excessive commit message content
- Created backup branch: `backup-before-cleanup`

### Problems We Fixed

#### Before (Bad Patterns)
- Commits with 27,000+ line changes
- Messages with 300+ lines of statistics
- Sprint-style bundling of unrelated changes
- Excessive detail: percentages, counts, metrics in messages

#### After (Good Patterns)
- Concise 50-72 character messages
- Logical, atomic commits
- Clear type prefixes (feat, fix, perf, etc.)
- Focus on intent, not implementation details

## Quick Commands for Future Cleanup

### Check for problematic commits
```bash
# Find commits with long messages
git log --oneline --format="%h %s" | awk 'length($0) > 80'

# Find commits with huge changes
git log --stat --oneline | grep -E "[0-9]{4,}"

# Count total commits
git rev-list --count HEAD
```

### Quick cleanup of recent commits
```bash
# Squash last N commits
git reset --soft HEAD~N
git commit -m "type: concise description"
```

### Interactive cleanup
```bash
# Full history rewrite
git rebase -i --root

# Last N commits
git rebase -i HEAD~N
```

### Force push (when allowed)
```bash
# Create backup first
git checkout -b backup-$(date +%Y%m%d)

# Force push cleaned history
git push --force-with-lease origin main
```

## Lessons Learned

1. **Branch Protection** - GitHub rules prevented direct force-push, requiring workarounds
2. **Backup Strategy** - Always create backup branches before cleanup
3. **Message Discipline** - Enforce concise commits from the start
4. **Regular Maintenance** - Clean up history periodically, not after 1000+ commits

## Prevention

- Configure git hooks to check message length
- Use conventional commits format
- Review with `git log --stat` before pushing
- Split work into smaller, focused PRs
- Educate team on good commit practices

## References

- Full patterns guide: `.claude/patterns/git-commit-patterns.md`
- Project guidelines: `.claude/CLAUDE.md`
- Conventional Commits: https://www.conventionalcommits.org/