# apps-script-publisher

> **Publisher de proyectos de Google Apps Script**: empaqueta el flujo completo — extracción con `clasp`, contenedores vía Drive API, sanitización con gitleaks — para que cualquier persona o agente de IA pueda replicarlo en su propia máquina.
>
> **Publisher for Google Apps Script projects**: it packages the whole flow — `clasp` extraction, containers via Drive API, gitleaks sanitization — so anyone (or any AI agent) can replicate it on their own machine.

[![test](https://github.com/Macorreag/apps-script-publisher/actions/workflows/test.yml/badge.svg)](https://github.com/Macorreag/apps-script-publisher/actions/workflows/test.yml)
[![gitleaks](https://github.com/Macorreag/apps-script-publisher/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/Macorreag/apps-script-publisher/actions/workflows/gitleaks.yml)

---

## Español

### Qué es

El **Agente organizador portable** del ecosistema de publicación de Apps Script (ADR-0002). Este repo **no guarda proyectos**: guarda el conocimiento y las herramientas para operar el flujo en cualquier máquina. Clonarlo = poder operar el flujo.

| Pieza | Para qué sirve |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Guía portable: issue tracker por REST, labels de triage, reglas de rama/PR/CI/merge, candado de secretos y PII |
| [`skills/monorepo-apps-script/SKILL.md`](skills/monorepo-apps-script/SKILL.md) | Skill del agente: cuándo usarla, el flujo en 6 fases y las lecciones aprendidas (OAuth, cuotas, Forms) |
| [`scripts/wizard-setup-machine.sh`](scripts/wizard-setup-machine.sh) | Wizard idempotente de onboarding para una máquina nueva |

### Estructura

```
AGENTS.md                                # guía portable del flujo y sus reglas
skills/monorepo-apps-script/SKILL.md     # skill del agente (flujo + lecciones)
scripts/wizard-setup-machine.sh          # wizard de setup de máquina nueva
.githooks/pre-commit                     # candado gitleaks local (fail-open)
.github/workflows/test.yml               # CI: sintaxis, JSON, wizard --check, clasp local
.github/workflows/gitleaks.yml           # CI: escaneo de secretos (fail-closed)
```

### Quickstart

```bash
git clone https://github.com/Macorreag/apps-script-publisher.git
cd apps-script-publisher
bash scripts/wizard-setup-machine.sh
```

El wizard deja lista la máquina: Node ≥ 20 (sugiere nvm), clasp **local** (sin `npm install -g`), `gh` autenticado, gitleaks y el hook pre-commit; sugiere rclone para la fase de Contenedores. Después solo falta el login de Google: `clasp login` (o `--no-localhost` en headless).

### Cómo correr el flujo

Sigue [`skills/monorepo-apps-script/SKILL.md`](skills/monorepo-apps-script/SKILL.md):

1. **Inventario** — `clasp list-scripts` (crudo en `.scratch/inventario/`).
2. **Tickets** — issues padre + hijo por proyecto, labels de triage.
3. **Extracción** — scaffold desde la plantilla canónica + `clasp clone-script`.
4. **Contenedores** — export Drive API (docx/xlsx/pptx/pdf; Forms: sin export binario).
5. **Sanitización** — gitleaks + redacción de PII de terceros.
6. **PR y merge** — rama por ticket, CI verde, squash.

## English

### What is this

The **portable organizing agent** of the Apps Script publishing ecosystem (ADR-0002). This repo **stores no projects**: it stores the knowledge and tooling to run the flow on any machine. Clone it = run the flow.

| Piece | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Portable guide: REST issue tracker, triage labels, branch/PR/CI/merge rules, secret & PII lock |
| [`skills/monorepo-apps-script/SKILL.md`](skills/monorepo-apps-script/SKILL.md) | Agent skill: when to use it, the 6-phase flow, hard-won lessons (OAuth, quotas, Forms) |
| [`scripts/wizard-setup-machine.sh`](scripts/wizard-setup-machine.sh) | Idempotent onboarding wizard for a fresh machine |

### Quickstart

```bash
git clone https://github.com/Macorreag/apps-script-publisher.git
cd apps-script-publisher
bash scripts/wizard-setup-machine.sh          # interactive
bash scripts/wizard-setup-machine.sh --check  # report only, changes nothing
```

The wizard gets the machine ready: Node ≥ 20 (nvm suggested), **local** clasp (no `npm install -g`), authenticated `gh`, gitleaks, and the pre-commit hook; it also suggests rclone for the Containers phase. Then only the Google login remains: `clasp login` (or `--no-localhost` when headless).

### Running the flow

Follow [`skills/monorepo-apps-script/SKILL.md`](skills/monorepo-apps-script/SKILL.md): inventory → tickets → clasp extraction → containers (Drive API) → sanitization (gitleaks + third-party PII redaction) → PR & merge.

## Ecosystem / Ecosistema

- [`Macorreag/google-apps-script-starter-template`](https://github.com/Macorreag/google-apps-script-starter-template) — plantilla canónica de cada proyecto / canonical per-project template.
- [`Macorreag/AppsScriptProyects`](https://github.com/Macorreag/AppsScriptProyects) — monorepo con los proyectos publicados / published projects monorepo.

## License

MIT
