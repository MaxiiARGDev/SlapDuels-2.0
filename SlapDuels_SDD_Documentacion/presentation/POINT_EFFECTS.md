# Slap Duels 2.0 — POINT_EFFECTS

> Especificación vigente. Define el comportamiento requerido; no certifica que la implementación ni los assets actuales hayan sido verificados en Studio.

## Arquitectura de Feedback Cinematográfico y Cosméticos de Punto (`PointFeedbackService` y `PointEffect`)

Para elevar el impacto visual y auditivo de cada anotación sin comprometer la estabilidad ni el equilibrio del juego, se introduce el sistema de **Point Effects** operado por `PointFeedbackService`.

> [!IMPORTANT]
> **Point Effects are cosmetic-only:**
> Un `PointEffect` es estrictamente estético. **PROHIBIDO** alterar daño, knockback base, velocidad, score, recompensas, duración de la partida o cualquier ventaja competitiva mediante efectos de punto.

### Separación Conceptual: Jugador (Efecto) vs Zona (Origen Físico)
- **El jugador anotador (`ScoringPlayer`) determina el efecto:** Su selección está en `Inventory.Equipped.PointEffects` (ej. "Inferno", "Frost", "Basic") y se consulta mediante la API de PlayerService.
- **La zona donde anota (`ScoringZone`) determina el origen físico:** El efecto se manifiesta física y espacialmente en el `BasePart` de gol:
  - Anotación de **Red** $\rightarrow$ el efecto del jugador aparece en `session.InstanceInfo.RedWin`.
  - Anotación de **Blue** $\rightarrow$ el efecto del jugador aparece en `session.InstanceInfo.BlueWin`.
- **Prohibido:** Ubicar el efecto sobre el personaje del jugador, en el spawn o en el centro de la arena. El origen es siempre el `ScoringZone` físico.

### Separación Estricta de Responsabilidades
- **`ScoreService` (Autoridad de Dominio y Gameplay):**
  - Detección espacial y física de contacto en zonas de gol.
  - Validación de elegibilidad del jugador y estado de la partida (`Playing`).
  - Determinación del equipo anotador (`Red` / `Blue`) y del jugador anotador (`ScoringPlayer`).
  - Incremento del puntaje autoritativo.
  - Otorgamiento de recompensas de economía (+50 Coins).
  - Emisión de actualización de marcador (`ScoreUpdated`) y aviso de `LastPoint`.
  - Determinación de punto final o programación de reinicio de punto (`PointResetDelay`).
  - Generación de `PointId` único determinista.
  - **No conoce:** Partículas, sonidos, explosiones ni Camera Shake.
- **`PointEffectDefinitions` (Catálogo Compartido de Definiciones):**
  - Define identidad, `DisplayName`, `Rarity` ("Common", "Rare", "Epic", "Legendary"), precio futuro y metadatos.
  - No contiene lógica de gameplay ni física.
- **`PlayerService` (Propiedad y Equipamiento - Player Ownership):**
  - Mantiene `Inventory.Owned.PointEffects` e `Inventory.Equipped.PointEffects`. Las APIs específicas de PointEffects son wrappers de la API genérica; no existen tablas paralelas.
  - **Fallback universal:** Todo jugador posee `"Basic"` por defecto.
  - **Autoridad del servidor:** El servidor valida existencia y propiedad antes de permitir equipar cualquier cosmético.
- **`PointFeedbackService` (Lifecycle, Origen Físico y Despacho):**
  - Responsable del ciclo de vida del **feedback audiovisual** del punto. RoundService conserva la autoridad sobre el reinicio y los estados.
  - Resuelve `ScoringPlayer` $\rightarrow$ `EquippedPointEffect` $\rightarrow$ `PointEffectDefinitions`. Si es nulo o inválido, aplica fallback seguro a `"Basic"`.
  - Valida defensivamente que `ScoringZone` pertenezca a la instancia activa y al equipo anotador.
  - Localiza el template en `ServerStorage.PointEffects[EffectId]` (editable desde Studio) y lo clona en `ScoringZone`.
  - Despacha la ejecución al `EffectController` registrado (`PointEffectRegistry.GetController(effectId)`).
  - Gestiona los handles activos y el cleanup por `Duration` o cancelación de partida (`CleanupMatch`).
  - Notifica a clientes vía RemoteEvent `Remotes.Match.PointFeedback`.
- **`PointEffectRegistry` & `EffectController` (Coreografía Visual y Sonora Específica):**
  - Cada efecto cuenta con su propio controller (ej. `BasicController`).
  - El controller gobierna la secuencia temporal de flashes, dispersión de partículas, expansión con `TweenService` y capas de SFX.
  - Retorna un `EffectHandle` con métodos `:Stop()` y `:Destroy()` para cancelación segura en cualquier momento.
  - **PROHIBIDO** modificar gameplay, daño, velocidad, scores o economía dentro de los controllers.
  - Permite añadir nuevos efectos (`InfernoController`, `FrostController`, `ThunderController`, `VoidController`) sin alterar una sola línea de `PointFeedbackService`.

### Flujo Futuro de Tienda (Point Effect Shop)
La arquitectura queda desacoplada y lista para la integración posterior de la tienda:
```
PointEffectShop
  ↓ (Gasto de Coins autoritativo en Servidor)
Comprar PointEffect
  ↓
PlayerService:AddOwnedPointEffect(player, effectId)
  ↓
PlayerService:SetEquippedPointEffect(player, effectId)
  ↓
Inventory.Equipped.PointEffects = effectId
```
Precios proyectados en definiciones: `Basic` (0 / Gratuito), `Inferno` (500 Coins), `Frost` (750 Coins), `Thunder` (1500 Coins), `Void` (3000 Coins).

### Soporte Multijugador (1v1, 2v2, 3v3)
- En partidas de múltiples jugadores por equipo, cada jugador conserva su propio cosmético equipado de forma independiente.
- Si el Jugador A (equipado con "Basic") anota para Red, se reproduce "Basic" en `RedWin`.
- Si el Jugador B (equipado con "Inferno") anota para Red, se reproduce "Inferno" en `RedWin`.
- El feedback incluye MatchId y PointId. Los clientes filtran los eventos según su contexto; recibir un broadcast no autoriza activar el HUD o la cámara de una partida ajena.

### Prevención de Duplicación, Camera Shake y Limpieza (Cleanup)
- **De-duplicación:** Se genera un identificador único por punto (`PointId`). `PointFeedbackService` mantiene el registro `_processedPoints` y descarta invocaciones repetidas de forma atómica.
- **Camera Shake:** El cliente recibe `PointFeedback` (`PointId`, `MatchId`, `ScoringTeam`, `ScoringPlayerName`, `ScoringZonePosition`, `EffectId`, `IsFinalPoint`) y ejecuta la reacción local de cámara de manera puramente pasiva.
- **Cleanup:** Al finalizar la partida o reiniciarse la sesión (`ScoreService:CleanupSession`), se invoca `PointFeedbackService:CleanupMatch(matchId)`, invocando `:Destroy()` en todos los handles de controllers activos y destruyendo cualquier clon residual con garantía de residuo cero.

### Herramienta de Testing y Desarrollo (`PointEffectTestService`)
Para permitir pruebas rápidas de cosméticos en Roblox Studio sin necesidad de iniciar una partida real, se incorpora `PointEffectTestService`:
- **Ubicación Física:** `Workspace.PointEffectTest.TestPart` (BasePart editable directamente desde Studio, con material Neon llamativo y ubicado en el Lobby).
- **Attributes Editables en Studio:**
  - `EffectId` (string, default `"Basic"`): Determina qué cosmético probar. Puede cambiarse en vivo desde Properties para probar cualquier efecto registrado.
  - `Cooldown` (number, default `1`): Intervalo mínimo en segundos entre activaciones consecutivas para prevenir spam.
  - `IsFinalPoint` (boolean, default `false`): Permite simular un punto definitivo de victoria para probar el multiplicador de partículas/volumen y la sacudida de cámara intensificada.
- **Métodos de Activación:**
  - `Touched`: Contacto directo de cualquier personaje o part.
  - `ProximityPrompt`: Activación manual interactiva ("Probar efecto" / "Point Effect Test").
- **Integración con Feedback de Pantalla (`PointCameraFX`):**
  - Al activarse, emite el `RemoteEvent` `PointFeedback` con `ScoringZonePosition = TestPart.Position`, permitiendo validar el camera shake, bloom, flash y FOV kick del cliente según la distancia del jugador.
- **Aislamiento Total del Gameplay:**
  - **NO** interactúa con `ScoreService`.
  - **NO** genera puntos reales ni altera `MatchScore`.
  - **NO** otorga Coins ni afecta la economía.
  - **NO** inicia `RoundService` ni afecta el matchmaking o respawn.
  - Reutiliza directamente `PointEffectRegistry` y los controllers correspondientes (`BasicController`), proveyendo un contexto mínimo de prueba (`MatchId = "TEST"` y `OriginPart = TestPart`).

### Sistema de Ragdoll y Física de Onda Expansiva (`RagdollService`)
Para brindar máximo impacto visual y cómico al anotar un punto y al probar cosméticos en el `TestPart`, se implementa `RagdollService`:
- **Arquitectura Universal (R15 y R6):**
  - Gestiona las articulaciones según el rig: `AnimationConstraint` en R15 y `Motor6D` en R6, preservando la integridad del personaje y la cámara.
  - Cuando necesita constraints físicos temporales, usa límites angulares y offsets del rig. El reset restaura las articulaciones originales y elimina únicamente recursos temporales; véase [Ciclo de vida](../gameplay/CHARACTER_LIFECYCLE.md).
  - Pasa el `Humanoid` a estado `Ragdoll` con `PlatformStand = true` y colisiones activas en extremidades.
- **Física de Lanzamiento:**
  - `LaunchCharacter(character, originPos, force, upwardRatio)` aplica un impulso vectorial de despegue con elevación vertical (65% por defecto) y dispersión radial away from the blast center, agregando torque rotacional aleatorio para giros en el aire.
- **Integración con Point Effects:**
  - **Partida Real (`PointFeedbackService`):** Al detonar un punto en `ScoringZone`, `BlastZone` aplica el festejo a los participantes de esa sesión dentro del radio (25 studs de referencia). No afecta jugadores de otras partidas ni del lobby.
  - **Herramienta de Testing (`PointEffectTestService`):** Al pisar o activar `TestPart`, el personaje sale eyectado por los aires con ragdoll inmediato. Los atributos `RagdollForce`, `RagdollRadius` y `RagdollDuration` son editables desde Studio.
- **Auto-Recuperación y Reseteo Seguro:**
  - Tras expirar la duración configurable (`DefaultDuration = 2.0s`), el servicio restaura automáticamente las colisiones, destruye los constraints y reincorpora el personaje de pie (`GettingUp`).
  - Al reposicionar el mismo Character en partida (`SpawnService:ResetCharacterInArena`), se invoca `ResetRagdollImmediate` de forma preventiva para asegurar que los jugadores siempre comiencen la siguiente ronda de pie en sus spawns.

## Física común y datos

BlastZone es una reacción común de festejo controlada por el sistema, independiente del cosmético elegido. Los EffectControllers no ajustan su fuerza, radio ni duración para dar ventajas. El reset y la protección de Ending siguen [Ciclo de vida](../gameplay/CHARACTER_LIFECYCLE.md).

La única especificación de estadísticas, esquema V2, inventario y guardado está en [Datos](../data/PLAYER_DATA.md). Las reglas de zonas están en [Matchmaking](../gameplay/MATCHMAKING.md), y el HUD en [UI](UI.md). El flujo de tienda y los precios proyectados son planificación documental, no certificación de entrega.
