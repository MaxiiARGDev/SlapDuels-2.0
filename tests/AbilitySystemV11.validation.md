# Ability System V1.1 — selector por botón y ventanas del countdown

Fecha: 2026-10-17. Implementado en repositorio y Roblox Studio Edit. Jugabilidad pendiente del desarrollador.

## Auditoría y cambio de flujo

V1 abría el menú desde AbilitySelection.Render y AbilityController._render al recibir Selecting=true. PrepareSelection añadía una espera de 6 s antes de las cuentas regresivas reales. En V1.1 se eliminan ambas conductas: la apertura es una decisión local explícita por botón y la autorización de selección permanece en el servidor.

RoundService llama PrepareSelection(session, startCountdownTime) justo antes del bucle del countdown inicial; pasa countdownTime en el reinicio. La función abre una ventana y retorna sin esperar. Los valores actuales de Config.Match son 5 s y 3 s. No existe otra constante de duración ni una espera de selección adicional. FinishSelection se invoca antes de GO; el Heartbeat existente también cierra una ventana vencida o invalidada. El reloj de 180 s sigue comenzando en BeginGameplayRound, después de la preparación, sin cambios en su código.

La primera preparación se identifica por ausencia de GameplayRound y PreparationIndex=1. Las posteriores usan GameplayRound.Index+1. El marcador no participa en esa decisión. Cada ventana tiene SessionId, PreparationId (índice/StateVersion), WindowId GUID, estado de preparación, versión y deadline monotónico del servidor. SelectionUntil en snapshots emplea el reloj compartido para la presentación local.

## Comportamiento y confirmación

Al recibir una ventana nueva, el menú permanece cerrado. El botón Cambiar habilidad aparece sobre el HUD actual durante el plazo. Pulsarlo abre el selector existente con cards adquiridas/bloqueadas. Elegir una card adquirida envía RequestId, SessionId, PreparationId, WindowId y AbilityId. No se cambia la selección local ni se cierra por una predicción optimista.

AbilityService valida jugador conectado, sesión registrada/activa, participante, preparación/StateVersion vigentes, estado no terminal, plazo estricto now < deadline, IDs de ventana y propiedad. Sólo entonces sustituye la elección de ese jugador. El snapshot devuelve SelectionReceipt con RequestId/ventana/preparación y Accepted. El cliente cierra al recibir la confirmación correspondiente y refleja AbilityId en el HUD; un rechazo conserva la habilidad autoritativa anterior.

Si el tiempo vence, Tick cierra el menú y oculta el botón aun si el mensaje de cierre del servidor tarda. Un paquete que llega tarde al servidor se rechaza. Una confirmación válida emitida dentro del plazo puede llegar después: refleja el estado confirmado, sin reabrir el menú. Al cambiar preparación/sesión o finalizar, se descartan pending/menu anteriores. Playing no permite abrir ni seleccionar.

Entre rondas se conserva la última elección adquirida válida. La preferencia guardada se usa como fallback inicial si no hay una elección previa válida; en último término se usa Dash. No se escribe el inventario ni se cambia la preferencia al elegir en el selector competitivo.

Un segundo PrepareSelection para la misma preparación devuelve la ventana existente y no extiende su deadline ni reinicia elecciones. No se crean threads ni conexiones por ventana. El cierre usa las conexiones y limpieza existentes; la conexión nueva del botón se incorpora al arreglo de conexiones del controller y se desconecta en Destroy.

## Objetos físicos de Studio

Se agregó **StarterGui.AbilityHUD.ChangeAbilityButton**, un TextButton con texto Cambiar habilidad, UICorner y UIStroke. Es hermano del botón de activación, por lo que no queda recortado por su ClipsDescendants.

| Propiedad | Observado en Edit |
|---|---|
| Botón nuevo Position | `{1, -28}, {1, -303}` |
| Botón original Position | `{1, -28}, {1, -175}` — conservado |
| Botón original Size | `{0, 148}, {0, 120}` — conservado |
| Botón original AnchorPoint/ClipsDescendants | Conservados respecto a la copia previa |
| ChangeAbilityButton al instalar | Visible=false, Active=false; una sola instancia |
| Selector físico al inspeccionar | Visible=false |
| AbilityHUD | 26 descendientes; exportación nativa y deserialización verificadas |

El controller no asigna Position ni Size a ninguno de los dos botones. El botón nuevo queda editable para ajustes artísticos. El HUD seleccionado se muestra durante preparación con activación bloqueada; los controles E/móvil y las reglas de activación en Playing siguen siendo los existentes.

Respaldo físico: ServerStorage._AbilityV11Backups.AbilityHUD. Copias externas al DataModel, dentro del Working Tree: tests/assets/backups/AbilitySystemV11, incluido AbilityHUD_Before.rbxm con el estado real de Studio previo a la instalación. No se guardó, cerró ni publicó el lugar.

## Archivos modificados

Fuentes de producción, exclusivamente relacionadas con selección:

1. src/server/Services/RoundService.luau: abre/cierra las ventanas dentro de los countdowns existentes.
2. src/server/Services/AbilityService.luau: apertura no bloqueante, plazo/generación, confirmación, conservación de elección y expiración.
3. src/client/Controllers/AbilityController.luau: botón, request de selección y HUD preparado; elimina apertura automática.
4. src/client/Abilities/AbilitySelection.luau: Open/Close explícitos, pending/receipt, validación local de ventana y limpieza.
5. src/shared/AbilityDefinitions.luau: elimina únicamente SelectionSeconds=6, ahora obsoleto. Items, mecánicas y cooldowns permanecen idénticos.

Recurso reexportado: src/ui/AbilityHUD.rbxm. Pruebas: nueva AbilitySystemV11.spec.luau; se adapta la preparación de AbilitySystemV1.spec.luau al contrato 5/3 sin cambiar sus pruebas de mecánicas; runner admite --spec y --output. Evidencias, hashes y este informe bajo tests/AbilitySystemV11.*.

No se modificaron compras, inventario, monedas, configuración general, módulos específicos de habilidades, CombatService, SlapService, KillPart/EliminationService, Death Effects, EndCinematic, música, mapas ni configuraciones de persistencia. 101 archivos de src fuera del alcance permitido conservaron exactamente sus SHA-256 previos.

## Validación ejecutada

| Verificación | Resultado | Alcance |
|---|---|---|
| Selector aislado | PASS: 54 aserciones | Estado de servidor y GUI con mocks fuera de Studio |
| Regresión aislada V1 | PASS: 108 aserciones | Lógica y contratos; preparación adaptada al contrato actual |
| Sintaxis Luau | PASS: 91 archivos | 89 fuentes y ambas suites |
| rojo build default.project.json | PASS | Build, sin ejecución de scripts |
| rojo build studio-safe.project.json | PASS | Perfil seguro mantenido |
| git diff --check | PASS | Whitespace de cambios rastreados |
| Repositorio frente a Studio | PASS: 5/5 fuentes | SHA-256 normalizado, usando GetEditorSource; sin fuentes divergentes |
| HUD físico | PASS de estructura | Botón único, menú inicialmente cerrado, posición/tamaño original preservados |
| Archivos protegidos | PASS: 101/101 | Comparación binaria SHA-256 de src fuera del alcance |
| Entorno resuelto en Edit | Studio / InMemory / WritesToCloud=false | El agente no inició un servidor de juego |
| Play, Run, servidor, dos clientes reales | NOT RUN | Los ejecuta el desarrollador |

Las 54 aserciones cubren apertura inicial no automática, apertura sólo explícita, cierre por confirmación/deadline, rechazo de receipt ajeno, selección no adquirida, plazo exacto, sesión/preparación vieja, ventanas repetidas, Playing, desconexión, resultados, StateVersion, conservación entre rondas aunque el marcador siga 0-0, aislamiento por jugador y limpieza. No constituyen PASS visual, físico ni multicliente.

## Prueba manual exacta con dos clientes

1. Conectar Rojo a 127.0.0.1:34873, proyecto SlapDuels-2.0 Scripts Only SAFE, si no sigue conectado. No ejecutar el instalador anterior de V1.
2. Iniciar personalmente el servidor local con dos clientes. Confirmar en Output Studio / InMemory / WritesToCloud=false; si no coincide, abortar. El agente no ejecutó este paso.
3. Si querés elegir una habilidad diferente de Dash, preparar propiedad temporal con el comando del apartado 1 de AbilitySystemV1.manual.md, exclusivamente en el servidor local InMemory y antes de entrar a matchmaking. Los precios siguen sin aprobarse y no se habilitaron compras. El resto del flujo de selección de aquella guía V1 queda reemplazado por esta guía.
4. Entrar ambos a Red/Blue y votar mapa. En el countdown real 5→1, verificar HUD actual y botón Cambiar habilidad; el menú grande no debe aparecer solo.
5. Cliente A pulsa Cambiar habilidad. Cliente B no lo pulsa: su menú debe seguir cerrado. A selecciona una adquirida: esperar confirmación, cambio del HUD y cierre. Una bloqueada no permite selección.
6. Volver a abrir en A y dejar el menú abierto hasta terminar los 5 s: debe cerrarse y desaparecer el botón. E sigue siendo activación de habilidad sólo cuando Playing está habilitado.
7. Anotar un gol. Durante el reinicio 3→1 vuelve el botón; no se abre el menú solo. Sin seleccionar otra, mantener la elección anterior. Repetir un gol, abrir y confirmar otra habilidad dentro de esos 3 s.
8. Abrir cerca del final y confirmar demasiado tarde. El servidor debe conservar la selección anterior si recibió el paquete fuera de plazo. Capturar Output y la habilidad efectiva del HUD para distinguir envío local de aceptación del servidor.
9. Durante Playing no debe aparecer el botón ni abrirse el menú. Finalizar/abandonar la partida y comprobar que no queda selector en EndCinematic/lobby. Repetir una segunda partida para comprobar limpieza.
10. Verificar que el reloj muestra 3:00 al habilitarse el combate: los 5/3 s de preparación no se descontaron del tiempo jugable. No deben agregarse los 6 s extra de V1.

Devolver Output de servidor/clientes y video de ambos HUDs. Los diez casos visuales/multicliente anteriores están **NOT RUN**, pendientes de esa evidencia. Las pruebas de jugabilidad previas de las habilidades y los precios/audio pendientes de V1 no se dan por aprobados con esta entrega.

Sin commits, push, publicaciones ni escrituras cloud. No continuar con otra fase hasta la validación del desarrollador.
