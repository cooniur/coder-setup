#!/usr/bin/env bash
set -euo pipefail

# === Config (override by env) ===
CODER_DIR="${CODER_DIR:-/opt/coder}"
COMPOSE_FILE_1="${COMPOSE_FILE_1:-$CODER_DIR/docker-compose.yaml}"
COMPOSE_FILE_2="${COMPOSE_FILE_2:-$CODER_DIR/docker-compose.yml}"

# Containers (override by env)
CODER_CONTAINER="${CODER_CONTAINER:-coder}"
DB_CONTAINER="${DB_CONTAINER:-db}"

# Project name (optional; used if you ran `docker compose -p <name> ...`)
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-}"

# === Helpers ===
say() { printf "\n\033[1m%s\033[0m\n" "$*"; }
warn() { printf "\n\033[33m[warn]\033[0m %s\n" "$*"; }
die() { printf "\n\033[31m[error]\033[0m %s\n" "$*"; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

confirm() {
  local prompt="${1:-Are you sure?}"
  printf "\n%s [y/N]: " "$prompt"
  read -r ans || true
  [[ "${ans:-}" == "y" || "${ans:-}" == "Y" ]]
}

compose_cmd() {
  # Pick docker compose plugin if present; else docker-compose binary.
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo ""
  fi
}

find_compose_file() {
  if [[ -f "$COMPOSE_FILE_1" ]]; then echo "$COMPOSE_FILE_1"; return 0; fi
  if [[ -f "$COMPOSE_FILE_2" ]]; then echo "$COMPOSE_FILE_2"; return 0; fi
  echo ""
}

# === Start ===
need docker

say "Coder cleanup (wipe & reinstall)"
echo "  CODER_DIR:              $CODER_DIR"
echo "  CODER_CONTAINER:        $CODER_CONTAINER"
echo "  DB_CONTAINER:           $DB_CONTAINER"

# ======== DANGER CONFIRMATION GATE ========
say "⚠️  DESTRUCTIVE OPERATION WARNING"

cat <<'EOF'
You are about to PERMANENTLY DELETE:

  • Coder server container
  • Postgres database container
  • ALL workspace metadata
  • ALL user accounts
  • ALL organizations
  • ALL templates
  • ALL audit logs
  • ALL database volumes

This action is IRREVERSIBLE.

If you already created workspaces or users,
ALL DATA WILL BE LOST.

Type exactly:

    WIPE CODER

to continue.
EOF

printf "\nConfirmation: "
read -r CONFIRM_TEXT || true

if [[ "$CONFIRM_TEXT" != "WIPE CODER" ]]; then
  echo "❌ Cleanup aborted."
  exit 1
fi

echo "✅ Confirmation accepted. Proceeding with cleanup..."
echo
# ======== END CONFIRMATION GATE ========

COMPOSE_BIN="$(compose_cmd)"
COMPOSE_FILE="$(find_compose_file)"

if [[ -n "$COMPOSE_BIN" ]]; then
  echo "  Compose command:        $COMPOSE_BIN"
else
  warn "No docker compose command found. Will fall back to removing containers/volumes by name."
fi

if [[ -n "$COMPOSE_FILE" ]]; then
  echo "  Compose file detected:  $COMPOSE_FILE"
else
  warn "No compose file found at $COMPOSE_FILE_1 or $COMPOSE_FILE_2"
fi

if [[ -n "$COMPOSE_PROJECT_NAME" ]]; then
  echo "  Compose project name:   $COMPOSE_PROJECT_NAME"
fi

# 1) Stop via compose if possible
if [[ -n "$COMPOSE_BIN" && -n "$COMPOSE_FILE" ]]; then
  say "Stopping/removing stack via compose (includes volumes => wipes DB)"
  if [[ -n "$COMPOSE_PROJECT_NAME" ]]; then
    $COMPOSE_BIN -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" down -v --remove-orphans || true
  else
    $COMPOSE_BIN -f "$COMPOSE_FILE" down -v --remove-orphans || true
  fi
fi

# 2) Force remove containers by name (covers non-compose runs)
say "Removing containers by name (if they exist)"
for c in "$CODER_CONTAINER" "$DB_CONTAINER"; do
  if docker ps -a --format '{{.Names}}' | grep -qx "$c"; then
    echo "  - Removing container: $c"
    docker rm -f "$c" >/dev/null 2>&1 || true
  else
    echo "  - Container not found: $c"
  fi
done

# 3) Remove related anonymous/named volumes (best-effort)
say "Removing volumes (best-effort)"
# If compose was used, volumes are usually project-prefixed; we can search for common patterns.
# Also remove volumes that are attached to the old containers if any remain.
vols_to_remove=()

# Volumes named like coder_* or *coder* are common in simple setups.
while IFS= read -r v; do
  vols_to_remove+=("$v")
done < <(docker volume ls --format '{{.Name}}' | grep -E '(^coder_|coder|_db$|postgres|pgdata)' || true)

# Deduplicate
if [[ ${#vols_to_remove[@]} -gt 0 ]]; then
  # uniq without sort? We'll sort+uniq for safety
  mapfile -t vols_to_remove < <(printf "%s\n" "${vols_to_remove[@]}" | sort -u)

  echo "Candidate volumes to remove:"
  for v in "${vols_to_remove[@]}"; do echo "  - $v"; done

  for v in "${vols_to_remove[@]}"; do
    docker volume rm "$v" >/dev/null 2>&1 || true
  done
  echo "Volumes removal attempted."
else
  echo "No matching volumes found."
fi

# 4) Optional: remove images
say "Optional: remove images"
echo "This can be helpful to force a clean pull:"
echo "  - ghcr.io/coder/coder"
echo "  - postgres:15-alpine"
docker image rm -f ghcr.io/coder/coder:latest >/dev/null 2>&1 || true
docker image rm -f postgres:15-alpine >/dev/null 2>&1 || true
echo "Images removal attempted."

# 5) Optional: delete install dir
say "Optional: delete install directory"
sudo rm -rf "$CODER_DIR"
echo "Deleted $CODER_DIR"

say "Cleanup complete."
echo "Next: rerun your installer script with a URL-safe DB password (or URL-encode it)."
