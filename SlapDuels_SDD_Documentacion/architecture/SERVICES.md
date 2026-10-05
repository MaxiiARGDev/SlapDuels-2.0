# Slap Duels 2.0 — SERVICES

> Este documento conserva contenido del `GAME_SDD.md` original suministrado, redistribuido por dominio para reducir el contexto necesario para agentes de IA.

## 8. Servicios de Gameplay vs Sistemas de Presentación

- **Servicios de Gameplay (Autoridad):** Gestionan el estado lógico del juego, validaciones, conteos, reglas y resultados (ej. `MatchmakingService`, `RoundService`, `MatchInstanceService`, `SpawnService`).
- **Sistemas de Presentación (Feedback):** Escuchan o responden a las transiciones de estado de los servicios de gameplay y aplican las representaciones visuales y sonoras correspondientes (ej. `MatchmakingFeedbackService`, controladores cliente de HUD y animaciones).

> No mezclar lógica de combate o reglas de matchmaking dentro de módulos visuales, ni ensuciar los servicios de dominio con manipulación de efectos de partículas ad-hoc.

---
