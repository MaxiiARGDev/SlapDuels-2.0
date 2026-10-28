# Registro de consolidación del SDD

## Origen y alcance

La redistribución original partió de Markdown(20261005-155845).md. La consolidación del 14 de octubre de 2026 convierte esa recopilación de fases en una especificación vigente por dominio. Conserva reglas activas y sustituye explícitamente las obsoletas. No certifica el estado del juego en Studio.

## Decisiones consolidadas

| Contenido anterior | Contrato vigente y propietario |
|---|---|
| KillPart letal, Health=0, Humanoid.Died adjudica kills | Sensores no letales; Died diagnóstico; [ELIMINATION](gameplay/ELIMINATION.md) |
| Respawn, LoadCharacter y rescate por CharacterAdded durante match | Mismo Character; reset de ragdoll y PivotTo; [CHARACTER_LIFECYCLE](gameplay/CHARACTER_LIFECYCLE.md) |
| Fases 1/2 con boundary y reset aún desconectados | Boundary, Touched y polling operativos en el contrato vigente |
| Deduplicación permanente por Character | Lock por jugador y contador por caída, permitiendo futuras eliminaciones del mismo Character |
| Punto final sin aclarar recuperación física | Ending sin countdown, con estabilización inmediata y sensores activos hasta retorno seguro |
| SoundJoinMusic reproducido por PadMusic | MusicController local como única autoridad; [AUDIO](presentation/AUDIO.md) |
| Schema V1 y tolerancia a versiones futuras | Schema V2, inventario genérico y bloqueo por versión incompatible; [PLAYER_DATA](data/PLAYER_DATA.md) |
| OwnedPointEffects como tabla paralela | Inventory.Owned/Equipped; API específica como wrapper |
| Animación aislada de TextSize del countdown | Curva C y rebote; bases visuales editables en Studio; [GAME_FEEL](presentation/GAME_FEEL.md) |

## Redistribución y navegación

- [ARCHITECTURE](architecture/ARCHITECTURE.md): mapa de responsabilidades e invariantes.
- [SCORING](gameplay/SCORING.md): validaciones, recompensas, resolución y reinicio.
- [UI](presentation/UI.md): estructura editable del MatchHUD y PlayerHUD; referencias a matchmaking y settings.
- [GAME_FEEL](presentation/GAME_FEEL.md): coreografía, perfiles y cleanup trasladados desde MATCH_FLOW.
- [MATCHMAKING](gameplay/MATCHMAKING.md): identidad de zonas trasladada desde POINT_EFFECTS; QueueSnapshot incluye ZoneId.
- [PLAYER_DATA](data/PLAYER_DATA.md): carga, guardado, cierre y limitaciones de concurrencia trasladados desde POINT_EFFECTS y alineados con V2.
- [POINT_EFFECTS](presentation/POINT_EFFECTS.md): dedicado a cosméticos, feedback, prueba y física común de festejo.
- [GAME_SDD](GAME_SDD.md): enlaces relativos corregidos; se retira el prefijo docs/ que no existe en esta carpeta.

Se preservaron las reglas preexistentes de LockSessionPlayers/UnlockSessionPlayers en MATCH_FLOW. No se modificó código de gameplay. Las capacidades futuras (tienda, assists, música adicional o persistencia de preferencias) no se declaran implementadas por esta revisión.
