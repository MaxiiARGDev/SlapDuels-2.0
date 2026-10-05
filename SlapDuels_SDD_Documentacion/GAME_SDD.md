# Slap Duels 2.0 — Game SDD

Este archivo es el índice y manifiesto arquitectónico principal del proyecto.

## Protocolo obligatorio para agentes de desarrollo

1. Leer este documento antes de comenzar cualquier tarea.
2. Identificar el dominio afectado.
3. Leer los documentos SDD específicos indicados para ese dominio.
4. Respetar las directrices arquitectónicas, audiovisuales y de ciclo de vida.
5. No improvisar decisiones arquitectónicas.
6. Si una nueva funcionalidad requiere una decisión no contemplada, reportarla antes de implementar código incompatible.

## Documentos por dominio

### Arquitectura
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/SERVER_CLIENT.md`
- `docs/architecture/SERVICES.md`

### Gameplay
- `docs/gameplay/MATCH_FLOW.md`
- `docs/gameplay/MATCHMAKING.md`
- `docs/gameplay/COMBAT.md`
- `docs/gameplay/SCORING.md`
- `docs/gameplay/ELIMINATION.md`
- `docs/gameplay/CHARACTER_LIFECYCLE.md`

### Presentación
- `docs/presentation/AUDIO.md`
- `docs/presentation/UI.md`
- `docs/presentation/GAME_FEEL.md`
- `docs/presentation/POINT_EFFECTS.md`

### Datos
- `docs/data/PLAYER_DATA.md`

### Estándares
- `docs/standards/ASSETS.md`
- `docs/standards/TESTING.md`
- `docs/standards/DEBUGGING.md`

## Routing rápido para agentes

| Si la tarea menciona | Leer |
|---|---|
| slap, golpe, knockback, ragdoll | `docs/gameplay/COMBAT.md` |
| Kill, KillPart, eliminación | `docs/gameplay/ELIMINATION.md` |
| WinPart, punto, score | `docs/gameplay/SCORING.md` |
| respawn, caída después de punto, CharacterAdded, Humanoid.Died | `docs/gameplay/CHARACTER_LIFECYCLE.md` |
| matchmaking, pads, cola | `docs/gameplay/MATCHMAKING.md` |
| estados de partida, countdown, ronda | `docs/gameplay/MATCH_FLOW.md` |
| música, SoundService, volumen musical | `docs/presentation/AUDIO.md` |
| HUD, SettingsGUI, interfaces | `docs/presentation/UI.md` |
| camera shake, flash, blur, countdown FX | `docs/presentation/GAME_FEEL.md` |
| PointEffect, cosméticos de punto | `docs/presentation/POINT_EFFECTS.md` |
| Coins, Wins, Losses, Kills, DataStore | `docs/data/PLAYER_DATA.md` |
| assets, templates, Instance.new | `docs/standards/ASSETS.md` |
| tests, Rojo, Definition of Done | `docs/standards/TESTING.md` |
| logs, cleanup, depuración | `docs/standards/DEBUGGING.md` |

## Regla de conservación

Estos documentos son una redistribución del `GAME_SDD.md` original suministrado para el proyecto. No se deben eliminar reglas existentes durante la migración. Cuando una regla afecte a varios dominios, se mantiene en el documento de dominio y se referencia desde los demás documentos.
