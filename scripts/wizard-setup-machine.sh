#!/usr/bin/env bash
#
# Wizard de onboarding para una MÁQUINA NUEVA (ticket 10 / issue #11 de
# AppsScriptProyects): deja esta máquina lista para operar el flujo del
# publisher — Node ≥ 20 (sugerencia nvm), clasp LOCAL (sin `npm install -g`,
# evita ROFS/permisos globales), gh autenticado, gitleaks, y el candado
# pre-commit (`git config core.hooksPath .githooks`).
#
# Idempotente: re-ejecutar no rompe nada; lo ya hecho se detecta y se respeta.
#
# Uso:
#   bash scripts/wizard-setup-machine.sh          # wizard interactivo
#   bash scripts/wizard-setup-machine.sh --check  # informe sin cambiar nada
#
# Todo lo anterior al marcador STAGES es la librería del wizard (estilo
# scripts/wizard-inventario.sh del monorepo): no se edita a mano.

set -euo pipefail

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
  BLUE=$(tput setaf 4); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1)
else
  BOLD=""; DIM=""; RESET=""; BLUE=""; GREEN=""; YELLOW=""; RED=""
fi

TOTAL_STAGES=0
_STAGE_INDEX=0
PENDIENTE=() # cosas que quedaron para después (no impiden re-ejecutar)

_clear() {
  [[ -t 1 ]] || return 0
  if command -v tput >/dev/null 2>&1; then tput clear; else printf '\033[2J\033[3J\033[H'; fi
}

banner() {
  _clear
  printf '\n%s%s  %s%s\n' "$BOLD" "$BLUE" "$1" "$RESET"
  printf '%s  %s stages%s\n\n' "$DIM" "$TOTAL_STAGES" "$RESET"
  printf '%s  Este wizard prepara la máquina para operar el flujo del publisher.\n' "$DIM"
  printf '%s  Es idempotente: Ctrl-C cuando quieras y re-ejecuta luego.%s\n\n' "$DIM" "$RESET"
  pause "¿Listo para empezar?"
}

stage() {
  _clear
  _STAGE_INDEX=$((_STAGE_INDEX + 1))
  printf '\n%s%s▸ Stage %s/%s · %s%s\n' \
    "$BOLD" "$BLUE" "$_STAGE_INDEX" "$TOTAL_STAGES" "$1" "$RESET"
}

say()  { printf '  %s\n' "$1"; }
ok()   { printf '  %s✓ %s%s\n' "$GREEN" "$1" "$RESET"; }
step() { printf '  %s•%s %s\n' "$BLUE" "$RESET" "$1"; }
note() { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
warn() { printf '  %s⚠ %s%s\n' "$YELLOW" "$1" "$RESET"; }
fail() { printf '  %s✗ %s%s\n' "$RED" "$1" "$RESET"; }

pause() {
  printf '  %s%s%s ' "$DIM" "${1:-Presiona Enter para continuar}" "$RESET"
  read -r _ || true
}

confirm() {
  local reply=""
  printf '  %s? %s [y/N] ' "$YELLOW" "$1"
  read -r reply || true
  [[ "$reply" =~ ^[Yy] ]]
}

# pendiente "mensaje": registra algo que el humano deberá resolver después.
pendiente() {
  PENDIENTE+=("$1")
  warn "queda pendiente: $1"
}

# node_major: versión mayor de Node, o 0 si Node no está disponible.
node_major() {
  command -v node >/dev/null 2>&1 || { printf '0'; return; }
  node -p 'process.versions.node.split(".")[0]' 2>/dev/null || printf '0'
}

# find_clasp: llena CLASP_CMD con el comando clasp usable. Preferencia:
# global → local del repo (node_modules, instalado con --no-bin-links, por lo
# que se invoca vía node sobre el bin declarado en su package.json).
CLASP_CMD=()
find_clasp() {
  CLASP_CMD=()
  if command -v clasp >/dev/null 2>&1; then
    CLASP_CMD=(clasp)
    return 0
  fi
  local pkg="$ROOT/node_modules/@google/clasp/package.json"
  [[ -f "$pkg" ]] || return 1
  local rel
  rel="$(node -e "const p=require('./node_modules/@google/clasp/package.json');console.log(typeof p.bin==='string'?p.bin:(p.bin&&p.bin.clasp)||'')" 2>/dev/null || true)"
  [[ -n "$rel" && -f "$ROOT/node_modules/@google/clasp/$rel" ]] || return 1
  CLASP_CMD=(node "$ROOT/node_modules/@google/clasp/$rel")
  return 0
}

clasp_version() {
  "${CLASP_CMD[@]}" --version 2>/dev/null || printf '?'
}

# githooks_instalados: true si core.hooksPath ya apunta a .githooks.
githooks_instalados() {
  [[ "$(git -C "$ROOT" config core.hooksPath 2>/dev/null || true)" == ".githooks" ]]
}

# ensure_gitignore ENTRADA [ALIAS]: agrega ENTRADA al .gitignore si no está
# (ninguna de las dos formas), idempotente.
ensure_gitignore() {
  local entry="$1" alias="${2:-}"
  grep -qxF "$entry" "$ROOT/.gitignore" 2>/dev/null && return 0
  [[ -n "$alias" ]] && grep -qxF "$alias" "$ROOT/.gitignore" 2>/dev/null && return 0
  printf '%s\n' "$entry" >> "$ROOT/.gitignore"
  ok ".gitignore += $entry"
}

# informe: modo --check, no instala, no pregunta y no escribe nada.
informe() {
  local rc=0 nm
  say "Informe de máquina (no se cambia nada) · repo: $ROOT"
  printf '\n'
  nm="$(node_major)"
  if (( nm >= 20 )); then
    ok "Node $(node --version) (≥ 20)"
  elif (( nm > 0 )); then
    fail "Node $(node --version) es < 20 (clasp v3 lo exige); usa nvm: nvm install 20"
    rc=1
  else
    fail "Node.js no encontrado (se requiere ≥ 20; sugerencia: nvm install 20)"
    rc=1
  fi
  if command -v git >/dev/null 2>&1; then
    ok "git $(git --version | cut -d' ' -f3)"
  else
    fail "git no encontrado"
    rc=1
  fi
  if find_clasp; then
    ok "clasp $(clasp_version) (${CLASP_CMD[*]})"
  else
    warn "clasp no instalado (el wizard interactivo lo instala local)"
  fi
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      ok "gh autenticado"
    else
      warn "gh instalado pero sin autenticar (gh auth login)"
    fi
  else
    warn "gh no instalado (https://cli.github.com)"
  fi
  if command -v gitleaks >/dev/null 2>&1; then
    ok "gitleaks $(gitleaks version 2>/dev/null || echo '?')"
  else
    warn "gitleaks no instalado (el pre-commit es fail-open; la CI escanea igual)"
  fi
  if githooks_instalados; then
    ok "core.hooksPath = .githooks"
  else
    warn "core.hooksPath sin configurar (el wizard interactivo lo activa)"
  fi
  printf '\n'
  if (( rc == 0 )); then
    ok "Base OK (Node ≥ 20 y git). Faltantes marcados con ⚠ se arreglan con el wizard interactivo."
  fi
  return "$rc"
}

# ──────────────────────────────────────────────────────────────────────────
# STAGES: author this section. One stage() per step.
# ──────────────────────────────────────────────────────────────────────────

# Siempre al directorio raíz del repo, desde cualquier cwd.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" == "--check" ]]; then
  informe
  exit $?
fi

TOTAL_STAGES=5

banner "Setup de máquina nueva — apps-script-publisher"

# ── Stage 1: Node ≥ 20 y git ──────────────────────────────────────────────
stage "Node.js ≥ 20 y git"
if ! command -v git >/dev/null 2>&1; then
  fail "git no está instalado: https://git-scm.com/downloads y re-ejecuta."
  exit 1
fi
ok "git $(git --version | cut -d' ' -f3)"

NODE_M="$(node_major)"
if (( NODE_M < 20 )) && [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  warn "Node insuficiente (ahora: $(command -v node >/dev/null 2>&1 && node --version || echo 'ninguno'))."
  if confirm "¿Instalar Node 20 con nvm ahora?"; then
    # shellcheck disable=SC1090
    . "$HOME/.nvm/nvm.sh"
    nvm install 20
    nvm use 20
    NODE_M="$(node_major)"
  fi
fi
if (( NODE_M < 20 )); then
  fail "Node.js ≥ 20 es obligatorio (clasp v3 lo exige)."
  step "Instala nvm: https://github.com/nvm-sh/nvm#installing--updating  → luego: nvm install 20"
  step "O instala Node LTS directo: https://nodejs.org"
  exit 1
fi
ok "Node $(node --version)"

# ── Stage 2: clasp LOCAL (npm cache dentro del repo, sin npm -g) ──────────
stage "clasp (instalación local, sin npm -g)"
if find_clasp; then
  ok "clasp ya disponible: $(clasp_version)  [${CLASP_CMD[*]}]"
else
  if ! command -v npm >/dev/null 2>&1; then
    pendiente "npm no disponible: instala Node ≥ 20 (nvm install 20) y re-ejecuta el wizard"
  else
    say "Instalando clasp LOCAL en el repo — cache de npm en .npm-cache/ (no toca"
    say "tu npm global ni permisos de sistema; evita ROFS/EPERM en entornos limitados)…"
    export npm_config_cache="$ROOT/.npm-cache"
    npm install @google/clasp --no-bin-links --no-audit --no-fund
    if find_clasp; then
      ok "clasp local instalado: $(clasp_version)"
      note "Se invoca con: ${CLASP_CMD[*]}"
    else
      pendiente "clasp no quedó usable tras npm install; revisa el output de npm"
    fi
  fi
fi
if (( ${#CLASP_CMD[@]} > 0 )); then
  note "Para autenticar (paso solo-humano):  ${CLASP_CMD[*]} login"
  note "Headless (sin navegador local):      ${CLASP_CMD[*]} login --no-localhost"
  warn "Si Google muestra 'This app is blocked': lección 1 de la skill — client OAuth propio."
fi

# ── Stage 3: GitHub CLI autenticado ───────────────────────────────────────
stage "GitHub CLI (gh)"
if ! command -v gh >/dev/null 2>&1; then
  pendiente "gh no instalado: https://cli.github.com (macOS: brew install gh · Debian/Ubuntu: sudo apt install gh)"
else
  ok "gh $(gh --version | head -n1 | cut -d' ' -f3)"
  if gh auth status >/dev/null 2>&1; then
    ok "gh autenticado"
  else
    warn "gh no está autenticado."
    step "En otra terminal corre:  gh auth login --hostname github.com --git-protocol https --web"
    note "(o simplemente: gh auth login y sigue el asistente; abre el device code en cualquier navegador)"
    pause "¿Login de gh completado?"
    if gh auth status >/dev/null 2>&1; then
      ok "gh autenticado"
    else
      pendiente "autenticar gh: gh auth login"
    fi
  fi
fi

# ── Stage 4: gitleaks (sugerencia según gestor disponible) ────────────────
stage "gitleaks (candado de secretos)"
if command -v gitleaks >/dev/null 2>&1; then
  ok "gitleaks $(gitleaks version 2>/dev/null || echo '?')"
else
  warn "gitleaks no está instalado (hook local fail-open; la CI es fail-closed)."
  if command -v brew >/dev/null 2>&1; then
    step "brew detectado — sugerido:  brew install gitleaks"
  elif command -v apt-get >/dev/null 2>&1; then
    step "apt detectado — sugerido:   sudo apt-get install gitleaks"
    note "(distros sin el paquete: usa el binario de las releases)"
  elif command -v dnf >/dev/null 2>&1; then
    step "dnf detectado — sugerido:   sudo dnf install gitleaks"
  elif command -v scoop >/dev/null 2>&1; then
    step "scoop detectado — sugerido: scoop install gitleaks"
  else
    note "Sin gestor conocido: descarga el binario de https://github.com/gitleaks/gitleaks/releases"
  fi
  note "Más opciones: https://github.com/gitleaks/gitleaks#installing"
  pendiente "instalar gitleaks para el candado local (la CI ya escanea el historial)"
fi

# ── Stage 5: higiene git — hooks + .gitignore ─────────────────────────────
stage "Higiene git: hooks pre-commit + .gitignore"
if [[ -f "$ROOT/.githooks/pre-commit" ]]; then
  ok ".githooks/pre-commit presente"
else
  pendiente ".githooks/pre-commit falta en este clone; restáuralo del repo antes de commitear"
fi
if githooks_instalados; then
  ok "core.hooksPath = .githooks (ya configurado)"
else
  git -C "$ROOT" config core.hooksPath .githooks
  ok "core.hooksPath = .githooks (candado de secretos activado)"
fi
touch "$ROOT/.gitignore"
ensure_gitignore ".clasprc.json" ""
ensure_gitignore ".env" ""
ensure_gitignore ".npm-cache/" ""
ensure_gitignore "node_modules/" "/node_modules"
ensure_gitignore ".scratch/" ""
note "Recuerda: .clasprc.json contiene TU token OAuth y NUNCA va a git; los"
note "contenedores con datos de terceros se sanitizan antes de publicar (AGENTS.md)."

# ──────────────────────────────────────────────────────────────────────────

_clear
printf '\n%s%s  ✓ Setup de máquina completado%s\n' "$BOLD" "$GREEN" "$RESET"
if (( ${#PENDIENTE[@]} )); then
  printf '\n'
  warn "pendientes para después (re-ejecuta el wizard cuando los resuelvas):"
  i=""
  for i in "${!PENDIENTE[@]}"; do note "  - ${PENDIENTE[$i]}"; done
fi
printf '\n'
note "Siguiente paso: el flujo completo vive en skills/monorepo-apps-script/SKILL.md"
printf '\n'
