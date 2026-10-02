# pulperia-app

Administrador de deudas (fiados) para pulperías. Offline-first en móvil, sincronizable con web.

```
pulperia-app/
├── AGENTS.md / CLAUDE.md   # contexto del agente
├── docs/
│   ├── constitution.md     # principios (borrador)
│   └── prompts.md          # prompt de cada fase SDD
├── specs/001-mvp/          # spec.md -> plan.md -> tasks.md
├── api/                    # .NET + PostgreSQL + Docker
├── mobile/                 # Flutter (SQLite/Drift, cola de sync)
├── web/                    # Angular
└── .claude/skills/spec-generator/
```

## Flujo SDD
Constitución → Spec → Clarificación → Plan → Tareas → Implementación (tarea a tarea, tests primero) → Validación → Cambio (primero la spec).

Estado: ✅ estructura base · ⬜ constitución aprobada · ⬜ spec · ⬜ plan · ⬜ tareas
