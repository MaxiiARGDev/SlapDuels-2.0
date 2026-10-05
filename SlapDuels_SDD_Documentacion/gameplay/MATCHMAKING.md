# Slap Duels 2.0 — MATCHMAKING

> Este documento conserva contenido del `GAME_SDD.md` original suministrado, redistribuido por dominio para reducir el contexto necesario para agentes de IA.

## 13. Arquitectura del Sistema de Matchmaking Genérico

El sistema de emparejamiento ha sido diseñado de forma genérica para soportar cualquier modalidad presente o futura (1v1, 2v2, 3v3, XvX) sin requerir reescrituras de código.

### 1. Fuente de Configuración y Escalabilidad de Zonas
- **Contenedor:** Cada zona física reside como carpeta en `Workspace.ZoneMatchmaking[NombreZona]`.
- **Configuración declarativa:** Cada carpeta declara Attributes editables desde Studio:
  - `Mode` (string, ej. `"1v1"`, `"2v2"`, `"3v3"`)
  - `TeamSize` (number, ej. 1, 2, 3)
  - `MaxPlayersPerTeam` (number)
  - `TotalPlayers` (number)
- **Fallback centralizado:** Si los Attributes no están definidos, se toman los valores por defecto configurados en `Config.Matchmaking.Modes[Mode]`.
- **Prohibido:** Condicionales hardcodeados (`if mode == "1v1" then ...`).

### 2. Modelo de Datos: `QueueSnapshot`
La cola se representa autoritativamente mediante un snapshot inmutable emitido por el servidor:
```luau
export type QueueSnapshot = {
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
  - `SoundJoinMusic` (música ambiental en loop mientras se espera en la plataforma): **Se reproduce de forma exclusiva y privada para el jugador que está ocupando la plataforma**. NO se clona en el `BasePart` del workspace para no molestar a jugadores cercanos; el servidor emite `Remotes.Matchmaking.PadMusic` y el cliente del ocupante reproduce el audio en `SoundService` localmente, deteniéndolo de inmediato al abandonar la plataforma o iniciar la partida.
- **Partículas dinámicas:** El template `ActivateParticle` se preserva intacto en `effects`. Se crea una instancia temporal `ParticleInstance_<Pad>` sobre el pad ocupado y se descubren y activan dinámicamente todos los `ParticleEmitter`s descendientes.
- **Beams dinámicos:** Los templates de Beams en `effects` se descubren dinámicamente, se clonan temporalmente (`BeamInstance_<Pad>_*`), se calcula su CFrame perimetral relativo al pad y se activan sus `Beam`s.
- **Material reactivo:** El pad cambia a `Enum.Material.Neon` al ocuparse y se restaura obligatoriamente a su `originalMaterial` guardado en memoria al desocuparse.
- **Independencia y concurrencia:** `Red` y `Blue` tienen instancias de efectos y sonidos completamente aisladas.

### 4. Interfaz de Usuario: `MatchmakingHUD` y `MatchmakingController`
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
