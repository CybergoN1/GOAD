# EnableClaude Toolkit

This project includes the EnableClaude DISTRO — 93 reusable, project-agnostic tools, skills, agents, and prompts for Claude Code. All resources are in the `DISTRO/` directory.

## Tools (37 scripts — `python DISTRO/Tools/<category>/<script>`)

| Category | Tools |
|----------|-------|
| Analysis | `Invoke-ProjectAnalysis.py`, `Analyze-Structure.py`, `Analyze-Tooling.py`, `Analyze-Access.py` |
| Data | `Invoke-DataSplitter.py`, `Invoke-EnvGenerator.py`, `Invoke-SessionSnapshot.py`, `Invoke-SessionContext.py`, `Invoke-RemotionBuilder.py`, `Invoke-SQLArchitect.py` |
| DevOps | `Invoke-DockerScaffold.py`, `Invoke-SystemdGenerator.py`, `Invoke-ReverseProxy.py`, `Invoke-BackupScheduler.py`, `Invoke-HealthCheck.py`, `Invoke-LogAnalyzer.py`, `Invoke-BashInstaller.py` |
| Git | `Invoke-SmartCommit.py`, `Invoke-ChangelogGenerator.py`, `Invoke-GitBootstrap.py`, `Invoke-GitHubManager.py`, `Initialize-GitHubAuth.ps1` |
| Network | `Invoke-SSHSetup.py`, `Invoke-URLChecker.py`, `Invoke-EmailProcessor.py`, `Invoke-PathValidator.ps1`, `Invoke-PhoneDialer.py`, `Invoke-WebScraper.py`, `Invoke-n8nWebhook.py` |
| Scaffolding | `Generate-Excalidraw.py`, `Generate-Kit.py`, `Generate-OnboardingPrompt.py`, `Initialize-EnableClaudeItem.py` |
| Security | `Invoke-CredentialScanner.py`, `Invoke-PromptScanner.py`, `Invoke-SchemaValidator.py` |

Each tool has a companion `.md` with usage details. Read the `.md` before running.

## Skills (21 workflows — `DISTRO/Skills/<domain>/<name>.md`)

| Domain | Skills |
|--------|--------|
| Content | `obsidian-vault-markdown`, `data-aware-content-creation`, `structured-data-linting`, `add-to-enableclaude`, `ab-headline-testing`, `brand-voice-seo-optimization` |
| Development | `region-map`, `batch-signature-first`, `lightweight-test-pattern`, `multi-file-atomic-edit`, `browser-automation-pattern`, `mcp-server-scaffold`, `agent-memory-pruning`, `tdd-enforcement-pattern` |
| Infrastructure | `cross-platform-ssh-config`, `post-deploy-health-check`, `service-watchdog-pattern` |
| Integration | `project-management-integration`, `messaging-bot-integration`, `google-workspace-automation`, `rest-to-graphql-translation` |

## Agents (23 definitions — `DISTRO/Agents/<name>.md`)

Autonomous workflow agents. Key agents:
- **project-orchestrator** — Coordinate complex multi-agent tasks
- **multi-agent-manager** — Master orchestrator for delegation
- **code-sense-checker** — Sanity-check code for correctness and design
- **software-architect** — Design systems, review architectures
- **docs-fanatic** — Create and audit all project documentation
- **process-enforcer** — Audit work for shortcuts, drive to completion
- **app-builder-cole** — E2E fullstack scaffolding in one pass
- **automated-qa-engineer** — Generate edge-case tests
- **devops-orchestrator** — Autonomous container lifecycle and repair

Full list: see `DISTRO/Agents/README.md`.

## Prompts (4 templates — `DISTRO/Prompts/`)

- `project-onboarding.md` — Full CLAUDE.md introducing all EnableClaude items
- `file-conversion-pipeline.md` — Engine + Interface separation pattern
- `multi-provider-abstraction.md` — Swappable provider pattern with fallbacks
- `contributing-to-enableclaude.md` — Contribution guidelines

## Session Kits (4 packs — `DISTRO/Kits/`)

Paste a Kit into this CLAUDE.md to scope a session:
- `devops-kit.md` — Deploy, monitor, fix services
- `security-audit-kit.md` — Scan for secrets and threats
- `new-project-kit.md` — Bootstrap a new codebase
- `content-creation-kit.md` — Write docs, blogs, content

## Classifying New Items

| Question | Yes → |
|----------|-------|
| Does it **run** as a script? | **Tool** |
| Does it **teach** Claude Code how to work? | **Skill** |
| Does it **run autonomously** with a goal? | **Agent** |
| Does it **configure** project behaviour? | **Prompt** |

Templates in `DISTRO/_templates/`.
