# Party HUD y matchmaking V1

## Alcance aprobado
Implementar las dos etapas. No iniciar Play, Run, servidores de prueba, partidas, publicaciones, commits ni push. El desarrollador ejecuta las pruebas de jugabilidad. Studio utiliza exclusivamente una cola local en memoria; nunca MemoryStore ni TeleportService durante pruebas de Studio.

## Etapa 1 — HUD y cola local
- HUD físico editable PartyMatchHUD: avatares de 1 a 4 integrantes, contador, líder y un botón + mientras haya espacio. Botón Jugar, lista de jugadores del servidor, selector de modos, estado de búsqueda/cancelación y telemetría.
- Reutilizar SocialPlayService/Engine para invitaciones, aceptación, salida, líder y desconexiones. Las invitaciones Group dejan de exigir distancia; Duel conserva su restricción.
- Solo el líder inicia/cancela. Roster construido por servidor. Partes completas y del mismo equipo; rellenar plazas con otras parties/solos. Nunca habilitar un modo menor que el tamaño de la party.
- Cola local independiente de las zonas, con exclusión mutua respecto a las plataformas y desafíos. Inicio mediante reserva validada por MatchmakingService y StartTeamMatch existente. No cambiar reglas competitivas ni concurrencia.
- Ventanas integradas con WindowNavigationController. El HUD de miembros permanece presente; controles deshabilitados cuando corresponde.

## Etapa 2 — Cola global y traslado
- Backend MemoryStore con transacciones atómicas por modalidad, tickets con expiración, límite de capacidad, cancelación y heartbeat. Cohortes indivisibles.
- Asignación única de tickets y coordinador de reserva. TeleportAsync a un servidor reservado del mismo Place; no crear experiencias ni modificar Place IDs.
- Manifest autoritativo en MemoryStore; TeleportData solo lleva identificador. Validar origen, destino privado, UserIds, tiempo de vigencia y una única instancia receptora. Esperar roster completo y perfiles listos, reconstruir parties y recién entonces iniciar.
- Timeout, desconexiones, reserva/teleport fallidos y llegada parcial: abortar, no iniciar partida parcial, desbloquear origen y ofrecer regreso al lobby a quienes llegaron. No teletransportar automáticamente otra vez ni entregar premios por la transferencia.
- Preferencia aproximada de región de jugadores y latencia actual con relajación por espera. Esto no mide el ping al destino ni selecciona un datacenter reservado: Roblox decide su ubicación. Verificar ping real al llegar y rechazar destinos que superen el límite configurado. Mostrar región del servidor como no disponible cuando no se conoce; nunca confundirla con país del jugador.
- Activación solo fuera de Studio y en el universo autorizado; sin ejecución cloud por parte del agente. La publicación y validación multiserver quedan pendientes del desarrollador.

## Verificación
Pruebas aisladas: composición de equipos, duplicados, cancelación/asignación concurrente, expiración, fallos, manifest y partidas incompletas. Compilación Luau, ambos Rojo builds y git diff --check. Inspección MCP exclusivamente Edit de scripts y HUD instalados.

## Matriz manual
1. Solo: avatar propio, +, Jugar, invitación/aceptación/rechazo/expiración.
2. Party 2/3/4: contador, avatares, límite, líder, salida/desconexión, modos compatibles.
3. Dos equipos locales: buscar, cancelar, impedir doble cola con plataformas, mapa/partida/retorno y repetir.
4. Publicado privado, dos servidores origen: búsqueda global, viaje de parties completas, perfiles/inventario conservados, una partida por reserva.
5. Fallos: salida durante búsqueda, cancelación simultánea al emparejar, destino incompleto, teleport fallido, timeout, regreso al lobby.
6. PC/móvil/consola: legibilidad, selección y navegación. Ping/FPS visibles sin mostrar datos geográficos inventados.

## Fuentes técnicas
- https://create.roblox.com/docs/cloud-services/memory-stores/sorted-map
- https://create.roblox.com/docs/projects/teleport
- https://create.roblox.com/docs/matchmaking

## Estado
Ambas etapas implementadas en código e instaladas en Studio Edit. 105 aserciones aisladas PASS, 221 scripts compilados, dos builds Rojo y git diff --check PASS. Inspección visual del HUD y del selector realizada en Edit. Jugabilidad y teletransportes reales NOT RUN; aprobación funcional pendiente del desarrollador.

## Configuración y operación
- `src/shared/PartyMatchConfig.luau`: GlobalEnabled=true; la selección efectiva exige no estar en Studio, universo 10769217377 y persistencia Production/WritesToCloud=true. En Studio se usa siempre una cola local independiente en memoria.
- Las partidas globales utilizan el mismo Place publicado. No se crearon experiencias, no se cambiaron Place IDs y no se publicó nada.
- Cola global acotada inicialmente a 32 tickets y 8 reservas por modalidad, con actualización cada 5 s. Ticket 45 s, asignación de servidor 30 s, llegada 180 s, búsqueda máxima 600 s.
- Preferencia inicial: mismo país aproximado de jugadores y diferencia de ping actual hasta 80 ms respecto al candidato de referencia; a los 90 s se amplía la búsqueda. País mixto/desconocido se trata como categoría propia. No es geolocalización del servidor ni predicción del ping al destino.
- Límite de llegada: 450 ms medidos al servidor destino. Si un integrante lo supera se cancela antes del combate. Estos valores son una base editable, no un objetivo de calidad validado.
- FPS, ping en ms, alias de servidor y versión visibles. No se muestra un país inventado para el servidor.
- El traslado de retorno conserva una party completa cuando todos llegan al mismo lobby y pasa la validación del manifest. Si la llegada es incompleta, vence y libera a los presentes; no fuerza una partida ni espera indefinidamente.
- Bloqueo de nuevas interacciones de trade, entrenamiento y cajas mientras existe PartyQueueTicket. Se rechaza entrar en cola si ya existe una actividad incompatible.

## Validación manual inicial exacta
1. Iniciar manualmente Studio con dos clientes. Confirmar Output `PersistenceEnvironment=Studio PersistenceProvider=InMemory WritesToCloud=false`.
2. Ver el avatar propio, 1/4 y +. Invitar desde + y aceptar en el otro cliente: ambos deben ver 2/4, el mismo líder y un solo +. El integrante no líder no puede iniciar búsqueda.
3. Salir de la party y buscar 1v1 desde ambos clientes. Ver contador, completar mapa/combate/resultados, volver y repetir. Cancelar una búsqueda antes de entrar el segundo. Pisar una plataforma mientras se está buscando no debe registrar una segunda cola.
4. Con cuatro clientes formar dos parties de dos y buscar 2v2. Cada party permanece en el mismo equipo. Con 3/4 integrantes, 1v1/2v2 incompatibles quedan deshabilitados según tamaño. Verificar 3v3/4v4 con seis/ocho clientes y mapas aptos.
5. Tras publicar manualmente la versión en la experiencia privada, usar Roblox Player y al menos dos servidores de origen, con permisos de acceso para todos. Buscar el mismo modo: deben viajar a una única reserva, esperar roster completo y comenzar una sola partida.
6. Finalizada la partida global, usar Volver al lobby; revisar party, Coins/inventario y perfil. La persistencia existente conserva sus bloqueos de sesión; si el perfil no queda listo, no debe iniciarse combate con datos por defecto.
7. Probar salida de un integrante durante búsqueda, fallo de teleport, llegada parcial, cancelación simultánea con asignación y cierre de servidor origen. La UI informa fallo/expiración y permite volver al lobby; no iniciar roster parcial ni duplicar partidas.
8. Probar PC, teléfono y consola. El indicador de latencia corresponde al servidor actual y puede variar después del viaje.

## Limitaciones de evidencia
La suite histórica ProfileSocialV12 no pudo comenzar: su ShopFixture no incluye la dependencia Progression.Model actual de PlayerService. Se conserva el resultado en tests/PartyMatchmakingV1.social-regression.txt. La nueva suite sí ejercita el SocialPlayEngine real (invitación, límite, líder, desconexión), además de la cola y el servicio con transporte simulado. No se atribuye PASS a la suite histórica ni a pruebas multijugador reales.

Informe de archivos y resultados: `tests/PartyMatchmakingV1.REPORT.md`.
