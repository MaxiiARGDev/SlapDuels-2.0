# EndCinematic V1.4 — informe técnico

Fecha: 2026-10-16, contexto horario America/Buenos_Aires. Implementado sobre el estado actual de V1.3.1. Se preservaron los IDs whoosh configurados por el desarrollador, su normalización, MusicController.Suspend/Resume y las posiciones actuales de ScenarioFinal. No se reutilizaron fuentes antiguas de V1.3 para sobrescribir esas mejoras.

## Arquitectura y autoridad

EndCinematicController conserva la coordinación de transición, audio, música, avatares, partículas, cámara, HUD y retorno. Se incorporan EndCinematicRanking y EndCinematicBillboards. El algoritmo puro de ranking está en `ReplicatedStorage.Shared.EndCinematicRanking`; el módulo cliente homónimo es un adaptador a esa única implementación. RoundService construye el snapshot una sola vez después de fijar resultado/Ending y antes de limpiar estadísticas. Los clientes validan identidad/versión y presentan el resultado; no envían estadísticas ni deciden MVP.

Resultado de equipo, ranking individual, selección visible y slots son datos distintos. `ResultSnapshot` incluye SessionId, StateVersion, WinningTeam, Entries completas, VisibleParticipants, MVPUserId y SelectionPolicy. Sus tablas del servidor se congelan y se separan de las referencias mutables de la partida. Los remotes existentes mantienen sus destinatarios privados, token y versión. No se agregan llamadas de red por Billboard.

En 1v1 se conserva un único ganador y CameraCheck-Only1V1. Los Billboards están deshabilitados por defecto en ese modo. En 2v2/3v3/XvX de preview se muestra ranking y se usa CameraCheck-v2. No se habilitan esas modalidades competitivas.

## Estadísticas de partida

La auditoría encontró marcador por equipo, anotador del punto actual y Kills históricas en PlayerService. No había un acumulador individual Goals/Kills/Deaths de MatchSession. No se copian los totales persistentes.

Cada participante admitido recibe `MatchStats = { Goals=0, Kills=0, Deaths=0 }`, nuevo para esa partida. Los ceros corresponden a un contador existente e inicializado; un campo no disponible en snapshots antiguos permanece nil y se oculta, nunca se sustituye por cero.

- Goals: ScoreService lo registra después de aceptar atómicamente el gol, antes de declarar el resultado final. Se reutiliza el ID del marcador de esa jugada para deduplicar.
- Kills: EliminationService lo registra para el atacante cuando ya se aceptó una CombatElimination válida y se marcó su EliminationId como resuelto.
- Deaths: eliminaciones competitivas sufridas por la víctima de ese mismo evento. Es una estadística temporal de bajas competitivas; no implica matar al Humanoid. Las caídas normales del sistema Zero-Death no cuentan como Deaths.
- RoundService.RecordMatchPerformance valida sesión vigente, participantes y evento único. Tras congelar el resultado rechaza cualquier incremento.
- MatchPoints: no existe una métrica de rendimiento de partida definida. Se deja ausente y su etiqueta se oculta. Coins no interviene en el ranking.

Los hooks observan eventos que el sistema ya aceptó. No cambian reglas de gol, atribución de Kill, premios, Wins/Losses, vida de los personajes ni persistencia. MVP no otorga nada adicional.

## Ranking, MVP y slots

Criterios configurables: Goals descendente, Kills descendente, Deaths ascendente, finalmente UserId original ascendente. No se aplica math.abs ni se transforman identificadores de Studio. Los empates son estables. Si faltan datos, los valores conocidos preceden a los desconocidos en ese criterio; no se inventa una estadística. Si todas las métricas de clasificación están ausentes no se declara MVP. Con estadísticas disponibles, MVP es el primer puesto, incluido un empate resuelto por UserId.

El equipo ganador sigue siendo el que declaró RoundService. Un rival puede quedar primero individualmente y ser MVP sin modificar el resultado colectivo.

Selección visual: integrantes ganadores ordenados por ranking global, luego mejores rivales hasta cinco avatares. `Rank` no cambia por esa prioridad. `CompetitiveSlot` conserva el slot del juego; `CinematicSlot` es la posición visual 1–5. Por ejemplo, un ganador de rango global 5 puede mostrarse antes de un rival de rango 3; sus etiquetas siguen indicando 5th y 3rd. No se afirma que los cinco visibles sean los cinco mejores individuales.

En 3v3, Entries conserva las seis filas; VisibleParticipants tiene cinco, con tres ganadores y dos rivales. La sexta fila permanece en el payload y en `run.Ranking.Entries`, disponible para el HUD/resultados. No se inventa un SlotPlayer_6 ni se altera el HUD físico existente para simular una sexta posición.

Los snapshots de apariencia se preparan para todos los participantes, no solo para ganadores. Avatars sigue siendo el único creador de rigs y recibe la fila seleccionada y su CinematicSlot. Ante una descripción no disponible utiliza un HumanoidDescription neutro con advertencia; no inventa estadísticas ni aborta todo el grupo por una apariencia. Un rig eliminado durante presentación cancela esa reproducción y desencadena su limpieza.

## Billboard físico

Fuente persistente: `src/ui/EndCinematicBillboardTemplate.rbxmx`. Mapeo Rojo y ubicación Edit: `ReplicatedStorage.UIAssets.EndCinematicBillboardTemplate` (BillboardGui). Existe físicamente en Studio; no se crea como diseño efímero dentro de un LocalScript.

MainFrame es un CanvasGroup con RankLabel, PlayerName, Username, TeamLabel, MVPLabel, PreviewLabel y StatsFrame. Este último contiene GoalsLabel, KillsLabel, DeathsLabel y MatchPointsLabel, con UIGridLayout. UICorner, UIStroke y UIScale completan la plantilla editable.

El módulo solo clona y completa la plantilla: un Billboard por rig visible, Adornee en Head, nombre con PlaybackId/UserId y destrucción ligada al rig/run. Indica «EQUIPO GANADOR» o «EQUIPO RIVAL», además del color. MVP usa texto/estrella; no depende únicamente del color.

La primera prueba visual detectó superposición con ancho fijo de 196 px. Se corrigió únicamente la UI: tamaño de 3,4 × 1,874 studs y lienzo de diseño 196 × 108 escalado mediante UIScale. Es más estrecho que el espaciado físico aproximado de cuatro studs entre slots. En viewport de 860 px se midieron paneles de 105–106 × 58 px, separados y sobre las cabezas. No se alejaron cámaras ni movieron slots. Los nombres largos se truncan. AlwaysOnTop=false, offset vertical 2,8 studs, MaxDistance=100, colores y visibilidad configurables. La aprobación de legibilidad en los dispositivos objetivo sigue siendo manual.

## FloatingFollow

EndCinematicCamera mantiene la autoridad exclusiva sobre Camera.CFrame. El recorrido anterior y su rebote concluyen; se desconecta la actualización del trayecto, se fija el CFrame físico final, se marca CameraDone y se inicia una única conexión RenderStepped. El HUD/Billboards aparecen después de terminar cámara y entrada de avatares. No se crea un Tween por frame.

Anclas: Only1V1 para 1v1, v2 para XvX. En 1v1 se sigue el rig ganador; en XvX se usa el centro de los rigs visibles, con altura focal de 1,4 studs. Se ignoran desplazamientos bruscos respecto del final de entrada y cambios del centro superiores al umbral de 1,5 studs. El seguimiento no escoge solamente al MVP.

Posición: seno lateral de amplitud 0,12 studs y vertical de 0,08 studs, calculados desde el CFrame ancla cada frame. Frecuencias 0,45 y 0,65 **radianes/segundo**, no Hz. No hay componente local Z ni acumulación sobre el frame anterior. La magnitud se limita a DistanceTolerance=0,15 studs; por desigualdad triangular también limita el cambio radial respecto al foco estable de composición. El movimiento de un avatar puede modificar su distancia personal; la cámara no lo persigue en profundidad para compensarlo.

Orientación: corrección relativa al encuadre autoral, acotada a yaw 1,5° y pitch 1°. Pequeñas oscilaciones angulares permanecen dentro de esos límites. Suavizado exponencial `1-exp(-responsiveness*dt)`, responsiveness=3,5/s. Entrada gradual smoothstep durante 1,2 s desde amplitud/corrección cero. No hay zoom ni cambios de FOV; FieldOfViewLocked conserva el valor guardado. StopFloating desconecta y elimina su conexión antes de restaurar la cámara normal.

Los controles de preview permiten activar/desactivar flotación y Billboards. El ranking de demo se identifica expresamente como «DATOS DE PREVIEW» y usa IDs únicos separados del AppearanceUserId. Las previews de 2v2 y 3v3 incluyen ambos equipos, no solamente ganadores. Esas estadísticas son demostración local, no datos de partida ni pruebas competitivas reales.

## Pruebas ejecutadas

Automáticas/aisladas: 21 aserciones de ranking y contadores, 10 de cámara (matemática, llegada y limpieza) y 32 de regresión de sesión/cierre/efectos = **63 PASS**. Los hooks de ScoreService y EliminationService se ejecutaron con dobles, incluidos duplicados, caída normal y evento terminal. No se inicializó persistencia en esos harnesses. La prueba de cámara también ejecuta Play con una cámara doble: confirma que FloatingFollow no existe durante los tweens de viaje/rebote, empieza después de ambos, conserva el ancla y queda desconectado en Cleanup, sin tocar la cámara real.

Matemática de cámara: 20 s a 30, 60 y 144 FPS simulados; posiciones finales idénticas. Salto inicial 0. Offset máximo 0,142823 studs, variación radial máxima 0,001020 studs, profundidad local máxima 0,000000519 studs (precisión numérica). A tiempo 100000 s la posición seguía acotada. Esto no equivale a una aprobación visual humana a cada FPS.

Preview real en Studio: 3v3 produjo cinco rigs/Billboards con seis filas de clasificación; rangos 1st/2nd/5th entre los ganadores y 3rd/4th entre los rivales. MVP y etiquetas de demo visibles; MatchPoints oculto. Se observó el HUD, cámara flotante y FOV 70. Al pulsar DETENER quedaron cero Billboards y la cámara volvió a Custom/FOV 70. También se ejecutaron previews independientes en dos procesos cliente: 1v1 con un rig/sin Billboard y 2v2 con cuatro rigs/cuatro Billboards.

Whoosh preservado en esos clientes: SoundId normalizados `rbxassetid://126941244422484` y `rbxassetid://123796710194563`. En un cliente, DiagonalCreated=1792126144.025554 y creación del sonido de cierre=1792126144.025580; apertura=1792126145.374589. Es evidencia de sincronización y reproducción programática, no una evaluación auditiva humana del sonido.

Escenas aisladas: dos SessionIds con contenedores distintos, 13 CFrames exactos bajo la transformación de prueba; destruir A mantuvo B y cerrar ambas no dejó huérfanos. La transformación de fixture no se presenta como prueba de un mapa real.

## Bloqueante de partida real

Los dos clientes reales se conectaron con perfiles independientes InMemory. Sin embargo, **ServerStorage.Maps está vacío**, confirmado tanto en el DataModel Edit como en el servidor local. RoundService informó **No maps available** después de MatchCountdown. La preparación se canceló y se limpió; no se completó ninguna partida competitiva V1.4.

Se observaron las admisiones `fe7136f8-ff40-491b-8d89-21b7e72267c4` y `3165c771-e190-4d49-912b-1e87a615f810`, seguidas de ReturningToLobby/cierre. No se fabricaron goles ni se restauraron mapas de otro respaldo para declarar un PASS. No se inició Shared Team Spawns ni Fase 2E.1. Para repetir el recorrido real hace falta que el desarrollador disponga una plantilla compatible en ServerStorage.Maps mediante su flujo de trabajo autorizado.

## Matriz solicitada

PASS distingue ejecución aislada, matemática o preview. BLOCKED indica cobertura real/visual todavía incompleta, incluso cuando el código fue revisado.

| ID | Resultado | Evidencia / límite |
|---|---|---|
| A1 | PASS | Preview 1v1: un ganador, cámara cercana, sin ranking gráfico invasivo |
| A2 | PASS | Cuatro filas en test puro y cuatro rigs/Billboards en preview 2v2 |
| A3 | PASS | Test conserva seis filas/selecciona cinco; preview 3v3 con cinco rigs |
| A4 | PASS | Test diez participantes limita visibles a cinco |
| A5 | PASS | Tres ganadores seleccionados primero aun con rivales mejor clasificados |
| A6 | PASS | MVP global determinista sobre snapshot congelado |
| A7 | PASS | Fixture MVP perdedor sin cambiar WinningTeam |
| A8 | PASS | Empates con UserIds originales, incluidos negativos |
| A9 | PASS | Hooks de eventos de partida con dobles; sin lectura de totales históricos |
| A10 | PASS | Campos ausentes permanecen nil, etiquetas ocultas, sin MVP ficticio |
| B1 | PASS | Plantilla persistente en Edit y en Rojo |
| B2 | PASS | Cinco rigs/cinco Billboards en preview 3v3 |
| B3 | PASS | Rangos globales visibles, separados de CinematicSlot |
| B4 | PASS | DisplayNames observados en preview |
| B5 | PASS | Etiquetas con datos explícitos de demo; contadores reales probados aisladamente |
| B6 | PASS | MatchPoints ausente/oculto |
| B7 | PASS | Indicador MVP en rango 1 de preview y test global perdedor |
| B8 | PASS | Captura refinada sin superposición entre paneles ni sobre rostros; validación de otros dispositivos pendiente |
| B9 | PASS | DETENER dejó cero Billboards residuales |
| B10 | PASS | Previews consecutivas limpiaron recursos sin duplicados observados |
| C1 | PASS | Preview 1v1 utiliza destino Only1V1 |
| C2 | PASS | Preview XvX utiliza destino v2 |
| C3 | PASS | Comparación de CFrames originales en Edit sin cambios |
| C4 | PASS | Recorrido y rebote previos conservados; llegada observada en preview |
| C5 | PASS | Test con cámara doble verifica ausencia de flotación durante viaje/rebote y conexión posterior |
| C6 | PASS | Frame inicial exactamente igual al ancla y entrada gradual |
| C7 | PASS | Seno lateral observado/calculado, amplitud acotada |
| C8 | PASS | Seno vertical observado/calculado, amplitud acotada |
| C9 | PASS | FOV 70 antes/durante/después y sin profundidad añadida |
| C10 | PASS | Evaluación absoluta y prueba a 100000 s acotada |
| C11 | PASS | Variación radial matemática 0,001020 < 0,15 studs |
| C12 | PASS | Preview cercano mantiene ganador en encuadre |
| C13 | PASS | Preview grupal refinado mantiene cinco rigs y Billboards en encuadre |
| C14 | BLOCKED | Posición matemática igual a 30/60/144 FPS; evaluación visual a esos FPS pendiente |
| C15 | PASS | Stop desconecta render; retorno a Custom sin movimiento residual observado |
| C16 | PASS | Cámara/FOV normales restaurados después de preview |
| D1 | BLOCKED | Falta mapa para observar quinto gol real en V1.4 |
| D2 | BLOCKED | Celebración preservada en código; duración real tras gol pendiente por mapas |
| D3 | PASS | Whoosh configurados y sincronización observada en previews; audición manual pendiente |
| D4 | PASS | Logs Suspend/Resume de MusicController en preview |
| D5 | BLOCKED | Presentación de escena ejecutada y módulos preservados; aprobación visual/auditiva completa de confeti/sonidos pendiente |
| D6 | PASS | HUD existente funciona en preview; no se reconstruyó |
| D7 | BLOCKED | Ruta aislada pasa, pero retorno individual de partida V1.4 sin mapa pendiente |
| D8 | BLOCKED | Cierre/timeout aislado pasa, recorrido real V1.4 pendiente |
| D9 | PASS | Copias por SessionId y destrucción aislada, sin alterar MatchInstanceService |
| D10 | PASS | Hook sin modificar reglas/recompensas; deduplicación de métricas y +50 aislado; real pendiente |
| D11 | PASS | Config real 2v2=false, 3v3=false |
| D12 | PASS | _maxConcurrentSessions=1 observado |
| D13 | PASS | Bootstrap Studio/InMemory/WritesToCloud=false antes de ensayos |
| D14 | PASS | rojo build, exit 0 |
| D15 | PASS | git diff --check, exit 0 |

## Alcance de archivos y restricciones

Nuevos: `src/shared/EndCinematicRanking.luau`, adaptador cliente `EndCinematicRanking.luau`, `EndCinematicBillboards.luau`, `src/ui/EndCinematicBillboardTemplate.rbxmx`, `tests/EndCinematicV14.spec.luau`, `tests/EndCinematicV14.camera.spec.luau` y este informe.

Modificados: `default.project.json`, `src/shared/EndCinematicConfig.luau`, `src/shared/Types.luau`, `src/server/Services/RoundService.luau`, `ScoreService.luau`, `EliminationService.luau`, `src/client/Controllers/EndCinematicController.luau`, `EndCinematicCamera.luau`, `EndCinematicAvatars.luau` y `src/client/EndCinematicPreview.client.luau`.

No se modificaron en V1.4 MusicController, EndCinematicAudio, reglas de matchmaking, modalidades habilitadas, spawns, mapas, geometría ni política de persistencia. No se implementó revancha ni Fase 2E.1. Cambios locales previos y respaldos preservados. No hubo commits, push, publicaciones, Places nuevos, TeleportService ni escrituras cloud. Los mensajes Save success/BindToClose de Play corresponden al proveedor InMemory observado, no a escrituras de producción.

GameId observado: 10769217377; PlaceId: 107328891970677. No se modifica la configuración de Universe ID.

Advertencias existentes observadas: `Pisos` sin joins-parts, assets/iconos de plugins no autorizados/archivados, sonidos swoosh.wav internos no aprobados y FoundationProvider de UI de Studio. La falta de mapas se reporta como bloqueo del entorno, no se corrige alterando sistemas fuera de alcance.

Pruebas adicionales de ciclo de vida observadas: desactivar flotación dejó error de posición 0 respecto del ancla y mantuvo FOV 70; desactivar Billboards dejó cero copias; reactivar ambos recuperó cinco Billboards y flotación (offset medido 0,023991 studs). Eliminar un rig exclusivamente de preview canceló la reproducción: cero Billboards, cero escenas temporales, cámara Custom/FOV 70 y plantilla física conservada. La generación de Billboards invalida callbacks de apariciones anteriores al alternar opciones.

La implementación queda disponible para validación manual. Para aceptación integral falta restaurar la disponibilidad de un mapa compatible por el desarrollador, completar 1v1 real y aprobar composición/legibilidad/sonido y suavidad en los dispositivos objetivo. No iniciar la siguiente fase.
