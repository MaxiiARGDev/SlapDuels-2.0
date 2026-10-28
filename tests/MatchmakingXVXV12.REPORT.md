# Matchmaking XvX V1.2 — programación 3v3 y 4v4

Fecha: 2026-10-20. Implementación y sincronización selectiva en Studio Edit completadas. **Jugabilidad no ejecutada ni aprobada por esta verificación.**

## Contrato corregido por el propietario

La aclaración posterior reemplaza la sección original que pedía ocho rigs en EndCinematic: **solo aparecen ganadores**, uno/dos/tres/cuatro según modalidad. Se conservan los cinco stands físicos; el quinto queda reservado, sin habilitar 5v5. Un empate conserva su HUD de resultados y no tiene rigs ganadores.

El propietario colocará las zonas físicas 3v3/4v4 después. Se implementan y habilitan los modos en el registro del servidor ahora; su entrada por plataformas permanece pendiente hasta existir zonas válidas. No se creó, movió ni reemplazó ningún objeto físico.

## 1. Archivos modificados y respaldo

Producción: seis archivos, comparados contra el estado local previo de esta tarea (no contra HEAD, porque existen muchos cambios locales anteriores):

| Archivo | Cambio |
|---|---|
| `src/shared/Config.luau` | Habilita 3v3/4v4 y registra 4v4 con capacidad 4+4. |
| `src/server/Services/MatchmakingService.luau` | Registro cerrado de modalidades, coherencia de atributos, pads de ambos lados obligatorios, ZoneId único y ordenamiento de pads. |
| `src/server/Services/SpawnService.luau` | Conserva CFrame completo tanto en traslado inicial como en recuperación individual, aplicando el clearance sobre el eje local del SpawnPart. No modifica los Parts. |
| `src/client/Controllers/MatchmakingController.luau` | Cupos RED/BLUE dinámicos, reutilización del texto central como estado si no existe header y ajuste del UIScale existente al ancho disponible. |
| `src/shared/EndCinematicRanking.luau` | Ranking completo, selección visual exclusivamente del equipo ganador, máximo cuatro; valida correspondencia de nombres, equipo, estadísticas y slots con el snapshot. |
| `src/client/EndCinematicPreview.client.luau` | Reemplaza la demostración de cinco ganadores por preview 4v4. |

RoundService permanece **byte a byte sin cambios respecto al comienzo de esta tarea**. También permanecen intactos otros 213 archivos incluidos en el manifiesto previo, entre ellos los dos proyectos Rojo, mapas locales, economía, combate, habilidades, compras y persistencia.

Respaldo previo: `tests/assets/backups/MatchmakingXVXV12/`: copia de fuentes Luau, ambos proyectos Rojo, estado Git previo y manifiesto SHA-256 de 219 archivos. `studio.before.json` registra fuentes/recursos de Edit. No reemplaza ni elimina los respaldos integrales anteriores.

Pruebas nuevas: `MatchmakingXVXV12.spec.luau`, `.prematch.luau`, `.integration.luau`; runner V1.0 ampliado con selección explícita de base, extensiones múltiples y archivo de resultados; nuevo `tests/tools/validate_matchmaking_xvx_v12.py`. Los resultados históricos V1.0/V1.0.1 no se reescribieron.

## 2–4. Modalidades, zonas y participantes

| Modo | TeamSize | MaxPlayersPerTeam | TotalPlayers | Habilitado en código | Zona actual en Edit |
|---|---:|---:|---:|---|---|
| 1v1 | 1 | 1 | 2 | Sí | `1v1` y `1v1-2` |
| 2v2 | 2 | 2 | 4 | Sí | `2v2` |
| 3v3 | 3 | 3 | 6 | Sí | Pendiente del propietario |
| 4v4 | 4 | 4 | 8 | Sí | Pendiente del propietario |

No hay modos adicionales ni cambios de concurrencia: una sola sesión registrada simultánea, incluyendo preparación/resultados/cierre.

El servidor descubre Folders directamente en `Workspace.ZoneMatchmaking`. Exige modalidad presente en `Config.Matchmaking.Modes`; los atributos ausentes usan esa configuración. Los atributos presentes deben coincidir exactamente con ella. Se rechazan números fraccionarios, negativos, cero, infinitos, NaN, strings o booleanos que pretendan cambiar las capacidades, así como modos desconocidos y ZoneIds duplicados. Se requieren pads Red y Blue válidos en `joins-parts`. Un Folder decorativo sin pads no se convierte en una cola. Los atributos locales de un cliente no autorizan partidas.

`Secuencia`, `DuracionFase` y `TiempoTransicion` no se escriben ni se usan como duración competitiva. Las futuras zonas deben estar completas/configuradas en Edit antes de que el propietario inicie su prueba.

## 5–6. Spawns y equipos

Se reutiliza `TeamSpawnResolver`: `MapModel.RedTeam/BlueTeam.Spawn1..Spawn4`, orden numérico explícito. Cada participante mantiene Team/Slot: 1v1 usa 1; 2v2 usa 1–2; 3v3 usa 1–3; 4v4 usa 1–4. La preparación valida todos los integrantes, conexiones, Character, registros y destinos antes del lote de transferencia. No hay fallback a Parts legacy.

Ambos modelos físicos finales (`Workspace.Levels` y `ServerStorage.Maps.Levels`) tienen Geometry, ZoneWin.RedWin/BlueWin y ocho SpawnParts válidos. Están en ubicaciones mundiales diferentes; los ocho CFrames relativos al pivot coinciden con error máximo de 0,000016 studs/componentes. No necesitan compartir coordenadas mundiales: el runtime usa el transform relativo de su plantilla de ServerStorage.

Durante la inspección el propietario reorganizó temporalmente estos mapas y lo confirmó en el chat. Por eso sus hashes nativos finales difieren de la primera lectura; **no se atribuye ese cambio a esta implementación ni se sobrescribe con el asset local anterior**. El agente no movió/rotó/recreó ningún spawn ni mapa. La evidencia final conserva las coordenadas actuales y el contraste relativo.

## 7–8. Prematch y RoundService

Se conserva el recorrido existente: ocupación/FIFO → reserva → admisión atómica → MatchReady → countdown completo de cinco segundos → votación → preflight físico/de personajes → carga → transferencia → StartCountdown → Playing.

La cancelación V1.0.1 se ejercitó para tamaños 1, 2, 3 y 4: salir un integrante confirmado cancela la sesión/token, no invoca retorno al lobby, premios ni resultados; los restantes conservan cola y orden. Un reemplazo crea otro SessionId y cinco segundos nuevos. Se probaron salidas finales, callbacks tardíos, ciclos repetidos y la tolerancia existente de 0,8 s. La consulta física final no acepta una ocupación retenida solo por gracia.

El caso excepcional de transferencia parcial conserva la recuperación selectiva anterior: vuelve únicamente quien fue realmente trasladado. No se equipara con abandonar un pad antes de cargar la arena.

No se creó un servicio por modalidad ni se modificó el ciclo competitivo central. El límite de una sesión impide que otra cola inicie una segunda partida mientras la capacidad está ocupada.

## 9–11. Recompensas, recuperación y abandonos

- Marcador compartido por equipo, máximo cinco goles.
- Gol: +150 Coins exclusivamente al anotador; Kill: +30 exclusivamente al atacante acreditado. Caída sin atacante: cero premio personal de Kill.
- Se conserva el bloqueo de resolución por ronda y la idempotencia de transacciones/recibos existentes. Se ejercitó un gol con llamadas repetidas y del equipo contrario: una anotación y un solo receptor.
- Cada ronda tiene 180 segundos, Muerte Súbita en los últimos 30 y un deadline nuevo tras el reinicio de gol. No son tres minutos totales por partida.
- Recuperación individual conserva Character, equipo y Slot; no reposiciona compañeros. La asignación y los dos métodos reales de posicionamiento se ejecutaron sobre adaptadores aislados.
- Abandono parcial durante Playing continúa mientras ambos equipos tengan integrantes; quedar vacío conserva la política existente de resultado por abandono. No hay reemplazos ni penalizaciones nuevas.
- Combate, ragdoll, inmunidad de víctima, tres palmadas, StrongSlap, Zero-Death, KillPart, Death Effects y habilidades no se modificaron.

## 12. HUD

Se reutiliza MatchmakingHUD. Sus TeamLabel muestran `RED n/N` y `BLUE n/N`, separados de los nombres. Si falta un Header de estado, se reutiliza el TextLabel de Versus para LISTA/ESPERANDO con el total; no se crea otro ScreenGui. CardScale se reduce cuando el contenido excede el ancho disponible y conserva la escala original cuando cabe. MatchController sigue presentando los countdowns/preparación/inicio y ocultando la cuenta cancelada con la identidad de sesión vigente.

La inspección encontró UIAspectRatioConstraint con eje dominante Height: los `400px` nominales de las tarjetas no equivalen necesariamente a ese ancho renderizado. No se declaró un fallo visual basándose únicamente en ese valor. La legibilidad y el encuadre en móvil/PC requieren la prueba visual del propietario.

MatchHUD ya recorre listas de participantes y dispone de contenedores de 160px para filas de 34px (cuatro por lado). Sus recursos y los de marcador, timer y Muerte Súbita se conservan. No se modificó ShopHUD ni PremiumShopHUD.

## 13–15. EndCinematic y recursos físicos

El snapshot retiene los 2/4/6/8 participantes con su ranking individual, estadísticas y MVP global; `VisibleParticipants` contiene exclusivamente al equipo ganador, ordenado por ranking, con CinematicSlot consecutivo 1–4. Un MVP del equipo perdedor sigue registrado, pero no se crea su rig ni se inventa otro MVP. Empate: snapshot válido con lista visible vacía y HUD EMPATE/SIN GANADOR.

Se conserva la resolución de cámaras, las animaciones, el estilo de BillboardGui, el aislamiento por sesión y la limpieza existentes. El controller ya crea un rig por fila visible; no crea rigs de relleno. No se comprobó su reproducción visual en esta tarea.

Inspección MCP en Edit: cinco anchors únicos, seguros y con componentes completos:

`ServerStorage["EndGames-Scenario"].ScenarioFinal.Players.SlotPlayer_N.BillboardAnchor`, para N=1,2,3,4,5.

Cada uno conserva `BillboardGui.MainFrame` con RankLabel, PlayerName, MVPLabel, Username, TeamLabel, PreviewLabel y StatsFrame; este contiene GoalsLabel, KillsLabel, DeathsLabel, MatchPointsLabel. Anchored=true, Transparency=1 y CanCollide/CanTouch/CanQuery=false. El stand 5 queda libre; máximo cuatro rigs ganadores. No se creó ningún rig/anchor ni recurso temporal en Edit. No fue necesario modificar ScenarioFinal; su hash nativo y sus cámaras son idénticos al inicio.

## 16–19. Verificaciones automatizadas

| Verificación | Resultado |
|---|---|
| Harness XvX V1.2 | **359 aserciones PASS aislado**: base 49, prematch 102, integración 208. |
| SlapVictimProtection | 150 PASS aislado. |
| AbilityMultiplayerFixV1.regression | 164 PASS aislado. |
| EconomyBalanceV1 | 30 PASS aislado: autoridad, Kill +30, gol +150, duplicados y caídas. |
| EconomyBalanceV1.shop | 86 PASS aislado. |
| PremiumShopV11 | 93 PASS aislado. |
| Total | **882 aserciones aisladas**. |
| Compilación Luau | 162 fuentes + 3 specs: cero errores. Compilación sintáctica, no promesa de análisis estático exhaustivo de tipos. |
| Rojo default.project.json | PASS. |
| Rojo studio-safe.project.json | PASS. |
| git diff --check | PASS; las advertencias LF/CRLF no son errores de whitespace. |

El harness ejecuta módulos reales con Players, consultas espaciales, reloj/coroutines, transporte, equipamiento y destrucción física adaptados. No acredita una partida real, latencia multicliente, física real de un rig, render de cámara ni limpieza nativa de instancias en Play.

Reproducción local sin Studio:

```powershell
& 'C:\Users\rataatrevida\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/validate_matchmaking_xvx_v12.py
```

### Matriz de los 37 puntos del pedido

Todos los PASS de esta tabla son **aislados** o inspección explícitamente indicada; la columna final no concede PASS funcional.

| # | Prueba | Evidencia actual | Funcional |
|---:|---|---|---|
| 1–4 | Flags 1v1/2v2/3v3/4v4 | PASS aislado: registro exacto y capacidades. | NOT RUN aquí. |
| 5–8 | Seis/ocho participantes y tres/cuatro por equipo | PASS aislado: admisión y coroutine común hasta Playing. | BLOCKED 3v3/4v4 hasta colocar zonas. |
| 9–10 | Spawn1–3 y Spawn1–4 | PASS aislado: resolución por todos los slots, sin orden de GetChildren. Ocho Parts inspeccionados en Edit. | NOT RUN. |
| 11 | Validación de todos | PASS aislado: se retira temporalmente cada Character, incluso el último, y se rechaza. | NOT RUN. |
| 12–16 | Cancelación, cero traslado, permanencia, contador nuevo, callbacks viejos | PASS aislado en los cuatro tamaños, incluyendo reemplazos y repeticiones. | 1v1/2v2 validación previa aportada; nueva ejecución NOT RUN. |
| 17–18 | Inicio 3v3/4v4 | PASS aislado hasta Playing, con lote adaptado y voting para seis/ocho destinatarios. | BLOCKED zonas físicas. |
| 19–20 | Marcador y gol personal | PASS aislado: score compartido, +150 al anotador, duplicados/oposición bloqueados. | NOT RUN. |
| 21 | Kill y Coins | PASS de regresión de métodos reales EliminationService/PlayerService: +30 y deduplicación. No simulación física de ocho jugadores. | NOT RUN. |
| 22 | Recuperación individual | PASS aislado: asignación última plaza y ejecución de métodos reales de traslado/recuperación sobre witness CFrame; compañero intacto. | NOT RUN física. |
| 23 | Reinicio de ronda | PASS aislado: reposiciona todos, conserva slots/score y reinicia deadline. | NOT RUN. |
| 24 | Muerte Súbita | PASS aislado: transición del reloj en 30 s y regresión del premio colectivo sin receptor inventado. | NOT RUN. |
| 25 | Abandono activo | PASS aislado: salida parcial y liberación de registro sin terminar/rebalancear. | NOT RUN multicliente. |
| 26 | Retorno tras partida | PASS aislado del cierre activo con adaptador de retorno y repetición idempotente; no partida completada real. | NOT RUN. |
| 27–28 | EndCinematic 3v3/4v4 | PASS aislado del snapshot: seis/ocho filas, tres/cuatro ganadores visibles, nombres y sesión validados. | NOT RUN reproducción. |
| 29 | Ocho rigs | Requisito sustituido por propietario: máximo cuatro ganadores; cinco anchors inspeccionados en Edit. | NOT RUN creación de rigs. |
| 30 | Sin relleno en 1v1 | PASS aislado: una sola fila ganadora; controller consume solo filas visibles por inspección. | NOT RUN visual. |
| 31 | Cámara | Configuración y recurso físico conservados por hash. | NOT RUN encuadre/travel. |
| 32 | Limpieza | PASS aislado: registros liberados, retorno idempotente e instancia retirada mediante adaptador. ActiveMatches vacío en Edit. | NOT RUN limpieza en Play. |
| 33 | Futuro mapa | PASS aislado: resolución relativa de otro mapa con ocho spawns y rechazo de capacidad insuficiente. | NOT RUN. |
| 34–35 | Economía/combate | PASS de regresiones y comparación de integridad; valores sin cambios. | NOT RUN aquí. |
| 36–37 | Regresión 1v1/2v2 | PASS aislado del mismo recorrido, cancelación y cierre. Conserva validación manual previa declarada por el propietario. | Nueva regresión NOT RUN. |

## 20. Sincronización e inspección final

Se comparó cada fuente con la copia previa y con el editor antes de actualizar. `ScriptEditorService.UpdateSourceAsync` escribió exclusivamente los seis scripts; las comprobaciones previas rechazan diferencias concurrentes o drafts sin guardar. La comprobación posterior exige SHA-256 igual al repositorio tanto en Source como en GetEditorSource.

No se ejecutó una sincronización global Rojo. Los builds son artefactos locales de verificación; no se importaron en Studio. Scene, MatchmakingHUD, MatchHUD, ShopHUD, PremiumShopHUD y ZoneMatchmaking conservaron sus hashes. Los cambios manuales de mapas se respetaron y registraron por separado, sin exportarlos sobre el asset local anterior.

Studio inspeccionado: PlaceId 107328891970677, GameId 10769217377; se conservaron los identificadores. El resolver real de persistencia se evaluó sin Bootstrap en Edit: Environment=Studio, ProviderName=InMemory, WritesToCloud=false, GetAsyncCalls=0, UpdateAsyncCalls=0, CommittedWrites=0 y StoredKeys=0. Es una selección de proveedor en Edit, **no un servidor de prueba arrancado**. Workspace.ActiveMatches: 0 hijos.

Evidencias: `MatchmakingXVXV12.checks.json`, `.results.txt`, `.studio-edit.json`, logs por suite/build y respaldo previo. No se inició Play/Run/Start Server/Team Test, no se controlaron personajes, no hubo escrituras cloud, publicaciones, commits ni push.

## 21. Guía manual del propietario

1. En Edit, colocar las zonas pendientes como Folders directamente en `Workspace.ZoneMatchmaking`, con `joins-parts` y BaseParts de entrada Red/Blue. Configurar antes de Play:

   | Zona | Mode (String) | TeamSize (Number) | MaxPlayersPerTeam (Number) | TotalPlayers (Number) |
   |---|---|---:|---:|---:|
   | 3v3 | 3v3 | 3 | 3 | 6 |
   | 4v4 | 4v4 | 4 | 4 | 8 |

   No reutilizar un ZoneId explícito de otra zona. Puede omitirse para generación automática. Conservar las secuencias/tiempos decorativos elegidos para esos recursos; no cambian el reloj de partida. No necesitan nuevos spawns: se usan los ocho de la plantilla `ServerStorage.Maps.Levels`.
2. Iniciar vos la prueba local con 2, 4, 6 u 8 clientes según modalidad. Antes de entrar en cola confirmar Output de Bootstrap: `PersistenceEnvironment=Studio PersistenceProvider=InMemory WritesToCloud=false`. Si no coincide, detener la prueba. No aprobar ni configurar Universe productivo por esta tarea.
3. Ocupar ambos lados completos. Comprobar RED N/N y BLUE N/N. Durante la cuenta de cinco retirar un integrante, esperar la gracia existente y verificar cancelación: cero traslado, ningún premio/cinemática, restantes en sus pads. Completar con reemplazo y comprobar cinco segundos nuevos. Repetir salida en último segundo.
4. Completar voting con todos los clientes, observar arena, distribución por Spawn1..N, equipos y equipamiento/bloqueo del Slap, countdown inicial y desbloqueo. Comprobar que otra cola no pueda abrir otra sesión.
5. Probar golpes, ragdoll/inmunidad de tres segundos, tercera palmada, KillPart y recuperación individual al mismo slot. Solo víctima recuperada; compañeros continúan. Kill acreditada +30 al atacante, caída sin atacante cero. Un cliente en lobby no debe recibir feedback ajeno.
6. Anotar con un integrante distinto del primero: score del equipo +1, +150 solo al anotador; varios contactos no duplican. Todos vuelven a sus propios slots y el reloj vuelve a 180 s. Comprobar Muerte Súbita al llegar a 30 s. Probar salida parcial durante Playing y continuidad sin reequilibrio.
7. Completar cinco goles. Verificar uno/dos/tres/cuatro rigs exclusivamente ganadores en 1v1/2v2/3v3/4v4. Nunca perdedores de relleno; quinto stand libre. Revisar nombres, ranking, stats, cámara, separación y permanencia de rigs. En empate: HUD EMPATE, sin rigs ganadores.
8. Volver al lobby: sin Slap, controles normales y sesión/mapa/cinemática/identidades retirados. Repetir una segunda partida por modalidad. Capturar Output completo, capturas de cupos/spawns/resultados y Explorer de ActiveMatches tras cerrar. La preview tiene botones 1v1/2v2/3v3/4v4 y no sustituye una partida real.

## 22. Riesgos y estado de entrega

Programación y sincronización selectiva listas. **3v3/4v4 aún no son accesibles por plataformas hasta que el propietario coloque sus zonas.** La prueba real de seis/ocho clientes, dimensiones útiles de pads, legibilidad del HUD, recorrido/cámara de la cinemática y limpieza real permanecen pendientes.

Los hashes de mapas modificados manualmente no coinciden con los de inicio; no usar un full sync/import de los builds para restaurarlos. Mantener la revisión SAFE por objeto: los proyectos Rojo y el asset local de Levels no se actualizaron con los cambios físicos temporales del propietario.

No se declara PASS funcional ni se avanza a otra fase antes de la validación manual.
