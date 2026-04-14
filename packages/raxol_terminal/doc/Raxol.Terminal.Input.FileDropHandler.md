# `Raxol.Terminal.Input.FileDropHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/file_drop_handler.ex#L1)

Handles file drag-and-drop operations for the terminal emulator.

Processes file URIs from drag-and-drop events and provides secure
file access with permission controls and type validation.

## Features

- File URI parsing and validation
- Multiple file drop support
- MIME type detection
- File size and permission checking
- Security controls and sandbox validation
- Integration with system file watchers

## Supported Protocols

- `file://` - Local file system paths
- `content://` - Android content URIs (if applicable)
- Data URLs for small embedded content

## Security

- File access is restricted to allowed directories
- File size limits prevent memory exhaustion
- MIME type validation prevents execution of dangerous files
- Symlink resolution with loop detection

# `drop_event`

```elixir
@type drop_event() :: %{
  files: [file_info()],
  position: {non_neg_integer(), non_neg_integer()},
  modifiers: map(),
  timestamp: non_neg_integer()
}
```

# `drop_options`

```elixir
@type drop_options() :: %{
  optional(:max_files) =&gt; non_neg_integer(),
  optional(:max_file_size) =&gt; non_neg_integer(),
  optional(:allowed_mime_types) =&gt; [String.t()],
  optional(:allowed_extensions) =&gt; [String.t()],
  optional(:allowed_directories) =&gt; [String.t()],
  optional(:resolve_symlinks) =&gt; boolean(),
  optional(:validate_permissions) =&gt; boolean()
}
```

# `file_info`

```elixir
@type file_info() :: %{
  path: String.t(),
  name: String.t(),
  size: non_neg_integer(),
  mime_type: String.t(),
  permissions: map(),
  last_modified: DateTime.t()
}
```

# `create_temporary_copies`

```elixir
@spec create_temporary_copies([file_info()], map()) ::
  {:ok, [String.t()]} | {:error, term()}
```

Creates a temporary copy of dropped files in a secure location.

Useful for processing files without affecting the originals or when
working with files from untrusted sources.

## Parameters

- `files` - List of files to copy
- `options` - Copy options including temporary directory

## Returns

- `{:ok, copied_files}` - List of temporary file paths
- `{:error, reason}` - Error during copying

# `get_file_info`

```elixir
@spec get_file_info(String.t(), map()) :: {:ok, file_info()} | {:error, term()}
```

Gets detailed information about a file.

Retrieves file metadata including size, permissions, MIME type, and timestamps.

## Parameters

- `file_path` - Path to the file
- `options` - Options for information gathering

## Returns

- `{:ok, file_info}` - File information structure
- `{:error, reason}` - Error accessing file

# `parse_file_uri`

```elixir
@spec parse_file_uri(String.t()) ::
  {:ok, String.t()} | {:ok, {:data, binary(), String.t()}} | {:error, term()}
```

Parses a file URI and extracts the local file path.

Supports various URI schemes and handles URL decoding properly.

## Parameters

- `uri` - File URI string (e.g., "file:///path/to/file.txt")

## Returns

- `{:ok, path}` - Successfully extracted file path
- `{:error, reason}` - Error parsing URI

## Examples

    iex> FileDropHandler.parse_file_uri("file:///home/user/test%20file.txt")
    {:ok, "/home/user/test file.txt"}

    iex> FileDropHandler.parse_file_uri("http://example.com/file.txt")
    {:error, :unsupported_scheme}

# `process_drop_event`

```elixir
@spec process_drop_event(
  [String.t()],
  {non_neg_integer(), non_neg_integer()},
  drop_options()
) :: {:ok, drop_event()} | {:error, term()}
```

Processes a file drop event from the terminal.

Takes raw file URIs from a drag-and-drop operation and converts them
into validated file information structures.

## Parameters

- `file_uris` - List of file URIs from the drop event
- `position` - {x, y} coordinates where files were dropped
- `options` - Configuration options for validation and security

## Returns

- `{:ok, drop_event}` - Successfully processed drop event
- `{:error, reason}` - Error with validation failure details

## Examples

    iex> FileDropHandler.process_drop_event([
    ...>   "file:///home/user/document.txt",
    ...>   "file:///home/user/image.png"
    ...> ], {100, 200})
    {:ok, %{files: [...], position: {100, 200}, ...}}

# `validate_files`

```elixir
@spec validate_files([file_info()], drop_options()) :: :ok | {:error, term()}
```

Validates that a file drop operation meets security and size constraints.

## Parameters

- `files` - List of file information structures
- `options` - Validation options

## Returns

- `:ok` - All files pass validation
- `{:error, reason}` - Validation failure with details

# `watch_dropped_files`

```elixir
@spec watch_dropped_files([file_info()], map()) :: {:ok, pid()} | {:error, term()}
```

Watches dropped files for changes and executes callbacks.

Sets up file system watchers on dropped files to detect modifications,
deletions, or other changes.

## Parameters

- `files` - List of files to watch
- `callbacks` - Map of callback functions for different events

## Returns

- `{:ok, watcher_pid}` - File watcher process ID
- `{:error, reason}` - Error setting up file watching

---

*Consult [api-reference.md](api-reference.md) for complete listing*
