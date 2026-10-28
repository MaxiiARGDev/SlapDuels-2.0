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
- [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md)
- [architecture/SERVER_CLIENT.md](architecture/SERVER_CLIENT.md)
- [architecture/SERVICES.md](architecture/SERVICES.md)

### Gameplay
- [gameplay/MATCH_FLOW.md](gameplay/MATCH_FLOW.md)
- [gameplay/MATCHMAKING.md](gameplay/MATCHMAKING.md)
- [gameplay/COMBAT.md](gameplay/COMBAT.md)
- [gameplay/SCORING.md](gameplay/SCORING.md)
- [gameplay/ELIMINATION.md](gameplay/ELIMINATION.md)
- [gameplay/CHARACTER_LIFECYCLE.md](gameplay/CHARACTER_LIFECYCLE.md)

### Presentación
- [presentation/AUDIO.md](presentation/AUDIO.md)
- [presentation/UI.md](presentation/UI.md)
- [presentation/GAME_FEEL.md](presentation/GAME_FEEL.md)
- [presentation/POINT_EFFECTS.md](presentation/POINT_EFFECTS.md)

### Datos
- [data/PLAYER_DATA.md](data/PLAYER_DATA.md)

### Estándares
- [standards/ASSETS.md](standards/ASSETS.md)
- [standards/TESTING.md](standards/TESTING.md)
- [standards/DEBUGGING.md](standards/DEBUGGING.md)

## Routing rápido para agentes

| Si la tarea menciona | Leer |
|---|---|
| slap, golpe, knockback, ragdoll | [gameplay/COMBAT.md](gameplay/COMBAT.md) |
| Kill, KillPart, eliminación | [gameplay/ELIMINATION.md](gameplay/ELIMINATION.md) |
| WinPart, punto, score | [gameplay/SCORING.md](gameplay/SCORING.md) |
| respawn, caída después de punto, CharacterAdded, Humanoid.Died | [gameplay/CHARACTER_LIFECYCLE.md](gameplay/CHARACTER_LIFECYCLE.md) |
| matchmaking, pads, cola | [gameplay/MATCHMAKING.md](gameplay/MATCHMAKING.md) |
| estados de partida, countdown, ronda | [gameplay/MATCH_FLOW.md](gameplay/MATCH_FLOW.md) |
| música, SoundService, volumen musical | [presentation/AUDIO.md](presentation/AUDIO.md) |
| HUD, SettingsGUI, interfaces | [presentation/UI.md](presentation/UI.md) |
| camera shake, flash, blur, countdown FX | [presentation/GAME_FEEL.md](presentation/GAME_FEEL.md) |
| PointEffect, cosméticos de punto | [presentation/POINT_EFFECTS.md](presentation/POINT_EFFECTS.md) |
| Coins, Wins, Losses, Kills, DataStore | [data/PLAYER_DATA.md](data/PLAYER_DATA.md) |
| assets, templates, Instance.new | [standards/ASSETS.md](standards/ASSETS.md) |
| tests, Rojo, Definition of Done | [standards/TESTING.md](standards/TESTING.md) |
| logs, cleanup, depuración | [standards/DEBUGGING.md](standards/DEBUGGING.md) |

## Mantenimiento y precedencia documental

Cada dominio es la referencia normativa de sus propias reglas. Las referencias cruzadas sustituyen las copias de contratos para evitar divergencias. Las decisiones sustituidas se registran en [MIGRATION_MANIFEST.md](MIGRATION_MANIFEST.md); no son instrucciones vigentes.

Esta consolidación del 14 de octubre de 2026 adopta Zero-Death, datos V2 y música local centralizada. No implica una auditoría completa del código ni pruebas en Studio. Si la implementación difiere del contrato, se registra la discrepancia antes de cambiar arquitectura o reglas.

Al cambiar una regla, actualizar su documento propietario y sus referencias en la misma tarea. No eliminar requisitos vigentes sin sustitución explícita. Las características futuras deben permanecer identificadas como planificadas.
