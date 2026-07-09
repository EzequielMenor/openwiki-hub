#!/usr/bin/env bash
# Removes everything install.sh set up. Asks before deleting anything.
set -e

confirm() {
  local msg="$1"
  read -r -p "$msg [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

[[ -d "$HOME/openwiki-hub" ]] && {
  if confirm "Delete ~/openwiki-hub/ (web viewer + wikis symlinks)?"; then
    rm -rf "$HOME/openwiki-hub"
    echo "✓ removed ~/openwiki-hub/"
  fi
}

[[ -f "$HOME/.openwiki/.env" ]] && {
  if confirm "Delete ~/.openwiki/.env (your API key)?"; then
    rm -f "$HOME/.openwiki/.env"
    echo "✓ removed ~/.openwiki/.env"
  fi
}

[[ -f "$HOME/.git-templates/hooks/pre-commit" ]] && {
  if confirm "Remove global pre-commit hook?"; then
    rm -f "$HOME/.git-templates/hooks/pre-commit"
    echo "✓ removed pre-commit hook"
  fi
}

for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
  [[ -f "$rc" ]] || continue
  if grep -q "openwiki-hub" "$rc"; then
    if confirm "Strip openwiki aliases from $rc?"; then
      # remove the openwiki-hub block (from "# ── openwiki-hub" up to the next blank-line + EOF)
      python3 - "$rc" <<'PYEOF'
import sys, re
from pathlib import Path
p = Path(sys.argv[1])
text = p.read_text()
new = re.sub(
    r"\n# ── openwiki-hub ─+.*?(?=\n# |\Z)",
    "\n",
    text,
    flags=re.DOTALL,
)
if new != text:
    p.write_text(new)
    print(f"✓ stripped openwiki block from {p}")
PYEOF
    fi
  fi
done

echo ""
echo "Done. Restart your shell for alias changes to take effect."