# Just Features Reference

Complete syntax reference for `just` features. See the [official manual](https://just.systems/man/en/) for exhaustive documentation.

## Recipe Attributes

Attributes are placed on the line(s) immediately before a recipe name.

| Attribute | Syntax | Effect |
|-----------|--------|--------|
| `[group]` | `[group('name')]` | Organize recipe under a heading in `--list` |
| `[doc]` | `[doc('text')]` | Set help text (overrides comment) |
| `[confirm]` | `[confirm]` or `[confirm('message')]` | Prompt before running |
| `[private]` | `[private]` | Hide from `--list` |
| `[no-cd]` | `[no-cd]` | Don't `cd` to justfile directory |
| `[no-exit-message]` | `[no-exit-message]` | Suppress "error: ..." on failure |
| `[no-quiet]` | `[no-quiet]` | Override `set quiet` for this recipe |
| `[script]` | `[script('interpreter')]` | Run recipe body as a single script |
| `[extension]` | `[extension('.py')]` | Set temp file extension (with `[script]`) |
| `[working-directory]` | `[working-directory('path')]` | Override working dir for this recipe |
| `[linux]` | `[linux]` | Only available on Linux |
| `[macos]` | `[macos]` | Only available on macOS |
| `[unix]` | `[unix]` | Available on Linux + macOS |
| `[windows]` | `[windows]` | Only available on Windows |
| `[positional-arguments]` | `[positional-arguments]` | Pass params as `$1`, `$2` for this recipe |

Multiple attributes can be stacked:

```just
[group('deploy')]
[confirm('Deploy to production?')]
[doc('Deploy all stacks to prod')]
deploy-prod:
    cdk deploy --all
```

## Settings

| Setting | Syntax | Default | Effect |
|---------|--------|---------|--------|
| `dotenv-load` | `set dotenv-load` | `false` | Load `.env` file |
| `dotenv-filename` | `set dotenv-filename := ".env.local"` | `".env"` | Custom dotenv filename |
| `dotenv-path` | `set dotenv-path := "/path/.env"` | — | Absolute path to dotenv file |
| `dotenv-required` | `set dotenv-required` | `false` | Error if dotenv file missing |
| `shell` | `set shell := ["bash", "-cu"]` | `["sh", "-cu"]` | Recipe shell |
| `quiet` | `set quiet` | `false` | Don't echo recipe lines |
| `export` | `set export` | `false` | Export all variables as env vars |
| `fallback` | `set fallback` | `false` | Search parent dirs for justfile |
| `positional-arguments` | `set positional-arguments` | `false` | Pass args as `$1`, `$2` |
| `working-directory` | `set working-directory := "src"` | justfile dir | Recipe working directory |
| `allow-duplicate-recipes` | `set allow-duplicate-recipes` | `false` | Allow recipe overrides |
| `allow-duplicate-variables` | `set allow-duplicate-variables` | `false` | Allow variable overrides |
| `ignore-comments` | `set ignore-comments` | `false` | Don't pass comments to shell |
| `tempdir` | `set tempdir := "/tmp"` | system | Temp dir for scripts |
| `windows-shell` | `set windows-shell := ["pwsh", "-NoLogo", "-c"]` | `["cmd", "/c"]` | Windows recipe shell |
| `windows-powershell` | `set windows-powershell` | `false` | Use PowerShell on Windows |
| `unstable` | `set unstable` | `false` | Enable unstable features |

## Built-in Functions

### Environment

| Function | Returns |
|----------|---------|
| `env_var('NAME')` | Value of `$NAME` (error if unset) |
| `env_var_or_default('NAME', 'fallback')` | Value of `$NAME` or `'fallback'` |
| `env('NAME')` | Alias for `env_var('NAME')` |
| `env('NAME', 'fallback')` | Alias for `env_var_or_default(...)` |

### System

| Function | Returns |
|----------|---------|
| `arch()` | CPU architecture (`x86_64`, `aarch64`, etc.) |
| `os()` | Operating system (`linux`, `macos`, `windows`) |
| `os_family()` | OS family (`unix`, `windows`) |
| `num_cpus()` | Number of CPUs as string |

### Path

| Function | Returns |
|----------|---------|
| `join(a, b)` | Path join (`a/b`) |
| `clean(path)` | Normalized path |
| `parent_directory(path)` | Parent dir |
| `file_name(path)` | Filename component |
| `file_stem(path)` | Filename without extension |
| `extension(path)` | File extension |
| `absolute_path(path)` | Absolute path |
| `without_extension(path)` | Path without extension |

### Path Testing

| Function | Returns |
|----------|---------|
| `path_exists(path)` | `"true"` or `"false"` |
| `is_dependency()` | `"true"` if recipe is running as dependency |

### String

| Function | Returns |
|----------|---------|
| `uppercase(s)` | Uppercased string |
| `lowercase(s)` | Lowercased string |
| `trim(s)` | Trimmed whitespace |
| `trim_start(s)` | Trimmed leading whitespace |
| `trim_end(s)` | Trimmed trailing whitespace |
| `trim_start_match(s, pat)` | Remove prefix `pat` |
| `trim_end_match(s, pat)` | Remove suffix `pat` |
| `replace(s, from, to)` | Replace all `from` with `to` |
| `replace_regex(s, regex, to)` | Regex replace |
| `quote(s)` | Shell-quoted string |
| `kebabcase(s)` | `kebab-case` |
| `snakecase(s)` | `snake_case` |
| `shoutysnakecase(s)` | `SHOUTY_SNAKE_CASE` |
| `titlecase(s)` | `Title Case` |
| `capitalize(s)` | `Capitalized` |

### Other

| Function | Returns |
|----------|---------|
| `uuid()` | Random UUID v4 |
| `sha256(s)` | SHA-256 hex digest |
| `sha256_file(path)` | SHA-256 of file contents |
| `blake3(s)` | BLAKE3 hex digest |
| `blake3_file(path)` | BLAKE3 of file contents |
| `datetime(format)` | Formatted UTC datetime |
| `datetime_utc(format)` | Same as `datetime` |
| `just_executable()` | Path to `just` binary |
| `just_pid()` | PID of `just` process |
| `justfile()` | Path to current justfile |
| `justfile_directory()` | Dir containing justfile |
| `source_file()` | Path to current source file |
| `source_directory()` | Dir of current source file |
| `invocation_directory()` | Dir from which `just` was invoked |
| `invocation_directory_native()` | Native path version |
| `error(msg)` | Abort with error message |
| `assert(condition, msg)` | Abort if condition is false |
| `cache_directory()` | User cache dir |
| `config_directory()` | User config dir |
| `data_directory()` | User data dir |
| `home_directory()` | User home dir |

## Conditional Expressions

```just
# if/else
foo := if env_var_or_default("CI", "") == "true" { "ci" } else { "local" }

# Chained if/else
tier := if env == "prod" { "production" } else if env == "staging" { "staging" } else { "development" }

# Regex match
is_release := if version =~ '\d+\.\d+\.\d+' { "yes" } else { "no" }

# Operators: == != =~
```

Conditionals work in variable assignments and inside recipe bodies:

```just
deploy env:
    {{ if env == "prod" { "echo 'PRODUCTION DEPLOY'" } else { "" } }}
    ./deploy.sh {{env}}
```

## Variables and Expressions

```just
# Simple assignment
name := "my-project"

# Backtick — capture command output
hash := `git rev-parse --short HEAD`

# Path concatenation with / operator
bin := ".venv" / "bin" / "python"

# Concatenation with +
greeting := "Hello, " + name

# Environment variable
home := env_var('HOME')

# Format strings (f-strings)
msg := f"deploying {name} at {hash}"

# Shell-expanded strings
files := x'ls *.txt'
```

## Parameters

```just
# Required parameter
build target:
    cargo build --target {{target}}

# Optional parameter with default
serve port="8080":
    python -m http.server {{port}}

# Variadic: one or more (required)
test +FILES:
    pytest {{FILES}}

# Variadic: zero or more (optional)
lint *FLAGS:
    ruff check {{FLAGS}} .

# Variadic with default
docker-build +TAGS="latest":
    docker build {{TAGS}} .

# Parameters with env var default
greet name=env_var_or_default('USER', 'world'):
    echo "Hello, {{name}}"
```

## Dependencies

```just
# Simple dependency
test: build
    cargo test

# Multiple dependencies
all: build test lint

# Dependency with arguments
push target: (build target) (test target)
    git push

# Run dependency after recipe
late-dep: && cleanup
    ./do-work.sh
```

## Modules

```just
# Load module from infra.just or infra/mod.just
mod infra

# Import recipes inline (no namespace prefix)
import 'common.just'

# Optional import (no error if file missing)
import? 'local.just'

# Optional module
mod? local
```

Run module recipes with `::` separator: `just infra::deploy`

## Installation

| Method | Command |
|--------|---------|
| Homebrew | `brew install just` |
| Cargo | `cargo install just` |
| apt (Ubuntu 24.04+) | `apt install just` |
| npm | `npx just-install` |
| Conda | `conda install -c conda-forge just` |
| Scoop (Windows) | `scoop install just` |
| Chocolatey | `choco install just` |
| Winget | `winget install just` |
| Nix | `nix-env -iA nixpkgs.just` |
| asdf | `asdf plugin add just && asdf install just latest` |
| Pre-built binary | `curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \| bash -s -- --to /usr/local/bin` |
