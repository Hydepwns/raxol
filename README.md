# Raxol

A comprehensive terminal UI framework for Elixir with web interface capabilities.

## Project Status

The Raxol project is currently in active development. We have completed the initial setup phase and are now focusing on implementing the core terminal emulation and web interface components.

### Current Features

- Basic project structure and configuration
- Terminal and web supervisors
- CI/CD pipeline setup
- Development environment configuration
- Documentation framework

### In Progress

- Terminal emulation layer
- ANSI processing module
- Web interface components
- Session management
- Authentication system

## Features

- Terminal emulation with ANSI support
- Web interface for remote access
- Real-time terminal synchronization
- Session management
- Authentication and authorization
- Performance monitoring
- Extensible architecture

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/hydepwns/raxol.git
   cd raxol
   ```

2. Install dependencies:

   ```bash
   mix deps.get
   ```

3. Set up the database:

   ```bash
   mix ecto.setup
   ```

4. Start the application:

   ```bash
   mix phx.server
   ```

## Project Structure

```
raxol/
├── assets/                 # Frontend assets (JS, CSS)
├── config/                 # Configuration files
├── lib/                    # Application code
│   ├── raxol/             # Core application
│   │   ├── terminal/      # Terminal emulation
│   │   └── web/           # Web interface
│   └── raxol_web/         # Phoenix web interface
├── priv/                   # Private assets
├── test/                   # Test files
├── .github/                # GitHub configuration
│   ├── workflows/         # GitHub Actions
│   └── dependabot.yml     # Dependabot config
├── .formatter.exs         # Code formatting
├── .credo.exs             # Code quality
├── .travis.yml            # Travis CI config
├── mix.exs                # Project configuration
├── README.md              # Project documentation
├── CHANGELOG.md           # Version history
├── LICENSE.md             # License information
└── CONTRIBUTING.md        # Development guide
```

## Configuration

The application can be configured through environment variables or configuration files. See `config/` directory for details.

### Environment Variables

- `DATABASE_URL`: Database connection URL
- `SECRET_KEY_BASE`: Secret key for session encryption
- `PORT`: Port to run the web server on
- `TERMINAL_WIDTH`: Default terminal width
- `TERMINAL_HEIGHT`: Default terminal height
- `WEB_THEME`: Default web interface theme

## Development

### Running Tests

```bash
mix test
```

### Code Quality

```bash
mix credo
mix dialyzer
```

### Documentation

```bash
mix docs
```

## Architecture

The application is built on a modular architecture with the following components:

- Terminal Layer: Handles terminal emulation and ANSI processing
- Web Layer: Provides web interface and WebSocket support
- Core Services: Manages sessions, authentication, and system state
- Utilities: Common functionality and helpers

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our development process and how to contribute to the project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Acknowledgments

- Phoenix Framework
- ExTermbox
- Phoenix LiveView
- All contributors and maintainers
