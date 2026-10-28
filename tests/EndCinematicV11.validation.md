# End Cinematic V1.1 — informe de implementación y regresión

Fecha: 15 de octubre de 2026. Alcance: desarrollo y preview local de Studio; sin integración con partidas.

## Auditoría previa y conservación

V1 concentraba en EndCinematicController: validación y orquestación (Play), cámara (_travel y restauración en Stop), transición (_transition/_slide), creación y colocación de rigs (_rig), caminata/Animator (_walk), emisores y audio (_effects), HUD generado en cada Play (_hud) y gestión de recursos (Stop).

Estado compartido anterior: ejecución _run/_serial, listas Resources/Connections/Tweens/Tracks/Sounds/Rigs, cámara previa, HiddenHUDs y contadores CameraDone/WalksDone. V1.1 mantiene un único estado por PlaybackId; los módulos no almacenan ejecuciones globales ni se requieren entre sí. Reciben run; run:IsAlive() y run:Tween() pertenecen al orquestador.

La fuente V1 previa a este trabajo se conserva en tests/fixtures/EndCinematicControllerV1.txt. No se cambió el respaldo externo ni se descartaron cambios locales.

La auditoría física actual reemplaza los datos históricos de V1:
- Workspace.EndCinematic es Folder.
- TransCamera contiene tres Parts: CameraCheck-v1, CameraCheck-v2 y CameraCheck-Only1V1.
- CameraCheck-Only1V1 ya estaba creada: posición (521.5717163, 53.8702774, 41.6956100); se usa su CFrame completo, con inclinación original.
- Cinco SlotPlayer_1–5 ya estaban orientados hacia la cámara al iniciar esta tarea. No se alteraron sus CFrames.
- DropT1/DropT2 contienen diez emisores, Rate=99, todos Enabled=false. No hay que corregir propiedades originales.
- AllSoundsPlay ya contiene seis sonidos configurados por el desarrollador: Confetti y Firework en bucle, Victory one-shot en cada Drop. No se inventaron ni editaron IDs.
- No existía StarterGui.EndCinematicHUD.
- PointCameraFX y MatchStartEffectsController escriben cámara en las partidas. La preview mantiene su restricción Studio/sin MatchId y se detiene si comienza una partida; no se alteraron esos controladores.

## Arquitectura y archivos

- src/client/Controllers/EndCinematicController.luau: orquesta y valida; API Initialize, Play, Stop, IsPlaying, Destroy. Mantiene PlaybackId, cancelación y registro de recursos.
- src/client/EndCinematic/Modules/EndCinematicCamera.luau: Resolve, Prepare, Play, Cleanup. Selección física, interpolación única, giro, rebote, llegada exacta y restauración.
- EndCinematicTransition.luau: Prepare, Play(cerrado/abierto), Cleanup. Se extrajo el algoritmo V1 sin cambiar tamaños, posiciones, ángulo, easing o duraciones.
- EndCinematicAvatars.luau: Prepare y Cleanup. Apariencia HumanoidDescription, rigs R15, limpieza de scripts/Tools, orientación y apoyo por slot, límites del comienzo de caminata.
- EndCinematicAnimations.luau: Play y Cleanup. Desfase, movimiento provisional, Animator cuando se configure WalkAnimationId.
- EndCinematicParticles.luau: Prepare/Play/Stop/Cleanup. Copias locales sin audio, continuo o burst según Rate, sin alterar propiedades artísticas originales.
- EndCinematicAudio.luau: Prepare/Play/Stop/Cleanup. Copias locales de sonidos, conserva Looped, controla solo sonidos propios, registro para no reiniciarlos.
- EndCinematicHUD.luau: Resolve/Prepare/Play/Cleanup. Usa la GUI existente en PlayerGui; no usa Instance.new ni reconstruye el diseño.
- src/shared/EndCinematicConfig.luau: única configuración de todos los subsistemas; valores visuales V1 conservados.
- src/client/EndCinematicPreview.client.luau: mismo panel ampliado a 1v1, 2v2, 3v3, XvX de cinco ganadores, victoria/derrota, reinicio y detener.
- src/ui/EndCinematicHUD.rbxmx: diseño persistente y editable.
- default.project.json: vínculo del rbxmx en StarterGui; ignoreUnknownInstances para conservar otros HUD.
- tests/fixtures/EndCinematicControllerV1.txt: referencia anterior.
- Este informe.

Los subsistemas no están dentro de Controllers para que el bootstrap no los interprete como controladores autónomos.

## HUD físico y fidelidad

StarterGui.EndCinematicHUD está presente en modo Edit después de detener Play. Tiene Enabled=false, ResetOnSpawn=false, IgnoreGuiInset=true y DisplayOrder=9990.

Jerarquía:
- MainFrame (CanvasGroup)
  - Title, Subtitle, Score, ReturnButton, RematchButton, RematchCounter
  - WinnerLine (Frame)
    - WinningTeam y WinnerNames (TextLabels)
    - Layout (UIListLayout horizontal)
  - UISizeConstraint, UICorner, UIStroke
- UIEffects (Folder)

Conserva panel de 700x265 máximo, tamaño relativo 0.9, posición (0.5, 0.96), colores, fuente, borde, esquinas y fade de V1. Equipo/nombres se mantienen en la misma línea visual; ahora tienen TextLabels separados. Se ajusta el tamaño del texto al ancho disponible. No se probó un dispositivo móvil real.

En Play Roblox replica el HUD de StarterGui a PlayerGui una vez. La misma instancia y sus 17 descendientes se reutilizaron entre reproducciones. El módulo solo modifica textos, estado y transparencia. La persistencia recuperable está en el rbxmx versionable y su vínculo Rojo; no se publicó ni se guardó el place en cloud. Ediciones posteriores en Explorer deben exportarse al rbxmx para mantenerse al reconstruir con Rojo.

## Cámara y configuración

Camera.StartPart = CameraCheck-v1.
Camera.Destinations:
- 1v1: CameraCheck-Only1V1.
- 2v2 y 3v3: CameraCheck-v2.
- Default, incluido XvX: CameraCheck-v2.

Mode explícito prevalece sobre la cantidad de ganadores. Compatibilidad documentada para payload antiguo sin Mode: un ganador usa 1v1; varios usan XvX. Falta de cámara 1v1 devuelve CameraDestinationMissing:CameraCheck-Only1V1, sin fallback silencioso.

Valores conservados: cierre 0.65 s, hold 0.35 s, apertura 0.65 s, ángulo 12°, viaje 3.5 s, giro 5°, rebote 0.08 studs/0.35 s, caminata 2.5 studs/2.2 s, demora 0.45 s y stagger 0.12 s, fade HUD 0.45 s. WalkAnimationId sigue vacío. El encuadre 1v1 usa la nueva referencia, no cambios de estos parámetros.

## Evidencia de ejecución

Studio: PersistenceEnvironment=Studio, PersistenceProvider=InMemory, WritesToCloud=false.
GameId=10769217377; PlaceId=107328891970677.

Previews completas:
- 1v1: un rig, una caminata, HUD victoria, destino cercano exacto.
- 2v2: dos rigs y dos caminatas, HUD derrota y REVANCHA (0/4), destino amplio exacto.
- 3v3: tres rigs y tres caminatas, destino amplio exacto.
- XvX: cinco rigs y cinco caminatas, HUD victoria y REVANCHA (0/10), destino amplio exacto.
- XvX explícito con un ganador: conservó cámara amplia, sin inferir 1v1.

Datos adicionales observados:
- AudioCopies=6, Loops=4, OneShots=2; cero originales reproduciéndose.
- Dos llamadas adicionales Audio.Play conservaron exactamente seis registros, sin copias extra.
- Diez emisores temporales y cero originales activos; los temporales se desactivaron al terminar cámara.
- Rebote medido: desplazamiento máximo muestreado de 0.075207844 studs; llegada final exacta.
- SawInitialV1=true; CancelledDuringMovement=true; carpeta removida.
- Cámara restauró CameraType y CameraSubject previos (se conserva también CFrame/FOV en el código).
- Tras Stop: Folders=0, TransitionGone=true, HUDHidden=true, SoundsDestroyed=true, Playing=false.
- HUD en Edit tras Stop: 17 descendientes, deshabilitado, cámara cercana presente.

## Matriz individual

PASS automático significa ejecución y medición, no aprobación visual del movimiento. Las capturas permiten verificar composición estática y textos; no equivalen a una grabación.

| Caso | Automático / funcional | Observación visual |
|---|---|---|
| A. Apariencia V1 | PASS: parámetros/diseño conservados | PASS en capturas de composición y HUD; no comparación píxel a píxel |
| B. Transición diagonal | PASS: funciones V1 extraídas sin cambio visual | PASS cobertura cerrada en captura; identidad del movimiento completo pendiente de revisión humana |
| C. Inicio v1 | PASS: SawInitialV1=true | NOT RUN captura dedicada de inicio |
| D. Destino 1v1 | PASS: Only1V1 exacto | PASS encuadre cercano capturado |
| E. Destino 2v2 | PASS: v2 exacto | PASS encuadre amplio capturado |
| F. Destino 3v3 | PASS: v2 exacto con tres rigs | NOT RUN captura dedicada |
| G. Destino XvX | PASS: v2 exacto con cinco rigs; también uno explícito | PASS encuadre amplio capturado |
| H. Llegada exacta | PASS: igualdad CFrame con referencia | No se deduce exactitud de captura |
| I. Rebote | PASS: muestra de 0.0752 studs y regreso exacto | NOT RUN revisión en vídeo |
| J. Un ganador | PASS: rig/caminata completa | PASS captura |
| K. Dos ganadores | PASS: dos rigs/caminatas | PASS captura |
| L. Cinco ganadores | PASS: cinco rigs/caminatas | PASS captura |
| M. Movimiento provisional | PASS: contadores completados, poses finales | NOT RUN revisión continua de caminata |
| N. Apariencia | PASS: HumanoidDescription aplicado | PASS accesorios/ropa del avatar local visibles |
| O. Emisores sin duplicación | PASS: diez locales, cero originales activos | PASS confeti durante preview; sin confeti al finalizar |
| P. Audio independiente | PASS: seis copias, deduplicación, originales intactos, limpieza | NOT RUN escucha humana |
| Q. HUD en StarterGui | PASS: presente en Edit tras detener Play | Explorer editable; comprobación por DataModel |
| R. HUD sin reconstrucción | PASS: misma instancia y 17 descendientes | PASS composición preservada |
| S. Victoria/derrota | PASS textos correctos | PASS ambas capturas |
| T. Volver | PASS: clic real mediante entrada del cliente, cierra y limpia | Botón observado; cierre comprobado |
| U. Revancha deshabilitada | PASS: Active=false; contador y PRÓXIMAMENTE | PASS capturas |
| V. Stop repetido | PASS | Sin overlay residual |
| W. Previews consecutivas | PASS | Capturas 1, 2 y 5 |
| X. Cancelar movimiento | PASS durante viaje real | No imagen negra residual |
| Y. Sin residuos | PASS: cero carpetas, sonidos destruidos; tweens cancelados/destruidos | HUD persistente oculto |
| Z. Servicios sin modificación | PASS: SHA-256 de todos los archivos de src/server/Services idéntico al inicio | No aplica |
| AA. Persistencia intacta | PASS: hashes; InMemory/WritesToCloud=false | No aplica |
| AB. Build | PASS | No aplica |
| AC. Diff check | PASS | No aplica |

También: AlreadyPlaying rechazado; Destroy es idempotente y permite Initialize posterior; cámara cercana ausente simulada en cliente y nombre restaurado inmediatamente; payload sin Mode comprobado. No se tocó la geometría para probarlo.

## Recursos, problemas y límites

Stop invalida PlaybackId, desconecta callbacks, cancela/destruye tweens y delega Cleanup. Audio limpia antes de partículas; los rigs y carpeta final se destruyen. Los resultados tardíos de generación de avatar se descartan. HUD físico no se destruye y los demás HUD recuperan Enabled. No hay segundo administrador global.

El Output no reportó errores de EndCinematic. Persistió el aviso ajeno preexistente de swoosh.wav no aprobado. Los IDs actuales fueron respetados; no se declara validada la escucha o mezcla de audio por una persona.

No se probaron dispositivos móviles reales ni sincronización multicliente; la reproducción es local de desarrollo. La animación real sigue pendiente de ID. Se requiere revisión visual del desarrollador antes de integrar.

Build final: rojo build default.project.json --output %TEMP%/EndCinematicV11.rbxlx, PASS.
git diff --check: PASS; avisos CRLF preexistentes. También se verificaron los archivos nuevos sin rastrear. El sandbox impidió acceso de Rojo/Git; las verificaciones se ejecutaron correctamente mediante la autorización de herramienta, sin modificar el índice.

Sin commits, push, publicación, TeleportService, nuevos places o escrituras cloud. No se modificaron servicios de partidas, persistencia, recompensas, estadísticas, PlayableModes ni concurrencia. La sesión de pruebas quedó detenida. La integración con RoundService permanece pendiente de autorización.
