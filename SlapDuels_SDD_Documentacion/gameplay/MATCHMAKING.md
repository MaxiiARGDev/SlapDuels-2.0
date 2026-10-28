# Slap Duels 2.0 — MATCHMAKING

> Especificación vigente. Define el comportamiento requerido; no certifica que la implementación ni los assets actuales hayan sido verificados en Studio.

## Arquitectura del Sistema de Matchmaking Genérico

El sistema de emparejamiento ha sido diseñado de forma genérica para soportar cualquier modalidad presente o futura (1v1, 2v2, 3v3, XvX) sin requerir reescrituras de código.

### Fuente de Configuración y Escalabilidad de Zonas
- **Contenedor:** Cada zona física reside como carpeta en `Workspace.ZoneMatchmaking[NombreZona]`.
- **Configuración declarativa:** Cada carpeta declara Attributes editables desde Studio:
  - `Mode` (string, ej. `"1v1"`, `"2v2"`, `"3v3"`)
  - `TeamSize` (number, ej. 1, 2, 3)
  - `MaxPlayersPerTeam` (number)
  - `TotalPlayers` (number)
- **Fallback centralizado:** Si los Attributes no están definidos, se toman los valores por defecto configurados en `Config.Matchmaking.Modes[Mode]`.
- **Prohibido:** Condicionales hardcodeados (`if mode == "1v1" then ...`).

### Modelo de Datos: `QueueSnapshot`
La cola se representa autoritativamente mediante un snapshot inmutable emitido por el servidor:
```luau
export type QueueSnapshot = {
    ZoneId: string,
    ZoneName: string,
    Mode: string,
    TeamSize: number,
    MaxPlayersPerTeam: number,
    TotalPlayers: number,
    Red: { Player },
    Blue: { Player },
    State: "WAITING" | "READY",
}
```
- Las listas `Red` y `Blue` son colecciones genéricas (`{ Player }`) con capacidad hasta `MaxPlayersPerTeam`.
- Cuando `#Red >= TeamSize` y `#Blue >= TeamSize`, el estado pasa a `"READY"`.

- **Audio de Entrada/Salida vs Música de Espera:**
  - `SoundJoin` (one-shot de entrada) y `SoundLeave` (one-shot de salida) se reproducen espacializados en 3D sobre el `BasePart` del pad activo para que el entorno perciba la llegada y salida del competidor.
  - La música de espera es local y pertenece exclusivamente a MusicController:PlayMatchmaking(). SoundJoinMusic es un recurso histórico clasificado como música; MatchmakingFeedbackService no lo reproduce ni emite PadMusic. Véase [Audio](../presentation/AUDIO.md).
- **Partículas dinámicas:** El template `ActivateParticle` se preserva intacto en `effects`. Se crea una instancia temporal `ParticleInstance_<Pad>` sobre el pad ocupado y se descubren y activan dinámicamente todos los `ParticleEmitter`s descendientes.
- **Beams dinámicos:** Los templates de Beams en `effects` se descubren dinámicamente, se clonan temporalmente (`BeamInstance_<Pad>_*`), se calcula su CFrame perimetral relativo al pad y se activan sus `Beam`s.
- **Material reactivo:** El pad cambia a `Enum.Material.Neon` al ocuparse y se restaura obligatoriamente a su `originalMaterial` guardado en memoria al desocuparse.
- **Independencia y concurrencia:** `Red` y `Blue` tienen instancias de efectos y sonidos completamente aisladas.

### Interfaz de Usuario: `MatchmakingHUD` y `MatchmakingController`
- **Instancias Reales:** Creado y mantenido como `ScreenGui` real en `StarterGui.MatchmakingHUD`. No se construye visualmente mediante código procedimental.
- **Representación Real de Participantes (Sin Placeholders):**
  - **Eliminación de Textos de Equipo:** Se elimina completamente cualquier texto obsoleto de cabecera como `"EQUIPO ROJO (1/1)"` o `"EQUIPO AZUL (1/1)"`. El HUD se enfoca exclusivamente en el enfrentamiento entre los participantes reales.
  - **Nombres Visibles:** Cada participante muestra su `DisplayName` (con fallback a `Name`) visible y legible directamente encima de su propio recuadro de tarjeta.
  - **Avatar Real del Jugador:** Cada slot ocupado carga el avatar real del jugador utilizando el thumbnail oficial de Roblox (`rbxthumb://type=AvatarBust&id=%d&w=150&h=150`).
  - **Orden Consistente Red / Blue:** El jugador de **Red** se sitúa permanentemente a la **izquierda**, y el jugador de **Blue** se sitúa permanentemente a la **derecha**, con el distintivo **CONTRA** en el centro. Ambos jugadores ven exactamente la misma disposición del match (no se invierte según el punto de vista del cliente).
  - **Estado de Espera (Waiting State):** Cuando no hay rival en la plataforma, el slot muestra limpiamente `"ESPERANDO..."` encima del recuadro y un símbolo central `"?"` con borde sutil. Se prohíben avatares de `Roblox`, imágenes genéricas rotas o UserIds ficticios.
- **Ciclo Reactivo de Actualización:**
  - `MatchmakingController` escucha `Remotes.Matchmaking.QueueStatus`. Al ingresar un rival, la tarjeta se actualiza de inmediato con su avatar y nombre. Al salir, se limpia de inmediato y retorna al estado de espera `"?"`.
  - La limpieza destruye clones anteriores (`_clearSlots`), impidiendo residuos visuales, imágenes cacheadas o fugas de memoria.
- **Visibilidad Contextual y Aislamiento:** El HUD se muestra **únicamente** si el `localPlayer` forma parte de los participantes de ese `snapshot.ZoneId`. Al salir de la zona o al iniciar la partida (`newState ~= "Waiting"`), el HUD se oculta y limpia automáticamente.
- **Compatibilidad con Equipos Mayores:** La arquitectura utiliza colecciones `Red` y `Blue` gobernadas por `snapshot.TeamSize`, permitiendo escalar a 2v2 y 3v3 de forma natural.

---

### Arquitectura de Matchmaking y Múltiples Zonas Físicas (`MatchmakingService` & `MatchmakingFeedbackService`)

> [!IMPORTANT]
> **Regla de Identidad de Zona vs Modalidad:**
> Multiple physical matchmaking zones may share the same Mode. Mode defines matchmaking rules; Zone Instance defines queue identity.

- **Definición de Términos:**
  - **`Mode`:** Define exclusivamente las reglas y configuración de la modalidad (ej. `"1v1"`, `"2v2"`, `"3v3"`, `TeamSize`, `MaxPlayersPerTeam`, `TotalPlayers`).
  - **`Instance` (`zoneFolder`):** La carpeta física dentro de `Workspace.ZoneMatchmaking` es la identidad primaria interna para separar colas, estados de ocupación, pads y recursos audiovisuales (`_zones[zoneFolder] = zoneState`).
  - **`ZoneName`:** Nombre de la carpeta física (ej. `"1v1"`, `"1v1_2"`, `"1v1_3"`, `"Ranked1v1"`) para identificación legible y depuración.
  - **`ZoneId`:** Identificador único por instancia (ej. `"Zone_1v1"`, `"Zone_1v1_2"`) transportado en `QueueSnapshot` y hacia `RoundService`.

- **Múltiples Zonas del Mismo Modo:**
  - Es completamente válido clonar `Workspace.ZoneMatchmaking["1v1"]` a `Workspace.ZoneMatchmaking["1v1_2"]` y `Workspace.ZoneMatchmaking["1v1_3"]`.
  - Todas comparten `Mode = "1v1"`, pero cada una opera de manera estrictamente independiente:
    - **Pads independientes:** Sus pads `Red` y `Blue` dentro de `joins-parts` detectan únicamente los jugadores parados en esa zona física.
    - **Feedback audiovisual independiente:** Cada zona tiene su propia carpeta `effects`. Los sonidos `SoundJoin`/`SoundLeave`, partículas y beams se disparan y limpian exclusivamente en la instancia que los originó (`SetPadOccupied(zoneFolder, teamName, isOccupied, occupant)`).
    - **Snapshots y HUD independientes:** Cada snapshot contiene `ZoneId`, `ZoneName` y `Mode`. El HUD del cliente (`MatchmakingController`) únicamente muestra la cola donde está el jugador y no se oculta ni interfiere por snapshots de otras zonas.
    - **Preparación simultánea y MATCH_READY:** Dos o más zonas pueden estar en `WAITING` o `READY` al mismo tiempo con jugadores distintos.

- **Ciclo de Vida Dinámico (Runtime Discovery & Cleanup):**
  - `MatchmakingService` detecta automáticamente cualquier carpeta nueva añadida a `Workspace.ZoneMatchmaking` en tiempo de ejecución vía `ChildAdded`.
  - Si una zona es eliminada (`ChildRemoved`), se realiza un cleanup exhaustivo: desconexión de eventos, desregistro en `MatchmakingFeedbackService:UnregisterZone(zoneFolder)` (destrucción de partículas, beams y restauración de materiales) y vaciado de caché de snapshots sin dejar fugas de memoria.

---
