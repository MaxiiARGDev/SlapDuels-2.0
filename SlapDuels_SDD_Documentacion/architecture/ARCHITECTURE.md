# Slap Duels 2.0 — Arquitectura

> Especificación vigente. Define el comportamiento requerido; no certifica que la implementación ni los assets actuales hayan sido verificados en Studio.

## Alcance y fuentes de autoridad

Slap Duels enfrenta equipos Red y Blue en arenas: los slaps desplazan oponentes; entrar en la zona de meta correspondiente genera puntos. Las kills son una estadística independiente. El diseño admite modalidades configurables y exige aislamiento entre zonas y partidas.

| Responsabilidad | Autoridad | Referencia |
|---|---|---|
| Cola y participantes | MatchmakingService; identidad ZoneId/instancia | [Matchmaking](../gameplay/MATCHMAKING.md) |
| Estados, tiempos y resultado | RoundService; MatchSession/MatchId | [Flujo](../gameplay/MATCH_FLOW.md) |
| Arena física | MatchInstanceService | [Ciclo de vida](../gameplay/CHARACTER_LIFECYCLE.md) |
| Personaje y reposicionamiento | SpawnService y RagdollService | [Ciclo de vida](../gameplay/CHARACTER_LIFECYCLE.md) |
| Golpes y último atacante | SlapService y CombatService | [Combate](../gameplay/COMBAT.md) |
| Puntos y recompensa por punto | ScoreService | [Scoring](../gameplay/SCORING.md) |
| Eliminaciones y atribución de kills | EliminationService | [Eliminación](../gameplay/ELIMINATION.md) |
| Estadísticas e inventario en memoria | PlayerService | [Datos](../data/PLAYER_DATA.md) |
| Carga y guardado | PlayerDataService | [Datos](../data/PLAYER_DATA.md) |
| HUD, cámara y música local | Controllers cliente | [UI](../presentation/UI.md), [Game feel](../presentation/GAME_FEEL.md), [Audio](../presentation/AUDIO.md) |
| Cosméticos de punto | PointFeedbackService y EffectControllers | [Point effects](../presentation/POINT_EFFECTS.md) |

## Invariantes

- El servidor valida reglas, estados y recompensas. El cliente solicita acciones y representa resultados autorizados.
- Cada sesión aísla participantes, score, tags, timers, sensores y efectos por MatchId. Mode define reglas; ZoneId identifica la cola física.
- Los módulos siguen Init(context) y Start(context), con responsabilidades delimitadas y sin dependencias circulares.
- Kill y Point son independientes. Los cosméticos no alteran ventajas competitivas.
- Zero-Death conserva el mismo Character durante la partida y el retorno al lobby.
- Los assets permanentes de presentación se editan en Studio; el código opera sobre instancias existentes o clones temporales.
- Todo recurso temporal tiene cleanup ante cierre, cancelación y desconexión.

## Alcance documental

Los documentos describen el contrato de diseño. Las fases antiguas se consolidaron en reglas vigentes; no se deben reimplementar mecanismos retirados. Una capacidad prevista, como una tienda o una modalidad adicional, necesita validación de implementación antes de considerarse entregada. No se infiere soporte operativo solo por aparecer en el SDD.
