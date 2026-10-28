# End Cinematic V1.2 — integración y validación

Fecha: 2026-10-15. No constituye aprobación visual final ni habilita XvX.

## Implementación

Antes: el quinto punto todavía podía activar PointFeedback físico antes de declarar el ganador. RoundService entraba en Ending, reposicionaba personajes y esperaba cuatro segundos antes del cierre. El sistema cinematográfico V1.1 era una presentación de preview independiente.

Ahora: ScoreService confirma el quinto punto y sus 50 Coins habituales; RoundService fija el resultado, GameplayFrozen, Closing y Ending antes del feedback final. Cancela PointRestartThread, desvincula eliminaciones, borra combat tags y cancela los efectos de esa sesión. Los Characters reales se recuperan en sus spawns seguros, se bloquean y anclan; solo los rigs visuales actúan en la cinemática. No se agrega un estado nuevo ni una segunda lógica de recompensas.

MatchInstanceService prepara una única copia EndCinematic junto con el mapa y registra EndCinematic/ArenaTransform en InstanceInfo. La transformación es `CFrame.new(arenaOrigin) * mapTemplate:GetPivot():Inverse()`, aplicada al CFrame original de cada BasePart de la copia. No depende del pivot del escenario. En Levels, el pivot original observado fue (288.5, 0, 805); slot 0 usa (10000, 500, 0), slot 1 (20000, 500, 0). La copia mantiene cámaras, slots, partículas y sonidos. Sus partes quedan ancladas y sin colisión/contacto/query; sus scripts se eliminan. La plantilla artística original no se reposiciona ni modifica.

El contenedor y la escena tienen SessionId; esta última usa PersistentPerPlayer y AddPersistentPlayer para los espectadores autorizados. WinnerDescriptions contiene snapshots de los avatares ganadores, incluidos los UserId negativos de Studio. El cliente resuelve únicamente `ActiveMatches/Match_<SessionId>/EndCinematic`, comprueba ambas identidades y espera cámaras, slots y snapshots con límite temporal. Durante una partida no busca la escena global. La escena global continúa disponible para preview.

## Remotes y ciclo de resultados

- Servidor → `Match.EndCinematic`: Prepare, Start, Returned.
- Cliente → `Match.EndCinematicAction`: Prepared, Return, Failed, con SessionId, StateVersion y token opaco.
- Prepare: MatchId/SessionId canónico, versión, token, Mode/TeamSize, WinningTeam, Score, Winners ordenados, DescriptionKey, participantes elegibles, LocalTeam y ruta/origen de la escena.
- El servidor valida registro autoritativo, participante exacto, estado Ending, versión y token. El cliente no decide ganador, equipo, recompensas ni teletransporte.
- Tras preparar HUD físico, cámaras y avatares bajo transición cerrada, cada cliente confirma Prepared. Start fija una hora común con GetServerTimeNow y 0,5 s de anticipación. Eventos repetidos y sesiones cerradas no crean una nueva reproducción.
- Volver solicita autorización. Returned detiene la presentación local; SpawnService retorna individualmente, se restaura el anclaje, se retiran herramientas, se limpia su HUD de partida y se libera solo ese participante. Otro espectador continúa con la escena intacta.
- Preparación: máximo 25 s; espera de escena: 12 s. Duración desde Start: máximo de apertura, viaje más rebote y entrada escalonada de cinco rigs, más demora/fade de HUD y 20 s de visualización. Configuración actual: 24,6 s. No usa el antiguo retorno de cuatro segundos.
- Última salida, desconexión o expiración conduce al CloseSession existente. Un retorno fallido conserva escena/slot en cuarentena y admite reintento. La excepción no deja Returning bloqueado. No se libera el slot antes del retorno físico satisfactorio.
- PointFeedback vuelve a comprobar autoridad después de un controller que pueda ceder ejecución; destruye handles tardíos y no llama BlastZone. El filtro físico comprueba sesión, versión y pertenencia. Ragdoll rechaza ResultsSessionId; sus mensajes de lanzamiento incluyen el MatchId original y el cliente rechaza reproducciones diferidas de otra sesión o de resultados. Los shakes de inicio y puntuación quedan neutralizados durante resultados.

## Evidencia y alcance de las pruebas

`EndCinematicV12.server.spec.luau`: **32 aserciones PASS**, con instancias de servicio aisladas y dobles de jugadores, remotes, recompensas, posicionamiento y gestores. No inicializa Bootstrap ni accede a persistencia. Incluye quinto punto, scoring/Slap/eliminaciones tardías, timer cancelado, recompensa única, tokens/versiones ajenos, retorno individual, duplicados, cierre repetido, cuarentena/reintento, excepción de retorno y controller de efectos que cede ejecución. Estas son pruebas programáticas, no partidas humanas.

También se crearon dos escenas aisladas: A/B ocuparon slots 0/1; la separación fue 10000 studs, Prepare reutilizó la referencia y destruir A no afectó B. Una repetición comprobó igualdad exacta de CFrame para las 13 BaseParts de la plantilla, incluidas las tres cámaras y los cinco slots, y ausencia de colisión/contacto/query en las copias. Destruir ambas y repetir DestroyInstance no dejó recursos.

Las pruebas multicliente usaron dos procesos cliente reales (-1 y -2), matchmaking y zonas físicas reales. Los desplazamientos a pads y zonas de gol se hicieron por MCP, sin sustituir scoring ni fabricar recompensas. No equivalen a una partida jugada con teclado y ratón de principio a fin.

Sesión inicial completada: `1c133d07-7a1c-4119-bfad-f7af41a5bce2`, Red 5–0, Player1 250 Coins/1 Win, Player2 1 Loss. Retornos individuales por RemoteEvent; el primero mantuvo la presentación del segundo y el último liberó la instancia. Durante una llamada MCP con espera que coincidió con la preparación, Assistant restauró la cámara del primer cliente; Output identificó explícitamente esa intervención. La comprobación de ambas cámaras se repitió con la versión final y llamadas sin espera durante el cambio de cámara.

Un intento de repetición `8c940aa1-1dee-424e-9df5-e3bde07a4ba2` se interrumpió: la automatización usó partes que dejaron de estar replicadas por streaming, el personaje cayó fuera del mapa y perdió HumanoidRootPart. No se cuenta como partida aprobada. No se modificó la política de streaming para resolverlo; se reinició el ensayo.

Versión final: `a12296e2-71cd-47ea-b4b5-10eb438a0edb`, Red 5–0, Player2 (-2) 250 Coins/1 Win; Player1 (-1) 0 Coins/1 Loss. Ambos recibieron StartAt=1792107890.438969. Llegadas del Start separadas por aproximadamente 2,8 ms. Ambas cámaras Scriptable tuvieron distancia 0 respecto de la cámara Only1V1 de su copia. HUD VICTORIA/DERROTA y nombre Player2; ambos Characters anclados y sin Slap durante resultados. Se pulsó el botón físico ReturnButton mediante user_mouse_input. Player2 recibió Returned a 1792107902.881315, volvió al lobby y se desancló; Player1 siguió viendo resultados y la escena permaneció. Player1 recibió Returned por timeout a 1792107915.091922, 24,653 s después de StartAt. Al terminar: ActiveMatches vacío, HUD desactivado, anclaje false, WalkSpeed 16 y velocidad residual aproximada 0,000052 studs/s (contacto físico normal), sin nuevos Coins/Wins.

Repetición en el mismo servidor final: `d075d273-a02e-4b7b-b54e-d858bbeacbd1`, slot 0 reutilizado, Red 5–0. Ambos clientes votaron Random mediante botones físicos y recibieron Voted=Random para esa sesión. Un intento de UnequipTools fue corregido por el bloqueo existente. El ganador acumuló 500 Coins y 2 Wins en las dos partidas del mismo servidor. StartAt=1792108137.378975. Se desconectó al ganador con Kick local de prueba mientras mostraba HUD de resultados y cámara Scriptable; el otro conservó su HUD/cámara/escena. No se considera prueba de combate aprobada: Tool:Activate se ejecutó pero no hubo evidencia suficiente de un golpe válido.

La evidencia de Output seleccionada se guarda en `EndCinematicV12.output.txt`; no incluye tokens de la presentación ni salidas ajenas de plugins. La lista de aserciones se devuelve al ejecutar el harness. Las lecturas mediante require desde Assistant pueden usar un contexto de módulos distinto del Bootstrap real; por eso la evidencia real se tomó de remotes observados, atributos, GUI, cámaras, personajes y Output, y no del registro de un require aislado.

## Matriz obligatoria

PASS indica ejecución observada; la columna distingue aislada, API o multicliente. BLOCKED indica cobertura incompleta, aunque el código haya sido inspeccionado.

| # | Prueba | Resultado | Evidencia / límite |
|---|---|---|---|
| 1 | Quinto punto único | PASS | Harness y partidas 5–0; una transición Ending |
| 2 | Scoring posterior rechazado | PASS | Harness; Touched en Ending sin aumento posterior |
| 3 | Slap posterior rechazado | PASS | Harness ejecuta selección autoritativa y obtiene SessionNotCombatReady |
| 4 | Eliminaciones tardías sin estadísticas | PASS | Harness ejecuta evento tardío sin registrar procesamiento |
| 5 | Recompensas sin duplicación | PASS | Harness idempotente y Output de Win/Loss únicas |
| 6 | Timers anteriores no reanudan Playing | PASS | Hilo anterior cancelado y transición Playing rechazada en harness |
| 7 | Física pendiente no llega al lobby | PASS | Controller cedido cancelado en harness; lobby real estable. Falta ensayo manual de todos los efectos equipables |
| 8 | Sin retorno prematuro | PASS | HUD real, salida individual y timeout de 24,653 s |
| 9 | Copia por sesión | PASS | Escenas aisladas A/B y escenas de sesiones reales |
| 10 | Transformación igual a arena | PASS | Comparación CFrame aislada con delta del mapa |
| 11 | Orientación de cámaras y slots | PASS | Igualdad exacta de los 13 CFrames transformados, incluidas tres cámaras y cinco slots. Encuadre artístico pendiente de aprobación humana |
| 12 | Escenas simuladas distintas | PASS | Referencias A ~= B, slots separados 10000 studs |
| 13 | Destruir una no afecta otra | PASS | B conservada tras DestroyInstance(A) |
| 14 | Copia destruida al cerrar | PASS | Output destrucción y ActiveMatches vacío en clientes |
| 15 | Sin escenas huérfanas | PASS | Cleanup aislado y real; ningún contenedor restante |
| 16 | Solo participantes reciben evento | BLOCKED | Dos participantes recibieron; falta tercer cliente en lobby como control negativo |
| 17 | Cámara cercana 1v1 | PASS | Resolve API y distancia final 0 en ambos clientes reales |
| 18 | Cámara amplia XvX | PASS | Resolve API devuelve CFrame de CameraCheck-v2 para 3v3; modo no habilitado |
| 19 | Mismo ganador para ambos | PASS | Payload y HUD reales indican Player2/Red |
| 20 | HUD según equipo local | PASS | VICTORIA Red y DERROTA Blue observados |
| 21 | Volver requiere servidor | PASS | Clic físico ReturnButton → Returned → lobby/desanclaje |
| 22 | Salida individual mantiene al otro | PASS | PeerHud=true y SceneCount=1 después de la primera salida |
| 23 | Última salida cierra | PASS | Primer ensayo con dos Return; harness y destrucción real |
| 24 | Timeout retorna restantes | PASS | Último Returned a StartAt+24,653 s y cierre completo |
| 25 | Desconexión durante Ending | PASS | Ganador desconectado durante HUD; el otro conserva cámara/escena y posteriormente retorna por timeout |
| 26 | Remotes repetidos | PASS | Prepared/Return duplicados no repiten acciones en harness |
| 27 | Evento de sesión anterior | BLOCKED | Servidor rechaza sesión cerrada en harness; falta replay real del evento servidor→cliente |
| 28 | Preview independiente | PASS | API acepta 1/2/3/5 y Stop limpia; selección de cámaras validada. Recorrido visual completo pendiente |
| 29 | FIFO | BLOCKED | Admisión y repetición reales funcionan; no se ensayó una cola de varias zonas |
| 30 | Votación 1v1 | PASS | Clic Random en ambos clientes; confirmación Voted=Random para misma sesión |
| 31 | Spawn y combate | BLOCKED | Spawn 2/2 y reequipado tras UnequipTools observados; activación programática no produjo evidencia de golpe válido |
| 32 | Coins por gol | PASS | Incrementos reales de 50, 250 por cinco goles; rival 0 |
| 33 | Wins/Losses | PASS | Una por resultado en Output y prueba idempotente |
| 34 | Cierre idempotente | PASS | Harness repetido; fallos de retorno conservan recursos y reintento recupera |
| 35 | 2v2/3v3 false | PASS | IsModePlayable devuelve false en harness con Config real |
| 36 | Concurrencia máxima 1 | PASS | Aserción sobre RoundService._maxConcurrentSessions == 1 |
| 37 | Persistencia aislada | PASS | Bootstrap real: Studio/InMemory/WritesToCloud=false antes de probar |

## Archivos de esta fase

- `src/server/Services/RoundService.luau`: barrera, preparación, autorización, retorno individual, timeout y cierre.
- `src/server/Services/MatchInstanceService.luau`: propiedad, transformación y clon de escena.
- `src/server/Services/ScoreService.luau`: declarar resultado antes del feedback final; no cambian reglas ni cantidades.
- `src/server/Services/PointFeedbackService.luau`: invalidación de handles/física por sesión.
- `src/server/Services/RagdollService.luau` y `src/character/RagdollStatesHandler.client.luau`: protección de resultados y lanzamiento con identidad de origen.
- `src/client/Controllers/EndCinematicController.luau`: integración real y handshake, conservando los siete módulos.
- `src/client/EndCinematic/Modules/EndCinematicAvatars.luau`: snapshots de descripción.
- `src/client/EndCinematic/Modules/EndCinematicHUD.luau`: Return funcional y empate, mismo HUD físico.
- `src/client/Controllers/MatchController.luau`: suprime el panel legado durante Cinematic Ending.
- `src/client/Controllers/MatchStartEffectsController.luau`, `src/client/PointCameraFX.client.luau`: supresión de efectos residuales durante resultados.
- `src/shared/Types.luau`, `src/shared/EndCinematicConfig.luau`, `default.project.json`: recursos/contrato, tiempos y dos remotes.
- `tests/EndCinematicV12.server.spec.luau`, este informe y `tests/EndCinematicV12.output.txt`.

Los demás cambios locales pertenecían a fases previas y se preservaron. EndCinematicPreview y la geometría/HUD físicos no fueron reescritos en esta fase.

## Verificación y validación manual pendiente

`rojo build default.project.json --output %TEMP%/EndCinematicV12.rbxlx`: PASS, exit 0. `git -c core.safecrlf=false diff --check`: PASS, exit 0. Las advertencias habituales LF/CRLF no son errores de diff. Rojo compila la jerarquía del proyecto; no sustituye las comprobaciones runtime de los assets físicos presentes en Studio.

GameId observado: **10769217377**. PlaceId: **107328891970677**. No se configura automáticamente ningún Universe ID de producción. Bootstrap observado: **PersistenceEnvironment=Studio, PersistenceProvider=InMemory, WritesToCloud=false**. No se invocaron APIs cloud, publicaciones, commits ni push. No se alteró la política de persistencia, modalidades, máximo de concurrencia ni la plantilla artística. Respaldo previo preservado.

Advertencias ajenas observadas: swoosh.wav no autorizado, icono de plugin no cargable, FoundationProvider de UI interna, música ausente para Levels. Errores deliberados del harness: InjectedSlapFailure y OperationReturnedFalse prueban recuperación, sin afectar sesiones reales. Errores de comandos MCP durante exploración (ruta Client inexistente, Name sobre CFrame y partes no replicadas) se distinguen de errores de los scripts del proyecto.

Para cerrar los BLOCKED: abrir un tercer cliente espectador; completar una partida con controles reales y golpe válido; probar respawn durante resultados; repetir los efectos equipables cerca de un gol final; verificar cola de dos zonas; realizar replay controlado de un evento viejo únicamente en entorno aislado. Capturar Output de servidor y clientes, IDs, resultados/Coins antes y después, HUD del espectador y ActiveMatches al cerrar. Aprobar visualmente cámara, rigs, transición, audio y previews 1/2/3/5. No habilitar todavía 2v2/3v3, concurrencia ni revancha.

La repetición terminó por timeout del último espectador a 1792108162.078203 (24,699 s desde StartAt). Output confirmó la desconexión durante Ending, totales 2 Wins/2 Losses y destrucción del contenedor con liberación del slot 0. El cliente restante quedó en lobby, desanclado, sin MatchId, HUD desactivado y SceneCount=0. Se completaron tres partidas con dos clientes reales en total, dos de ellas consecutivas en el servidor de la versión final; el intento interrumpido no cuenta. La plantilla original conservó la cámara Only1V1 en (521.781677, 55.390274, 41.574371), ActiveMatches de Edit quedó vacío y no quedaron carpetas de pruebas aisladas.

HEAD observado al finalizar: `8bcdfa48e2d12a596943cefca45f7f57698b1e0e`, rama `master`. No se creó ningún commit.

Recomendación: integración funcional validada en su flujo principal; aceptación final condicionada a la revisión manual y los negativos pendientes. Detenerse aquí, sin avanzar a otra implementación.
