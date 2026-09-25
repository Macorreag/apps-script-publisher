---
name: monorepo-apps-script
description: Organizar, extraer y publicar proyectos de Google Apps Script en un monorepo versionado — inventario de la cuenta, tickets en GitHub, extracción con clasp, contenedores vía Drive API, sanitización con gitleaks y PR. Úsala cuando el usuario pida respaldar/extraer/publicar sus proyectos de Apps Script, inventariar su cuenta Google, migrar scripts a git, o recuperar el código de Sheets/Forms/Docs vinculados. / Use it when the user asks to back up, extract, publish, or inventory their Google Apps Script projects.
---

# Skill: monorepo-apps-script

Flujo completo para convertir los proyectos de Google Apps Script de una
cuenta en un monorepo versionado y publicable, **sin exponer secretos ni PII
de terceros**. Empaquetada para agentes; también operable por un humano
paciente.

## Cuándo usar esta skill

- "Extrae/respalda/publica mis proyectos de Apps Script".
- "Inventaria qué scripts tengo en mi cuenta de Google".
- "Pasa estos scripts de Sheets/Forms a un repo git".
- Recuperar el código fuente de proyectos container-bound (el binario del
  contenedor va aparte: fase de Contenedores).

**Cuándo NO:** editar/probar un único proyecto Apps Script en su repo propio
(usa clasp normal), o cosas que no involucren Apps Script.

## Prerrequisitos (máquina)

```bash
bash scripts/wizard-setup-machine.sh
```

Deja listo: Node ≥ 20, clasp local (sin `-g`), `gh` autenticado, gitleaks y
hooks pre-commit. Después falta SOLO el login de Google:
`clasp login` (con navegador) o `clasp login --no-localhost` (headless).
Si Google bloquea el login con "This app is blocked", es la lección 1 de
abajo: hace falta client OAuth propio.

## El flujo (6 fases)

### Fase 1 — Inventario

Objetivo: la lista definitiva de Proyectos de la cuenta (scriptId, nombre,
tipo de contenedor). Produce un crudo en `.scratch/inventario/` (nunca a git).

```bash
# Opción A: clasp (requiere login)
clasp list-scripts | tee .scratch/inventario/clasp-list-scripts.txt

# Opción B: Drive API (token OAuth con scope drive en $TOKEN)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://www.googleapis.com/drive/v3/files?q=mimeType%3D%27application%2Fvnd.google-apps.script%27%20and%20trashed%3Dfalse&fields=nextPageToken,files(id,name)&pageSize=200"
# paginar con nextPageToken; clasificar cada script: standalone o container-bound
```

### Fase 2 — Tickets

Issues en GitHub (REST con `gh api`, ver AGENTS.md): un issue padre (mapa)
con el inventario resumido + un hijo por Proyecto con el plan de extracción.
Labels de triage: `needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`. El agente reclama asignándose el ticket antes de
trabajar.

### Fase 3 — Extracción con clasp

Por cada Proyecto (un ticket = una rama = un PR):

```bash
# Scaffold desde la plantilla canónica (botón "Use this template" o):
gh repo create OWNER/<slug> --template OWNER/google-apps-script-starter-template

# Clonar el código del script dentro del proyecto
clasp clone-script <SCRIPT_ID> --rootDir <proyecto>/src
# se generan <proyecto>/src/.clasp.json (scriptId) y appsscript.json (manifiesto)
```

Versionar: código fuente, `appsscript.json`, `.clasp.json` (solo describe el
proyecto; sin credenciales), `.claspignore`. NUNCA `.clasprc.json`.
Commit: `feat: extracción de <Proyecto> (ticket NN, #N)`.

### Fase 4 — Contenedores (Drive API)

Exportar los documentos vinculados a los scripts (Sheet, Docs, Slides):

```bash
# Formatos de export por tipo (Drive API v3): Sheets→xlsx/csv(1ª hoja)/pdf,
# Docs→docx/txt/pdf/md, Slides→pptx/pdf. Forms: NO exportable (lección 6).
curl -s -H "Authorization: Bearer $TOKEN" \
  -o "contenedores/<slug>.xlsx" \
  "https://www.googleapis.com/drive/v3/files/<FILE_ID>/export?mimeType=application%2Fvnd.openxmlformats-officedocument.spreadsheetml.sheet"

# o con rclone (elegir --drive-export-formats;Forms solo copia server-side ≥1.65)
rclone copy "gdrive:MiCarpeta" ./contenedores --drive-export-formats "docx,xlsx,pptx,pdf" --tpslimit 5 -P
```

El 403 `storageQuotaExceeded` durante export es la lección 5.

### Fase 5 — Sanitización

Antes de push/publicar:

```bash
gitleaks detect --no-banner -v          # secretos en todo el árbol
gitleaks protect --staged -v            # (lo hace el pre-commit)
```

Checklist humano/agente:

- [ ] `.clasprc.json`, `.env`, `client_secret*.json`, `.npm-cache/`,
      `node_modules/`, `.scratch/` fuera de git (`.gitignore` + hook).
- [ ] PII de terceros redactada → placeholders (`NOMBRE_CLIENTE`,
      `CORREO_ADMIN`) o datos de prueba (`algo@ejemplo.test`).
- [ ] API keys de terceros empotradas en el código original → variables de
      entorno / PropertiesService.
- [ ] Contenedores con datos reales de clientes → no se publican; se publica
      plantilla o versión con datos de prueba.
- [ ] CI verde (`test` + `gitleaks`).

### Fase 6 — PR y merge

Rama por ticket → PR → CI verde → squash merge → cerrar ticket comentando
URL/commit. En monorepo con protección: nunca push directo a `main`.

## Lecciones aprendidas (no negociables, en orden de dolor)

1. **OAuth con client propio.** El client OAuth que trae clasp está
   **bloqueado por Google para scopes restringidos** ("This app is blocked"
   al hacer login). Solución: crear en Google Cloud Console un OAuth client
   tipo *Desktop app* propio, dejarlo en modo *Testing* con el dueño como
   usuario de prueba, descargar el `client_secret_*.json` y:
   `clasp login --creds client_secret_*.json` (+ scope extra con
   `--include-clasp-scopes` si hace falta). El `client_secret*.json` y el
   token resultante jamás van a git.
2. **Las APIs se habilitan en el proyecto Cloud.** Antes de clonar/exportar:
   habilitar **Google Apps Script API** en
   <https://script.google.com/home/usersettings> y, en el proyecto Cloud del
   client propio, las APIs que uses (Apps Script, Drive, Forms, Service
   Usage). Un 403 "API not enabled" no es un bug del pipeline.
3. **Los codes OAuth son single-use.** El código del flujo copiar/pegar se
   canjea UNA vez: si el canje falla (expiró, red, reintentos), NO reutilizar
   el mismo code — repetir el flujo y generar uno nuevo.
4. **Los refresh tokens de apps en Testing vencen a 7 días.** Con el client
   propio en modo Testing, el refresh token expira ~7 días después de emitido
   (policy de Google): re-login semanal, o publicar la app (In production;
   con datos de prueba basta para uso personal) para tokens de larga vida.
   Síntoma clásico: `invalid_grant` a la semana exacta.
5. **`403 storageQuotaExceeded` en export = cuota de la CUENTA, no del
   pipeline.** El dueño de la cuenta llenó su Drive (o su cuota de export):
   liberar espacio/vaciar papelera o exportar a menos formatos. El script
   está bien; no "arreglar" el pipeline.
6. **Forms no tiene export binario.** La tabla oficial de export formats de
   Drive no incluye Forms: para respaldarlo usar Forms API (`forms.get`,
   JSON de estructura) o copia server-side con rclone ≥ 1.65
   (`--drive-show-all-gdocs`). Pantallazo = complemento documental.
7. **`.clasprc.json` puede vivir local** (junto al proyecto) o global (`~`).
   clasp v3 lee el local. En cualquier ubicación: NUNCA a git; el wizard lo
   ignora y el pre-commit lo escanea.
8. **clasp v3 renombró comandos** (`list`→`list-scripts`, `clone`→
   `clone-script`); los scripts viejos se rompen (quedan alias). Node ≥ 20
   obligatorio.
9. **Verifica el estado real antes de rehacer.** `git log`, `gh api …/check-runs`,
   la hoja misma: si el paso ya se aplicó, re-ejecutarlo duplica (filas,
   commits, proyectos creados). Idempotencia primero.

## Reglas duras (resumen)

- Nada de secretos a git: `.clasprc.json`, `.env`, `client_secret*.json`,
  tokens, keys. CI gitleaks = fail-closed.
- PII de terceros siempre redactada antes de publicar.
- Un ticket = una rama = un PR; CI verde antes de merge.
- Issues por REST (`gh api`); `gh issue view` puede estar roto (GraphQL 499).
