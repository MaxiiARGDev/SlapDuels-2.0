# Slap Duels 2.0 — AUDIO

> Este documento conserva contenido del `GAME_SDD.md` original suministrado, redistribuido por dominio para reducir el contexto necesario para agentes de IA.

## 12. Music System (Sistema Centralizado de Música Local)

El sistema de música de *Slap Duels 2.0* es una arquitectura exclusivamente de **cliente (local-only)**, desacoplada por completo del servidor y de los sistemas de sonido de efectos (SFX).

### 12.1 Principios Arquitectónicos
1. **100% Local por Jugador:** Cada cliente computa y reproduce su propia banda sonora según su estado lógico de juego. No existen `RemoteEvents` en el servidor dedicados a sincronizar música ni llamadas a `FireAllClients` para reproducción sonora.
   - *Ejemplo simultáneo:* Jugador A (Lobby) escucha `LobbyMusic`; Jugador B (en cola) escucha `MatchmakingMusic`; Jugador C (en duelo) escucha `FactoryMusic`.
2. **Sin Dependencia de Parts Físicos:** El estado musical no se activa tocando o habitando `Parts` en Workspace (como `LobbyMusicPart` o `ArenaMusicPart`). Se gobierna estrictamente por la **máquina de estados lógica** del juego y los controllers de cliente.
3. **Separación Estricta Music vs SFX:**
   - No modifica `SoundService.Volume` global ni volúmenes maestros de otros elementos.
   - Totalmente independiente de `MatchStartEffectsController` (ticks, whoosh, impacts).
   - Independiente de `MatchmakingFeedbackService` (`SoundJoin`, `SoundLeave`, partículas, beams).
   - Independiente de `PointFeedbackService` y SFX de combate (`Slap`, `Hit`, `Elimination`).
4. **Assets Centralizados y Editables en Studio:**
   - La jerarquía canónica reside en `SoundService.Music`:
     ```text
     SoundService
     └── Music
         ├── Lobby (Sound)
         ├── Matchmaking (Sound)
         └── Arenas (Folder)
             ├── Factory (Sound)
             ├── Inferno (Sound)
             └── ArenaDefault / Default (Sound, opcional)
     ```
   - Las propiedades (`SoundId`, `Volume`, `Looped = true`, `PlaybackSpeed`) se configuran en Studio. El código Luau **jamás hardcodea SoundIds**.

### 12.2 Responsabilidades de `MusicController`
El único controlador responsable de la música es:
`src/client/Controllers/MusicController.luau`

- **Gestión de Estados:** `Lobby`, `Matchmaking`, `Arena` (extensible a `Victory`, `Defeat`, `Draw`).
- **Cross-Fade Suave con TweenService:** Desvanece a 0 el track previo y eleva el nuevo track con curvas `Quad Out`.
- **Cancelación de Tokens (`_transitionToken`):** Cualquier cambio de estado incrementa un token mono-atómico que invalida y cancela inmediatamente transiciones anteriores, impidiendo tracks duplicados, hilos huérfanos o superposiciones sonoras bajo cambios rápidos.
- **Volumen Proporcional del Usuario:**
  $$\text{FinalVolume} = \text{StudioBaseVolume} \times \text{UserMusicVolume} \quad (\text{si } \text{MusicEnabled} = \text{true}, \text{ sino } 0)$$
- **Fallback Tolerante a Fallos:** Si un mapa no tiene un `Sound` correspondiente en `SoundService.Music.Arenas`, busca `ArenaDefault`/`Default` o desvanece a silencio sin generar errores ni romper la partida.

### 12.3 Integración con el Flujo Existente
```mermaid
graph TD
    Bootstrap["ClientBootstrap"] -->|Init/Start| MusicController["MusicController (PlayLobby)"]
    QueueSnap["MatchmakingController (QueueSnapshot)"] -->|Entrar en Cola| MM["MusicController:PlayMatchmaking()"]
    QueueSnap -->|Salir de Cola (sin match)| Lobby1["MusicController:PlayLobby()"]
    MatchCtrl["MatchController (StateChanged)"] -->|MapLoading / StartCountdown (Participante)| Arena["MusicController:PlayArena(SelectedMap)"]
    MatchCtrl -->|ReturningToLobby / Waiting| Lobby2["MusicController:PlayLobby()"]
```

- **Matchmaking (`MatchmakingController`):** Detecta cuando el jugador local es participante de un `QueueSnapshot` y transiciona hacia `PlayMatchmaking()`. Al cancelar la cola o salir de la plataforma sin emparejar, transiciona de vuelta a `PlayLobby()`.
- **Arenas (`MatchController`):** Al pasar a `MapLoading`, extrae `extraData.SelectedMap` (ej. `"Factory"`) y, si el jugador local forma parte del encuentro (`IsParticipant() == true`), invoca `PlayArena("Factory")`. Al finalizar la partida y retornar al lobby (`ReturningToLobby` o `Waiting`), invoca `PlayLobby()`.

### 12.4 Configuración de Usuario (Settings API)
- `MusicController:SetMusicEnabled(enabled: boolean, fadeDuration: number?)`
- `MusicController:SetMusicVolume(volume: number, fadeDuration: number?)`
- `MusicController:IsMusicEnabled(): boolean`
- `MusicController:GetMusicVolume(): number`

### 12.5 Extensibilidad Futura
La arquitectura queda preparada para añadir sin refactorizaciones estructurales:
- `Victory` / `Defeat` / `Draw` stings o música tras finalizar la partida.
- `FinalPoint` / Match Point música de alta tensión.
- `DynamicIntensity` (variaciones de pitch, ecualizador o layers rítmicos basados en la vida/tiempo restante).

### 12.6 Distinción y Clasificación: SoundJoinMusic vs SFX de Matchmaking
- **Clasificación del Asset:** Tras auditoría en `Workspace.ZoneMatchmaking.1v1.effects.<Team>`, se constató que `SoundJoinMusic` tiene una duración de `60.33` segundos y un loop continuo. Se clasifica formalmente como **MÚSICA** y no como SFX.
- **Autoridad Única:** Siguiendo la regla de que `MusicController` es la única autoridad sonora para música de fondo, el servidor (`MatchmakingFeedbackService`) no emite eventos para reproducir pistas de música independientes (`PadMusic`). La banda sonora de matchmaking es gestionada exclusivamente por `MusicController:PlayMatchmaking()`.
- **Preservación de SFX Reales:** Los sonidos puntuales de ocupación (`SoundJoin`, 0.38s) y desocupación (`SoundLeave`, 0.38s), así como partículas, Beams y Neon, continúan operando a través de `MatchmakingFeedbackService`.

---


## 13. Music Settings (Configuración de Audio del Cliente)

### 13.1 Visión General y Propósito
El sistema de **Music Settings** permite al jugador personalizar su experiencia auditiva en tiempo real mediante una interfaz gráfica dedicada (`SettingsGUI`) controlada por `SettingsController`.
Esta configuración opera de manera **100% local** en el cliente y actúa **EXCLUSIVAMENTE sobre el canal de música**, garantizando que los efectos de combate, UI, matchmaking, feedback de puntos y transiciones de arena permanezcan audibles e inalterados.

### 13.2 Arquitectura y Separación de Responsabilidades
El diseño respeta estrictamente el principio de autoridad única:
```mermaid
graph TD
    UI["SettingsGUI (PlayerGui)"] -->|Interacciones (Touch / Click / Drag)| SettingsController["SettingsController (Cliente)"]
    SettingsController -->|SetMusicEnabled / SetMusicVolume| MusicController["MusicController (Única Autoridad Musical)"]
    MusicController -->|Tween Volume / Stop / Play| SoundServiceMusic["SoundService.Music (Canal Musical)"]
    SFX["SFX / Combat / UI / Matchmaking"] -.->|INDEPENDIENTE| SoundServiceSFX["SoundService (Canal SFX - Intacto)"]
```

- **`SettingsController`:** Responsable exclusivo de la interfaz de usuario, captura de inputs (mouse, touch móvil), actualización visual del estado (porcentaje, perilla, toggle) y sincronización con el controlador de música. **No reproduce ni manipula instancias de `Sound` directamente.**
- **`MusicController`:** Única autoridad musical. Almacena las variables de estado `_musicEnabled` y `_musicVolume`, aplicando la fórmula de volumen proporcional (`BaseVolume * UserVolume`) a la pista actualmente en reproducción y a cualquier pista futura que inicie durante la sesión.

### 13.3 Variables de Configuración Local
- **`MusicEnabled` (boolean):**
  - Valor inicial: `true`.
  - Cuando es `false`: Aplica un *fade out* suave sobre la pista activa y la detiene. Si el estado musical cambia (ej. el jugador entra a una partida en Factory mientras la música está desactivada), `MusicController` registra el nuevo estado pero no emite sonido.
  - Cuando se reactiva a `true`: Detecta el estado contextual actual del jugador (`Lobby`, `Matchmaking` o el mapa activo en `Arena`) y ejecuta un *fade in* de la música correspondiente.
- **`MusicVolume` (number, rango 0.0 a 1.0):**
  - Valor inicial: `1.0` (100%).
  - Determina el multiplicador de volumen proporcional. Se escala en porcentaje entero legible (0% a 100%).
  - Al arrastrar el slider continuamente, se aplica `fadeDuration = 0` para una respuesta en tiempo real sin latencia ni saturación de tweens; al soltar o hacer click discreto se aplica un micro-fade de 0.1s.
  - El volumen se preserva automáticamente a través de cambios de mapa y fases (Lobby → Matchmaking → Factory → Lobby) sin que el Settings UI necesite reaplicarlo manualmente.

### 13.4 Separación Estricta: Music vs SFX
El sistema de configuración de música **no toca en ningún momento**:
- `SoundService.Volume` (volumen maestro del juego permanece intacto).
- Sonidos de matchmaking (`SoundJoin`, `SoundLeave`).
- Sonidos de cuenta regresiva y efectos de inicio (`MatchStartSFX`, beeps de conteo).
- Sonidos de combate y bofetadas (`Slap`, ragdoll, impactos).
- Efectos de puntos (`PointImpact`, `PointCameraFX`).
- Sonidos de interfaz de usuario (clicks y notificaciones).

### 13.5 Soporte Multiplataforma (PC, Móvil, Touch)
- El `MusicSlider` implementa listeners para `UserInputService.InputBegan`, `InputChanged` y `InputEnded`, soportando tanto `MouseButton1` / `MouseMovement` como gestos continuos de `Touch`.
- Admite tanto el click puntual en cualquier parte de la barra (`Track`) como el arrastre fluido de la perilla (`Knob`).
- El valor del slider se calcula matemáticamente mediante:
  $$\text{Volume} = \text{math.clamp}\left(\frac{\text{InputPosition.X} - \text{SliderAbsolutePosition.X}}{\text{SliderAbsoluteSize.X}}, 0, 1\right)$$
- El botón de toggle (`MusicToggle`) utiliza un tamaño táctil accesible (mínimo 44px de altura) y comunica su estado mediante texto explícito (`ON` / `OFF`) y contraste cromático.

### 13.6 Persistencia y Ciclo de Vida
- **Estado de Sesión en Memoria:** Durante la Fase 2, las preferencias de audio se conservan en memoria durante toda la sesión del cliente. Al cerrar y reabrir el menú de ajustes, la interfaz consulta y refleja con exactitud el estado actual (`MusicController:IsMusicEnabled()` y `MusicController:GetMusicVolume()`).
- **Ausencia de DataStore:** No se utiliza `DataStoreService` ni se alteran las estructuras de `PlayerDataService`/`PlayerService` (monedas, victorias, etc.), evitando escrituras innecesarias en el servidor para preferencias que son exclusivamente locales del cliente.
- **Persistencia Futura:** La persistencia entre diferentes sesiones de juego queda planificada como una fase posterior mediante un almacenamiento de preferencias locales (ej. servicio centralizado de perfil cliente/preferencias).

---
