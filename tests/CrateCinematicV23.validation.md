# Crate Opening V2.3 — entrega

Implementado el 2026-10-19 en repositorio y **Studio Edit**, lugar SlapDuels 2.0, PlaceId 107328891970677. No se ejecutaron Play, Run, Test, Local Server ni pruebas con personajes. La apariencia, legibilidad, intensidad y sonido requieren aceptación manual del desarrollador.

## Comportamiento implementado

**Prompt local.** El comprador adquiere `StandPromptVisibility` después de obtener CameraLease, antes de cerrar Shop. Oculta los ProximityPrompts del stand seleccionado mediante Enabled local, incluyendo los añadidos durante la apertura. Guarda Enabled previo y observa reactivaciones externas para mantener el ocultamiento. `_stop` restaura y desconecta, tanto en final como cancelación, muerte, error o pérdida de cámara. El prompt permanece oculto hasta terminar toda la secuencia, incluida la segunda mitad del Outro. Espectadores no adquieren el lease. No hay remotes nuevos ni cambios en validación/interacción del servidor.

**Solo premio 3D.** `CinematicConfig.RewardOverlayByMode.StandCinematic=false` impide llamar a Presenter.Show en este flujo. El inicio oculta preventivamente RewardOverlay. El HUD, Presenter y sus componentes no se destruyeron. El modelo obtenido, RewardBillboard, nombre y variación mantienen la presentación y el resultado autoritativo existentes. Spin conserva su ruta anterior; no se modificó su implementación.

**Cierre/apertura.** Dos Frames físicos editables, ShutterTop y ShutterBottom, cierran desde arriba y abajo hasta cubrir completamente la pantalla. El cierre desacelera con potencia 3, la apertura con potencia 4. Durante la presentación quedan barras discretas de 7,5% por lado. En Outro se cierra, se devuelve/cede la cámara a mitad de etapa y después se abre sobre la vista del jugador. Si el frame salta el instante exacto de retorno, se fuerza cobertura completa ese frame. La cancelación oculta inmediatamente los shutters, sin tareas retardadas que puedan interferir con otra apertura. Se conserva Flash; el antiguo fade plano dejó de conducir esta transición.

**Cámara.** Se conserva el CameraPoint artístico como referencia y CameraLease como propietario. Tras el cierre, comienza elevada 7 studs, 2 studs hacia atrás y mirando 12 studs más alto; desciende durante 1,8 segundos, con pequeño overshoot suave, y converge al encuadre del stand. Growth/Shake añaden tensión progresiva. Flash produce un impulso amortiguado de 0,85 segundos, que continúa brevemente sobre la revelación del premio y desaparece. Los máximos por defecto son 0,2 studs de traslación y 0,8 grados, sin ruido aleatorio ni acumulación por FPS. FocusResponse y acercamiento conservan la suavidad del encuadre final. El FOV está limitado entre 35 y 100.

**Duraciones y otras reglas.** No cambió `Shared.SlapCrates.OpeningConfig` ni OpeningTimeline: total **10,5 segundos**, mismas etapas, cooldown personal de cinco segundos y límite de reserva. Se preservó CharacterVisibility V2.2: ocultamiento únicamente comprador y liberación después de la cámara. No se modificaron economía, precios, probabilidades, stock, inventario, compra, recompensa ni exclusividad.

## Configuración editable

`StarterPlayer.StarterPlayerScripts.CrateOpening.CinematicConfig` / `src/client/CrateOpening/CinematicConfig.luau`:

- `HideStandPrompt`.
- `RewardOverlayByMode.StandCinematic`; Spin sigue controlado por su implementación existente.
- `Transition`: Letterbox, ClosePower, OpenPower y OutroHandoff (fracción de etapa).
- `Camera`: IntroDuration, IntroHeight, IntroBack, IntroLookHeight, IntroFov, Bounce, tensión, impacto, frecuencia, duración, límites, enfoque y acercamiento.
- `Audio`: nombres de cues y volumen local.

No cambiar arbitrariamente OutroHandoff a 0/1 ni duraciones a cero: son parámetros de autoría, no inputs del cliente. Las duraciones de etapas siguen centralizadas en OpeningConfig; no se duplicaron en este config.

## Recursos instalados y pendientes

- `StarterGui.CrateOpeningHUD.ShutterTop`: Frame negro, anclado arriba, ZIndex 120, oculto en Edit.
- `StarterGui.CrateOpeningHUD.ShutterBottom`: Frame negro, anclado abajo, ZIndex 120, oculto en Edit.
- `Workspace.CrateStands.MainCrateStand.PresentationTemplate.Effects.FXAnchor.WhooshClose`: Sound, **SoundId pendiente**.
- Misma ruta `WhooshOpen`: Sound, **SoundId pendiente**.

Asignar los dos SoundIds en esas plantillas; el controlador clona/reproduce los cues privadamente en SoundService y los limpia al finalizar. Close se dispara en Intro y Outro; Open en CameraReveal y tras devolver la cámara. El volumen lo define CinematicConfig.Audio.Volume. Los sonidos de etapas que ya habías configurado conservan sus IDs/propiedades. No se afirma haber escuchado los nuevos whooshes.

## Preservación y Rojo

Se serializaron **antes de editar** stand y HUD en `tests/assets/backups/CrateCinematicV23/`, junto con el controlador previo y hashes del árbol src. Tu stand actual tenía 171 descendientes y SoundIds más recientes que los snapshots V2.1. Se tomó como fuente el objeto actual de Edit; no se importó el snapshot antiguo.

Una comparación posterior contra copias deserializadas sin Parent comprobó **197 instancias originales y 1.090 propiedades seleccionadas**, sin diferencias. Comprende geometría, colores, atributos originales, UI y sonido, entre otras propiedades. Los clones de verificación fueron destruidos. No es una comparación de todas las propiedades posibles del motor. Se añadieron solamente dos Sounds al stand y dos Frames al HUD.

Snapshots finales exportados desde Edit, hashes comprobados contra archivos y DataModel:

| Recurso | Descendientes | Bytes | SHA-256 |
|---|---:|---:|---|
| MainCrateStand | 173 | 52463 | b1e65dfeb934508dcb4d586c0753179e165f8164202933845df360968672f69a |
| CrateOpeningHUD | 26 | 10912 | 569d148832b054438e5cee40fbbe138f41765e29269d82281c4514042bbaf935 |

`default.project.json` apunta ahora a estas dos copias V2.3, sin overrides de hijos que creen duplicados. Se mantuvieron snapshots y respaldos anteriores. SAFE sigue siendo la opción habitual para scripts: no pisa arte. Nuevas modificaciones físicas posteriores en Studio requieren volver a exportar antes de un full sync. No se guardó, cerró ni publicó el lugar; guardarlo normalmente desde Studio conserva los cambios Edit en disco.

## Archivos de implementación exactos

Modificado:

- `src/client/Controllers/CrateStandCinematicController.luau`.
- `default.project.json`.
- `studio-safe.project.json` (regenerado, 131 scripts).

Creados:

- `src/client/CrateOpening/CinematicConfig.luau`.
- `src/client/CrateOpening/CinematicMotion.luau`.
- `src/client/CrateOpening/CinematicTransition.luau`.
- `src/client/CrateOpening/StandPromptVisibility.luau`.
- `src/assets/CrateCinematicV23/MainCrateStand.rbxm`.
- `src/assets/CrateCinematicV23/CrateOpeningHUD.rbxm`.
- `src/assets/CrateCinematicV23/manifest.json`.

Fixtures modificados:

- `tests/tools/run_ability_unit_tests.py`.
- `tests/SlapCratesV2.extension.luau`.
- `tests/CrateVisibilityV22.spec.luau`.

Pruebas nuevas:

- `tests/CrateCinematicV23.extension.luau`.
- `tests/CrateCinematicV23.spec.luau` (compuesto).
- `tests/tools/crate_cinematic_v23_spec.py`.
- `tests/tools/validate_crate_cinematic_v23.py`.

También se regeneraron los specs compuestos `tests/SlapCratesV2.spec.luau`, `tests/CrateOddsV13.spec.luau` y `tests/CrateVisualV21.spec.luau`. El inventario completo de evidencia/respaldos está en `tests/CrateCinematicV23.files.json`.

## Verificaciones

| Verificación | Resultado |
|---|---|
| Cinemática + ciclo V2.2 aislado | PASS: 1.931 aserciones, incluidas 1.803 comprobaciones de límites sobre 601 muestras temporales |
| Regresión cajas/V2.1 aislada | PASS: 1.172 aserciones |
| Economía / combate / habilidades / registry / Shop | PASS: 30 / 150 / 164 / 89 / 86 aserciones |
| Compilación Luau | PASS: 131 scripts runtime + spec V2.3 |
| `rojo build default.project.json` | PASS |
| `rojo build studio-safe.project.json` | PASS |
| Jerarquías del build | PASS: shutters, overlay conservado, whooshes, conteos y nombres sin duplicados |
| `git diff --check` | PASS; advertencias LF/CRLF existentes |
| Integridad src anterior | Solo cambió el controlador previsto; otros archivos src anteriores mantienen sus hashes |
| Sincronización Edit | PASS: cinco Sources y fuentes del editor coinciden por SHA; sin módulos duplicados |
| Prueba visual, audio y multicliente real | **NOT RUN** |

La primera aserción exacta del final del impulso se ajustó a una tolerancia de punto flotante; la ejecución completa posterior pasó. No se atribuye PASS funcional a estos tests. No hubo commits, push, publicaciones ni escrituras cloud.
