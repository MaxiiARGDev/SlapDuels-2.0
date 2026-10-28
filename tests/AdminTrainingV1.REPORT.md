# Admin y práctica V1 — implementación y verificación

Implementado en repositorio y DataModel **Edit**. No se ejecutaron Play, Run, servidores, personajes, escrituras cloud, publicaciones, commits ni push. La jugabilidad y el guardado/carga en producción siguen **NOT RUN**. No se guardó ni cerró el lugar abierto: conservá tus cambios de Studio guardándolo cuando corresponda.

## Objetos instalados

- `Workspace.TrainingZone`, plataforma junto al lobby, centro `(-55.2215, 16.5793, 237.5)`, conectada al spawn mediante un puente propio. No se movieron partes existentes.
- `Workspace.TrainingZone.TrainingDummy`: R6 con seis Motor6D válidos, Humanoid.RequiresNeck=false y raíz anclada en reposo.
- `Workspace.TrainingZone.DummyHome`: referencia editable para el retorno del NPC.
- `Workspace.TrainingZone.EntryPad.TrainPrompt`: entrada/salida de práctica.
- `Workspace.TrainingZone.Bounds`: límites de la práctica.
- `StarterGui.TrainingHUD.Panel`: botón Golpear y Salir; oculto fuera de práctica.
- `StarterGui.AdminHUD.OpenButton`: botón único ADMIN, inicialmente invisible. El servidor determina su visibilidad mediante AdminPanelAllowed.
- `StarterGui.AdminHUD.MainFrame`: comandos, lista de jugadores conectados, cantidad/Slap, confirmación y estado.
- `ReplicatedStorage.Remotes.Admin.Request` y `Training.Activate/Leave/Updated`.

MCP verificó existencia, clases y ausencia de duplicados en Edit. Los hashes serializados de los diez HUD anteriores coinciden con el estado previo. Evidencia en `AdminTrainingV1.native.json`. Modelo físico exportado a `src/assets/TrainingZone.rbxm`; interfaces declarativas incluidas en ambos proyectos Rojo.

## Autorización y comandos

Administrador inicial: **1522376993**, exclusivamente en `src/server/Admin/Access.luau`. Lista adicional Studio vacía: no se concede acceso automático al creador, por nombre, por atributos del cliente ni a UserIds negativos de pruebas locales.

Cada solicitud vuelve a verificar el Player conectado y la lista del servidor. El cliente nunca acredita inventario/Coins. Campos y catálogo se validan en servidor; no se admiten montos negativos, cero, decimales, NaN, infinito, perfiles fallidos/cerrando ni jugadores desconectados. Límite actual: 1.000.000 Coins por operación, configurable en Access.

GrantCoins usa PlayerService:AddCoins con identificador de transacción. El servidor conserva hasta 1.000 operaciones por administrador/sesión y un registro circular de 256 auditorías, además de `[AdminAudit]` en Output. Reintentar **la misma solicitud** no vuelve a ejecutar la operación. Esta caché no constituye un historial durable entre servidores o reconexiones. Una nueva operación es un nuevo otorgamiento intencional.

GrantSlap agrega propiedad de la variación del catálogo mediante PlayerService:AddItem; no equipa herramientas ni genera unidades comerciables falsas. Repetir un Slap poseído devuelve AlreadyOwned. Recursos limitados/premium e IDs desconocidos se rechazan. Los Slaps administrativos son propiedad de inventario; **no son unidades de trade con procedencia de caja**.

Se reutiliza el ciclo de persistencia existente. El panel no habilita producción, no altera Universe IDs ni evita fallos de carga. La configuración previa de universo de producción aprobado continúa pendiente: antes de operar con perfiles reales debe resolverse por el procedimiento de aprobación existente. No se probó persistencia real. En Edit se resolvió Environment=Studio, ProviderName=InMemory, WritesToCloud=false, GameId=10769217377, PlaceId=107328891970677.

## Extensibilidad

Agregar `src/server/Admin/Commands/NuevoComando.luau` y su nombre a CommandManifest. Contrato: Id igual al módulo, DisplayName, Description, Fields, Execute(context,args). Campos existentes: Player, Integer, Slap. TargetUserId es obligatorio. Execute recibe Actor, Target, PlayerService y OperationId; debe usar las APIs autoritativas correspondientes. El menú genera controles desde metadatos y el registro rechaza IDs duplicados/módulos no aprobados. Nuevos tipos de campo necesitan su validador/renderizador; no se ejecutan módulos recibidos del cliente ni se ofrece ejecución arbitraria de código.

## Maniquí

La práctica usa un Tool temporal del Slap equipado, o Classic como fallback. No usa sesiones competitivas ni acredita golpes, Kills, estadísticas, recompensas o Coins. Solo su NPC explícito puede ser golpeado por este canal. La excepción de equipamiento exige Tool y Character exactos registrados y jugador dentro de Bounds, sin partida ni resultados.

Se comparten el cálculo original de alcance/dirección/impulso de SlapService y el RagdollService. El valor Power del Classic sigue siendo 20. El NPC permanece protegido durante los tres segundos configurados, recupera sus articulaciones, vuelve a DummyHome y elimina velocidades residuales. Salir de zona, entrar a partida, morir o desconectarse elimina el Tool temporal. Se conserva la recuperación competitiva de acierto/fallo.

## Validación realizada

| Comprobación | Resultado | Alcance |
| --- | --- | --- |
| AdminTrainingV1 | PASS, 73 aserciones | Módulos reales con tablas y reloj aislados: permisos, montos, duplicados, perfiles, propiedad, cooldowns, ragdoll/retorno con dobles de física |
| SlapVictimProtection | PASS, 150 aserciones | Regresión aislada del Slap competitivo |
| EconomyBalanceV1 | PASS, 30 aserciones | Recompensas existentes |
| Compilación Luau | PASS, 188 scripts | Sintaxis; no prueba de ejecución en Roblox |
| Rojo default y SAFE | PASS ambos | Construcción local con recursos |
| git diff --check | PASS | Advertencias previas LF/CRLF, sin errores de whitespace |
| Existencia y jerarquía Edit | PASS | Inspección MCP, sin iniciar servicios ni simular física |
| Física, animación y menú en juego | NOT RUN | Validación del desarrollador |
| Persistencia real / reconexión | NOT RUN | No se accedió a cloud |

## Archivos y protección

Comparación SHA-256 del inicio: se modificaron únicamente Bootstrap.server.luau, SlapService.luau y ambos JSON de proyecto entre archivos preexistentes de src/proyectos; 14 archivos agregados y ninguno eliminado. Lista completa: AdminTrainingV1.scope.json. Cambios de SlapService: excepción restringida de práctica y extracción de dos cálculos compartidos sin cambiar balance. No se modificaron RoundService, CombatService, RagdollService, PlayerService, persistencia, Shop, habilidades ni otros HUD.

También se agregaron pruebas, evidencias, instalador de zona, generador UI y se extendió el empaquetador de pruebas `tests/tools/run_ability_unit_tests.py`. Respaldo inicial específico: `tests/assets/backups/AdminTrainingV1/`. No reemplaza el respaldo integral previo del proyecto.

## Prueba manual pendiente (desarrollador)

1. Guardá los cambios de Edit cuando corresponda. Iniciá vos una prueba y comprobá Output: Studio / InMemory / WritesToCloud=false. Si no coincide, detené la prueba.
2. Con tu cuenta UserId 1522376993, verificá el botón ADMIN debajo de Mi Perfil. Clientes locales Player1/Player2 con IDs negativos no son administradores: deben carecer del botón. Para comprobar el panel usá una prueba de Studio que conserve tu UserId real; no cambies permisos desde el cliente.
3. ADMIN → Dar Coins → elegir jugador conectado → ingresar 100 → aplicar. Verificá aumento exacto de 100 y una línea AdminAudit. Dar Slap → elegir variación no poseída → aplicar → abrir inventario y comprobar propiedad/equipamiento normal. Repetir la misma variación no agrega duplicados ni cambia Coins.
4. Caminá por el puente junto al spawn hasta el pad de PRÁCTICA. Activá su prompt (E). Se equipa el Slap temporal y aparece Golpear/Salir. Acercate de frente al NPC y golpeá.
5. Comprobá impulso/ragdoll, inmunidad mientras está caído y retorno al mismo sitio al completar tres segundos. Repetí cinco golpes. Un fallo conserva la recuperación de 0,45 s tras la ventana de 0,10 s. No deben cambiar Coins/Kills/estadísticas.
6. Probá Salir, abandonar Bounds, respawn y entrar a una partida: el Slap de práctica debe desaparecer. Otro jugador fuera de la zona no debe recibir sus mensajes ni daño por este canal. Probá un 1v1 normal para verificar la regresión competitiva.
7. Si falla, enviá Output con errores AdminService/TrainingService, ClientBootstrap/Bootstrap y AdminAudit, jugador/acción realizada y si el NPC quedó anclado o ragdoll. La instalación de Edit está verificada; no declarar aprobada la jugabilidad hasta estas pruebas.
