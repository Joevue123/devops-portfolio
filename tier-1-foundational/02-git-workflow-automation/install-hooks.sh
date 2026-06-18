#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-$(pwd)}"
HOOKS_DIR="${REPO_PATH}/.git/hooks"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/hooks" && pwd)"

if [[ ! -d "${REPO_PATH}/.git" ]]; then
    echo "Error: ${REPO_PATH} is not a git repository."
    exit 1
fi

echo "Installing git hooks into ${REPO_PATH}..."

for hook in "${SOURCE_DIR}"/*; do
    hook_name=$(basename "${hook}")
    dest="${HOOKS_DIR}/${hook_name}"

    if [[ -f "${dest}" ]]; then
        echo "  Backing up existing ${hook_name} to ${hook_name}.bak"
        cp "${dest}" "${dest}.bak"
    fi

    cp "${hook}" "${dest}"
    chmod +x "${dest}"
    echo "  Installed: ${hook_name}"
done

# Install pre-commit framework if available
if command -v pre-commit &>/dev/null; then
    echo ""
    echo "Detected pre-commit framework — installing hooks..."
    (cd "${REPO_PATH}" && pre-commit install --install-hooks)
    echo "  pre-commit hooks installed"
else
    echo ""
    echo "Tip: Install the pre-commit framework for richer hooks:"
    echo "  pip install pre-commit && pre-commit install"
fi

echo ""
echo "Done. Hooks installed in ${HOOKS_DIR}"
