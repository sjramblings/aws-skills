# AWS CDK Justfile
# Usage: just <recipe> [args]
# Run `just` or `just --list` to see available recipes

set dotenv-load := true
set shell := ["bash", "-cu"]

# Default environment (override with ENV=prod just deploy)
ENV := env_var_or_default("ENV", "dev")

# AWS Configuration (loaded from .env or .env.{ENV})
AWS_PROFILE := env_var_or_default("AWS_PROFILE", "default")
AWS_REGION := env_var_or_default("AWS_REGION", "us-east-1")
AWS_ACCOUNT_ID := env_var_or_default("AWS_ACCOUNT_ID", "")

# CDK Configuration
CDK_CONTEXT := env_var_or_default("CDK_CONTEXT", "")
CDK_REQUIRE_APPROVAL := env_var_or_default("CDK_REQUIRE_APPROVAL", "broadening")

# Python Configuration
VENV_DIR := ".venv"
PYTHON := VENV_DIR / "bin/python"
PIP := VENV_DIR / "bin/pip"

# Colors for output
_green := '\033[0;32m'
_yellow := '\033[0;33m'
_red := '\033[0;31m'
_nc := '\033[0m'

# Default recipe - show help
[private]
default:
    @just --list

# ─────────────────────────────────────────────────────────────────────────────
# Environment Setup
# ─────────────────────────────────────────────────────────────────────────────

# Create Python virtual environment
[group('setup')]
venv:
    #!/usr/bin/env bash
    if [ ! -d "{{ VENV_DIR }}" ]; then
        echo -e "{{ _green }}Creating virtual environment...{{ _nc }}"
        python3 -m venv {{ VENV_DIR }}
        echo -e "{{ _green }}Virtual environment created at {{ VENV_DIR }}{{ _nc }}"
    else
        echo -e "{{ _yellow }}Virtual environment already exists{{ _nc }}"
    fi

# Install all dependencies
[group('setup')]
install: venv
    #!/usr/bin/env bash
    echo -e "{{ _green }}Installing dependencies...{{ _nc }}"
    source {{ VENV_DIR }}/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    [ -f requirements-dev.txt ] && pip install -r requirements-dev.txt || true
    echo -e "{{ _green }}Dependencies installed{{ _nc }}"

# Clean virtual environment and caches
[group('setup')]
[confirm('This will delete .venv and cdk.out. Continue?')]
clean:
    #!/usr/bin/env bash
    echo -e "{{ _yellow }}Cleaning up...{{ _nc }}"
    rm -rf {{ VENV_DIR }}
    rm -rf cdk.out
    rm -rf .pytest_cache
    rm -rf **/__pycache__
    rm -rf **/*.egg-info
    echo -e "{{ _green }}Cleanup complete{{ _nc }}"

# ─────────────────────────────────────────────────────────────────────────────
# AWS Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Show current AWS configuration
[group('ops')]
aws-whoami:
    #!/usr/bin/env bash
    echo -e "{{ _green }}Current AWS Configuration:{{ _nc }}"
    echo "  Environment: {{ ENV }}"
    echo "  Profile:     {{ AWS_PROFILE }}"
    echo "  Region:      {{ AWS_REGION }}"
    echo "  Account ID:  {{ AWS_ACCOUNT_ID }}"
    echo ""
    echo -e "{{ _green }}AWS Identity:{{ _nc }}"
    aws sts get-caller-identity --profile {{ AWS_PROFILE }} --region {{ AWS_REGION }}

# Bootstrap CDK for the configured account/region
[group('cdk')]
bootstrap:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Bootstrapping CDK...{{ _nc }}"
    echo "  Profile: {{ AWS_PROFILE }}"
    echo "  Region:  {{ AWS_REGION }}"
    echo "  Account: {{ AWS_ACCOUNT_ID }}"
    if [ -z "{{ AWS_ACCOUNT_ID }}" ]; then
        echo -e "{{ _red }}Error: AWS_ACCOUNT_ID not set. Add it to your .env file.{{ _nc }}"
        exit 1
    fi
    cdk bootstrap aws://{{ AWS_ACCOUNT_ID }}/{{ AWS_REGION }} \
        --profile {{ AWS_PROFILE }}

# Bootstrap CDK with trust for CI/CD pipelines (accepts trusted account IDs)
[group('cdk')]
[doc('Bootstrap with cross-account trust for CI/CD pipelines')]
bootstrap-pipeline *TRUSTED_ACCOUNTS:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Bootstrapping CDK with pipeline trust...{{ _nc }}"
    if [ -z "{{ AWS_ACCOUNT_ID }}" ]; then
        echo -e "{{ _red }}Error: AWS_ACCOUNT_ID not set{{ _nc }}"
        exit 1
    fi
    TRUST_ARGS=""
    for account in {{ TRUSTED_ACCOUNTS }}; do
        TRUST_ARGS="$TRUST_ARGS --trust $account"
    done
    cdk bootstrap aws://{{ AWS_ACCOUNT_ID }}/{{ AWS_REGION }} \
        --profile {{ AWS_PROFILE }} \
        --cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess \
        $TRUST_ARGS

# ─────────────────────────────────────────────────────────────────────────────
# CDK Commands
# ─────────────────────────────────────────────────────────────────────────────

# Synthesize CloudFormation templates
[group('cdk')]
synth *STACKS:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Synthesizing CDK stacks...{{ _nc }}"
    CONTEXT_ARGS=""
    if [ -n "{{ CDK_CONTEXT }}" ]; then
        CONTEXT_ARGS="--context {{ CDK_CONTEXT }}"
    fi
    cdk synth {{ STACKS }} \
        --profile {{ AWS_PROFILE }} \
        $CONTEXT_ARGS

# Show differences between deployed and local stacks
[group('cdk')]
diff *STACKS:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Comparing stacks...{{ _nc }}"
    cdk diff {{ STACKS }} \
        --profile {{ AWS_PROFILE }}

# Deploy stacks (use STACKS="--all" or specific stack names)
[group('cdk')]
deploy *STACKS:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Deploying stacks...{{ _nc }}"
    echo "  Environment: {{ ENV }}"
    echo "  Profile:     {{ AWS_PROFILE }}"
    echo "  Region:      {{ AWS_REGION }}"
    STACKS_ARG="{{ STACKS }}"
    if [ -z "$STACKS_ARG" ]; then
        STACKS_ARG="--all"
    fi
    cdk deploy $STACKS_ARG \
        --profile {{ AWS_PROFILE }} \
        --require-approval {{ CDK_REQUIRE_APPROVAL }}

# Deploy all stacks without approval prompts (for CI/CD)
[group('cdk')]
[doc('Deploy without approval prompts (CI/CD mode)')]
deploy-ci *STACKS:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Deploying stacks (CI mode)...{{ _nc }}"
    STACKS_ARG="{{ STACKS }}"
    if [ -z "$STACKS_ARG" ]; then
        STACKS_ARG="--all"
    fi
    cdk deploy $STACKS_ARG \
        --profile {{ AWS_PROFILE }} \
        --require-approval never \
        --ci

# Destroy stacks (requires explicit stack names for safety)
[group('cdk')]
[confirm('This will DESTROY stacks. Are you sure?')]
destroy +STACKS:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _yellow }}Destroying stacks: {{ STACKS }}{{ _nc }}"
    echo "  Environment: {{ ENV }}"
    echo "  Profile:     {{ AWS_PROFILE }}"
    cdk destroy {{ STACKS }} \
        --profile {{ AWS_PROFILE }} \
        --force

# List all stacks in the CDK app
[group('cdk')]
ls:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    cdk ls --profile {{ AWS_PROFILE }}

# Build agent deployment package (optional; CDK zips agents/simple_runtime automatically on deploy)
[group('cdk')]
agent-package:
    #!/usr/bin/env bash
    echo -e "{{ _green }}Building agent deployment package...{{ _nc }}"
    mkdir -p agents/simple_runtime/dist
    (cd agents/simple_runtime && zip -r dist/deployment_package.zip main.py requirements.txt -x "*.pyc" -x "__pycache__/*" -x "dist/*")
    echo -e "{{ _green }}Created agents/simple_runtime/dist/deployment_package.zip{{ _nc }}"

# Show CDK doctor diagnostics
[group('cdk')]
doctor:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    cdk doctor

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────

# Run all tests
[group('dev')]
test *ARGS:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Running tests...{{ _nc }}"
    pytest {{ ARGS }}

# Run tests with coverage
[group('dev')]
test-cov:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Running tests with coverage...{{ _nc }}"
    pytest --cov=infrastructure --cov=backend --cov-report=term-missing

# Lint Python code
[group('dev')]
lint:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Linting code...{{ _nc }}"
    ruff check .

# Format Python code
[group('dev')]
fmt:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Formatting code...{{ _nc }}"
    ruff format .
    ruff check --fix .

# Type check Python code
[group('dev')]
typecheck:
    #!/usr/bin/env bash
    source {{ VENV_DIR }}/bin/activate
    echo -e "{{ _green }}Type checking...{{ _nc }}"
    mypy infrastructure backend --ignore-missing-imports

# ─────────────────────────────────────────────────────────────────────────────
# Multi-Environment Shortcuts
# ─────────────────────────────────────────────────────────────────────────────

# Deploy to dev environment
[group('cdk')]
deploy-dev *STACKS:
    ENV=dev just deploy {{ STACKS }}

# Deploy to staging environment
[group('cdk')]
deploy-staging *STACKS:
    ENV=staging just deploy {{ STACKS }}

# Deploy to production environment
[group('cdk')]
[confirm('You are about to deploy to PRODUCTION. Type "yes" to confirm.')]
deploy-prod *STACKS:
    ENV=prod CDK_REQUIRE_APPROVAL=broadening just deploy {{ STACKS }}

# ─────────────────────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────────────────────

# Generate .env file from example
[group('setup')]
init-env:
    #!/usr/bin/env bash
    if [ -f .env ]; then
        echo -e "{{ _yellow }}.env already exists. Skipping.{{ _nc }}"
    else
        if [ -f .env.example ]; then
            cp .env.example .env
            echo -e "{{ _green }}Created .env from .env.example{{ _nc }}"
            echo "Please edit .env with your AWS configuration."
        else
            echo -e "{{ _red }}.env.example not found{{ _nc }}"
        fi
    fi

# Full setup: create venv, install deps, init env
[group('setup')]
[doc('One-command project setup: venv + deps + .env')]
setup: venv install init-env
    @echo -e "{{ _green }}Setup complete!{{ _nc }}"
    @echo "Next steps:"
    @echo "  1. Edit .env with your AWS configuration"
    @echo "  2. Run: just aws-whoami"
    @echo "  3. Run: just bootstrap"

# Watch for changes and re-synthesize (requires entr)
[group('dev')]
watch:
    #!/usr/bin/env bash
    if ! command -v entr &> /dev/null; then
        echo -e "{{ _red }}Error: 'entr' not installed. Install with: brew install entr{{ _nc }}"
        exit 1
    fi
    echo -e "{{ _green }}Watching for changes...{{ _nc }}"
    find . -name "*.py" -not -path "./.venv/*" | entr -c just synth

# Open AWS Console for the current account
[group('ops')]
console:
    #!/usr/bin/env bash
    echo -e "{{ _green }}Opening AWS Console...{{ _nc }}"
    open "https://{{ AWS_REGION }}.console.aws.amazon.com/console/home?region={{ AWS_REGION }}"

# Show CloudFormation stacks in AWS
[group('ops')]
cf-stacks:
    #!/usr/bin/env bash
    echo -e "{{ _green }}CloudFormation Stacks:{{ _nc }}"
    aws cloudformation list-stacks \
        --profile {{ AWS_PROFILE }} \
        --region {{ AWS_REGION }} \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --query 'StackSummaries[].{Name:StackName,Status:StackStatus,Updated:LastUpdatedTime}' \
        --output table

# ─────────────────────────────────────────────────────────────────────────────
# Agentic Commands (Claude Code)
# ─────────────────────────────────────────────────────────────────────────────

# Deterministic CDK setup (hook only)
[group('claude')]
cldi:
    claude --model opus --dangerously-skip-permissions --init

# Agentic CDK setup (hook + /install for reporting)
[group('claude')]
cldii:
    claude --model opus --dangerously-skip-permissions --init "/install"

# Agentic CDK setup - interactive (human-in-the-loop)
[group('claude')]
cldit:
    claude --model opus --dangerously-skip-permissions --init "/install hil"

# Deterministic maintenance (hook only)
[group('claude')]
cldm:
    claude --model opus --dangerously-skip-permissions --maintenance

# Agentic maintenance (hook + /maintenance for reporting)
[group('claude')]
cldmm:
    claude --model opus --dangerously-skip-permissions --maintenance "/maintenance"

# Reset agentic artifacts
[group('claude')]
[confirm('This will delete .venv, cdk.out, and hook logs. Continue?')]
cld-reset:
    #!/usr/bin/env bash
    echo -e "{{ _yellow }}Resetting agentic artifacts...{{ _nc }}"
    rm -rf {{ VENV_DIR }} cdk.out
    rm -f .claude/hooks/*.log
    rm -f app_docs/*_results.md
    echo -e "{{ _green }}Reset complete{{ _nc }}"

# Show Claude Code hook logs
[group('claude')]
cld-logs:
    #!/usr/bin/env bash
    echo -e "{{ _green }}Claude Code Hook Logs:{{ _nc }}"
    for log in .claude/hooks/*.log; do
        if [ -f "$log" ]; then
            echo -e "\n{{ _yellow }}=== $(basename $log) ==={{ _nc }}"
            cat "$log"
        fi
    done
    if [ ! -f .claude/hooks/*.log ] 2>/dev/null; then
        echo "No log files found"
    fi
