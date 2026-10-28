# End Cinematic V1 — validación de preview

Implementación exclusivamente cliente y Studio. Sin integración con partidas.

## Auditoría física

`Workspace.EndCinematic` es Folder. Contiene `Structure` (Floor, Floor1, Floor2), `Players` (cinco Parts SlotPlayer_1–5), `TransCamera` (dos Parts CameraCheck-v1/v2) y `Confeti` (DropT1/DropT2, Parts). Referencias físicas ancladas. Diez ParticleEmitters en total, Enabled=true, Rate=99, Lifetime=1–2. Cada Drop contiene AllSoundsPlay con Confetti, Firework y Victory: seis Sounds, todos con SoundId vacío y Looped=false.

La orientación física de los slots presenta los avatares de espaldas a la cámara. Se conserva para revisión humana. Los emisores originales permanecen activos; la preview solo controla copias locales y por eso el confeti original puede continuar visible después del recorrido. No se alteraron geometría ni CFrames originales.

## Arquitectura y uso

- `src/shared/EndCinematicConfig.luau`: todas las duraciones, color, giro, rebote, caminar, efectos y preview.
- `src/client/Controllers/EndCinematicController.luau`: Initialize, Play, Stop, IsPlaying. No suscripciones a remotes de partida. Play actualmente exige Studio y ausencia de MatchId local.
- `src/client/EndCinematicPreview.client.luau`: panel Studio con 1/2/5 ganadores, alternancia victoria/derrota, reiniciar y detener.

Rojo incluye automáticamente los tres archivos mediante las carpetas existentes. El bootstrap requiere el controlador sin iniciarlo: solo el panel de desarrollo dispara Play.

Para probar: iniciar Play, usar el panel END CINEMATIC, elegir cantidad. VISTA cambia el resultado para la próxima reproducción. Los ganadores usan jugadores conectados; si faltan, repiten la apariencia local con etiqueta Demo explícita. No representan estadísticas reales. REVANCHA no acepta acciones; muestra 0/N y PRÓXIMAMENTE. N se recibe mediante EligibleParticipantCount; en demostración equivale a ganadores*2.

La transición utiliza dos Frames sobredimensionados rotados y TweenService. La cámara se interpola con un NumberValue único, giro sinusoidal opcional y rebote local sutil, terminando en el CFrame exacto v2. Los rigs R15 se generan desde HumanoidDescription, sin scripts ni Tools, con raíz anclada. Orden estable Slot/UserId. La caminata termina en el slot; limita distancia de inicio a la plataforma. WalkAnimationId vacío no carga Animation; un ID posterior usa Animator. HUD propio aparece cuando terminan cámara y caminatas. Se ocultan y restauran los ScreenGuis existentes sin modificar sus fuentes.

Stop invalida la ejecución antes de cancelar tweens/conexiones y destruir recursos. Restaura CameraType, Subject, CFrame, FOV y HUD. Cambio de cámara, respawn o inicio de partida cancelan la preview. Los trabajos asíncronos comprueban su ejecución vigente y los rigs que llegan tarde se destruyen.

## Matriz observada

| Caso | Resultado | Evidencia / límite |
|---|---|---|
| A | PASS | Modelo físico localizado mediante Studio MCP |
| B | PASS | Dos CameraChecks BasePart y CFrames leídos |
| C | PASS | Cinco slots BasePart |
| D | PASS | Un rig visible, caminata completa, HUD |
| E | PASS | Dos rigs visibles y HUD derrota |
| F | PASS | Cinco rigs visibles, cinco caminatas, cámara completa |
| G | PASS | Slot 5 temporalmente ausente en cliente: InsufficientSlots; restaurado inmediatamente |
| H | PASS | Captura de cierre completamente oscuro sobre la escena; panel de desarrollo permanece accesible encima |
| I | NOT RUN | Apertura ejecutada; capturas no prueban ausencia de parpadeos en movimiento |
| J | NOT RUN | Asignación a v1 implementada; falta captura temporal del comienzo |
| K | PASS | Igualdad exacta CFrame con CameraCheck-v2 observada |
| L | NOT RUN | Giro implementado; falta revisión visual en movimiento |
| M | NOT RUN | Rebote implementado; falta revisión visual en movimiento |
| N | PASS | Desplazamiento completado y apoyo visual corregido con HipHeight |
| O | BLOCKED | Configuración preparada; falta AnimationId autorizado válido |
| P | PASS | Confeti visible; copias de ambos Drop; originales también activos |
| Q | BLOCKED | Seis SoundIds vacíos; no se inventaron assets ni bucles |
| R | PASS parcial | Cero emisores temporales activos al final y recursos destruidos; audio sin verificar |
| S | PASS | Captura VICTORIA / GANASTE EL DUELO |
| T | PASS | Captura DERROTA / PERDISTE EL DUELO |
| U | PASS | Nombres Demo, equipo Red, marcador 5–3 |
| V | NOT RUN | Handler Stop enlazado; Stop probado por API, falta pulsación real del botón |
| W | PASS | Botón inactivo y PRÓXIMAMENTE visible; contador 0/2 y 0/4 |
| X | PASS | Reproducciones consecutivas de uno, dos y cinco ganadores |
| Y | PASS | Cancelación a 0.15 s: overlay eliminado, cámara restaurada |
| Z | PASS | CameraType restaurado; HUD previo restaurado |
| AA | PASS | Carpeta local destruida tras Stop; doble Stop seguro |
| AB | PASS | Esta tarea creó únicamente archivos nuevos; sin edición de servicios |
| AC | PASS | Bootstrap Studio/InMemory/WritesToCloud=false; sin APIs cloud en los componentes |

También se observó rechazo AlreadyPlaying al segundo Play concurrente. No se probaron resoluciones móviles, reemplazo real de cámara, respawn, avatares remotos fallidos ni AnimationIds inválidos. No se declara validada la sincronización multicliente: la etapa es local.

## Verificación final

`rojo build default.project.json --output %TEMP%/SlapDuels-EndCinematic.rbxlx`: PASS. `git diff --check`: PASS (avisos CRLF preexistentes). Studio detenido tras pruebas. Sin commits, push, publicación, TeleportService, nuevos places, escritura cloud ni cambios de modalidades/concurrencia. El Working Tree previo permanece conservado, incluyendo cambios de fases anteriores.

Pendiente de revisión visual humana antes de cualquier integración. No continuar a integración automáticamente.
