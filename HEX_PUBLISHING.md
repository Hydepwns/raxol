# Hex.pm Publishing Instructions

Manual instructions for publishing Raxol v2.0.0 packages to Hex.pm.

## Prerequisites

1. Hex account with publishing permissions
2. Local authentication configured: `mix hex.user auth`
3. All packages tested and ready

## Package Publishing Order

Publish in dependency order to ensure all dependencies are available:

### 1. raxol_core (zero dependencies)

```bash
cd apps/raxol_core
mix hex.publish

# Review package contents when prompted
# Confirm version 2.0.0
# Provide package description when asked
# Type 'Y' to proceed
```

Expected output:
- Package: raxol_core 2.0.0
- Files: lib/, mix.exs, README.md, LICENSE, CHANGELOG.md
- Dependencies: none

### 2. raxol_plugin (depends on raxol_core)

```bash
cd ../raxol_plugin
mix hex.publish
```

Expected output:
- Package: raxol_plugin 2.0.0
- Files: lib/, mix.exs, README.md, LICENSE, CHANGELOG.md
- Dependencies: raxol_core ~> 2.0

### 3. raxol_liveview (depends on raxol_core)

```bash
cd ../raxol_liveview
mix hex.publish
```

Expected output:
- Package: raxol_liveview 2.0.0
- Files: lib/, priv/, mix.exs, README.md, LICENSE, CHANGELOG.md
- Dependencies: raxol_core ~> 2.0, phoenix_live_view, phoenix, phoenix_html

### 4. raxol (meta-package, depends on all)

```bash
cd ../raxol
mix hex.publish
```

Expected output:
- Package: raxol 2.0.0
- Files: lib/, mix.exs, README.md, LICENSE, CHANGELOG.md
- Dependencies: raxol_core ~> 2.0, raxol_liveview ~> 2.0, raxol_plugin ~> 2.0

## Verification

After publishing, verify each package:

```bash
# Check package exists and is accessible
mix hex.info raxol_core
mix hex.info raxol_plugin
mix hex.info raxol_liveview
mix hex.info raxol

# Verify version
mix hex.info raxol_core | grep "2.0.0"
```

## Test Installation

Create a new project to test the published packages:

```bash
# Test core package
mix new test_raxol_core
cd test_raxol_core
# Add to mix.exs: {:raxol_core, "~> 2.0"}
mix deps.get
mix compile

# Test meta-package
cd ..
mix new test_raxol_full
cd test_raxol_full
# Add to mix.exs: {:raxol, "~> 2.0"}
mix deps.get
mix compile
```

## Documentation

After publishing, documentation will be automatically generated at:
- https://hexdocs.pm/raxol_core
- https://hexdocs.pm/raxol_liveview
- https://hexdocs.pm/raxol_plugin
- https://hexdocs.pm/raxol

## Troubleshooting

### "package name already taken"
- Package names are reserved - contact Hex.pm support or choose different name

### "dependencies not found"
- Ensure raxol_core is published before raxol_liveview/raxol_plugin
- Check dependency versions match published versions

### "invalid metadata"
- Verify mix.exs has all required fields: name, version, description, licenses
- Ensure files list includes all necessary files

### "authentication failed"
- Run: `mix hex.user auth`
- Check you have publish permissions for the organization

## Updating Dependencies After Publishing

If packages need updates after initial publish:

1. Update version in mix.exs (e.g., 2.0.1)
2. Update CHANGELOG.md with changes
3. Follow same publishing order as above
4. Hex.pm will automatically version the update

## Package URLs

After publishing, packages will be available at:
- https://hex.pm/packages/raxol_core
- https://hex.pm/packages/raxol_liveview
- https://hex.pm/packages/raxol_plugin
- https://hex.pm/packages/raxol

## Alternative: Automated Publishing with GitHub Actions

For automated publishing on git tag, see `.github/workflows/hex-publish.yml` (to be created).

Workflow:
```bash
git tag v2.0.0
git push origin v2.0.0
# GitHub Actions will automatically publish all packages
```
