# Combat System V1.3.2 — guía manual

El agente dejó los scripts y la UI en Edit. No ejecutó partidas. Todas las pruebas funcionales siguientes las realiza el desarrollador.

## Inspección en Edit

En Explorer seleccionar StarterGui > PlayerHUD > CombatSlots > SlapSlot. Allí existen CooldownOverlay > CooldownTimeLabel y CooldownOverlay > CooldownBarBackground > CooldownBarFill. El contenedor está Visible=false por defecto para no mostrar inventario en lobby.

Para editar el diseño sin Play, podés activar temporalmente Visible en CombatSlots y CooldownOverlay, poner CooldownTimeLabel.Text="0.3 s" y ajustar manualmente el ancho Scale.X del fill. Al terminar, volver CombatSlots.Visible=false, overlay.Visible=false, label.Text="" y fill.Size.X.Scale=0. No hace falta publicar ni cerrar el place. El asset fuente es src/ui/CombatSlots.project.json; SAFE preserva esta UI física.

## Preparación de la prueba

Activar opcionalmente trazas en Command Bar de Edit:

~~~lua
local run = game:GetService("RunService")
assert(run:IsStudio() and not run:IsRunning(), "Solo Edit")
game:GetService("ReplicatedStorage"):SetAttribute("SlapDiagnosticsEnabled", true)
~~~

Iniciá vos un servidor local con dos clientes. Verificá los marcadores **CombatSystemV132 Protocol=3** en servidor y ambos clientes. Si no coinciden, detener y comprobar sincronización, sin publicar para forzarla.

Antes de jugar, el Output del servidor debe confirmar Studio / InMemory / WritesToCloud=false. Consulta opcional de solo lectura, ejecutada por vos en la Command Bar del servidor local:

~~~lua
local run = game:GetService("RunService")
assert(run:IsStudio() and run:IsRunning() and run:IsServer(), "Solo servidor local")
local info = require(game:GetService("ServerScriptService").Services.PlayerDataService):GetPersistenceDiagnostics()
assert(info.Environment == "Studio" and info.ProviderName == "InMemory"
    and info.WritesToCloud == false, "ABORTAR: persistencia no aislada")
print("CombatV132 persistence:", info.Environment, info.ProviderName, info.WritesToCloud)
~~~

## Matriz de prueba con A/B

| Paso | Acción | Esperado |
| --- | --- | --- |
| 1 | Mirar el lobby con ambos clientes. | Ningún slot de inventario nativo ni de combate; nada equipado en mano. Backpack puede conservar datos/Tools almacenados, pero no se muestra. |
| 2 | Entrar a Red/Blue, votar y esperar countdown. | Slot propio “Clásico” aparece al equipar el Slap. No se ataca antes de Playing. |
| 3 | Separarse más de 9 studs y hacer un clic con A. | Swing inmediato una sola vez; overlay y barra vacía; contador visible. |
| 4 | Enseguida hacer diez clics rápidos y mantener pulsado. | No se reinicia Swing ni barra durante bloqueo conocido; una ventana aceptada, Miss y 0.45 desde su cierre. Aproximadamente 0.55 entre inicios de fallos normales. |
| 5 | Dejar recuperar y observar el slot. | Fill avanza a la derecha y contador baja; al quedar disponible, fill completo, overlay y contador ocultos. Si falta respuesta, “…” no representa listo. |
| 6 | Repetir con B y alternar. | Cooldowns, barra, IDs y animaciones independientes. |
| 7 | Acercarse de frente, acertar y continuar cuando sea elegible. | Ajuste a 0.15 desde Hit aceptado. Un solo track, sin segundo Play al llegar Started. |
| 8 | Intentar reequipar por los controles normales durante recuperación. | Se conserva el plazo. Si el bloqueo de equipamiento lo impide (y la barra nativa ya está oculta), registrar esa maniobra manual NOT RUN; no fabricar cambios mediante scripts. |
| 9 | Recibir tres impactos válidos en la misma vida. | Ragdoll de 3 s, eliminación única al tercero, Kill/Death/+50 una vez. Fallos/rechazos no cuentan. |
| 10 | Caer a KillPart y reaparecer. | Slot viejo oculto durante retiro; tracks/IDs obsoletos no afectan la vida nueva. Primer ataque válido no hereda el bloqueo anterior. |
| 11 | Probar StrongSlap y demás habilidades disponibles por el flujo normal. | Comportamiento anterior, sin modificar compras/inventario real; Miss conserva armado de StrongSlap. |
| 12 | Hacer gol y pasar a nueva ronda. | Sin ataques durante preparación; nueva ronda y cooldown correctos. |
| 13 | Finalizar, mirar EndCinematic y volver al lobby. | Sin slot ni herramienta competitiva en mano; cámara, efectos y premios intactos. |
| 14 | Completar una segunda partida. | Sin conexiones/tracks/cooldowns residuales; limpiar ActiveMatches al terminar. |
| 15 | Repetir interfaz en una sesión móvil/táctil que vos puedas iniciar. | Slot legible, sin cubrir joystick/salto ni capturar toques. El ataque sigue por Tool.Activated; no hay otro botón de ataque. |

La secuencia actual tiene unos 0.55 s visuales de Swing a velocidad 1.2. Atacar válidamente cada 0.55 s puede parecer continuo: distinguir movimiento continuo de reinicios adicionales durante un mismo bloqueo. No agregar una pausa de balance para fabricar una separación visual.

## Si continúa el spam o falla la barra

Enviar Output de servidor y ambos clientes, primero un clic limpio y después los diez clics, junto con video corto. Filtrar [SlapTrace]:

- ClientRequest/PredictionPlayed: presentación local, NO aceptación.
- RequestReceived: recepción del mensaje, NO hitbox nueva por sí sola.
- AttackStarted: aceptación real con AttackId autoritativo.
- RecoverySet: Outcome Hit/Miss y deadline.
- ServerRejected/ClientBlocked: bloqueo.
- FeedbackIgnored: acuse obsoleto.
- AttackError: error con identidad.

Comparar PredictionId, RequestId, AttackId, SessionId, RoundId y CharacterGeneration. En Miss, RecoveryUntil-AttackWindowClosed=0.45; en Hit=0.15. El siguiente inicio de la misma vida/ronda debe cumplir StartMonotonic>=PreviousRecoveryMonotonic.

Indicar si hubo reequipamiento, cambio de Character o generación, y cuántas partidas se completaron. Reportar PASS/FAIL/BLOCKED/NOT RUN para cada fila. Los logs se limitan a 12 filas por jugador/segundo por lado; spam extremo puede omitir trazas, por eso primero se necesita un intento limpio.

Al detener la prueba y regresar a Edit:

~~~lua
local run = game:GetService("RunService")
assert(run:IsStudio() and not run:IsRunning(), "Solo Edit")
game:GetService("ReplicatedStorage"):SetAttribute("SlapDiagnosticsEnabled", nil)
~~~

El agente no declara PASS funcional antes de recibir esta validación.

