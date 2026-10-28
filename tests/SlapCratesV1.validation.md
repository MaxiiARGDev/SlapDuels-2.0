# Slap Crates System V1 — entrega

Implementación funcional para el proveedor aislado de Studio, con catálogos comerciales pendientes y producción bloqueada. Sin Play, Run, Team Test, Start Server, control de personajes, publicaciones, commits, push ni escrituras cloud.

## Arquitectura e integración

| Entregable | Implementación |
|---|---|
| Auditoría Shop/Slaps | SlapCratesV1.audit.md; economía e inventario existentes reutilizados. |
| VariationRegistry / CrateRegistry | Catalog.Variations y Catalog.Crates mediante Registry.Build, manifests autorizadas y IDs duplicados rechazados. 12 variaciones, 12 cajas comerciales sin valores aprobados; fixture adicional StudioTest opt-in. |
| Slap + variación | Catalog.Rewards genera RewardId estable y permite varios SlapId por variación. Classic:Basic conserva el default; se preservan derechos legados. |
| StockService | InMemoryStock + StockLedger; reservas conjuntas reward/variación, estados Reserved/Issued/Released, sin regenerar emisiones. Scope explícito StudioServerInMemory. |
| Backend productivo | ProductionStockAdapter preparado con store inyectado/UpdateAsync; no conectado y snapshot deliberadamente bloqueado. NO hay backend productivo completo ni validación real entre servidores. Ver contrato y bloqueantes en SlapCratesV1.persistence.md. |
| Operaciones parciales | Journal dentro de Inventory; GrantCommitted conserva reserva hasta reconciliación. Reintento usa mismo OperationId y premio; no se confunde UpdateAsync con transacción entre stores. |
| Motor de probabilidades | Peso por variación dividido entre SlapId elegibles, exclusiones por recursos/stock/propiedad, normalización por recompensa. Pesos inválidos/stock desconocido bloquean antes de cobrar. |
| Disclosure | Quote por jugador con token de 30 s y firma de distribución/stock/precio. UI muestra porcentaje final por RewardId; cambios exigen consultar otra vez. |
| Shop | Providers Crates/Slaps registrados desde CrateService, sin cambios a ShopService/ShopRegistry/ProfilePurchase. Whitelist de ShopRemotes ampliada para metadatos pendientes. Tab CAJAS y botones por tarjeta. |
| Compra y cajas cerradas | Purchase separado de Open. Purchase debita Coins y agrega Inventory.Crates en commit único del perfil actual. |
| Apertura | Open consume caja, fija recompensa, reserva y registra unidad antes de emitir Reveal. Cierre/desconexión del HUD no concede ni elimina premios. |
| Ruleta HUD | Controlador cliente, tira horizontal con desaceleración, centro exacto sobre resultado confirmado, cierre al terminar, Sounds editables Tick/Reveal. |
| Apertura 3D | Instancias locales de modelos persistentes para comprador/observadores cercanos en lobby; sin HUD ajeno, partes sin colisiones/touch/query y limpieza 2 s después de reveal. |
| VFX/SFX | 12 perfiles editables, ParticleEmitters y Sounds vacíos. Mesh de preview reutiliza Classic.Hand. Diseños/audio definitivos pendientes; no se inventaron SoundIds. V1 soporta AnimationProfile Horizontal; extensiones visuales nuevas requieren adaptador, no se aceptan perfiles arbitrarios. |
| Anuncios | AnnouncementAdapter local idempotente por OpeningId sobre Remotes.Crates.Announce y TextChatService.RBXGeneral. PublishGlobal queda inerte; ningún MessagingService. AnnounceInChat=false en las 12 definiciones hasta aprobación. |
| Inventario y equipo | SlapUnits guarda identidad/unidad/edición/operación/propietario; Owned.Slaps mantiene compatibilidad. Equipar valida la combinación exacta, lobby y recurso; GiveSlap usa la misma Tool base y añade solo presentación. No compra individual. |
| Extensibilidad | SlapCratesV1.add-content.md detalla nuevas definiciones/módulos explícitos y recursos, stock, pesos y anuncios. No se editan servicios generales para agregar contenido. |
| PolicyService | Consulta real desde servidor; cualquier error, respuesta desconocida o ArePaidRandomItemsRestricted distinto de false bloquea Quote/Purchase/Open. Se aplica conservadoramente también a Coins; sin trading. |

Los porcentajes, precios y stocks de producción NO están configurados. StudioTest usa 1 Coin, Basic=3/Common=1, exclusivamente como fixture aislada. Sigue desactivada en el place: ServerStorage.CrateStudioTestsEnabled=false/ausente. El uso manual requiere activarla explícitamente en Edit siguiendo la guía.

## Objetos físicos verificados en Edit

- ReplicatedStorage.CrateEffects: Basic, Common, Uncommon, Rare, Gold, Arcoiris, Emote, Wings, Epic, Legendary, Blood, Galaxy; Body/Lid, ParticleEmitter Burst y Sound Reveal.
- ReplicatedStorage.SlapVariationEffects: mismos 12 perfiles; atributo Tint, Sparkles y Reveal.
- ReplicatedStorage.CrateRewardPreviews.Classic.Hand.Mesh: forma de Classic existente; sin Tool ni lógica autoritativa replicada.
- StarterGui.ShopHUD.MainFrame.Tabs.CratesTab.
- StarterGui.ShopHUD.CratePanel: Title, Count, Status, Outcomes, ViewOdds, Buy, Open, Receipt y Close.
- StarterGui.ShopHUD.CrateSpinPanel: Window.RollingStrip.RewardTemplate.Title, Indicator, Result, Close, Tick y Reveal.
- StarterGui.ShopHUD.CrateActionsTemplate: ViewOdds y Action.
- ReplicatedStorage.Remotes.Crates: Request (RemoteFunction), Reveal/World/Announce (RemoteEvent).

Verificados 132 nodos de recursos y 521 propiedades, además de cuatro remotes bajo su Folder. Las 25 partes están Anchored=true y CanCollide/CanTouch/CanQuery=false. No hay scripts dentro de assets visuales ni nombres duplicados en los subárboles. Paneles y plantillas quedan ocultos en Edit por defecto.

La primera comparación exacta detectó solo cuantización RGB8 de BasePart.Color en 25 partes. Se verificaron de nuevo con tolerancia por canal 1/255: ninguna diferencia restante. No se cambiaron colores para ocultar el hallazgo. Evidencia: SlapCratesV1.edit-evidence.json.

Se preservaron las instancias originales de ShopHUD y los elementos de ScenarioFinal/cámaras. No se cerró ni guardó forzosamente el lugar. Los nuevos objetos residen en el DataModel Edit; para guardar a disco el place completo el propietario conserva el control de Save.

## Archivos

Modificados de runtime: Bootstrap.server.luau, PlayerDataService.luau, PlayerService.luau, SlapService.luau, ShopRemotes.luau, ShopController.luau, Types.luau.

Nuevos de runtime: shared/SlapCrates/{Registry,VariationDefinitions,SlapDefinitions,CrateDefinitions,StockDefinitions,Catalog,Inventory,Odds}; Services/Crates/{StockLedger,InMemoryStock,ProductionStockAdapter,CrateEngine,AnnouncementAdapter}; Services/CrateService; Shop/Providers/CrateProviders; Controllers/CrateController.

Recursos nuevos: 3 .project.json en src/assets y 4 en src/ui. default.project.json los incluye preservando ShopHUD y remotes desconocidos. studio-safe.project.json sigue intacto y deja estos assets físicos bajo control de Edit; no sincroniza destructivamente UI.

Pruebas/documentación: SlapCratesV1.spec, auditoría, contrato, guía de contenido, manual, este informe, evidencias, logs y helpers. El runner de pruebas existente recibe nuevas fuentes sin modificar sus suites previas. Respaldos previos y copias de los archivos intervenidos se conservan en tests/assets/backups/SlapCratesV1. Integridad de otros 110 archivos originales de src comprobada por SHA-256.

## Resultados y límites

| Comprobación | Resultado |
|---|---|
| Cajas: registros, pesos, agotados, última unidad, duplicados, retries, commit fallido, reconciliación, política, provider, equipo, HUD y escena con objetos simulados | PASS: 107 aserciones aisladas |
| Regresión de combate/protección de víctima | PASS: 150 aserciones aisladas |
| Habilidades | PASS: 164 aserciones aisladas |
| Registry/seguridad | PASS: 89 aserciones aisladas |
| Shop/economía | PASS: 86 aserciones aisladas |
| Compilación Luau | PASS: todos los runtime scripts y spec nuevo; cantidades finales en checks.json |
| Rojo default y studio-safe | PASS |
| git diff --check | PASS; advertencias LF/CRLF preexistentes |
| Fuentes repo vs Source/editor de Studio | PASS: 23 scripts; hashes normalizados en evidencia |
| Partidas/regresión visual real, móviles, latencia de red, audio final | NOT RUN; a cargo del desarrollador |
| PolicyService con jugadores sintéticos reales | NOT RUN; puede bloquear según disponibilidad de Roblox |
| Stock global/cierre entre servidores/recuperación durable productiva | BLOCKED: backend/session lease/snapshot/outbox y pruebas reales pendientes |

Las pruebas de concurrencia usan dos proveedores sobre ledger falso compartido y UpdateAsync simulado con callback repetido y respuesta perdida. NO son concurrencia real entre servidores Roblox ni validación cloud.

Total: **596 aserciones aisladas aprobadas**. La compilación abarca 114 scripts de runtime más el spec nuevo. Ninguna es una declaración de PASS de jugabilidad o de stock global real.

Riesgos/bloqueos pendientes: aprobación comercial, diseños/audio, revisión visual y multicliente, layout horizontal heredado en pantallas angostas, canal de chat si se reemplaza RBXGeneral, capacidad/archivo de journals (256 perfil, 1024 ledger), backend durable con session owner, snapshot global seguro y recuperación/outbox entre procesos. No basta aprobar precios o cambiar un booleano para abrir producción.

Siguiente acción: realizar únicamente la validación humana descrita en SlapCratesV1.manual.md. No se avanza a otra fase ni se activa comercio productivo.
