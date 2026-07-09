#!/usr/bin/env bash
# openwiki-hub installer
# ─────────────────────
# Sets up:
#   • ~/openwiki-hub/        — the web viewer (copied from this repo's app/)
#   • ~/.openwiki/.env       — openwiki config (Anthropic-compatible, MiniMax)
#   • ~/.git-templates/hooks/pre-commit  — global hook that refreshes wikis
#   • aliases in ~/.zshrc (or ~/.bashrc) — ow / owi / owu / owhu / owhu-stop
#
# Re-runnable: detects existing setup and only patches what's missing.
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SRC="$REPO_DIR/app"
INSTALL_DIR="$HOME/openwiki-hub"
ENV_FILE="$HOME/.openwiki/.env"
ENV_TEMPLATE="$REPO_DIR/templates/openwiki.env"
HOOK_SRC="$REPO_DIR/templates/pre-commit"
HOOK_DIR="$HOME/.git-templates/hooks"
HOOK_FILE="$HOOK_DIR/pre-commit"

# ── helpers ─────────────────────────────────────────────────────────────
say() { printf "\033[1;36m▸\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m⚠\033[0m  %s\n" "$*"; }
die() { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# ── preflight ───────────────────────────────────────────────────────────
command -v openwiki  >/dev/null || die "openwiki not installed. Run: npm install -g openwiki"
command -v python3   >/dev/null || die "python3 not installed"
command -v git       >/dev/null || die "git not installed"

# ── 1. copy app/ → ~/openwiki-hub/ ──────────────────────────────────────
say "Installing web viewer → $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -R "$APP_SRC/." "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/link.sh"
ok "Web viewer installed"

# ── 2. ~/.openwiki/.env ─────────────────────────────────────────────────
mkdir -p "$HOME/.openwiki"
chmod 700 "$HOME/.openwiki"
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ENV_TEMPLATE" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  ok "Created $ENV_FILE (template — edit to add your MiniMax token)"
else
  ok "$ENV_FILE already exists (left untouched)"
fi

# ── 3. global git hook ──────────────────────────────────────────────────
say "Installing global pre-commit hook → $HOOK_FILE"
mkdir -p "$HOOK_DIR"
cp "$HOOK_SRC" "$HOOK_FILE"
chmod +x "$HOOK_FILE"
git config --global init.templateDir "$HOME/.git-templates"
ok "Hook installed"

# ── 4. shell aliases ────────────────────────────────────────────────────
SHELL_RC="$HOME/.zshrc"
[[ ! -f "$SHELL_RC" ]] && SHELL_RC="$HOME/.bashrc"
[[ ! -f "$SHELL_RC" ]] && SHELL_RC="$HOME/.bash_profile"

if ! grep -q "openwiki-hub" "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" <<'ALIASES'

# ── openwiki-hub ────────────────────────────────────────────────────────
alias ow='openwiki'
alias owi='openwiki --init -p "Documenta el repo desde cero" --modelId MiniMax-M3'
alias owu='openwiki --update -p "Actualiza la wiki con los cambios recientes" --modelId MiniMax-M3'
alias owhu='_owhu_run'
alias owhu-stop='_owhu_stop'

_OWHUB_PID="/tmp/openwiki-hub.pid"

_owhu_run() {
  if [[ -f "$_OWHUB_PID" ]] && kill -0 "$(cat "$_OWHUB_PID")" 2>/dev/null; then
    kill "$(cat "$_OWHUB_PID")" 2>/dev/null
    rm -f "$_OWHUB_PID"
  fi
  ~/openwiki-hub/link.sh
  cd ~/openwiki-hub && python3 -m http.server 8765 --bind 127.0.0.1 >/tmp/openwiki-hub.log 2>&1 &
  local pid=$!
  echo "$pid" > "$_OWHUB_PID"
  sleep 0.5
  if kill -0 "$pid" 2>/dev/null; then
    echo "📚 OpenWiki Hub → http://localhost:8765"
    command -v open >/dev/null && open "http://localhost:8765" >/dev/null 2>&1
  else
    echo "❌ no arrancó. log:"
    tail -20 /tmp/openwiki-hub.log
  fi
}

_owhu_stop() {
  if [[ -f "$_OWHUB_PID" ]] && kill -0 "$(cat "$_OWHUB_PID")" 2>/dev/null; then
    kill "$(cat "$_OWHUB_PID")" 2>/dev/null
    rm -f "$_OWHUB_PID"
    echo "📚 Hub parado"
  else
    echo "no hay hub corriendo"
  fi
}
ALIASES
  ok "Aliases appended to $SHELL_RC"
else
  ok "Aliases already present in $SHELL_RC"
fi

# ── 5. done ─────────────────────────────────────────────────────────────
echo ""
ok "Install complete"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.openwiki/.env and set your MiniMax API key (sk-cp-...)"
echo "  2. Open a new shell (or: source $SHELL_RC)"
echo "  3. In any project: git init && owi  (generates the wiki)"
echo "  4. From anywhere:  owhu             (opens http://localhost:8765)"