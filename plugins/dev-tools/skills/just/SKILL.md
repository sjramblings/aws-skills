---
name: just
description: >-
  Create and manage justfiles for project-specific task automation. Use when
  the user mentions justfile, just recipes, task runner, command runner, project
  commands, just setup, or needs a simple alternative to make. Covers recipe
  syntax, settings, parameters, dependencies, shebang recipes, modules, and
  modern attributes like [group], [confirm], and [doc]. Always use this skill
  when creating or editing a justfile, even for simple recipe additions.
---

# Just Command Runner

[GitHub Repository](https://github.com/casey/just) · [Manual](https://just.systems/man/en/)

## Quick Reference

- **Install**: `brew install just` · `cargo install just` · `npm install -g just-install` · `apt install just`
- **File**: `justfile` (or `Justfile`) at project root
- **Run**: `just` (default recipe) · `just <recipe>` · `just --list`

## Creating a Justfile

Always start with these conventions:

```just
set dotenv-load        # load .env automatically
set shell := ["bash", "-cu"]

# Default recipe - list available commands
[private]
default:
    @just --list
```

- Comments above recipes (`# ...`) become help text in `just --list`
- Use `@` prefix to suppress command echo for a line
- Use `set quiet` to suppress echo globally

## Recipe Syntax

### Basic Recipes

```just
# Recipe with dependency
test: build
    cargo test

# Recipe with parameters
deploy env:
    ./deploy.sh --target {{env}}

# Optional parameter with default
serve port="8080":
    python -m http.server {{port}}

# Variadic: one or more args (required)
test +FILES:
    pytest {{FILES}}

# Variadic: zero or more args (optional)
lint *FLAGS:
    ruff check {{FLAGS}} .
```

### Recipe Attributes

```just
[group('infra')]           # Organize in --list output
[doc('Deploy to AWS')]     # Override comment as help text
[confirm('Continue?')]     # Prompt yes/no before running
[private]                  # Hide from --list
[no-cd]                    # Don't change to justfile directory
[no-exit-message]          # Suppress error message on failure
[linux]                    # Only available on Linux
[macos]                    # Only available on macOS
[unix]                     # Available on Linux and macOS
[windows]                  # Only available on Windows
```

### Shebang Recipes

Use other languages by starting with a shebang line:

```just
check-env:
    #!/usr/bin/env python3
    import os
    print(f"HOME = {os.environ['HOME']}")
```

### Dependencies with Arguments

```just
push target: (build target)
    git push

build target:
    cargo build --target {{target}}
```

## Settings

| Setting | Syntax | Effect |
|---------|--------|--------|
| `dotenv-load` | `set dotenv-load` | Load `.env` file |
| `dotenv-filename` | `set dotenv-filename := ".env.local"` | Custom `.env` filename |
| `shell` | `set shell := ["bash", "-cu"]` | Override default shell |
| `quiet` | `set quiet` | Don't echo recipe lines |
| `export` | `set export` | Export all variables as env vars |
| `fallback` | `set fallback` | Search parent dirs for justfile |
| `positional-arguments` | `set positional-arguments` | Pass args as `$1`, `$2` |
| `working-directory` | `set working-directory := "src"` | Set recipe working dir |
| `allow-duplicate-recipes` | `set allow-duplicate-recipes` | Allow overriding recipes |

## Variables and Expressions

```just
# Assignment
version := "1.0.0"

# Environment variable with fallback
env := env_var_or_default("ENV", "dev")

# Path concatenation (/ operator)
python := ".venv" / "bin" / "python"

# Backtick — capture shell output
git_hash := `git rev-parse --short HEAD`

# Conditional
mode := if env_var_or_default("CI", "") == "true" { "ci" } else { "local" }
```

## Modules

```just
# Load from name.just or name/mod.just (namespaced)
mod infra

# Import inline (no namespace)
import 'common.just'
```

Access module recipes: `just infra::deploy`

## For Complete Syntax Reference

See [references/just-features.md](references/just-features.md) for all built-in functions, conditional expressions, settings, and attribute details.

## Example Justfile

See [examples/cdk-python.just](examples/cdk-python.just) for a complete AWS CDK project justfile demonstrating groups, confirms, shebang recipes, variadic parameters, and dotenv integration.
