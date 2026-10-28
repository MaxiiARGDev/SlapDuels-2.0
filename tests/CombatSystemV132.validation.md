# Combat System V1.3.2 — slot de combate, cooldown y Swing

Fecha: 2026-10-18 (America/Buenos_Aires). Estado: implementación en Edit terminada; **validación funcional pendiente del desarrollador**.

## Auditoría y diagnóstico

Se inspeccionaron SlapController, SlapService, CombatService, los remotes y su contrato Protocol=3, configuración y distribución de Classic, fuentes de Studio y StarterGui. La búsqueda del DataModel abierto encontró referencias de combate/Swing en SlapController y SlapService; la Tool Classic no contiene scripts embebidos. No se encontró un slot personalizado de Classic ni otro controlador de hotbar en el repositorio/StarterGui. El slot anterior era el inventario nativo, no un descendiente editable de PlayerHUD.

El desarrollador autorizó expresamente crear slots propios para los combates dentro de PlayerHUD y aclaró que fuera de combate no debe haber slots ni herramientas en mano. Se implementó esa política sin un ScreenGui adicional.

Classic.Swing sigue siendo rbxassetid://204062532. Una consulta de solo lectura al recurso original devolvió KeyframeSequence, Loop=false, 5 keyframes y duración 0.6600000262 s. A la velocidad existente 1.2 su duración visual ronda 0.55 s, muy próxima al ciclo normal de Miss. Eso puede dar sensación de continuidad, pero **no demuestra que el servidor aceptara ataques prematuros**.

Solo existe una llamada de reproducción de Swing en SlapController, después del gate local/reserva de predicción. No hay una segunda ruta propia de UserInputService o ContextActionService para atacar. Tool.Activated es la entrada común a ratón/touch. No se cargan animaciones por clic ni se usa Stopped como reloj competitivo.

Debilidades concretas reforzadas:

- V1.3.1 no fijaba Looped=false y al desequipar detenía pero no destruía explícitamente el track. El recurso actual NO está en loop: esa falta era una defensa ausente, no la causa probada.
- Equip/Init/Start repetidos podían rehacer enlaces; ahora son idempotentes.
- La búsqueda del remote puede ceder mediante WaitForChild. Se añadió revalidación después de ella para impedir que dos callbacks que reanudan creen dos predicciones. Un test de reentrada ejerce este caso; no se afirma que haya ocurrido en el intento manual anterior.

La causa histórica de las palmadas percibidas como spam sigue sin confirmarse sin sus logs. Los FAIL manuales anteriores de spam/latencia no se convierten en PASS por estas pruebas.

## Distribución y reproducción de la animación

SlapService:GiveSlap clona ServerStorage.Slaps.<slap> con su Animation Swing hacia Backpack/Character y lo equipa; añade IsSlapWeapon=true. El cliente no accede directamente a ServerStorage. SlapController lee Swing de la Tool equipada replicada y lo carga en el Animator de esa vida.

- Solo Tools selladas como Slap por el servidor pueden enlazar este controlador.
- Un equip repetido de la misma Tool/track/conexión no crea otro enlace.
- El track se carga al equipar; Priority=Action y Looped=false.
- Un intento local elegible reserva su predicción antes de Play; el spam conocido retorna sin Play ni FireServer.
- Un nuevo Hit elegible puede detener/reiniciar el MISMO track para la cadencia rápida; no apila tracks. La velocidad permanece en 1.2.
- Desequipar, morir o cambiar de generación/Character libera los tracks obsoletos. El reequipamiento conserva deadlines de la misma vida.
- Un rechazo cancela únicamente la predicción correlacionada. Started no vuelve a animar y un acuse antiguo no detiene una predicción nueva.

Looped/Play/Stop pertenecen al track; su fin no concede permiso para atacar. Véase [AnimationTrack, documentación oficial](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack). La consulta de metadatos se realizó con el método de lectura del [KeyframeSequenceProvider](https://create.roblox.com/docs/reference/engine/classes/KeyframeSequenceProvider); no se usa ese servicio en los scripts de producción.

## Contrato competitivo intacto

| Parámetro | Valor y comienzo |
| --- | --- |
| Ventana | 0.10 s desde inicio aceptado; termina antes si se acepta Hit |
| HitRecovery | 0.15 s desde RegisterHit aceptado |
| MissRecovery | 0.45 s desde cierre efectivo sin impacto válido |
| Muestreo | Hasta cada 0.025 s |
| Classic.Power | 20, sin cambios |
| Classic.SlapCooldown | 0.6, fallback si SlapCombo.Enabled=false |
| SlapCombo.Enabled | true |

El ciclo normal de fallo ronda 0.55 s; no se añade una pausa cosmética artificial entre ciclos válidos. No cambiaron knockback, ragdoll de 3 s, umbral de tres impactos, StrongSlap, Kills, efectos, Coins, Shop, cinco habilidades/AbilityRegistry, marcador, 180 s, Muerte Súbita ni EndCinematic.

Se conserva Protocol=3: RequestId/PredictionId y AttackId autoritativo separado; Character/generación/sesión/ronda, Sequence y RecoveryUntil. La presentación se predice al input; el servidor sigue siendo la única autoridad de ventana, impacto y recuperación. Los estados Window/Recovery impiden otra búsqueda/impacto prematuro aunque un cliente se salte su gate.

## Estado compartido para input y barra

GetCooldownState(now) es la única lectura de bloqueo temporal usada por el input y el renderer. Deriva Deadline de max(deadline autoritativo, deadline provisional) y la espera de transporte existente. No crea otro cooldown ni otro task/timer competitivo.

Al comenzar un intento se registra visualStart y el plazo provisional existente de ventana+Miss. La barra parte de cero; segundos y fracción se calculan con GetServerTimeNow. Hit/Miss confirmados ajustan al deadline real; Hit no queda esperando un Miss provisional. Un rechazo no borra bloqueos posteriores.

La fracción es (ahora-visualStart)/(deadline-visualStart), limitada a [0,1]. Mientras falta resultado, se mantiene por debajo de 100 %. Si el plazo provisional venció pero aún se espera respuesta, el contador muestra “…” en vez de anunciar disponibilidad falsa. Al finalizar realmente, fill=100 %, overlay/contador ocultos y apariencia normal. Clics bloqueados no cambian visualStart.

Un RenderStepped por controlador dibuja la UI; no decide impactos ni modifica deadlines. El render se desconecta en Destroy. El slot se oculta durante ArenaRespawnPending, muerte, final y lobby.

## UI persistente y rutas exactas

Raíz existente: StarterGui.PlayerHUD. Nuevo contenedor: **StarterGui.PlayerHUD.CombatSlots**, Frame inferior centrado, con UIListLayout horizontal para extender a futuros slots. Su slot actual es **StarterGui.PlayerHUD.CombatSlots.SlapSlot**.

Componentes pedidos:

| Componente | Ruta relativa a StarterGui.PlayerHUD.CombatSlots.SlapSlot |
| --- | --- |
| CooldownOverlay | CooldownOverlay |
| CooldownBarBackground | CooldownOverlay.CooldownBarBackground |
| CooldownBarFill | CooldownOverlay.CooldownBarBackground.CooldownBarFill |
| CooldownTimeLabel | CooldownOverlay.CooldownTimeLabel |

Otros componentes: NameLabel, ToolIcon, FallbackIcon, KeyLabel, UICorner/UIStroke y StringValues DefaultToolName/DefaultDisplayName. El nombre inicial “Clásico” es configuración física: no hay if SlapName=="Classic" en la lógica. Futuros slaps usan DisplayName, ToolTip o su nombre y su propia Animation/TextureId.

Se instalaron **18 instancias**, sin ScreenGui nuevo, duplicados ni objetos temporales en el DataModel. Todos los GuiObjects creados tienen Active=false y Selectable=false; no se añadió otro botón de ataque ni captura de gestos. Los 22 objetos previos de PlayerHUD conservaron las propiedades inspeccionadas. No se alteraron ProfileCard, Coins ni otros HUD.

La instalación existe en Edit, con CombatSlots.Visible=false como estado de lobby. Sus propiedades coinciden con el asset declarativo; se tolera 1e-6 para precisión float32 de Roblox. La jerarquía está verificada también en el build default.

Fuente editable: src/ui/CombatSlots.project.json. default.project.json añade solamente este hijo bajo PlayerHUD con ignoreUnknownInstances=true, preservando los hijos previos. El asset permite hijos desconocidos. [Rojo documenta la preservación de instancias desconocidas](https://rojo.space/docs/v7/project-format/). El perfil SAFE no cambió: sigue gestionando scripts y preserva la UI física como desconocida; su build no pretende contener la UI del place.

## Política autorizada de slots y manos vacías

La barra nativa Backpack permanece oculta mientras funciona SlapController, incluso en lobby. Se utiliza únicamente el tipo Backpack mediante la [API oficial de StarterGui](https://create.roblox.com/docs/reference/engine/classes/StarterGui); no se ocultan joystick, salto ni otros CoreGui. La preferencia original se conserva para teardown del controlador; una salida normal de combate no la restaura.

El slot propio aparece solo con Slap equipado y jugador vivo en su sesión, durante StartCountdown/Playing/PointRestartCountdown. La preparación conserva los bloqueos existentes y no permite ataques.

SlapService observa solo Players reales y sus Characters. Una Tool sin permiso competitivo se mueve a Backpack (o a Player si todavía no existe Backpack) en la comprobación diferida; **no se borra el inventario**. Se requiere Slap sellado, participante autoritativo, MatchId vigente y estado competitivo permitido; no se permiten herramientas equipadas en lobby/Ending. La limpieza existente de ronda destruye los Slaps gestionados y ahora guarda también herramientas ajenas que hubiera en mano.

No se recorren ni modifican NPCs, herramientas decorativas del mapa o las Tools almacenadas en packs de VFX. PlayerAdded/CharacterAdded/ChildAdded son las entradas de la política; PlayerRemoving desconecta sus enlaces. No se cambió Shop ni economía.

## Archivos y protección

Funcionales modificados:

- src/client/Controllers/SlapController.luau.
- src/server/Services/SlapService.luau.
- default.project.json (mapeo del slot).

Añadidos:

- src/ui/CombatSlots.project.json.
- tests/CombatSystemV132.spec.luau.
- tests/tools/combat_v132_files.py y verify_combat_v132_ui.py.
- Informe, guía, evidencia, manifiestos, logs y builds CombatSystemV132.

studio-safe.project.json no se modificó. El resto de **114 archivos existentes bajo src** se comprueba por SHA-256 sin diferencias. Respaldo: tests/assets/backups/CombatSystemV132, con cuatro copias previas (dos scripts y ambos perfiles), manifest.json y protected.json. Respaldos anteriores preservados.

## Resultados de verificación

| Verificación | Resultado |
| --- | --- |
| Combate, tracks, estado y render de UI | PASS: 124 aserciones aisladas |
| Regresión habilidades | PASS: 164 |
| AbilityRegistry | PASS: 89 |
| Total | **377 aserciones aisladas** |
| Compilación | PASS: 99 archivos (98 fuentes + spec) |
| Rojo default | PASS |
| Rojo SAFE | PASS |
| Jerarquía del asset/build | PASS: 18 instancias, 0 ScreenGui dentro del nuevo asset, 0 objetos interactivos |
| MCP Edit | PASS de existencia/hashes: dos Source/GetEditorSource coinciden con disco; componentes únicos y propiedades verificadas |
| Integridad | PASS: 114 archivos protegidos sin diferencias, cuatro respaldos íntegros y sin problemas de espacios finales |
| git diff --check | PASS: código 0; git-diff-check.log. Solo advertencias preexistentes LF/CRLF, sin cambiar configuración |

La suite ejercita los quince grupos solicitados: Miss/Hit, un Swing por intento, diez clics bloqueados, rechazo, plazos/barra/texto, reequipamiento, acuses viejos, muerte/respawn, tercer impacto, StrongSlap, independencia y UI sin captura de input. Añade clics/reentrada, inicialización repetida y manos vacías fuera de combate.

La red, geometría, Animator y sinks de ragdoll/eliminación son fixtures. CombatService y hooks de habilidad se ejecutan realmente, pero esto no prueba física del motor ni transacciones integradas con jugadores. La compatibilidad móvil se verifica aquí por propiedades y ausencia de nuevos handlers, no mediante una sesión táctil real.

## Evidencia y límites

CombatSystemV132.edit-evidence.json conserva auditoría de fuentes/rutas, metadatos del recurso, instalación y hashes finales. No se activó Play/Run/Start Server/Team Test ni se controlaron personajes. El único acceso remoto fue la lectura de metadatos de la Animation; no hubo escrituras cloud ni DataStoreService.

IsStudio=true, IsRunning=false; Config y PersistenceEnvironment mantienen los hashes anteriores. Studio sigue seleccionando InMemory/false por su política fuente, sin inicializar persistencia en Edit para esta auditoría. La guía exige confirmar el proveedor runtime antes de probar.

Diagnósticos [SlapTrace] siguen apagados; cliente/servidor se identifican CombatSystemV132 Protocol=3. Si persiste el FAIL, enviar servidor y ambos clientes, PredictionId/AttackId, RequestTime, AttackStarted, cierre/RecoveryUntil, próximo inicio y video del reinicio real de Swing.

**No hay PASS funcional de V1.3.2.** Quedan pendientes dos clientes, sensación de la animación, layout real en pantallas móviles, reenlace físico de Animator y regresión integrada de tercer golpe/KillPart/Coins/EndCinematic. Guía: CombatSystemV132.manual.md.

No hubo commits, push, publicaciones, guardado forzado, cierre del place ni modificaciones a DataStores. Detenerse hasta validación del desarrollador.

