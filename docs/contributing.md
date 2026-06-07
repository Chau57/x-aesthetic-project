# Đóng góp / Contributing

Hướng dẫn workflow cho thành viên team khi làm việc trên X-Aesthetic.

---

## Before you start

1. Read [TODO.md](../TODO.md) — identify which phase and task your work maps to.
2. Read [current-state.md](current-state.md) — confirm what is already implemented.
3. For plugin work, read [plugin_contract.md](plugin_contract.md).

If your task is not in `TODO.md`, propose a new checklist item to the team before implementing. Do not expand scope silently.

---

## Branch workflow

1. Create a feature branch from the main integration branch (e.g. `ntd1` or `main`).
2. Keep commits focused and atomic — one logical change per commit.
3. Separate refactors from feature work when possible.
4. Open a pull request when ready for review.

Suggested branch names:

```text
feat/camera-plugin-overlays
fix/gallery-delete-confirm
docs/update-architecture
test/evaluator-unit-tests
```

---

## Quality gates

Before every commit and PR:

```bash
flutter analyze   # must pass — no new warnings
flutter test      # all tests must pass
```

Do not commit:

- Generated build artifacts (`build/`, `.dart_tool/`)
- Local IDE config (`.idea/`, unless team-agreed)
- Secrets (`.env`, API keys, credentials)

---

## Commit messages

Use semantic prefixes:

| Prefix | Use for |
|--------|---------|
| `feat:` | New feature or user-visible behavior |
| `fix:` | Bug fix |
| `refactor:` | Code restructure without behavior change |
| `docs:` | Documentation only |
| `test:` | Tests only |
| `chore:` | Tooling, deps, config |

Example:

```text
feat: register rule-of-thirds plugin at startup

- Add RuleOfThirdsPlugin under lib/domain/plugins/
- Wire PluginRegistry in bootstrap
- Mark Phase 7 plugin task in TODO.md
```

---

## TODO sync rule

`TODO.md` is the **source of truth** for project progress (see also `.cursor/rules/todo-roadmap.mdc`).

| When | Action |
|------|--------|
| Starting a feature | Note which phase/task you are working on |
| Completing a feature | Mark `[x]` on the relevant checklist items |
| Scope changes | Update checklist wording; discuss with team first |

---

## Code conventions

- Follow existing patterns in surrounding files — match naming, imports, and abstraction level.
- `analysis_options.yaml` enforces `flutter_lints` with `prefer_const_constructors`, `prefer_final_fields`, `avoid_print`.
- Plugins return **data** (`PluginOutput`), not Flutter widgets — rendering stays in `presentation/`.
- Layer dependency: `presentation` → `domain` / `core`; `data` implements `domain` contracts.

### Adding a new aesthetic plugin

1. Implement `AestheticPlugin` (see [plugin_contract.md](plugin_contract.md)).
2. Place file under `lib/domain/plugins/` (directory to be created — Phase 7).
3. Register in `PluginRegistry` at startup.
4. Add unit test following `test/core/plugin/base_plugin_test.dart`.
5. Update [TODO.md](../TODO.md) Phase 7 checkboxes.

---

## Documentation changes

When your change affects behavior or architecture:

- Update [current-state.md](current-state.md) if implementation status changes.
- Update [architecture.md](architecture.md) only for structural changes.
- Update [TODO.md](../TODO.md) checkboxes.
- Update [README.md](../README.md) only if entry-point information changes.

---

## Pull request checklist

- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Relevant `TODO.md` items marked `[x]`
- [ ] Docs updated if behavior or setup changed
- [ ] No secrets or generated files committed
- [ ] PR description explains **why**, not just what changed
