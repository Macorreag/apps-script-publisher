# AGENTS.md — apps-script-publisher

Guía portable para agentes de IA (y humanos técnicos) que operan el flujo de
extracción, sanitización y publicación de proyectos de Google Apps Script
**desde cualquier máquina**. Regla de diseño del repo (ADR-0002 del monorepo):
**clonar este repo = poder operar el flujo.**

## Qué es este repo (y qué no es)

Este repo NO guarda proyectos. Es el **Agente organizador portable**: skill,
convenciones y wizard de onboarding. El ecosistema tiene tres repos con roles
distintos:

| Repo | Rol |
|---|---|
| `google-apps-script-starter-template` | Plantilla canónica de cada Proyecto (botón "Use this template") |
| `AppsScriptProyects` | Monorepo con los Proyectos publicados (colección) |
| `apps-script-publisher` (este) | Skill + AGENTS.md + wizard de setup de máquina |

## Requisitos de máquina

Ejecuta una vez, desde la raíz del clone:

```bash
bash scripts/wizard-setup-machine.sh          # interactivo
bash scripts/wizard-setup-machine.sh --check  # solo informe, no toca nada
```

Deja instalado/verificado: Node ≥ 20 (sugerencia nvm), clasp **local** (sin
`npm install -g`: evita ROFS/permisos globales), GitHub CLI autenticado,
gitleaks, y `git config core.hooksPath .githooks` (candado pre-commit de
secretos).

## El flujo en 6 fases

La versión detallada, con comandos listos para copiar, vive en
[`skills/monorepo-apps-script/SKILL.md`](skills/monorepo-apps-script/SKILL.md).

1. **Inventario** — listar TODOS los proyectos de la cuenta: `clasp
   list-scripts` (o Drive API `files.list` con
   `mimeType='application/vnd.google-apps.script'`); el crudo se guarda en
   `.scratch/inventario/` (jamás commiteado).
2. **Tickets** — un issue padre (mapa) + un issue hijo por Proyecto, con los
   labels de triage de abajo. El agente reclama el ticket con assignee.
3. **Extracción (clasp)** — scaffold del Proyecto desde la plantilla canónica
   y `clasp clone-script <scriptId> --rootDir <proyecto>/src`; se versionan
   código + `appsscript.json` + `.clasp.json` (este último no contiene
   credenciales).
4. **Contenedores** — export de los documentos vinculados (Sheet/Docs/Slides →
   docx/xlsx/pptx/pdf vía Drive API). Forms **no tiene export binario**: JSON
   de estructura (Forms API) o copia server-side con rclone ≥ 1.65.
5. **Sanitización** — gitleaks + redacción de PII de terceros (abajo) antes de
   que nada salga de la máquina.
6. **PR y merge** — rama por ticket, CI verde, squash merge.

## Issue tracker (GitHub Issues vía REST)

Los issues y specs viven en GitHub Issues del repo en que se opera (inferir
`OWNER/REPO` desde `git remote -v`). **Usa la API REST con `gh api`, no `gh
issue view`** (en varios entornos el CLI rompe con GraphQL 499):

```bash
# Leer un issue (cuerpo, labels, estado)
gh api repos/OWNER/REPO/issues/11 --jq '{title, state, body, labels: [.labels[].name]}'

# Listar issues abiertos con labels
gh api "repos/OWNER/REPO/issues?state=open&per_page=100" \
  --jq '[.[] | {number, title, labels: [.labels[].name]}]'

# Comentar (body como formulario; soporta multilinea con heredoc)
gh api repos/OWNER/REPO/issues/11/comments -X POST -f body="texto del comentario"

# Etiquetar / desetiquetar
gh api repos/OWNER/REPO/issues/11/labels -X POST -f labels[]=needs-triage
gh api -X DELETE repos/OWNER/REPO/issues/11/labels/needs-triage

# Cerrar / reabrir
gh api -X PATCH repos/OWNER/REPO/issues/11 -f state=closed
```

`#N` puede ser issue o PR (comparten numeración): resolver con
`gh api repos/OWNER/REPO/issues/N` y comprobar `pull_request` en la respuesta.

## Labels de triage

Vocabulario canónico de las cinco funciones de triage:

| Label | Significado |
|---|---|
| `needs-triage` | Sin evaluar; mantenedor debe decidir qué es |
| `needs-info` | Esperando datos del reportador |
| `ready-for-agent` | Completamente especificado; un agente puede operarlo AFK |
| `ready-for-human` | Requiere intervención humana (login, pagos, decisiones) |
| `wontfix` | No se accionará |

Al reclamar un ticket: asignarse como primera escritura de la sesión
(`gh api -X POST repos/OWNER/REPO/issues/N/assignees -f assignees[]=@me`).

## Git: ramas, PR, CI y merge

- **Rama por ticket**: `feat|fix|docs/<NN>-<slug>` (NN = número de issue).
- **Commits** estilo conventional (`feat:`, `fix:`, `docs:`, `chore:`) con
  referencia al issue: `(issue #N)` o `(ticket NN, #N)`.
- **CI**: los workflows `test` y `gitleaks` deben estar **verdes** antes de
  merge. Rojo de gitleaks bloquea siempre.
- **Merge** squash a `main` y borrar la rama. Repos con protección de rama:
  nunca push directo a `main`. Repos sin protección (p. ej. este publisher):
  push directo permitido solo para scaffolding/docs del propio publisher;
  **jamás** para contenido extraído sin sanitizar.
- Identidad de commit en máquina compartida: `git config user.name
  "Macorreag" && git config user.email
  "32028541+Macorreag@users.noreply.github.com"` (nunca un email real).

## Candado de secretos y PII (no negociable)

**NUNCA se commitea:**

- `.clasprc.json` (global en `~` o local junto al proyecto): contiene el token
  OAuth del dueño. El wizard lo agrega a `.gitignore` y el pre-commit lo
  escanea.
- `.env`, `.npm-cache/`, `node_modules/`, `.scratch/` (inventario crudo,
  extracciones en curso, contenedores sin sanitizar).
- Credenciales de client OAuth (`client_secret*.json`), refresh tokens, keys
  de service account.
- Binarios exportados con datos reales cuando contengan datos de terceros.

**PII de terceros**: nombres, correos, teléfonos, IDs de clientes o dominios
que aparezcan en código o documentos exportados se redactan antes de publicar
— placeholders (`NOMBRE_CLIENTE`, `CORREO_ADMIN`) o datos de prueba
(`cliente-ejemplo@ejemplo.test`). Revisar también credenciales de terceros
empotradas en el código original (API keys ajenas), nombres de hojas y valores
de celdas en contenedores.

**Defensa en profundidad:**

1. `.gitignore` (el wizard lo asegura).
2. `.githooks/pre-commit`: `gitleaks protect --staged` — **fail-open** si
   gitleaks no está instalado (avisa y deja pasar).
3. CI `gitleaks` (escanea el historial completo) — **fail-closed**: rojo
   bloquea.

Si un secreto llegó al historial: **rotarlo/revocar primero**, luego limpiar
historial (`git filter-repo`) — borrar el archivo en un commit nuevo no basta.

## Cuando algo "falla", verifica el estado real antes de rehacer

Estado de CI por commit (`gh api repos/OWNER/REPO/commits/SHA/check-runs`),
estado de issues (REST arriba), `git status` / `git log --oneline` antes de
repetir pasos. Rehacer a ciegas duplica trabajo y contamina el historial.

## Referencias

- Skill del flujo: `skills/monorepo-apps-script/SKILL.md`
- Docs del monorepo `AppsScriptProyects`: `docs/agents/issue-tracker.md`,
  `docs/agents/triage-labels.md`,
  `docs/adr/0002-plantilla-externa-y-agente-aparte.md`
- Lecciones OAuth/Drive: sección "Lecciones aprendidas" de la skill.
