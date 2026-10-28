# Matchmaking XvX V1.0 — migración y habilitación de 2v2

Fecha: 2026-10-20. **Implementado y sincronizado en Edit; aceptación funcional pendiente del desarrollador.** No se ejecutó Play, Run, Start Server, Team Test, control de personajes, publicación, commit, push ni escritura cloud.

## Resultado

- 1v1 y 2v2 habilitados en Config.Round.PlayableModes. 3v3 y 4v4 explícitamente false; otros modos continúan sin autorización. Config.Matchmaking.Modes no incorpora un nuevo modo 4v4.
- _maxConcurrentSessions sigue en **1**. El tamaño de equipo es independiente de esa capacidad.
- Resolver nuevo: MapModel.RedTeam/BlueTeam.SpawnN, genérico por índice positivo, hasta una cota defensiva de 1024 marcadores. No hay cuatro implementaciones por modalidad ni un límite funcional de tres spawns.
- 1v1 utiliza Spawn1 por equipo; 2v2 usa Spawn1 y Spawn2. Las posiciones 3/4 están disponibles en el contrato, pero no habilitan sus modalidades.
- No existe fallback que busque RedSpawn, BlueSpawn ni TeamSpawns/Red/1 del contrato anterior. No se recrearon los Parts eliminados.
- Los cuatro participantes se validan por roster completo, sesión, registro autoritativo, Team/Slot y conexión; el Character se comprueba después del posicionamiento y durante el countdown final. Se conserva el mecanismo existente para preparar/esperar Characters durante el teleport.
- Los tres gates de presencia comprueban ambos equipos completos; salir caminando del segundo integrante ahora invalida la preparación.
- SpawnMatchPlayers resuelve todos los destinos antes de mover a nadie; falla la carga si falta un destino o un teleport. Solo entrega Slaps a los participantes colocados. La preparación no entra en Playing si queda incompleta.

## Rutas antiguas y nueva arquitectura

La resolución anterior estaba en MatchInstanceService.resolveTeamSpawns: TeamSpawns/Red/1..3 y Blue/1..3, con fallback a Parts directos RedSpawn/BlueSpawn. No se encontró una dependencia necesaria del runtime a Workspace.Levels.RedSpawn/BlueSpawn: el juego selecciona plantillas de **ServerStorage.Maps** y las clona dentro de Workspace.ActiveMatches.Match_<SessionId>.

Ahora TeamSpawnResolver.Resolve recibe el modelo seleccionado y la capacidad requerida. Exige carpetas Folder por equipo, BaseParts con nombres SpawnN y un rango contiguo sin IDs duplicados; rechaza carpetas/Parts inválidos o posiciones faltantes con errores MissingTeamFolder, MissingSpawn, InvalidSpawnPart, DuplicateSpawn o InvalidRequiredTeamSize. No exige SpawnLocation ni CanCollide=true: los marcadores actuales son referencias invisibles, no superficies de apoyo. No escribe CFrame, Size, orientación ni propiedades de esos objetos.

IsMapCompatible filtra mapas para el tamaño solicitado y emite un diagnóstico claro de incompatibilidad, deduplicado por mapa/tamaño/causa. Los errores no se ocultan únicamente detrás de “No maps available”.

MatchInstanceService guarda TeamSpawns[Red/Blue] en la instancia clonada. GetSpawnPoint(SessionId, Team, Slot) determina el destino. Los campos internos RedSpawn/BlueSpawn de MatchInstanceInfo quedan como aliases derivados de la primera entrada para conservar el contrato tipado existente; **no buscan ni requieren Parts con esos nombres**. GetSpawnPoints y SpawnService ya obtienen la primera posición desde TeamSpawns.

El CFrame completo del marcador se conserva y el mecanismo existente aplica el margen vertical para el rig. Al mover el mapa completo a su ArenaSlot se transforman también sus marcadores, manteniendo relaciones y orientación. No se usan coordenadas absolutas del Levels de edición en la lógica de spawn.

## Mapa físico y respaldo

Al comenzar había **dos modelos llamados Workspace.Levels**. El primero contenía los spawns antiguos; el segundo contenía las carpetas y los ocho marcadores indicados por el desarrollador. Se recorrieron todos los candidatos y se seleccionó inequívocamente el de BlueTeam y RedTeam; no se dependió de FindFirstChild("Levels") para elegir esa fuente.

Se respaldaron ambos modelos antes de instalar la plantilla:

`H:\repos-github\SlapDuels-2.0\tests\assets\backups\MatchmakingXVXV10`

Archivos principales:

- Levels-current.rbxm: modelo actualizado, 152 descendientes.
- Levels-legacy.rbxm: candidato antiguo, 241 descendientes.
- maps.manifest.json: hashes y CFrames/propiedades de los ocho spawns nuevos.
- maps.before.json: serialización nativa base64 del respaldo.
- Copias anteriores de fuentes y configuraciones, más src-hashes.before.json.

SHA-256 del modelo actualizado: `a1da792e7d79b65b85f78fb2919aa4f35da996d504698b6e97f00c1bcd0aceb2`.

El hash nativo del **modelo original actualizado de Workspace siguió siendo idéntico** en la verificación final: no se movieron, rotaron, recrearon ni editaron los ocho spawns. En la última consulta solo apareció el modelo actualizado en Workspace; este trabajo no ejecutó ninguna eliminación del candidato antiguo. Su respaldo sigue conservado.

Se creó la plantilla de selección **ServerStorage.Maps.Levels** mediante clonación del modelo actualizado, sin mover el original. La carpeta Maps existía y no tenía una plantilla Levels antes de esa instalación. Se verificaron ocho CFrames y Sizes contra la fuente. La copia de plantilla es necesaria para el flujo existente de selección/instanciación; no reemplaza los originales editados por el desarrollador.

Rutas de plantilla instaladas y comprobadas en Edit:

| Equipo | Rutas |
|---|---|
| Red | ServerStorage.Maps.Levels.RedTeam.Spawn1, Spawn2, Spawn3, Spawn4 |
| Blue | ServerStorage.Maps.Levels.BlueTeam.Spawn1, Spawn2, Spawn3, Spawn4 |

Todos conservan Anchored=true, Transparency=1 y CanCollide=false. CanTouch/CanQuery y dimensiones también se preservan. La comparación binaria del modelo original cubre el conjunto completo de sus propiedades serializadas.

Se exportó esa fuente a **src/assets/Maps/Levels.rbxm**, idéntica byte a byte al respaldo Levels-current.rbxm, y se añadió el mapping ServerStorage.Maps.Levels en default.project.json. El build completo contiene los ocho SpawnParts y ningún Part directo RedSpawn/BlueSpawn en esa plantilla. Los Levels de Workspace no están mapeados ni fueron reemplazados mediante Rojo.

La sincronización fue puntual mediante MCP, con validación de hashes de Source y editor drafts; no se aplicó una sincronización completa que pudiera restaurar recursos antiguos. SAFE continúa solo scripts y conserva objetos desconocidos; se regeneró para incluir TeamSpawnResolver. Ningún recurso Shop/Premium/Crates/HUD/cinemático fue sobrescrito.

**Mantenimiento:** si volvés a ajustar artísticamente Workspace.Levels después de esta exportación, será necesario actualizar de nuevo la plantilla/snapshot desde esa versión. El runtime no lee dinámicamente el modelo de edición en Workspace. Evitar duplicados con el mismo nombre facilita identificar la fuente; no se ejecuta una limpieza no solicitada.

## Participantes, respawns y reglas conservadas

AdmitSession ya asigna Slot estable según el orden autoritativo de RedTeam/BlueTeam, no según los hijos de los Folders. ValidatePreparationParticipants comprueba que cada slot conserve su Player/Team/registro, y GetSessionParticipant rechaza desconexiones, otro registro o participantes Left/Released.

La resolución numérica no depende del orden de GetChildren(): el harness suministra los hijos deliberadamente en orden inverso y obtiene Spawn1/Spawn2 correctos. Un abandono no compacta los slots de quienes permanecen.

ResolveParticipantSpawn se utiliza en carga inicial, SpawnPlayerInMatch y ResetCharacterInArena. KillPart conserva su recuperación individual, generación y pipeline: se conecta al mismo destino Team/Slot sin modificar retrasos, física ni economía. El reset de posiciones después de un gol recorre los participantes activos; una eliminación individual no teletransporta al compañero.

El abandono durante preparación utiliza cancelación/CloseSession existentes. Durante Playing se conserva la regla de continuar si queda alguien en cada equipo y resolver cuando un equipo se vacía. No se añadieron sustituciones ni balanceo automático.

No cambiaron ScoreService, CombatService, EliminationService, PlayerService ni economía:

- Gol: marcador compartido de equipo, +150 Coins solo al anotador acreditado.
- Kill: +30 Coins solo al atacante acreditado; caída sin atacante, 0 por Kill.
- Ronda de 180 segundos; Muerte Súbita en últimos 30; reinicio tras gol, acumulación hasta cinco y resolución por tiempo/empate.
- Equipamiento, protección de víctima, tres golpes, Kills, Death Effects y recompensas conservan sus servicios actuales.

## EndCinematic

Sin cambios de diseño ni código cinematográfico. Se verificó el contrato existente: captura todos los participantes y sus estadísticas, equipo ganador común, viewers autorizados y retorno individual/colectivo con cierre idempotente. El algoritmo real de ranking representa cuatro participantes en 2v2 y también cuatro en empate. Las pruebas nuevas ejercitan esa construcción; **no equivalen a haber visto cuatro rigs renderizados en una partida real**.

Win/Loss se aplica una vez a cada participante conectado correspondiente; el integrante desconectado queda excluido. El harness verifica el procesamiento repetido de un resultado de equipo sin duplicar esas estadísticas. La limitación de cinco visibles para seis permanece fuera del alcance, con 3v3 deshabilitado.

## Archivos cambiados

Fuentes preexistentes modificadas:

1. src/shared/Config.luau: habilitar 2v2 y explicitar 4v4=false; valores económicos sin cambios.
2. src/server/Services/MatchInstanceService.luau: nuevo resolver, validación y diagnóstico de plantilla, accesos derivados a primer spawn.
3. src/server/Services/SpawnService.luau: preflight de destinos del lote y entrega de Slaps únicamente a PlacedPlayers.
4. src/server/Services/RoundService.luau: validación de preparación y presencia de ambos rosters completos.

Nuevo: src/server/Services/TeamSpawnResolver.luau. También se añadió src/assets/Maps/Levels.rbxm, mapping del recurso en default.project.json, actualización SAFE y pruebas/evidencia de esta tarea.

La comparación contra el inicio encontró **solo esas cuatro fuentes preexistentes modificadas**; los otros **211 archivos src preexistentes** permanecen idénticos. No se modificaron MatchmakingService, ZoneMatchmaking ni sus siete atributos, HUDs, EndCinematic, economía, Slap Crates o Premium Shop.

## Pruebas y evidencia

**49 aserciones nuevas** sobre módulos reales con dependencias físicas/scheduler sustituidas por fixtures de tablas. No se inicializaron servicios de producción ni se invocó Bootstrap. Los módulos de spawns, instancia, RoundService, ScoreService, configuración, ranking y matchmaking se cargan desde las fuentes actuales.

Regresiones existentes ejecutadas: SlapVictimProtection 150; AbilityMultiplayerFixV1.regression 164; EconomyBalanceV1 30; EconomyBalanceV1.shop 86; PremiumShopV11 93. **Total: 572 aserciones aisladas aprobadas**.

| # | Comprobación solicitada | Evidencia / resultado |
|---:|---|---|
| 1 | Resolución 1v1 | PASS aislado: índice 1 por equipo |
| 2 | Resolución 2v2 | PASS aislado: índices 1/2, destinos distintos |
| 3 | Preparación de cuatro | PASS aislado: cuatro válidos; cuarto desconectado o segundo sin Character rechazan |
| 4 | Dos integrantes por equipo | PASS aislado: AdmitSession real, Team y Slot |
| 5 | Orden estable | PASS aislado: hijos en orden inverso no alteran asignación |
| 6 | Respawn asignado | PASS aislado del resolver autoritativo que usa ResetCharacterInArena; física/recuperación real NOT RUN |
| 7 | Reinicio tras gol | PASS aislado: lote repetido conserva destinos; commit usa reinicio existente |
| 8 | Spawn faltante | PASS aislado: error y preflight sin teleport parcial |
| 9 | Folder faltante | PASS aislado: rechazo |
| 10 | Part inválido | PASS aislado: rechazo; también índice duplicado |
| 11 | Mapa incompatible | PASS aislado: capacidad insuficiente excluida |
| 12 | Cancelación de preparación | PASS aislado: gate de roster y cancelación 1v1 retornan/liberan registros; flujo de cuatro clientes NOT RUN |
| 13 | Abandono parcial | PASS aislado: compañero conserva sesión y slot |
| 14 | Marcador compartido | PASS aislado: commit a Score.Blue común |
| 15 | Gol personal correcto | PASS aislado nuevo + EconomyBalance: +150 solo anotador |
| 16 | Kill personal correcta | PASS suite EconomyBalanceV1: AwardConfirmedKill +30, caída no acreditada 0 |
| 17 | Sin duplicar recompensas | PASS: resultado Win/Loss repetido; suite existente verifica IDs repetidos de gol/Kill |
| 18 | Fin de partida | PASS aislado: quinto gol llama resolución existente; partida completa NOT RUN |
| 19 | Cinemática de cuatro | PASS ranking real en victoria/empate; presentación visual y cámaras NOT RUN |
| 20 | Limpieza | PASS CloseSession real con adaptadores: retorno de participantes restantes, liberación de registros y repetición idempotente; recursos Roblox runtime NOT RUN |
| 21 | Protección 1v1 | PASS admisión/Slot1/cancelación y regresiones; partida manual pendiente |
| 22 | 3v3 deshabilitado | PASS configuración real e IsModePlayable |
| 23 | 4v4 deshabilitado | PASS configuración real e IsModePlayable |
| 24 | Mapas futuros | PASS otro Model con mismo contrato, capacidad 4, sin ruta fija Workspace.Levels |

Compilación Luau: **162 scripts** y spec nueva, PASS. Ambos builds Rojo: PASS. git diff --check: PASS; advertencias LF/CRLF del working tree no son errores whitespace. No se hizo commit ni normalización masiva.

Evidencia: MatchmakingXVXV10.results.txt, logs de compilación/builds/regresiones, MatchmakingXVXV10.checks.json y MatchmakingXVXV10.studio-edit.json. La persistencia observada en Edit continuó **Studio / InMemory / WritesToCloud=false**, sin partidas activas. El resolver puro se inspeccionó sobre la plantilla física en Edit y devolvió capacidad 4; no se requirieron RoundService/Bootstrap para ejecutar un juego en Studio.

## Guía de validación manual — desarrollador

No cambiar flags de persistencia. En tu próximo Play/servidor de prueba, confirmar primero Studio/InMemory/WritesToCloud=false. Las fuentes editadas se cargarán en ese nuevo runtime; no reutilizar un servidor iniciado antes de sincronizar.

### 1v1: dos clientes

1. Entrar en una cola 1v1 y completar countdown/votación de Levels.
2. Confirmar RedTeam.Spawn1 y BlueTeam.Spawn1 dentro del **mapa clonado en ActiveMatches**, orientación correcta y Slap equipado/bloqueado. Los spawns originales de Workspace no se mueven al ArenaSlot.
3. Probar golpe válido, protección de víctima, tercer golpe, caída sin atacante y recuperación en Spawn1.
4. Anotar: marcador del lado correcto, +150 solo anotador, reposicionamiento de ambos y nuevo reloj 3:00. Kill acreditada +30; contacto repetido no duplica.
5. Completar a cinco y revisar resultados, equipo ganador, retorno, retirada del Slap y ActiveMatches vacío. Repetir o comprobar empate/timeout/Muerte Súbita según corresponda.

### 2v2: cuatro clientes y opcional observador

1. Entrar dos en Red y dos en Blue de la zona existente. Nadie debe iniciar con solo tres. Capturar cupos y cuatro identidades en Output.
2. Durante countdown, hacer bajar del pad al **segundo** Red o Blue: debe cancelarse toda la preparación y liberar plazas. Repetir desconectando un integrante. Volver a formar cuatro para continuar.
3. Votar con los cuatro y confirmar asignación estable Red1/Red2 y Blue1/Blue2 en una sola sesión; no intercambiar compañeros ni amontonarlos en Spawn1.
4. Eliminar/caer con un integrante: solo él se recupera en su SpawnN; compañero sigue jugando. Repetir con el segundo de ambos equipos. Verificar friendly fire rechazado y que varios atacantes no dupliquen eliminación/Coins.
5. Gol del segundo integrante: marcador común para los dos, premio personal +150 y reinicio de los cuatro en sus mismos índices. Repetir desde el otro equipo.
6. Probar abandono parcial durante Playing: el compañero continúa; vaciar un equipo termina según regla vigente. Comprobar que no se reasigna el slot del superviviente.
7. Completar partida normal, empate/timeout y Muerte Súbita; revisar cuatro participantes representados en resultados, premios sin duplicados y retorno de todos. El cliente ajeno no debe recibir HUD/cámara de la partida.
8. Repetir otra partida, comprobar ActiveMatches vacío tras cierre y ausencia de Slaps, locks, HUD o conexiones residuales. Revisar disposición de las cuatro tarjetas en PC/móvil; el riesgo de ancho del HUD identificado en la auditoría sigue necesitando validación visual.

Si falla algo, enviar Output del servidor y cliente con SessionId, Team/Slot, motivo de preparación/spawn, score/recompensa y paso exacto. No declarar PASS funcional solamente porque un build o el harness haya pasado.

## Pendientes

- Validación humana integral 1v1/2v2, física, tiempos, streaming, HUD/cámaras y repetición con clientes reales.
- Cualquier ajuste artístico futuro debe exportarse desde la versión actual de Studio al snapshot/plantilla; no mezclar con snapshots antiguos.
- 3v3/4v4, concurrencia adicional y rediseño de UI/cinemática permanecen fuera del alcance. No se activan automáticamente por tener cuatro spawns.

Se detiene la implementación para la validación manual del desarrollador.
