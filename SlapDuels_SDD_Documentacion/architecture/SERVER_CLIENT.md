# Slap Duels 2.0 — SERVER_CLIENT

> Este documento conserva contenido del `GAME_SDD.md` original suministrado, redistribuido por dominio para reducir el contexto necesario para agentes de IA.

## 9. Distribución: Servidor vs Cliente

1. **Autoridad del Servidor:** El servidor es siempre la autoridad para estados de partida, resultados, ocupación de pads, instanciación física de mapas y posicionamiento de jugadores.
2. **Presentación en Cliente:** La interfaz de usuario (HUD), animaciones locales de cámara y efectos que sólo incumben al jugador local deben ser gestionados en el cliente.
3. **Efectos Compartidos (World VFX/SFX):** Los efectos globales o visibles para todos los jugadores en la zona pueden ser replicados por el servidor o despachados mediante `RemoteEvent` al cliente según el rendimiento requerido.
4. **No Duplicación:** Nunca disparar el mismo efecto simultáneamente desde el servidor y desde el cliente para evitar sonidos desfasados o acumulación de partículas dobles.

---
