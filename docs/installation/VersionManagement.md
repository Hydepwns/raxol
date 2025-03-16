# Raxol Version Management

This guide details how to manage Raxol versions, perform updates, and configure the update system.

## Version Check Commands

Raxol provides commands to check and manage versions:

```bash
# Display current version
raxol --version

# Check for available updates
raxol update --check

# Force update check (bypass cache)
raxol update --check --force
```

## Update System

### Automatic Updates

Raxol includes a built-in update system that can automatically check for and apply updates.

```bash
# Check for updates without installing
raxol update check

# Download and install the latest version
raxol update

# Update to a specific version
raxol update --version 1.2.3

# Rollback to previous version
raxol update rollback
```

### Delta Updates

Raxol supports efficient delta updates, which only download the differences between versions rather than the entire package, resulting in:

- Faster updates with smaller downloads (typically 80-90% smaller)
- Reduced bandwidth usage
- More efficient update process on slow connections

Delta updates are used automatically when available. To manage delta updates:

```bash
# Check delta update availability without installing
raxol update --delta-info

# Force a full update (disable delta updates)
raxol update --no-delta

# Update to a specific version using delta if available
raxol update --version 1.2.3
```

Example delta update information:
```
Delta update available!
Full package size: 15.50 MB
Delta size: 1.37 MB
Space savings: 91%

To update using delta updates, run: raxol update
```

### Update Configuration

You can configure how Raxol handles updates:

```bash
# Enable automatic update checks
raxol update --auto on

# Disable automatic update checks
raxol update --auto off
```

Update settings are stored in `~/.raxol/update_settings.json`. This file can be edited manually if needed:

```json
{
  "auto_check": true,
  "last_check": 1679013245,
  "channel": "stable"
}
```

## Managing Multiple Versions

Raxol supports installing and managing multiple versions side by side.

### Listing Installed Versions

```bash
raxol version list
```

Example output:
```
Installed Raxol versions:
* 1.2.0 (current)
  1.1.0
  1.0.5
```

### Switching Versions

```bash
raxol version use 1.1.0
```

This command will switch the active Raxol version to 1.1.0.

### Removing Old Versions

```bash
raxol version remove 1.0.5
```

This will remove the specified version from your system.

## Update Channels

Raxol supports different update channels:

- **stable**: Production-ready releases (default)
- **beta**: Pre-release versions with new features
- **nightly**: Latest development builds

To change your update channel:

```bash
raxol update --channel stable
raxol update --channel beta
raxol update --channel nightly
```

## Update Notifications

Raxol will display update notifications when a new version is available:

```
Update Available!
A new version of Raxol is available: v1.2.0 (current: v1.1.0)
Run raxol update to update
```

## Offline Updates

For environments without internet access, Raxol supports offline updates:

```bash
# Download update package without installing
raxol update download --output /path/to/save

# Install from a local package
raxol update install --file /path/to/raxol-1.2.0.tar.gz
```

## Configuration Migration

When updating between major versions, configuration files might need migration:

```bash
# Check if migration is needed
raxol config check

# Migrate configuration files
raxol config migrate

# Backup configuration before migration
raxol config backup
```

## Troubleshooting Updates

### Common Update Issues

#### Update check fails

- Check your internet connection
- Ensure GitHub access isn't blocked by your firewall
- Try with `--force` flag: `raxol update --check --force`

#### Update installation fails

- Ensure you have write permission to the installation directory
- Check disk space
- Try running with elevated privileges (sudo/administrator)

#### Rollback needed

If an update causes issues, you can rollback to the previous version:

```bash
raxol update rollback
```

### Update Logs

Update logs are stored in `~/.raxol/logs/updates.log` for troubleshooting purposes. 