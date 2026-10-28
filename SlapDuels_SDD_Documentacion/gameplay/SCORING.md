# Slap Duels 2.0 — Puntos y resultado

> Especificación vigente. Define el comportamiento requerido; no certifica que la implementación ni los assets actuales hayan sido verificados en Studio.

## Autoridad y reglas

ScoreService valida contactos físicos y detección espacial en RedWin/BlueWin. Un punto requiere participante elegible de esa sesión, zona correspondiente al equipo dentro de su arena, estado Playing y ausencia de otro punto en procesamiento.

- Un punto válido suma +1 al equipo y +50 Coins al anotador mediante PlayerService. Nunca concede kill.
- Red anota en la zona identificada como RedWin y Blue en BlueWin según el contrato de la arena. El nombre identifica el equipo anotador.
- Se registra PointScorer y se activa el bloqueo por MatchId antes de permitir otra anotación. La protección combina _pointInProgress y validación de estado; contactos repetidos no duplican score ni recompensa.
- ScoreUpdated actualiza el HUD inmediatamente. LastPoint anuncia la oportunidad del punto de victoria. Cada punto tiene un PointId determinista para deduplicar su presentación.
- ScoreService determina score, recompensas y resultado. PointFeedbackService representa el punto; sus controllers no pueden modificar estas reglas.

## Resolución

| Condición | Resultado |
|---|---|
| Score alcanza WinningScore (5) | Victoria inmediata y Ending; sin countdown de reinicio |
| Punto intermedio | Feedback durante PointResetDelay (1.5 s de referencia), reposicionamiento del mismo Character y PointRestartCountdown de 3 s |
| Tiempo de combate llega a 0 | GetWinner compara los scores; mayor score gana, igualdad produce Draw |

RoundDuration es 300 s de combate. StartCountdown y PointRestartCountdown no consumen tiempo de combate. No se reinician los 5 minutos tras un punto. El contrato temporal está en [Flujo](MATCH_FLOW.md).

## Reanudación y cierre

Antes de reanudar se limpian presencias de zonas con ResetZonePresences. ResumeScoring libera el bloqueo y limpia el estado temporal de punto cuando vuelve Playing. El cierre desconecta detecciones y limpia estado y feedback de esa sesión. La estabilización física en Ending y el retorno al lobby siguen [Ciclo de vida](CHARACTER_LIFECYCLE.md).

Referencias: [Eliminación independiente](ELIMINATION.md), [Cosméticos de punto](../presentation/POINT_EFFECTS.md), [Persistencia](../data/PLAYER_DATA.md).
