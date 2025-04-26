---
title: Development Environment Setup
description: Setting up the Raxol development environment from source
date: 2023-04-04
author: Raxol Team
section: installation
tags: [installation, setup, development, contributing]
---

# Development Environment Setup

This guide explains how to set up your environment to develop and contribute to Raxol. If you want to _use_ Raxol as a dependency in your own project, see the [Installation Guide](Installation.md).

## System Requirements

Ensure you have the following installed:

- Elixir 1.14 or later
- Erlang/OTP 25 or later
- Node.js 16 or later (for JavaScript components)
- npm 8 or later (for JavaScript components)

For platform-specific instructions on installing these system dependencies, see the [Cross-Platform Support](CrossPlatformSupport.md) guide.

## Getting the Code

1.  Clone the repository:
    ```bash
    git clone https://github.com/Hydepwns/raxol.git
    cd raxol
    ```

## Building the Project

1.  Install Elixir dependencies:
    ```bash
    mix deps.get
    ```
2.  Compile the project:
    ```bash
    mix compile
    ```
3.  Run the tests to ensure everything is set up correctly:
    ```bash
    mix test
    ```

## Next Steps

Now you have a working development environment. You can start exploring the code in `/lib` or run the examples in `/examples`. See the main [README.md](../../README.md) for project structure and other development tasks like running static analysis.
