#!/usr/bin/env bash
# Escanea directorios comunes y crea symlinks ~/openwiki-hub/wikis/<name> → <openwiki>
# Escribe ~/openwiki-hub/wikis.json con el manifest para que la UI lo lea.
set -e

HUB="$HOME/openwiki-hub"
WIKIS_DIR="$HUB/wikis"
MANIFEST="$HUB/wikis.json"

ROOTS=(
  "$HOME/Proyectos" "$HOME/projects" "$HOME/code" "$HOME/dev"
  "$HOME/work" "$HOME/repos" "$HOME/src" "$HOME/Documents"
  "$HOME/Documents/GitHub" "$HOME/ai-brain"
)

# 1) Limpiar symlinks viejos
rm -f "$WIKIS_DIR"/*

# 2) Buscar openwiki/ a max 3 niveles
FOUND=0
for root in "${ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' owp; do
    name=$(basename "$(dirname "$owp")")
    # dedupe slug
    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g')
    [[ -z "$slug" ]] && slug="wiki"
    suffix=""
    while [[ -e "$WIKIS_DIR/${slug}${suffix}" ]]; do suffix="-${RANDOM:0:4}"; done
    ln -s "$owp" "$WIKIS_DIR/${slug}${suffix}"
    FOUND=$((FOUND+1))
  done < <(find "$root" -maxdepth 4 -type d -name openwiki -not -path '*/node_modules/*' -not -path '*/.git/*' -print0 2>/dev/null)
done

# 3) Generar manifest.json
python3 - "$WIKIS_DIR" "$MANIFEST" <<'PYEOF'
import json, os, sys
from pathlib import Path
from datetime import datetime

wikis_dir = Path(sys.argv[1])
manifest = Path(sys.argv[2])
wikis = []
for entry in sorted(wikis_dir.iterdir()):
    if not entry.name.startswith('.'):
        target = entry.resolve()
        if not target.is_dir():
            continue
        files = []
        for f in sorted(target.iterdir()):
            if f.suffix == ".md" and f.is_file():
                # HTTP path: wikis/<symlink-name>/<file>
                rel_path = f"wikis/{entry.name}/{f.name}"
                files.append({
                    "name": f.name,
                    "label": f.stem,
                    "path": rel_path,
                    "updatedAt": datetime.fromtimestamp(f.stat().st_mtime).strftime("%Y-%m-%d"),
                })
        # also try .last-update.json
        wiki_updated = "nunca"
        meta = target / ".last-update.json"
        if meta.exists():
            try:
                with meta.open() as fp:
                    wiki_updated = json.load(fp).get("updatedAt", wiki_updated)[:10]
            except Exception:
                pass
        wikis.append({
            "name": entry.name,
            "label": entry.name.replace("-", " ").replace("_", " ").title(),
            "files": files,
            "updatedAt": wiki_updated,
        })

manifest.write_text(json.dumps({
    "wikis": wikis,
    "builtAt": datetime.utcnow().isoformat() + "Z",
}, indent=2))
print(f"📚 {len(wikis)} wikis · manifest → {manifest}")
PYEOF
