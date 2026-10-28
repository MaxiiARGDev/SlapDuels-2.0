# Perfil social: diseño, rachas, desafíos y grupos temporales

Estado: implementado en repositorio y sincronizado con **Studio Edit**. Jugabilidad y aceptación visual pendientes del desarrollador. No se inició Play, Run, Start Server ni Team Test. No hubo publicaciones, commits, push, transferencias reales ni acceso cloud.

## Diseño instalado

Se reutilizó `StarterGui.PlayerProfileHUD`: panel oscuro marrón/negro, bordes, degradados, identidad/avatar en cabecera, cierre rojo y tarjetas de Rachas, Victorias y Kills. El diseño toma como referencia la imagen del usuario y adapta las armas a un preview del Slap equipado. No se inventó un nivel o EXP: continúa el texto pendiente, acompañado por derrotas.

Rutas principales:

- `StarterGui.PlayerHUD.ProfileButton`: acceso propio existente.
- `StarterGui.PlayerProfileHUD.MainFrame.Summary.Streak.Value`: rachas permanentes.
- `...Summary.Wins.Value`, `...Summary.Kills.Value`: estadísticas existentes.
- `...Summary.Equipped.Preview`: Slap equipado mediante el mismo ViewportPool.
- `...Articles`, `...Challenge`, `...Invite`, `...Trade`: Ver artículos, Desafío, Invitar e Intercambio.
- `...Collection`, `...Previous`, `...Page`, `...Next`: colección existente; Ver artículos alterna entre resumen y colección, sin otro inventario o ProfileHUD.
- `StarterGui.SocialPlayHUD.RequestPanel`: solicitudes de grupo o 1v1, aceptar/rechazar y expiración.
- `StarterGui.SocialPlayHUD.GroupPanel`: integrantes, líder, salir y disolver; se oculta mientras otra ventana ocupa la pantalla o durante la partida.

En el perfil propio, las tres acciones dirigidas a otra persona se ocultan/desactivan; Ver artículos ocupa la fila. El avatar y los Slaps usan el renderer existente. El Slap equipado se incluye fuera de la paginación del DTO, para no depender de que esté en la página actual. Se conserva el presupuesto de previews.

Se inspeccionaron en Edit 84 descendientes de PlayerProfileHUD y 28 de SocialPlayHUD, con una sola instancia de cada HUD. Esto confirma estructura/configuración instalada; **no demuestra apariencia, encuadre, responsive o funcionamiento en un cliente real**. El lugar abierto no se cerró ni se forzó su guardado a disco.

## Regla de racha

`WinStreak = {Total, Progress, LastMatchId}`:

- Cada victoria confirmada incrementa Progress.
- Al completar tres, Total aumenta en uno y Progress vuelve a cero para el bloque siguiente.
- Tres victorias consecutivas acreditan una racha; seis acreditan dos; nueve acreditan tres.
- Una derrota o empate reinicia solamente Progress; Total nunca se reinicia por ese resultado.
- Cancelled no altera los contadores.
- No se deducen rachas de las victorias históricas: los perfiles anteriores empiezan los campos nuevos en cero.

RoundService registra los resultados junto al hook de recompensas existente. Se conserva su protección por partida/jugador y se agrega la comprobación de LastMatchId en la operación de racha. El módulo no modifica Coins, Win/Loss, combate ni premios. Se mantiene el tratamiento previo de participantes desconectados/Left: no se reabren perfiles removidos para aplicar estadísticas; esta tarea no cambia la política competitiva de abandonos existente.

PlayerService normaliza/carga/expone los campos; PlayerDataService los valida y lleva a su payload de guardado existente. No se cambió nombre de DataStore, proveedor, Universe ID ni activación cloud. En Studio, estos datos siguen siendo de memoria y no sobreviven al reinicio del servidor de prueba. La conservación entre sesiones está preparada en el esquema; no se validó contra producción ni se habilitó para hacerlo.

## Desafíos 1v1

La solicitud se valida en SocialPlayService y SocialPlayEngine: identidades, jugadores conectados y disponibles, perfiles cargados, personaje vivo, distancia de envío, ausencia de cola/sesión, ausencia de negociación de trade, cooldown y un pedido pendiente por jugador.

Si **cualquiera pertenece a un grupo**, Challenge se oculta/desactiva en cliente y el servidor deniega tanto el envío como la aceptación. Se vuelve a validar al aceptar; el booleano cliente no otorga permisos.

Solo el destinatario puede aceptar/rechazar la solicitud identificada. Expira a los 15 segundos y cada emisor tiene 15 segundos de cooldown. La aceptación es de uso único: crea una reserva privada con ZoneId `Duel:<id>`, token y plantilla exacta de dos participantes. Pasa por StartTeamMatch/AdmitSession; no se omite el registro autoritativo ni se modifica la concurrencia global (sigue una sesión).

MatchmakingService delega únicamente el prefijo Duel a la reserva del servidor. La validación comprueba token, identidad, modo 1v1, tamaño, roster, expiración y consumo. Durante preparación, verifica que ambos estén en la misma sesión autorizada. Para este flujo consentido no se exige permanecer en una plataforma física. No hay un remoto que acepte rosters o tokens arbitrarios del cliente. Un inicio fallido elimina su reserva; desconexión, cierre o expiración limpian el estado.

Si hay otra partida ocupando la capacidad, el desafío se rechaza y se informa disponibilidad; no se habilitó una segunda partida simultánea.

## Grupos temporales

Invitar crea un grupo únicamente tras aceptar. Máximo **cuatro integrantes contando al líder**. No es un clan persistente, no tiene compras ni transferencias y se elimina al finalizar el servidor.

Solo el líder invita/disuelve. Un miembro puede salir; si sale el líder, el siguiente integrante pasa a liderar. Con menos de dos integrantes se disuelve. Las invitaciones se vinculan a la identidad y revisión del grupo; no recrean un grupo disuelto ni aceptan una plantilla antigua. Desconexiones liberan pertenencia y solicitudes.

**Entrada al matchmaking:** se conserva el flujo físico existente. Todos los integrantes deben estar en los pads del mismo equipo, en una modalidad con capacidad suficiente, junto a los rivales requeridos. No se teletransporta ni se mete remotamente a los demás en la cola por pisar un pad el líder. Se pueden completar plazas del equipo con jugadores sin grupo.

La validación se aplica tanto al armado de la reserva física como a AdmitSession: un grupo incompleto, demasiado grande o dividido entre lados no entra parcialmente. Modificar voluntariamente la plantilla mientras algún integrante está en cola o partida se rechaza; una desconexión fuerza limpieza de la membresía.

## Integración y restricciones preservadas

- Intercambio conserva el sistema V1.0 de negociación; TradeCommit sigue false y no existen transferencias reales habilitadas.
- Ver artículos conserva PublicInventory, páginas, previews, propiedad y equipamiento reales.
- Se conserva el acceso propio validado por Player de OnServerInvoke y la inspección ajena por proximidad.
- ProfileActions se actualiza desde DTO validado y pertenencia replicada por servidor; la vista abierta refresca sus permisos/datos periódicamente.
- Sonidos existentes: placeholders sin SoundId; no se inventaron assets ni se promete audio audible.
- No se alteraron fórmulas/precios de economía, habilidades, daño, ragdoll, Slaps, mapas, cámaras, EndCinematic ni concurrencia.

## Archivos

Nuevos:

- `src/shared/SocialPlayConfig.luau`.
- `src/server/Services/Gameplay/WinStreak.luau`.
- `src/server/Services/Gameplay/SocialPlayEngine.luau`.
- `src/server/Services/SocialPlayService.luau`.
- `src/client/Controllers/SocialPlayController.luau`.
- `src/ui/SocialPlayHUD.project.json`.

Adaptados:

- `src/server/Bootstrap.server.luau`: registro del servicio nuevo.
- `src/server/Services/PlayerService.luau`, `PlayerDataService.luau`, `src/shared/Types.luau`: contadores y esquema.
- `src/server/Services/RoundService.luau`: comprobación de grupos y hook de resultados de racha.
- `src/server/Services/MatchmakingService.luau`: consulta de cola, cohesión de grupos y reservas de desafíos.
- `src/server/Services/SocialService.luau`, `Trading/PublicInventory.luau`: datos públicos y permisos de botones.
- `src/client/Controllers/SocialController.luau`: presentación y acciones del perfil.
- `src/ui/PlayerProfileHUD.project.json`: diseño editable.
- Ambos proyectos Rojo: entradas aditivas y regeneración SAFE de los módulos nuevos, preservando entradas anteriores.

Pruebas/herramientas: `ProfileSocialV12.spec.luau`, `.integration.luau`, `tools/profile_social_v12_ui.py`, `tools/validate_profile_social_v12.py`; se ampliaron los runners existentes y el fixture de Shop para cargar las dependencias reales nuevas. El fixture V1.1 recibió FindFirstChild en su MainFrame simulado.

## Verificación

| Verificación | Resultado | Alcance |
|---|---|---|
| Rachas, duplicados, migración, guardado y grupos/solicitudes | PASS: 111 aserciones | Módulos reales, tablas y adaptador aislados |
| Desafío: aceptar → token → AdmitSession → countdown → votación → cierre | PASS | Coroutine real con scheduler y jugadores simulados |
| Resultado real RoundService → racha, Draw/Cancelled, grupo completo/dividido | PASS | Incluido en 16 aserciones nuevas de integración |
| Regresión de matchmaking | PASS: 359 aserciones | Fixtures existentes |
| Perfil/Trading V1.0 y V1.1 | PASS: 121 + 104 | Fixtures existentes |
| Combate, habilidades, economía, Shop, Premium y cajas | PASS: 150 +164 +30 +86 +93 +1375 | Regresiones existentes |
| Total aislado | **2609 aserciones** | No equivale a 2595 escenarios reales de Studio |
| Compilación Luau | PASS | 177 fuentes + dos specs de esta fase; cero errores de sintaxis |
| Rojo default y SAFE | PASS | SAFE incluye los cinco módulos nuevos |
| git diff --check | PASS | Avisos preexistentes de conversión LF/CRLF no son errores de whitespace |
| Fuente local / Source / borradores del editor | PASS | 14 scripts sincronizados o ya coincidentes |
| Jerarquía de HUD y duplicados | PASS | Inspección física Edit |
| Jugabilidad 1v1 / grupos de 4 / visual PC y móvil | **NOT RUN** | Exclusivo del desarrollador |

Evidencias: `tests/ProfileSocialV12.checks.json`, `.results.txt`, `.integration.txt`, `.studio-edit.json`, `.sync-manifest.json` y logs de suites/builds. La serialización de ColorSequence se ajustó al formato de propiedades de Rojo: https://github.com/rojo-rbx/rojo.space/blob/master/docs/properties.md.

## Studio, respaldo e integridad

Instancia MCP `5984807e-5268-4214-8b30-e127bebb4d84`, SlapDuels 2.0 [EVENTOS DE HALLOWEEN], PlaceId `107328891970677`. Se comprobó modo Edit antes de cada escritura.

Respaldo previo: `tests/assets/backups/ProfileSocialV12/` con todas las fuentes existentes, proyectos, JSON del perfil, PlayerProfileHUD nativo, estado Git y SHA-256. No se borró ese respaldo ni ningún respaldo anterior.

Antes de sincronizar se aceptaron únicamente fuentes iguales al respaldo o al resultado local esperado y con GetEditorSource idéntico a Source. Las guardas se repitieron en UpdateSourceAsync; los módulos nuevos se crearon solo si no colisionaban con una instancia existente. El perfil se adaptó en su lugar, conservando hijos desconocidos, y SocialPlayHUD se creó por separado para solicitudes/grupo, no como otro perfil.

Hashes nativos finales idénticos a los previos: PlayerHUD, ShopHUD, PremiumShopHUD, TradeHUD, TradeRequestHUD, MatchHUD, MatchmakingHUD y EndCinematicHUD. Se mantienen `Studio / InMemory / WritesToCloud=false` y TradeCommit=false. Esta es evidencia del resolvedor en Edit, no del Output de un servidor iniciado por el agente.

## Prueba manual del desarrollador

1. En Edit, revisar PlayerProfileHUD/MainFrame y SocialPlayHUD en Explorer. Guardar localmente el lugar cuando corresponda; no se forzó un guardado/publicación.
2. Iniciar vos dos clientes. Confirmar Output `PersistenceEnvironment=Studio`, `PersistenceProvider=InMemory`, `WritesToCloud=false`; si no coincide, detener la prueba.
3. Abrir MI PERFIL: diseño, identidad, avatar, valores, Slap equipado, Ver artículos, scroll, páginas, volver y cerrar/reabrir. Challenge/Invite/Trade deben estar ocultos en el propio.
4. Inspeccionar al otro jugador a distancia válida: probar Desafío, aceptar, countdown, votar, partida y retorno. Rechazar otra solicitud y dejar expirar una. Si la capacidad está ocupada, comprobar rechazo sin segunda sesión.
5. Volver al lobby e Invitar: aceptar crea grupo 2/4. Desde ambos perfiles ajenos comprobar que Desafío desaparece. Intentar otro desafío no debe saltarse el grupo.
6. Con cuatro clientes, invitar hasta cuatro integrantes; comprobar límite, liderazgo, salida y disolución. Un miembro sin liderazgo no invita/disuelve. Desconectar un miembro y comprobar limpieza.
7. En modalidad física con capacidad, colocar al grupo completo en el mismo equipo y a los rivales correspondientes. Dividirlo o dejar un miembro fuera debe impedir la admisión; reagruparlo debe permitirla. Las zonas físicas necesarias deben existir y los rivales deben completar la modalidad. No se crean zonas automáticamente.
8. Validar rachas mediante resultados reales del servidor: victorias 1/2 → total 0; victoria 3 → total 1; victoria 6 → total 2. Ganar dos y perder/empatar elimina solo el progreso; el total permanece. Cancelar preparación no acredita ni borra rachas.
9. Mantener Trade como negociación de prueba sin transferir, y comprobar los accesos de Shop/Premium existentes. Repetir aperturas en PC y emulación móvil para verificar tamaño, botones, avatar y ausencia de superposiciones.
10. Si falla: enviar Output, captura, modo Self/Other, integrantes/líder, estado de cola/sesión y secuencia exacta. No enviar datos privados, tokens de sesión o credenciales.

Se detiene esta implementación para la validación manual; no se declara aprobado el funcionamiento multicliente ni la fidelidad visual solo por inspección estructural.
