# Slap Duels 2.0 — Game feel

> Especificación vigente. Define el comportamiento requerido; no certifica que la implementación ni los assets actuales hayan sido verificados en Studio.

## Contrato de presentación

El servidor determina cada tick y transición. El cliente interpreta Phase y MatchId del countdown descrito en [Flujo](../gameplay/MATCH_FLOW.md); no adelanta la partida con un reloj local. MatchController anima los números y MatchStartEffectsController compone cámara, flash, blur y SFX. La trayectoria en curva C es el contrato visual vigente; reemplaza la antigua animación aislada de TextSize 84→72.

Los valores siguientes son perfiles de referencia para tuning. Las propiedades base y recursos permanecen editables en Studio; Config contiene parámetros de animación, no reemplazos del diseño permanente. La estructura del HUD está en [UI](UI.md).

### Match Start Presentation / Game Feel (Controlador de Efectos Cliente)
- **Controlador Dedicado:** `src/client/Controllers/MatchStartEffectsController.luau`.
- **Naturaleza Arquitectónica:** Responsabilidad exclusiva de **presentación en cliente**. No participa de la autoridad del servidor ni modifica las reglas de la partida ni la máquina de estados.
- **Sincronización Autoritativa:** Escucha el evento existente `Remotes.Match.Countdown` con la fase `"MatchStart"` o `"PointRestart"` en su payload (el label de transporte de compatibilidad es `"START_COUNTDOWN"`). El cliente reacciona en tiempo real a cada emisión del servidor sin adelantar conteos locales (`wait(1)`).
- **Aislamiento por MatchId:** Todo evento valida `extraData.MatchId` contra el match activo del cliente local, asegurando independencia total entre partidas concurrentes (1v1, 2v2 o 3v3).
- **Componentes y Efectos Integrados:**
  1. **Camera Shake Local:**
     - Enlazado con `RunService:BindToRenderStep` (`RenderPriority.Camera.Value + 1`).
     - Modela trauma decreciente cuadrático sin alterar permanentemente el CFrame base de la cámara (cero drift).
     - Desplazamiento dinámico en studs y rotación angular suave controlada por `math.noise`.
  2. **Screen Flash (`MatchHUD.StartEffects.FlashOverlay`):**
     - Destello blanco instantáneo que atenúa rápidamente hacia transparencia 1 mediante `TweenService`.
     - Intensidad creciente desde `0.90` (sutil en 5) hasta `0.18` (destello cegador en ¡COMIENZA!).
  3. **Blur Dinámico (`Lighting.MatchStartBlur`):**
     - Desenfoque efímero en `Lighting` que sube de 0 al tamaño objetivo (`Size` 2 en 5 hasta 10 en ¡COMIENZA!) y desvanece de inmediato.
  4. **Pulse & Shockwave (`MatchHUD.StartEffects.PulseFrame` / `ShockwaveFrame`):**
     - Anillos circulares con `UIStroke` que se expanden hacia afuera y desvanecen simulando ondas expansivas.
  5. **Audio Feedback (`SoundService.MatchStartSFX`):**
     - Dispara sonidos reales y editables: `CountdownTick` (5..3), `CountdownHeavy` (2), `CountdownFinal` (1), y combinación explosiva `StartWhoosh` + `StartImpact` en ¡COMIENZA!.
- **Perfiles de Intensidad Configurables (`Config.StartCountdownEffects`):**
  - Centralizados en `src/shared/Config.luau` con parámetros para studs de sacudida, grados de rotación, duración, transparencias, blur, escalas y volúmenes para tuning continuo.
- **Política de Limpieza (Cleanup):**
  - Cancelación inmediata de todos los tweens, hilos y sacudida de cámara ante desconexión, abandono, fin de partida (`Ending`, `ReturningToLobby`, `Waiting`) o tras la culminación del clímax al pasar a `Playing`.
  - Garantiza que `BlurEffect.Enabled = false`, `Blur.Size = 0` y `FlashOverlay.BackgroundTransparency = 1` sin residuos visuales en pantalla.

---

#### Animación en Curva "C" (Salto Parabólico y Rebote)
- **Marcadores de Referencia:** `StartNumberHere` (esquina superior derecha) y `EndNumberHere` (centro de pantalla) determinan la trayectoria de forma 100% editable desde Studio.
- **Trayectoria en Arco / Onda "C":** Se interpola la posición mediante una curva de Bézier cuadrática que abre hacia la derecha y barre por debajo antes de curvar hacia el centro.
- **Relieve 3D Chiseled:** `CountdownLabel` cuenta con una capa inferior `Shadow3D` desplazada con trazo oscuro y degradado vertical, logrando profundidad y volumen tridimensional.
- **Ciclo Secuencial ("Entra un número, rebota, se va, entra el siguiente"):**
  1. **Aparición:** El número nace en `StartNumberHere` con escala pequeña (`0.35`), inclinación de rotación (`24°`) y transparencia.
  2. **Vuelo:** Desciende y curva hacia la izquierda agrandándose hasta `1.28` mientras rota hacia `-8°`.
  3. **Aterrizaje con Rebote (Bounce):** Impacta en `EndNumberHere`, la escala rebota elásticamente (`1.30 → 1.00` con `Back.Out`) y la rotación se estabiliza en `0°`.
  4. **Pausa de Lectura:** Se mantiene nítido en el centro durante ~0.32 segundos.
  5. **Salida Dinámica:** Continúa su impulso hacia abajo-izquierda desvaneciéndose antes de la llegada del próximo número.
  6. **Clímax en ¡COMIENZA!:** Aterriza directamente en el centro con la máxima escala expansiva, destello y ondas de choque.

#### Perfiles de Game Feel (`Config.PointRestartCountdownEffects`)
- Optimizado para ser más ágil e intenso que el inicio de la partida:
  - **3:** Sacudida media (`0.25 studs`, `1.0°`), flash leve (`0.80`), blur (`3.5`), sonido `CountdownTick`.
  - **2:** Sacudida fuerte (`0.40 studs`, `1.5°`), flash medio (`0.65`), blur (`5.0`), sonido `CountdownHeavy`.
  - **1:** Sacudida muy fuerte (`0.55 studs`, `2.0°`), flash intenso (`0.50`), blur (`7.0`), sonido `CountdownFinal`.
  - **¡COMIENZA!:** Clímax rápido (`0.85 studs`, `2.8°`), destello principal (`0.20`), blur (`9.0`), onda expansiva `Shockwave`, combinación `StartWhoosh` + `StartImpact`.

---

Los efectos por punto y su cámara local se describen en [Point effects](POINT_EFFECTS.md). La física común del festejo pertenece al sistema de ronda/ragdoll; elegir un cosmético no cambia su fuerza, radio ni ventajas competitivas.
