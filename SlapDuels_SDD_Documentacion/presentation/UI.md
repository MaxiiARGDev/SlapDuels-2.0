# Slap Duels 2.0 — Interfaz de usuario

> Especificación vigente. Define el comportamiento requerido; no certifica que la implementación ni los assets actuales hayan sido verificados en Studio.

Las interfaces permanentes existen en StarterGui y se editan en Studio. Los controllers enlazan PlayerGui, actualizan datos autorizados y animan propiedades temporales. No crean ni redefinen por código el diseño permanente.

| Interfaz | Responsable | Contrato |
|---|---|---|
| MatchmakingHUD | MatchmakingController | [Participantes reales, orden Red/Blue y visibilidad por ZoneId](../gameplay/MATCHMAKING.md) |
| MatchHUD | MatchController | Countdown, score y timer; datos filtrados por MatchId |
| PlayerHUD | PlayerHUDController | Estadísticas autorizadas de PlayerService, sin escritura cliente |
| SettingsGUI | SettingsController | [Toggle y slider de música, mouse y touch](AUDIO.md) |

Los valores visuales descritos abajo son referencias de diseño editables. El controlador debe respetar los valores base de Studio. Las animaciones y perfiles dinámicos se definen en [Game feel](GAME_FEEL.md).

StartCountdownFrame usa UICorner, UIStroke y UIGradient. Su Title muestra «LA PARTIDA COMIENZA» y CountdownLabel presenta los ticks y «¡COMIENZA!» en GO, con GothamBlack como fuente de referencia. El estilo verde del clímax se configura en el asset; la animación no redefine permanentemente sus colores ni fuentes.

### UI Real y Editable en StarterGui.MatchHUD

Toda la presentación visual del countdown y sus efectos existe como **Instances reales y editables directamente desde Roblox Studio**, sin construcción de UI por código. El código cliente manipula exclusivamente propiedades dinámicas (visibilidad, transparencia temporal y escala animada).

#### Estructura en StarterGui
```text
StarterGui
└── MatchHUD
    ├── StartCountdownFrame
    │   ├── Title
    │   ├── CountdownLabel
    │   │   ├── Shadow3D (Capa de relieve y extrusión 3D)
    │   │   └── UIGradient (Brillo y biselado)
    │   ├── UIScale
    │   ├── StartNumberHere (Marcador visual de origen del salto)
    │   └── EndNumberHere (Marcador visual de destino del salto)
    │
    └── StartEffects (Frame, Size=1,1, BackgroundTransparency=1)
        ├── FlashOverlay (Frame blanco, BackgroundTransparency=1)
        ├── PulseFrame (Frame centrado, BackgroundTransparency=1)
        │   ├── UIStroke
        │   └── UIScale
        ├── ShockwaveFrame (Frame centrado, BackgroundTransparency=1)
        │   ├── UIStroke
        │   └── UIScale
        └── UIScale
```

#### Regla de Editabilidad
- Colores (`BackgroundColor3`, `TextColor3`, `UIStroke.Color`), fuentes (`Font`), tamaños base (`TextSize`, `Size`), posiciones (`Position`, `AnchorPoint`), bordes (`Thickness`) y degradados (`UIGradient`) se configuran visualmente en Studio.
- El HUD scoreboard (`RedTeamFrame`, `BlueTeamFrame`) y el timer (`MatchTimerFrame`) se mantienen visibles en pantalla durante `PointRestartCountdown`, mientras que el score actualizado (`ScoreUpdated`) se refleja antes de que inicie la cuenta regresiva.

## Global Player HUD (`PlayerHUD`)
- **Independencia Total de MatchHUD:**
  - `PlayerHUD` es un `ScreenGui` permanente en `StarterGui` (replicado a `PlayerGui`).
  - `ResetOnSpawn = false` y `DisplayOrder = 10`.
  - Permanece visible tanto en el Lobby como durante la partida (`Playing`), sin interferir con `MatchHUD` ni con `MatchmakingHUD`.
- **Diseño Responsive:**
  - Anclado en `TopLeft` (`Position = UDim2.new(0, 16, 0, 16)`).
  - Controlado por `UISizeConstraint` (`MinSize = (220, 60)`, `MaxSize = (320, 80)`).
- **Componentes Nativos Editables:**
  - `ProfileCard`: Tarjeta horizontal moderna con fondo degradado azul/violeta oscuro (`UIGradient`, `UICorner`, `UIStroke`).
  - `Avatar`: Imagen circular con borde brillante cargada dinámicamente con `Players:GetUserThumbnailAsync(userId, HeadShot)`.
  - `PlayerName`: Muestra el `DisplayName` o `Name` del jugador.
  - `WinsLabel` & `LossesLabel`: Etiquetas informativas de récord con colores verde y rojo suave.
  - `CoinsContainer`: Contenedor elegante en la esquina superior derecha con icono dorado (`CoinIcon`) y cantidad de monedas (`CoinsLabel`).

### Controlador Cliente (`PlayerHUDController`)
- Ubicación: `src/client/Controllers/PlayerHUDController.luau`.
- Enlaza dinámicamente con `PlayerGui.PlayerHUD`.
- Escucha `Remotes.Player.DataUpdated` para actualizar los labels.
- **Animación:** Al incrementarse el valor de `Coins`, interpola visualmente el número mediante `TweenService` (0.25 segundos) y aplica un sutil efecto de escala/pulse en `CoinsContainer`.

---
