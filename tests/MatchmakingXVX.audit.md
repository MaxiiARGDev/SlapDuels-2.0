# Matchmaking XvX — auditoría técnica del estado real

Fecha: 2026-10-20. Repositorio: H:\repos-github\SlapDuels-2.0.

Auditoría de lectura de fuentes, configuración y DataModel de Studio **Edit**. Único entregable añadido: este informe. No se modificaron scripts, Attributes, mapas, interfaces ni flags; no se ejecutó Play/Run/Team Test, compras o persistencia cloud. Los builds y resultados de las pruebas existentes se generaron en un directorio temporal externo al proyecto.

Las líneas indicadas corresponden a las fuentes del repositorio; pueden desplazarse en futuras ediciones. Se contrastaron hashes de fuentes normalizadas con Studio: los 158 scripts encontrados de los 159 candidatos server/shared/client coincidieron. El candidato legacy ServerScriptService.RagdollModule no apareció en esa ruta; no se interpreta como fallo del matchmaking ni se modifica. Las dos fuentes de Character quedan fuera de esa comparación. El script decorativo AnimacionLetras1v1 se inspeccionó directamente en Studio.

## A. Estado general

| Modalidad | Clasificación real | Evidencia / límite |
|---|---|---|
| 1v1 | Implementada y habilitada | Config.Round.PlayableModes["1v1"]=true. Validación manual aportada por el desarrollador; no se repitió aquí. |
| 2v2 | Parcialmente implementada y deshabilitada | Cola 2+2, admisión, equipos, scoring y recuperaciones generales existen. Inicio real bloqueado; mapa insuficiente y gate de presencia incompleto. Sin validación integral vigente de cuatro clientes. |
| 3v3 | Parcialmente implementada y deshabilitada | Config/registro admiten 3+3 y resolver de spawns hasta tres. No hay zona física 3v3 ni mapa compatible; cinematografía visible limitada a cinco. Sin prueba integral. |
| 4v4 y N | Parcialmente implementada como infraestructura; modalidad concreta sin configurar | Colecciones genéricas y ranking, pero registro de modos cerrado, spawns limitados a tres y escena a cinco visibles. No es soporte arbitrario habilitado. |

**No basta activar un booleano para declarar 2v2 listo.** El límite de una sesión regula partidas simultáneas, no participantes: una sesión puede estructuralmente contener cuatro o seis jugadores. No hay que aumentar concurrencia para probar un único 2v2.

## B. Componentes y objetos existentes

| Área | Fuentes / objetos relevantes |
|---|---|
| Configuración y contratos | src/shared/Config.luau:7–27,251–273; src/shared/Types.luau; src/shared/Constants.luau |
| Cola y reservas | src/server/Services/MatchmakingService.luau; MatchmakingFeedbackService.luau |
| Admisión, ciclo y resultados | src/server/Services/RoundService.luau; Gameplay/RoundClock.luau |
| Arenas y spawns | src/server/Services/MatchInstanceService.luau; SpawnService.luau; Services/Respawn y ArenaRespawnPolicy |
| Competición | ScoreService, CombatService, SlapService, RagdollService, EliminationService |
| Habilidades | AbilityService, AbilityRegistry, módulos src/server/Abilities; presentación src/client/Abilities |
| Presentación | MatchmakingController, MatchController, SuddenDeathController, DeathFeedbackController, KillRewardController, PointFeedbackService |
| Final | EndCinematicController; src/client/EndCinematic/Modules; EndCinematicRanking y EndCinematicConfig compartidos |
| Objetos Edit | Workspace.ZoneMatchmaking; ServerStorage.Maps.Levels; ServerStorage["EndGames-Scenario"].ScenarioFinal.Players; StarterGui.MatchmakingHUD/MatchHUD/SuddenDeathHUD/EndCinematicHUD |

Instancia inspeccionada: Studio 83efe1df-78d3-4185-9a81-5926651bd41b, PlaceId 107328891970677, GameId 10769217377. Es una identificación de la sesión abierta, no una nueva aprobación del Universe productivo. Workspace.ActiveMatches tenía **0** hijos; no se creó ninguna sesión.

### Inventario completo de hijos de ZoneMatchmaking

| Hijo (todos Folder) | Mode | TeamSize / MaxPlayersPerTeam / TotalPlayers | DuracionFase / TiempoTransicion | Secuencia | Estado |
|---|---|---|---|---|---|
| 1v1 | 1v1 | 1 / 1 / 2 | 4 / 0.6 | 3, 4, 5 | Registrable; modo habilitado |
| 1v1-2 | 1v1 | 1 / 1 / 2 | 4 / 0.6 | 3, 7, 5 | Segunda cola 1v1; compite por la misma capacidad global |
| Pisos | ausente | ausentes | ausentes | ausente | Carpeta decorativa: también se intenta registrar por ser Folder, pero sin pads nunca se completa |
| 2v2 | 2v2 | 2 / 2 / 4 | 4 / 0.6 | 2, 8, 7 | Registrable y consistente; inicio real bloqueado |

No existe hijo 3v3 ni 4v4. Pisos contiene subcarpetas 1v1 y 2v2 con plataformas/texturas; no son colas anidadas descubiertas como zonas independientes. Al no tener Mode, Pisos toma ese nombre como modo y defaults 1/1/2; no es un modo autorizado ni una cola operativa.

Cada zona jugable tiene joins-parts con cuatro Parts: **Red, Blue, red-v1 y blue-v1**. Red/Blue miden 8×1×8, están medio stud sobre las bases red-v1/blue-v1 de 10×1×10, y tienen CanQuery/CanTouch/CanCollide=true. No poseen Attribute Team. El detector reconoce Red/Blue por nombre sensible a mayúsculas; las bases en minúscula no son pads inscritos. Un pad Red y uno Blue pueden alojar dos personas cada uno por capacidad lógica; no hacen falta cuatro pads para que la cola pueda contar cuatro jugadores. La comodidad física y solapamientos requieren prueba humana.

Centros de pads 2v2: Red ≈(120.966,12.112,-44.198), Blue ≈(125.979,12.112,-62.662). Los puntos de entrada efectivos son esos volúmenes de detección; no se encontraron Parts de entrada/salida dedicados. Salir significa abandonar el volumen y agotar la gracia de 0,8 s. Retorno de partida: Workspace.Lobby.SpawnLocation, no un exit pad de la cola.

Las tres zonas tienen text, efectos Red/Blue (SoundJoin, SoundLeave, SoundJoinMusic, ActivateParticle y Beams) y geometría/NPC decorativos con Animate. **No se encontraron BillboardGui ni SurfaceGui dentro de las zonas**. Los cupos se presentan en el HUD del jugador; las letras físicas son modelos. El feedback visual/audio de ocupación es por lado, no por cada plaza.

## C. Contrato exacto de atributos

| Atributo | Consumidor | Significado y fallback |
|---|---|---|
| Mode | MatchmakingService.getZoneConfiguration, ≈257–276 | String no vacío, o nombre del Folder. Busca defaults en Config.Matchmaking.Modes[Mode]. RoundService exige después un modo registrado. |
| TeamSize | Misma función; _updateQueue ≈625–665 | Número de integrantes comprometidos de cada equipo. Si falta/no es number: config del modo o 1. Se copia al request y se contrasta con Config.Matchmaking.Modes en AdmitSession. |
| MaxPlayersPerTeam | Configuración y updateTeamOccupants ≈111–254 | Máximo de ocupantes aceptados por lado; default del modo o TeamSize. Por pad se reparte ceil(capacidad/número de pads), conservando el máximo global del lado. |
| TotalPlayers | Configuración y QueueSnapshot | Default del modo o TeamSize×2. Se muestra como denominador del HUD y en logs. **No controla por sí mismo el inicio ni valida el total real.** |
| Secuencia | StarterPlayerScripts.AnimacionLetras1v1.obtenerSecuencia, ≈185–200 (Studio) | IDs de animaciones decorativas de letras separados por comas/espacios; no modos, equipos ni cupos. |
| DuracionFase | Mismo script | Segundos de cada paso de una secuencia explícita; tonumber o 4. Si no hay secuencia válida usa la secuencia default con duraciones propias 5/4/4,5 s. |
| TiempoTransicion | AnimacionLetras1v1 callback de render, ≈234–237 | Tiempo de fundido entre animaciones, tonumber o 0,6. No cambia countdown ni matchmaking. |
| ZoneId (opcional) | _registerZone ≈372–386 | Identidad interna; usa atributo no vacío o genera Zone_<nombre> con sufijo si hace falta. La instancia Folder sigue siendo identidad primaria del registro. Un ZoneId explícito repetido no recibe la misma validación de unicidad que el generado: riesgo futuro. |
| Team en pad (opcional) | _registerZone ≈359–368 | Red/Blue identifica lado; también se aceptan nombres que contienen Red/Blue. No se usa en los pads actuales. |

**2,8,7 significa Pulso → Péndulo → Latido**, 4 s cada paso; ciclo decorativo de 12 s con crossfade configurado en 0,6 s. Las secuencias de 1v1 son Rebote/Flotación/Glitch y Rebote/Latido/Glitch respectivamente. No son fases de preparación ni matchmaking.

No se identificó un atributo obsoleto entre esos siete: todos tienen consumidor, pero **tres son exclusivamente decorativos** y TotalPlayers es principalmente presentación. La existencia del atributo no habilita la modalidad.

Falta validación conjunta en el registro de zona: enteros positivos/finitez, MaxPlayersPerTeam≥TeamSize, TotalPlayers=2×TeamSize y consistencia de Mode con TeamSize. AdmitSession sí contrasta tamaño con el modo configurado y ambos arrays exactos, pero no corrige una cola mal configurada. Los cuatro atributos de cola se leen al registrar; no hay observador que reconstruya config al cambiarlos durante runtime. Los decorativos se releen en render.

## D. Colas, reservas y equipos

MatchmakingService.Init ≈316–346 registra **todos los hijos Folder** y escucha altas/bajas dinámicas. No hay lista fija de nombres físicos. Los modos admitidos por RoundService sí están registrados explícitamente en Config. Agregar solo un Folder 3v3 crea una cola registrable si cumple jerarquía/atributos, pero no le da mapa ni habilitación. Un Folder 4v4 puede mostrarse, pero RoundService no conoce ese modo.

La detección consulta GetPartBoundsInBox sobre los Characters: volumen de 6 studs por encima de cada pad, polling cada 0,3 s, Humanoid vivo y Character en Workspace. Deduplica múltiples partes del mismo avatar. Retiene plazas con gracia de 0,8 s; descarta muertos/desconectados sin esa gracia. Ordena candidatos por llegada y desempata por UserId. Evita doble plaza, equipo contrario y candidatos ya ocupantes de otra zona. No hay balance por habilidad, grupos premade ni redistribución automática: **el jugador elige lado al pisar** y las listas son estables mientras conserva plaza.

La cola forma committedRed/committedBlue tomando TeamSize por lado; exige equipos completos/disjuntos y ausencia de sesiones existentes. La reserva copia los arrays, Mode, TeamSize y ZoneId, token GUID, CreatedAt y TTL default 15 s. ValidateReservation compara orden, jugadores, modo, tamaño, zona y vencimiento. Al admitir consume el token; si cambian los ocupantes o vence, la cola invalida/recrea la reserva. PlayerRemoving limpia ocupación/candidatos y fuerza actualización; un cambio de Character se refleja en el detector del Character actual, no en un array de dos jugadores.

Con la configuración 2v2 actual **la estructura de cola admite 2 Red + 2 Blue**, y StartTeamMatch recibe una sola solicitud con cuatro personas. Esto es evidencia estática, no observación de cuatro clientes. QueueSnapshot puede mostrar READY aunque StartTeamMatch devuelva ModeNotPlayable o no haya capacidad global; el mensaje “¡PARTIDA LISTA!” no demuestra que vaya a iniciarse. Los intentos bloqueados se reevalúan mientras la cola sigue lista; el aviso ModeNotPlayable solo se imprime una vez por zona/modo.

## E. RoundService y reglas implementadas

### Admisión y capacidad

RoundService.AdmitSession ≈631–823 acepta arrays por equipo para modos registrados, exige tamaño exacto de cada array, valida conexión, UserIds, duplicados y pertenencia previa. Construye Participants={Player,UserId,Team,Slot,State}, RedTeam/BlueTeam, registro por SessionId/UserId/Player, Score={Red=0,Blue=0} y estadísticas individuales. RedPlayer/BluePlayer se conservan como **alias del primer integrante**, no como únicas fuentes autoritativas en todos los servicios.

_registerSession valida antes de escribir y revierte registros si falla. La reserva es opcional en la API interna; si existe se valida/consume a través de MatchmakingService. No es un remote cliente para elegir libremente sesiones. La admisión estructural no equivale a permiso de jugar.

IsModePlayable ≈614–618 consulta PlayableModes. StartTeamMatch ≈957–960 devuelve **ModeNotPlayable antes de admitir**; _runSession ≈1174–1178 repite el bloqueo defensivo. Config.Round habilita 1v1 y deshabilita 2v2/3v3. _maxConcurrentSessions=1 (≈42,106,557,687,828) permite una sola sesión registrada, incluyendo preparación/resultados/cuarentena. Arena.MaxSlots=100 es capacidad de posiciones físicas potenciales, no cien partidas habilitadas.

### Ciclo, votos y marcador

Estados, hilo, votos y reloj se guardan en la sesión. Las emisiones competitivas usan destinatarios de Participants y SessionId/StateVersion; MatchController también exige pertenencia/identidad y descarta estados viejos.

SubmitMapVote exige sesión/estado y mapa compatible. _resolveMap conserva una rama 1v1 y otra que cuenta votos de participantes activos para XvX, desempate aleatorio entre mapas más votados y elección aleatoria sin votos. No limita el voto a los alias del primer jugador para XvX.

El reloj de Gameplay V2 es **180 s por ronda/jugada**, con nuevo deadline después del reinicio de punto; no necesariamente 180 s totales para toda la partida. A 30 s restantes entra Muerte Súbita. Al expirar, el resultado se determina por marcador compartido, incluido empate. El quinto gol finaliza inmediatamente. Una caída en Muerte Súbita puede resolver la jugada y otorgar un gol al equipo contrario según la configuración existente; no se espera a eliminar a todos sus integrantes.

ScoreService.GetPlayerTeam ≈230–236 resuelve el participante autoritativo. _commitPoint ≈448–548 aumenta score[team], bloquea otra resolución, registra anotador/equipo e informa al grupo. **Un gol de cualquier integrante suma al mismo marcador de su equipo.** Solo el anotador recibe Config.Match.PointReward (**150 Coins actuales**, no los antiguos 50); gol colectivo de Muerte Súbita con scorer=nil concede 0 Coins de gol. La Kill acreditada es independiente, con recompensa actual **30 Coins**, no 50. No se modificaron esos valores.

Después de un gol no final se reposicionan **todos los participantes activos** y reinicia el countdown/reloj. Es el comportamiento implementado, no un reinicio accidental de compañeros por cualquier muerte. El scoring tiene barrera por sesión, resolución de ronda y deduplicación; el polling revisa Red antes que Blue, por lo que contactos simultáneos merecen validación de orden/equidad sin inventar otra regla.

### Eliminaciones y abandonos

CombatService.RegisterHit ≈165–184 exige participantes de la misma sesión y **equipos opuestos**: no hay friendly fire. Tags, historial y acumulación de impactos son por víctima; en XvX varios atacantes pueden contribuir al contador de golpes de la misma vida, y la atribución vigente corresponde al último atacante válido, no a una pareja exclusiva fija. La inmunidad tras impacto es por víctima, con sesión/ronda/Character/generación y deadline; los 3 segundos no se vuelven otra inmunidad distinta por atacante.

EliminationService identifica víctima y equipo por registro; valida KillPart/arena, bloquea eventos repetidos y recuperaciones pendientes, resuelve atacante opuesto, acredita Kill/Coins personales y emite un recibo único. Las caídas normales no inventan Kills. Durante Playing normal usa BeginKillPartRespawn/ResetCharacterInArena **solo para la víctima**, manteniendo el rig existente. No marca al equipo entero eliminado ni termina la partida por una muerte normal. Los compañeros pueden seguir jugando. Humanoid.Died es diagnóstico pasivo Zero-Death; no debe confundirse con una eliminación autoritativa ni prometer recuperación de cualquier muerte física externa.

_handlePlayerLeaving ≈1646–1710 marca Left, libera registros y atributos. Antes de Playing cancela toda la preparación. Durante Playing/PointRestartCountdown cuenta participantes activos: continúa si queda al menos uno en cada equipo; declara contrario ganador si un equipo queda vacío y empate si ambos vacíos. No hay reemplazo ni rebalanceo durante la partida. El desconectado no recibe nuevas estadísticas; _processReward recorre participantes conectados, concede Win/Loss por equipo y deduplica; Draw/Cancelled no dan Win/Loss. El ranking captura todas las filas originales, por lo que debe revisarse la presentación de quien se fue.

**Defecto pendiente concreto:** los tres controles de presencia de _runSession ≈1200,1212,1226 llaman ArePlayersInZone con **session.RedPlayer y session.BluePlayer**, aunque esa API acepta listas. Un segundo integrante puede bajar del pad sin desconectarse mientras los primeros siguen; esos gates no lo verifican. La cancelación por PlayerRemoving no cubre caminar fuera. Deben comprobarse los dos rosters completos; no se cambió aquí.

## F. Arenas, teletransportes y respawn

El DataModel Edit contiene un solo mapa: **ServerStorage.Maps.Levels (Model)**, con Geometry, KillPart, ZoneWin.RedWin/BlueWin y los spawns legacy RedSpawn/BlueSpawn. No dispone de TeamSpawns.Red/Blue con posiciones numeradas válidas. Los legacy están anclados y colisionables, aproximadamente Red=(77.776,12.733,978.836), Blue=(77.776,12.795,1169.512). No persiste el antiguo bloqueo histórico “Maps vacío”: hoy hay Levels.

MatchInstanceService.resolveTeamSpawns ≈27–52 acepta TeamSpawns/Red/1,2,3 y Blue/1,2,3 contiguos; usa legacy por lado únicamente si no encuentra numerados. La capacidad es el mínimo de ambos lados. **El bucle termina en 3**, no N. Valida capacidad requerida, superficies Anchored/CanCollide, Geometry y ZoneWin. GetAvailableMaps(TeamSize) filtra por compatibilidad antes de votar; Levels resulta apto por capacidad para 1v1 y excluido para 2v2/3v3. No se invocó IsMapCompatible contra módulos vivos durante Edit; se verificaron su algoritmo y los objetos.

SpawnService.ResolveParticipantSpawn ≈361–383 enlaza SessionId, jugador, participante Team/Slot e instancia, luego pide el spawn correspondiente; no manda a todo un equipo al legacy del primer integrante. SpawnMatchPlayers ≈776–826 itera Participants, omite Left/Released, contabiliza resultados y cancela la carga si falta colocar a alguien. No debe habilitarse un modo esperando que el sistema coloque a dos en el mismo RedSpawn: **se rechaza la capacidad insuficiente**.

Existe ya el resolver individual para carga, reinicio y recuperación, así que no es necesario inventar otro sistema de respawn para 2v2. Sí se necesitan recursos físicos aprobados con dos posiciones por lado; para 3v3, tres. No hay validación completa de distancia mínima entre spawns: pueden ser Parts distintos pero coincidentes. Anchored/CanCollide no demuestra buena separación, orientación, acceso o ausencia de intersecciones con geometría; es validación manual pendiente.

El retorno al lobby acepta arrays y restaura locomoción/rigs, cancela recuperación y retira identidad. La distribución final en un único Lobby.SpawnLocation puede superponer jugadores momentáneamente; es una limitación de presentación/física a probar, distinta de los spawns competitivos.

## G. HUD y presentación de equipos

MatchmakingController._handleQueueStatus ≈175–259 muestra currentTotal/TotalPlayers y crea TeamSize slots por lado: admite 2/4, cuatro slots y la etiqueta 3v3 sin reescribir una lista de jugadores. Con READY reemplaza el contador por “¡PARTIDA LISTA!”, no muestra literalmente 4/4. Oculta headers Red/Blue en _bindHUD: el lado y color son los indicadores de equipo.

En Edit, los SlotsContainer y ambos equipos son AutomaticSize.X con UIListLayout horizontal; la plantilla mide **400 px de ancho**. Para 2v2 el contenido de cuatro slots ronda 1600 px más separaciones; para 3v3 supera 2400 px antes de escalado. No hay ajuste por TeamSize en el código inspeccionado. La estructura es genérica, pero **no se acredita que entre visualmente en PC pequeño/móvil**. Se necesita validar el escalado/layout actual y solo después autorizar ajustes. No se tocó diseño.

MatchController._populatePlayers ≈662–715 clona todos los RedTeam/BlueTeam snapshots; los alias Red/Blue son fallback. MatchHUD tiene PlayersContainer por lado de 160 px y plantilla de 34 px de alto; el código no fija una única fila. Marcador, countdown y temporizador son de sesión/equipo, SuddenDeathHUD está presente. Los avatares con UserId negativo no usan la miniatura web de IDs positivos: puede quedar imagen genérica en Studio; no equivale a ausencia del participante.

Riesgo adicional: snapshots de equipo se toman de los arrays originales y la lista visible se repuebla sobre todo al cambiar a Playing. Al abandonar un integrante no hay una actualización dedicada de roster visible en esa ruta; puede quedar un slot desactualizado hasta otra transición. Esto no cambia la pertenencia autoritativa.

## H. EndCinematic y finalización

RoundService.BeginSessionResults ≈1823–1967 congela competición, captura ranking, recorre Participants y prepara viewers conectados. Todos los miembros del equipo ganador entran en Winners; emite Prepare/Start solo a esos participantes autorizados, con LocalTeam, SessionId, StateVersion y token. Resultados/retorno pueden manejar varios espectadores y salidas individuales.

EndCinematicRanking.Build guarda **todas** las filas, distingue equipo y ganador, MVP individual y selección visible con prioridad del equipo vencedor. La escena Edit tiene **cinco SlotPlayer**. El ranking limita visibles a min(5, MaxVisible, Ranking.MaxVisible). Para 2v2 caben cuatro; para 3v3 se conservan seis entradas pero solo cinco rigs/billboards visibles. Los tres ganadores caben si hay resultado ganador; no puede afirmarse que aparezcan simultáneamente los seis participantes. Modos con más de cinco ganadores superan además la validación de Winners del controlador.

Draw es un resultado aceptado explícitamente; no fabrica Winners. En XvX puede seleccionar participantes por ranking sin ganador; en la rama 1v1 el filtro de visibles prioriza solo ganadores, por lo que un empate puede quedar sin rigs de participantes. Es una dependencia visual a validar, no motivo para cambiar reglas en esta auditoría.

EndCinematicController.Play ≈93–119 exige contexto autorizado para partida; previews solo Studio y sin MatchId activo. Los módulos de cámara y avatares trabajan sobre recursos locales del run; Stop cancela conexiones/tweens y limpia subsistemas. La cámara no obtiene autorización por compartir equipo solamente. El scoreboard cinematográfico no obliga a tener un único vencedor y perdedor; los nombres legacy no prueban esa restricción.

CloseSession ≈2003–2144 coordina stop scoring, recompensas, habilidades, eliminaciones, tags, retorno de todos los viewers/participantes, Slaps, identidad, mapa/slot y recursos. Solo libera registros al completar los pasos críticos; si falla, retiene la sesión en cuarentena. Eso protege de reaperturas parciales pero **bloquea toda la capacidad del servidor** con maxConcurrentSessions=1. Sigue pendiente validar esa limpieza integral con 4/6 clientes reales.

## I. Impedimentos concretos y alcance del cambio necesario

| Prioridad | Archivo / función / ubicación aprox. | Comportamiento actual y efecto | Cambio necesario, NO ejecutado |
|---|---|---|---|
| Bloqueo directo 2v2/3v3 | Config.luau:14–18; RoundService.IsModePlayable:614; StartTeamMatch:957; _runSession:1174 | Solo 1v1 jugable; devuelve ModeNotPlayable | Autorizar habilitación individual después de preparar recursos y corregir gates; conservar defensa común |
| Bloqueo físico 2v2/3v3 | ServerStorage.Maps.Levels; MatchInstanceService.resolveTeamSpawns:27/_validateMapTemplate:141 | Capacidad 1; GetAvailableMaps excluye el único mapa para equipos mayores | Añadir spawns aprobados 1..2 o 1..3 por lado, separados y seguros, sin destruir arte existente |
| Integridad de preparación | RoundService._runSession:1200/1212/1226 | Solo confirma presencia del primer Red/Blue | Pasar y validar ambos equipos completos durante preparación y antes del compromiso |
| Cola 3v3 inexistente | Workspace.ZoneMatchmaking + _registerZone:349 | No hay zona física 3v3 | Crear/configurar su jerarquía aprobada y validar contrato; no basta clonar el nombre |
| Config inconsistente tolerada | MatchmakingService.getZoneConfiguration:257/_registerZone:353 | No valida enteros ni relaciones entre los tres campos de cupo | Validación fail-closed y diagnóstico por zona, preservando defaults compatibles 1v1 |
| Legibilidad XvX sin verificar | MatchmakingController._handleQueueStatus:239; PlayerSlotTemplate físico | Slots horizontales de 400 px, expansión por cantidad | Validación PC/móvil y eventual layout adaptable autorizado; no bloquea admisión por sí mismo |
| Generalización N>3 | MatchInstanceService.resolveTeamSpawns:34 | Lee solo 1..3 aunque haya un cuarto spawn | Resolver capacidad genérica acotada y validada; configurar modos explícitamente |
| Todos visibles en 3v3/N | EndCinematicRanking.Build:42; escenario físico/EndCinematicController.Play:105 | Cinco rigs visibles y máximo cinco ganadores | Decidir si política actual de top visibles es aceptable; para mostrar todos, ampliar/paginar recursos y contrato bajo autorización |
| Aceptación funcional pendiente | tests/TeamAdmission.spec.luau, Phase2D.spec.luau y regresiones multicliente | Existen specs estructurales pero no se ejecutó aquí un 2v2/3v3 real completo | Ejecutar pruebas aisladas específicas y validación humana de cuatro clientes, luego seis; no etiquetar PASS por compilación |

El límite de una sesión no figura como impedimento para una partida XvX. Tampoco faltan desde cero scoring por equipo, votación de todos, registro de participantes, resolver individual o retorno de arrays.

## J. Riesgos e incertidumbres

1. Salida caminando del segundo integrante durante countdown no cubierta por los gates legacy; diferencia importante frente a desconexión, que sí cancela.
2. READY visual con modo deshabilitado o servidor ocupado; el usuario puede interpretar inicio inminente aunque no ocurra.
3. Configuración inconsistente/ZoneIds explícitos repetidos y carpetas decorativas registradas pueden producir diagnósticos engañosos y snapshots ambiguos; Pisos es el ejemplo físico actual de registro sin pads.
4. Simultaneidad de goles/caídas: primera resolución cierra la jugada; Red se comprueba antes en polling. No se propone cambiar reglas; hay que probar y documentar la prioridad efectiva.
5. Varios atacantes sobre una víctima comparten contador/tag e inmunidad. Debe validarse la eliminación única, atribución, Coins y transición entre generaciones con cuatro clientes, sin suponer combate de parejas aisladas.
6. Slap/equipamiento y ciertas presentaciones aún iteran RedTeam/BlueTeam como arrays originales; tras abandono pueden quedar referencias al desconectado aunque Participants ya lo rechace. Revisar re-equip/reinicio y slots desactualizados antes de considerar cerrada esa regresión.
7. Cooldowns/Abilities se guardan por jugador dentro de sesión; Invisibility presenta efectos a todos los participantes de la sesión, incluidos compañeros, con limpieza por ActivationId/generación. No hay una excepción de visibilidad de aliados demostrada ni se inventa ahora. Probar que no colisione con ocultamiento de resultados/cajas.
8. Ragdoll es por Character y respawns por jugador/generación; los resets colectivos se reservan al gol/cambio de ronda. Una muerte física externa Humanoid.Died es solo diagnóstico y no está certificada como recuperación XvX.
9. _currentSession/GetSession y adaptadores legacy siguen existiendo. Con una sola sesión son compatibles con el alcance, pero antes de habilitar concurrencia hay que auditar consumidores restantes. No extrapolar aislamiento por mapas a concurrencia lista.
10. Cinco slots cinematográficos no garantizan seis representaciones ni ganadores arbitrarios; UI horizontal puede desbordar. Los límites visuales son distintos de los competitivos.
11. No existe medición runtime actual de latencia, colisiones, rendimiento, cámara, móviles o limpieza multicliente. No presentar el código compilado como esa evidencia.

## K. Roadmap propuesto, sin ejecución

1. **Preservar 1v1:** guardar baseline/arte y confirmar casos humanos actuales; añadir en una fase autorizada pruebas aisladas de admisión, rollback y cierre con el código vigente. Mantener concurrencia=1 y persistencia Studio aislada.
2. **Preparación mínima 2v2:** validar contrato de zona, corregir gates de rosters completos y preparar un mapa con dos spawns seguros por equipo. Revisar referencias Left en re-equip/roster y legibilidad de cuatro slots. Agregar pruebas nuevas únicamente con autorización de implementación.
3. **Habilitación controlada 2v2:** activar solo PlayableModes["2v2"] en un entorno acordado; mantener 3v3/N bloqueados y una sola sesión. Verificar conteos, reserva, salida del segundo jugador, votos, spawn y Slaps antes de combate.
4. **Validación manual 2v2 por el desarrollador:** cuatro clientes, repetir dos partidas completas; friendly fire rechazado, hit entre cualquiera de los equipos, inmunidad/tercera palmada única, muerte individual con compañero activo, gol compartido/premio personal, reinicio de cuatro, timeout/empate/Muerte Súbita, abandono parcial/total, cuatro resultados y retorno/limpieza. Un quinto cliente en lobby no debe recibir HUD/cámara ajenos. Logs con SessionId/Team/Slot/StateVersion/EliminationId y conteos de recursos. No ejecutar esta lista durante la auditoría.
5. **Generalización 3v3:** después de aprobar 2v2, zona 3v3 y mapa con tres posiciones por lado; revisar capacidad HUD y aceptar expresamente cinco visibles o implementar otra presentación. Pruebas con seis clientes, mismas barreras de seguridad y repetición.
6. **Futuras XvX:** contrato y capacidades genéricos, resolver de spawns sin el 1..3 fijo, catálogo explícito de modalidades y capacidad de presentación. Separar este trabajo de una eventual concurrencia entre partidas, que requiere auditoría propia.

### Respuestas expresas a las 17 preguntas

1. **¿Zona 2v2 correcta?** Sus cuatro atributos de modalidad/cupo son consistentes 2/2/4 y sus pads Red/Blue son detectables. No está operativa de extremo a extremo: flag bloqueado, mapa insuficiente y aceptación visual pendiente.
2. **¿Se usan todos sus atributos?** Sí tienen consumidor; los tres de animación son decoración independiente. TotalPlayers no impone capacidad ni habilita el modo.
3. **¿Cola de cuatro?** Sí en estructura/detector por capacidad; no se observó ejecución multicliente en esta auditoría.
4. **¿Dos equipos de dos?** Así construye committedRed/Blue y el request único; asignación por pad/FIFO, no balance por habilidad. Falta observación real.
5. **¿RoundService permite 2v2?** AdmitSession lo admite estructuralmente; StartTeamMatch/_runSession lo bloquean para jugar.
6. **¿Bloqueo fuera de 1v1?** Sí, PlayableModes false y ModeNotPlayable; modos desconocidos tampoco tienen contrato registrado.
7. **¿Spawns suficientes?** No: Levels solo capacidad 1. El resolver ya admite múltiples posiciones numeradas hasta tres.
8. **¿HUD soporta equipos?** Sí sus datos/slots y marcador; no está certificada legibilidad de cuatro/seis tarjetas en el layout actual.
9. **¿Puntuación por equipos?** Sí, score.Red/Blue compartido; anotador y premio siguen personales. Requiere prueba integral XvX.
10. **¿Muere un integrante?** Eliminación normal autoritativa recupera solo ese jugador; compañero continúa. En Muerte Súbita la caída puede conceder gol contrario y reiniciar/cerrar jugada; Humanoid.Died externo es diagnóstico.
11. **¿Abandona un integrante?** Antes de Playing cancela; jugando continúa si ambos equipos conservan alguien, o resultado al quedar vacío. Sin backfill ni rebalanceo.
12. **¿EndCinematic para cuatro?** Tiene contrato/recursos para cuatro filas/rigs y equipo ganador múltiple; no validado aquí mediante partida real. Para seis conserva ranking pero cinco visibles.
13. **¿Qué está listo estructuralmente?** Colas listas, reservas, admisión/rollback, identidad Team/Slot, combate opuesto, scoring compartido, votos colectivos, respawn individual, resultados/limpieza iterativos.
14. **¿Qué falta?** Gates completos de presencia, mapa XvX, habilitación controlada, validación de atributos, aceptación visual y regresión real; para 3v3 además zona y decisión sobre seis participantes/cinco visibles.
15. **¿Cambio mínimo para empezar 2v2?** Corregir las tres llamadas de presencia, disponer de dos spawns por lado y autorizar PlayableModes 2v2; mantener una sesión. Eso permite empezar a probar, no aprobar soporte final. Validación de contrato/UI es parte del cierre de calidad.
16. **¿Generalizar 3v3?** Zona y spawns 1..3, habilitación individual tras aprobar 2v2, adaptación/aceptación de HUD/resultados y seis clientes. Para N>3 hace falta además eliminar el límite duro del resolver y registrar el modo.
17. **¿Porcentaje aproximado?** Estimación cualitativa **65–75% de la infraestructura necesaria para un primer XvX 2v2/3v3**: colas/reservas, registros, combate, scoring y recuperación ya están generalizados; recursos físicos, gates de preparación y presentación/validación están incompletos. No es una medición de líneas, calidad ni probabilidad de funcionar. Para N arbitrario la cobertura es menor por límites duros; la aceptación integral XvX sigue pendiente y no se convierte en un porcentaje de partidas aprobadas.

## Verificaciones ejecutadas y límites de evidencia

| Check ejecutado durante esta auditoría | Resultado |
|---|---|
| Compilador Luau sobre todos los scripts src | PASS, sin errores de compilación |
| SlapVictimProtection existente | PASS, 150 aserciones aisladas |
| AbilityMultiplayerFixV1.regression existente | PASS, 164 aserciones aisladas |
| EconomyBalanceV1 existente | PASS, 30 aserciones aisladas |
| PremiumShopV11 existente | PASS, 93 aserciones aisladas; protección de monetización, no soporte XvX |
| Ambos builds Rojo actuales, sin regenerar configuraciones | PASS |
| git diff --check | PASS; advertencias preexistentes de normalización LF/CRLF, no errores whitespace |
| Inspección de Attributes, pads, mapa y HUD/cinemática en Edit | Realizada, sin escribir propiedades ni instancias |
| TeamAdmission/Phase2D/GameplayV2/EndCinematicV14 sobre servicios vivos | NOT RUN: requieren harness específico; no se alteró ni inicializó Studio para ejecutarlos |
| 2v2/3v3 real, colisiones, UI renderizada, dos partidas y limpieza runtime | NOT RUN por restricción expresa |

Total de esta ejecución: **437 aserciones aisladas**. No se añadieron ni modificaron tests. Los tests estructurales históricos se leyeron como evidencia de cobertura preparada, no como aprobación actual. Las referencias a 1v1 en comentarios/alias se distinguen de bloqueos ejecutables: hay comentarios antiguos que ya no describen todas las colecciones actuales.

Verificación final: los hashes de los **218 archivos src/configuración presentes al comenzar** permanecen idénticos, sin altas dentro de ese conjunto. Studio seguía en Edit, ActiveMatches=0 y los siete atributos de la zona 2v2 conservaban sus valores. Un intento de git diff --check dentro del sandbox no reconoció el work tree; la comprobación desde el directorio explícito del repositorio se ejecutó por separado.

Se detiene el trabajo aquí. No se autoriza ni ejecuta ninguno de los cambios propuestos.
