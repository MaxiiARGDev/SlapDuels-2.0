# Ability System V1 — implementación y validación pendiente

Fecha: 2026-10-17. Repositorio: H:\repos-github\SlapDuels-2.0.

## 1. Auditoría previa

| Área | Situación encontrada |
|---|---|
| Gameplay V2 | Código de rondas de 180 s, Muerte Súbita a 30 s, recuperación por fallo/acierto y eliminación por tres palmadas. No hay resultados manuales nuevos del desarrollador en esta tarea: NO VALIDADO funcionalmente. |
| RoundService | Registro autoritativo por SessionId/Player; StartCountdown de 5 s y PointRestartCountdown de 3 s; un RoundClock por ronda; cierre y resultados centralizados. |
| Selección | No existía selección de habilidades. Los 3 s del reinicio resultan demasiado ajustados para presentar cinco opciones; se añadió una ventana explícita de 6 s, manteniendo las cuentas regresivas de 5/3 s. |
| Slap/Combat | Herramienta equipada legítima, alcance/cone, sesión/equipos y vida vigente; swing autoritativo y recuperación; CombatTag e impactos por ronda/Character/generación. |
| Ragdoll/knockback | Ragdoll centralizado, estado PlatformStand y timer activo. Es necesario cancelar primero el movimiento de habilidad para que su cleanup no cambie el ownership que toma ragdoll. |
| Eliminación/Zero-Death | Claim por vida y protección de gol; retiro inmediato y recuperación existente de 500 ms; una Kill/Death, recompensa confirmada de 50 Coins y efecto equipado por la víctima. Se reutiliza la misma ruta. |
| Shop/inventario | Providers por categoría, identidad Category:Id, lock, staging copy-on-write y commit único en PlayerService. Owned y Equipped ya admiten categorías adicionales. No había precios de habilidades. |
| Persistencia | Resolve observado en Edit: Studio / InMemory / WritesToCloud=false. Proveedor inyectado y fijo en PlayerDataService; sin cambio de adapters, nombres, Universe ID ni escritura cloud. El Bootstrap de un servidor de juego no se ejecutó en esta tarea. |
| Cliente/inputs | ClientBootstrap descubre controllers; SlapController usa Tool.Activated; no existía asignación de habilidad. Se añade E y el botón táctil; no se inventa un binding de gamepad. |
| Music/preferences | Música local centralizada, preferencias y suspensiones existentes. No se modificaron MusicController ni SettingsController. Los SFX de habilidad son independientes de música. |
| Recursos | HUDs físicos existentes; pestañas Shop basadas en atributo Category. No existían AbilityHUD ni AbilityEffects. |

## 2. Arquitectura y contratos

AbilityDefinitions centraliza IDs, orden, nombres, tipos, duraciones, cooldowns, balance, disponibilidad, Icon y ruta de efecto. AbilityService administra selección, propiedad, temporizadores, lifecycle y el estado por sesión/jugador. ServerScriptService.Abilities contiene los cinco módulos y MovementGuard. AbilityController enlaza el HUD/input; Abilities.AbilitySelection y AbilityPresentation separan selección y presentación local.

Bootstrap carga AbilityService después de los servicios de combate. Init conecta dos RemoteEvents bajo el namespace Combat existente; Start conecta un solo Heartbeat y PlayerRemoving. No hay bucles/task.wait por habilidad activa.

Remotes físicos: ReplicatedStorage.Remotes.Combat.AbilityRequest y AbilityState. Request acepta Sync, Select, Activate y AirJump. El cliente no elige víctima, fuerza, recompensa, duración, cooldown ni CFrame. El servidor calcula todo eso. AbilityState entrega snapshots privados por jugador; no usa FireAllClients.

## 3. Catálogo y configuración

| ID | Duración mecánica | Cooldown | Balance V1 |
|---|---:|---:|---|
| Dash | Impulso de 0,2 s, presentado como instantáneo | 11 s | 24 studs provisionales, dirección horizontal de movimiento; orientación si está quieto |
| StrongSlap | Armed hasta 15 s o impacto válido | 25 s | Kill inmediata por ruta existente; espectáculo local asciende 25 studs |
| AirJumps | 15 s | 20 s | Impulso vertical 32, mínimo 0,8 s, máximo 4 consecutivos, tope vertical 38 y ascenso de 24 studs desde suelo |
| DevilSpeed | 5 s | 14 s | Base × 2,4, máximo 48, aceleración 100 studs/s² |
| Invisible | 5 s | 35 s | Invisibilidad local coordinada, rastro tenue configurable |

La geometría inspeccionada contiene pisos con dimensiones distintas: entre otras, 27×2×9 y 14×2×9, además de piezas orientadas con 9 en otros ejes. No se demostró un cuadriculado uniforme: 24 studs NO se declaran equivalentes a cuatro cuadros.

## 4. Precios y compras pendientes

Dash es un entitlement gratuito. StrongSlap, AirJumps, DevilSpeed e Invisible tienen Price=0 como campo pendiente, PriceApproved=false y PurchaseEnabled=false. Ese cero NO constituye una oferta gratuita. Shop muestra PRECIO PENDIENTE y desactiva COMPRAR. Provider y ProfilePurchase también rechazan la transacción.

Para habilitar una compra futura se necesita un precio entero positivo aprobado, PriceApproved=true y PurchaseEnabled=true en AbilityDefinitions. No se decidió ningún precio comercial, no se usaron Robux ni Developer Products. La validación funcional de compras reales de estas cuatro habilidades está BLOCKED hasta esa aprobación. Las pruebas aisladas usan precios ficticios únicamente en sus copias descartables de configuración.

Se añadió ProductType="Ability" al registro, staging y equipamiento existentes. Se conserva el mismo saldo Coins, Owned, Equipped y commit atómico; no se crea otra economía ni inventario.

## 5. Propiedad, preferencia y selección

- OwnedAbility: Inventory.Owned.Abilities[id]. Dash se agrega de forma aditiva al inventario inicial y al sanitizer; se preservan categorías e ítems existentes.
- PreferredAbility: Inventory.Equipped.Abilities, almacenado por el contrato existente. Shop dice PREFERIDA/PREFERIR. Cambiarla no modifica la ronda activa.
- RoundSelectedAbility: AbilityService._sessions[SessionId].Players[player].AbilityId. Se confirma solamente en la ventana vigente y con propiedad comprobada. Preferencia inválida o inexistente cae a Dash.

La ventana tiene WindowId propio, deadline de servidor y snapshots con SelectionUntil. Se abre después del spawn/bloqueo, antes del countdown inicial, y después del spawn de reinicio, antes de su countdown. Se cierra al cumplirse sus 6 s; luego corren los 5/3 s originales. Cada participante selecciona individualmente. No se habilitaron modos XvX ni concurrencia.

## 6. Dash

Movimiento mediante velocidad física de una assembly temporalmente administrada por el servidor; no usa PivotTo/teleport. Direction del cliente debe ser Vector3 finito y de magnitud limitada; el servidor normaliza sólo la componente horizontal. La distancia y duración son del catálogo.

MovementGuard comprueba volumen inicial, Blockcast con margen, límites X/Z del envelope de arena y una intersección geométrica adicional de KillParts, incluso si CanQuery=false. Si no hay envelope válido o el frame es demasiado largo, se detiene. Un contacto/sweep inseguro no habilita invulnerabilidad ni modifica sensores. La respuesta real contra esquinas, obstáculos, latencia y bordes debe probarla el desarrollador.

## 7. Golpe Fuerte

La activación arma una carga. SlapService captura un token de carga al resolver el contacto, registra el CombatTag usando la validación existente y omite el incremento de combo para ese impacto. Consume la carga una sola vez y llama HandleStrongSlap, que valida rival/tag y usa _processEliminationEvent con fuente StrongSlap. No recorre además la rama de tercer golpe.

La eliminación captura la posición real antes del retiro. Sólo después de que EliminationService devuelve confirmación se emite el espectáculo vertical local. Es un prop físico autorado (LaunchSpectacle) clonado para presentación y animado sin colisiones; NO se aplica fuerza al Character competitivo retirado. El Death Effect de la víctima, Kill/Death, reward de 50 Coins, killfeed y respawn siguen en los servicios existentes. El feedback de Coins sigue dependiendo del monto realmente confirmado; no se acredita dinero desde AbilityController.

## 8. Saltos de Aire

El servidor cuenta saltos, controla el intervalo, verifica suelo/ascenso/tope y comprueba espacio superior. Cada impulso toma brevemente ownership (0,15 s) y luego devuelve el estado anterior. La ventana completa no retiene ownership permanentemente. JumpRequest reutiliza el salto normal del dispositivo; el botón de habilidad también solicita un salto adicional durante la ventana activa. No se agregan bindings de plataforma sin definir.

## 9. Velocidad Diabólica

WalkSpeed aumenta progresivamente hasta el objetivo. El módulo guarda base y último valor aplicado: si otro sistema cambia WalkSpeed, deja de ser dueño y cancela; al limpiar sólo restaura si sigue teniendo su propio valor. El derribo cancela la duración restante, sin pausar/reanudar y sin devolver cooldown. No cambia colisiones, KillPart, hitboxes o inmunidad.

## 10. Invisible

Estado del servidor, presentación local sólo para participantes de esa sesión. Guarda LocalTransparencyModifier de BaseParts, Transparency de Decals, estado de efectos/GUI del avatar y DisplayDistanceType. Incluye descendientes nuevos del Slap/accesorios. Al reparentar un objeto ya ocultado no sobrescribe su valor original guardado. Restaura sólo propiedades que todavía conserva como propias.

No cambia transparencias del servidor, colisiones, hitboxes o sensores. Los jugadores ajenos a la sesión no reciben esta presentación local. El rastro se clona del asset persistente y se excluye de la ocultación del avatar. La restauración visual/multicliente requiere prueba manual.

## 11. Cooldowns y vida

Todos comienzan en la activación aceptada (CooldownPolicy="OnActivation"). El registro activo contiene AbilityId, SessionId, UserId original, Character, CharacterGeneration, ActivationId, ActivatedAt, ActiveUntil y CooldownUntil. LifeId adicional distingue Characters distintos aun si reinician el mismo número de generación. Los requests de la vida anterior se rechazan.

Se cancela el efecto al morir/eliminarse, cambiar Character/generación, derribarse, resolver gol/timeout, cerrar sesión o desconectarse. Los cooldowns se conservan dentro de la misma ronda y se reinician en BeginGameplayRound, después de la preparación. Ragdoll cancela primero las habilidades antes de tomar ownership/velocidad. La restitución conserva ownership anterior automático/manual y respeta un nuevo dueño explícito.

## 12. HUD PC/móvil

StarterGui.AbilityHUD es físico, ResetOnSpawn=false, con AbilityButton.Icon, AbilityName, CooldownLabel y CooldownOverlay. AbilitySelectionFrame contiene Title, Hint y Cards.AbilityCardTemplate con Icon, AbilityName, Description, Cooldown y Status. Sólo las cards de datos se clonan de esa plantilla durante el juego.

E activa en PC, respetando input procesado y TextBox. El botón grande funciona por Activated para mouse/touch. El controller nunca reasigna Position del botón. Tamaños/límites son editables; selección horizontal con scrolling para pantallas pequeñas. El HUD informa cooldown, disponibilidad, bloqueo, estado activo/Armed y tiempo restante. Iconos quedan como campos editables sin inventar asset IDs; los nombres siempre identifican la habilidad.

## 13. Recursos físicos instalados

- ReplicatedStorage.AbilityEffects.{Dash,StrongSlap,AirJumps,DevilSpeed,Invisible}.Origin: Attachment con Particles, TrailStart, TrailEnd, Trail, Beam y ActivationSound.
- StrongSlap.LaunchSpectacle: Part anclado, sin colisión/touch/query; presentación abstracta independiente del rig competitivo.
- StarterGui.AbilityHUD: 23 descendientes.
- StarterGui.ShopHUD.MainFrame.Tabs.AbilitiesTab: Category="Abilities", etiqueta ABILITIES, usando el estilo de la pestaña existente.
- ServerStorage._AbilityV1Backups.ShopHUD_Before: copia física anterior de la tienda; original conservado.

AbilityEffects tiene 41 descendientes, cinco emitters, cinco trails, cinco beams y cinco Sounds con SoundId vacío. AUDIO BLOCKED: no se inventaron IDs. Los recursos se exportaron nativamente a .rbxm y se comprobó su deserialización/estructura. La inspección Edit no equivale a aprobación visual en juego.

## 14. Seguridad y aislamiento

Se validan Player conectado, identidad de sesión/participante, sesión activa no cerrada, Playing y ronda abierta, habilidad seleccionada/adquirida, Character/Generation/LifeId, salud, ragdoll, root no anclado, ausencia de recuperación pendiente, cooldown y ausencia de activación en curso. Rate limit de 0,12 s por jugador; AirJump exige el ActivationId vigente. Selección exige el WindowId vigente y su deadline. Revisión creciente en snapshots evita aplicar mensajes viejos.

No se modifica MatchmakingService, ScoreService, SpawnService, Config general, los adapters de persistencia, MusicController, SettingsController, DeathEffectService ni los módulos EndCinematic. Sus fuentes están entre las 64 comprobadas sin cambios frente al baseline anterior. No se modificaron mapas, cámaras ni ScenarioFinal.

## 15. Integración y limpieza

BeginGameplayRound confirma/activa habilidades y reinicia cooldowns. CancelGameplayRecoveries cancela efectos antes de las transiciones por gol/timeout/final. CloseSession libera AbilityService mediante un paso del coordinador de cierre. PlayerRemoving puede limpiar aun si RoundService ya quitó al participante de su índice. El Heartbeat vuelve a comprobar identidad y deadline; no depende de un task.wait para caducar.

La Muerte Súbita no crea otro régimen: mientras Playing/ronda abierta, las habilidades siguen las mismas reglas. Un StrongSlap no se clasifica como caída que otorga gol súbito. La resolución de puntuación y recompensas de gol permanece intacta.

## 16. Archivos y respaldo

25 fuentes: 13 existentes ajustadas y 12 nuevas. Lista y hashes normalizados en AbilitySystemV1.deployment.json. Cambios existentes: Bootstrap, Types, ShopController, CombatService, EliminationService, PlayerDataService, PlayerService, RagdollService, RoundService, ShopService, SlapService, ProfilePurchase y ShopRegistry.

Nuevos: AbilityDefinitions, AbilityService, AbilityProvider, AbilityController, seis módulos en src/server/Abilities y dos en src/client/Abilities. Recursos: AbilityHUD.rbxm y AbilityEffects.rbxm nuevos, ShopHUD.rbxm reexportado tras añadir la pestaña. default.project.json agrega esas rutas y la carpeta Abilities; studio-safe.project.json agrega mappings individuales y los dos remotes, manteniendo ignoreUnknownInstances en todos los nodos.

Respaldo de archivos previos y manifiesto: tests/assets/backups/AbilitySystemV1. El respaldo integral anterior y las carpetas _RojoSyncRecovery permanecen intactos. No se hizo reset/restore/clean/stash/checkout/commit/push. Las modificaciones locales anteriores se preservan. No se guardó ni cerró el lugar: los objetos existen en Edit y están exportados, pero el guardado del lugar sigue bajo control del desarrollador.

## 17. Evidencia y resultados

| Comprobación | Resultado | Límite |
|---|---|---|
| Lógica aislada Luau | PASS: 108 aserciones | Mocks descartables fuera de Studio; no valida física/red/GUI |
| Sintaxis | PASS: 91 archivos | 89 fuentes y dos suites/instalador; no es un análisis completo de tipos Roblox |
| rojo build default.project.json | PASS | Build completo de recursos mapeados; no prueba jugabilidad |
| rojo build studio-safe.project.json | PASS | Perfil de sincronización de código |
| git diff --check | PASS | Whitespace de cambios rastreados |
| Fuentes tocadas repositorio/Studio | PASS: 25/25 | Hash SHA-256 con CRLF y whitespace final normalizados; también se revisó GetEditorSource |
| Fuentes protegidas | PASS: 64/64 sin cambios | Baseline anterior de 77 fuentes menos las 13 ajustadas |
| Recursos Edit | PASS de estructura | Cinco efectos, HUD, tab, remotes y ningún nombre duplicado en árboles de código revisados |
| Perfil seguro Rojo | PASS: 89/89 fuentes, 133 nodos, sin rutas duplicadas | Todos conservan objetos desconocidos |
| Persistencia en Edit | Studio / InMemory / WritesToCloud=false | Resolución inspeccionada; comprobar de nuevo el diagnóstico del servidor que inicie el desarrollador |
| Play/Run/servidores/partidas por el agente | NOT RUN | Prohibido por alcance |
| Compras comerciales de habilidades | BLOCKED | Faltan cuatro precios aprobados |
| Audio de habilidades | BLOCKED | Cinco Sounds preparados, sin IDs autorizados |

Compilador oficial Luau 0.743, descargado únicamente en una carpeta temporal. Los resultados de la suite están en AbilitySystemV1.unit-results.txt; recursos y fuentes Edit en AbilitySystemV1.edit-evidence.json; hashes protegidos en AbilitySystemV1.protected-sources.json.

## 18. Matriz de regresión funcional

Todos estos escenarios quedan pendientes del desarrollador. Ninguno se marca PASS por inspección de código o por la suite aislada.

| Prueba | Estado | Evidencia requerida |
|---|---|---|
| Matchmaking, voto, spawn y countdown original | NOT RUN | Video de ambos clientes y Output de servidor |
| Selección primera ronda y después de gol | NOT RUN | HUD de selección, confirmación, elección bloqueada en Playing |
| Dash frontal/lateral/diagonal/atrás/quieto, 11 s | NOT RUN | Video, HUD y registro autoritativo de cooldown |
| Dash contra pared/borde y durante ragdoll | NOT RUN | Sin atravesar ni activar derribado, sin impulso residual |
| StrongSlap ventana 15 s y cooldown 25 s | NOT RUN | Caducidad sin Kill, fallo conserva penalización |
| StrongSlap válido y sobre tercer impacto | NOT RUN | Una Kill/Death, +50 Coins una vez, efecto víctima, un respawn |
| AirJumps durante 15 s y cooldown 20 s | NOT RUN | Saltos moderados, límite de encadenamiento/ascenso/techo |
| DevilSpeed 5 s y cooldown 14 s | NOT RUN | Aceleración controlable, colisiones y restauración correcta |
| Speed derribado/respawn/lobby | NOT RUN | Sin velocidad/ownership residual ni sobrescritura de locks |
| Invisible 5 s y cooldown 35 s | NOT RUN | Avatar/Slap ocultos, rastro y restauración de accesorios |
| Invisible recibe golpes/KillPart | NOT RUN | Sigue siendo vulnerable y se recupera correctamente |
| Preferencia Shop vs selección vigente | NOT RUN | PREFERIR no cambia habilidad durante Playing |
| Compra de no adquirida sin precio | NOT RUN | UI bloqueada; rechazo server y mismo saldo |
| Compra comercial/duplicados reales | BLOCKED | Requiere aprobación de precios; staging sí probado con mocks |
| Cooldown tras morir y reset en nueva ronda | NOT RUN | Deadline conserva valor tras vida nueva y se reinicia tras preparación |
| Spam/replay/ajeno a sesión | NOT RUN | Sin activaciones/recompensas extra; datos autoritativos |
| KillPart, tres slaps, Zero-Death, death feedback | NOT RUN | Conteo/recompensa única, respawn existente |
| Gol +50, aviso 4, quinto/EndCinematic | NOT RUN | Puntuación/premio normales y habilidades canceladas |
| Reloj 180 s / Muerte Súbita / timeout | NOT RUN | Timer y resolución existentes, sin régimen de cooldown paralelo |
| Lobby, segunda partida, limpieza | NOT RUN | Sin efectos/HUD ajenos ni estados/conexiones residuales |
| Shop Frost/Void y preferencias musicales | NOT RUN | Compra/equipamiento existentes y configuración intacta |
| PC/móvil y escalado artístico | NOT RUN | E, touch, scrolling y botón en su posición editada |

## 19. Próximo paso

El desarrollador ejecuta el procedimiento de AbilitySystemV1.manual.md. Si el plugin se desconectó al reiniciar el servidor seguro para incorporar las rutas nuevas, reconectar a 127.0.0.1:34873 y confirmar SlapDuels-2.0 Scripts Only SAFE. Los scripts y objetos ya fueron instalados mediante MCP Edit; no hace falta ejecutar el instalador de recursos, que rechaza sobreescrituras.

No continuar a otra fase ni publicar. Falta validación funcional/física/multicliente, aprobación de precios y asignación de audio/iconos definitivos.

Referencias técnicas: [Blockcast y límites de detección inicial](https://create.roblox.com/docs/reference/engine/classes/WorldRoot), [serialización nativa de instancias](https://create.roblox.com/docs/reference/engine/classes/SerializationService), [herramientas oficiales Luau](https://github.com/luau-lang/luau/releases).
