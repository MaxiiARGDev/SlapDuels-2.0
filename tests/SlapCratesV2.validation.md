# Slap Crates V2.0 — Cinematic Opening Stand

Implementado en repositorio y Studio **Edit**. **Aceptación funcional PENDING**: no se ejecutaron Play, Run, Start Server, Team Test, partidas, compras reales ni control de personajes. Sin publicación, commits, push o cloud.

## 1. Auditoría y contratos reutilizados

| Área | Ruta real / contrato |
|---|---|
| Registro | ReplicatedStorage.Shared.SlapCrates.Catalog + Registry; manifests explícitas CrateDefinitions, SlapDefinitions, VariationDefinitions |
| Compra/apertura | ServerScriptService.Services.CrateService.Request -> ShopService._withShopLock -> _transact -> Crates.CrateEngine.Stage |
| Economía/perfil | PlayerService.CommitCrateState sobre el mismo perfil Coins + Inventory; sin segundo sistema económico |
| Inventarios | Inventory.Crates, SlapUnits, Owned.Slaps, Equipped.Slaps y CrateOperations existentes |
| Probabilidades | Odds.Resolve + Quote de 30 s, distribución y firma de stock existentes |
| Stock | InMemoryStock/StockLedger/Engine.Reconcile existentes; producción bloqueada |
| Identidades | OperationId estable por petición; OpeningId=op.UnitId; RewardId=SlapId:VariationId confirmado por servidor |
| Shop | StarterGui.ShopHUD; ShopController.OpenCategory("Crates") abre la misma pestaña; CratePanel existente |
| Spin | CrateController._spin y _world, ShopHUD.CrateSpinPanel; funciones conservadas íntegramente |
| Modelos | ReplicatedStorage.CrateEffects; CrateRewardPreviews; SlapVariationPreviews[SlapId][VariationId] y SlapVariationEffects |
| Cámara | No había broker global reutilizable. EndCinematicController.IsPlaying y MatchId/ResultsSessionId son barreras de prioridad; EndCinematic no modificado |
| Música/SFX | MusicController.Suspend/Resume con token; Sounds locales de plantillas, sin otro reproductor de música |
| Control | ContextActionService, acción local temporal para PlayerActions; no escribe WalkSpeed, Anchored ni ragdoll del Character |
| Prompts | Nuevo prompt en MainCrateStand; Triggered validado en servidor, sin reemplazar interacciones existentes |
| Bootstrap | CrateService compone StandOpeningService; ClientBootstrap ya descubre ModuleScripts de Controllers. No se modificaron bootstraps ni RoundService |

El desarrollador confirmó previamente el flujo V1 con StudioTest. Ese resultado humano se conserva como antecedente; no equivale a haber probado V2.

## 2. Configuración central y modo

Archivo: **src/shared/SlapCrates/OpeningConfig.luau**, físico en **ReplicatedStorage.Shared.SlapCrates.OpeningConfig**.

Estado entregado: Mode="StandCinematic", Stand.Enabled=true, ExclusiveOpening=true, ReopenCooldown=5, SpectatorRadius=80, MaxActivationDistance=10, MaxIdleCrates=3, MaxSequenceDuration=25.

Tiempos: intro .7; apertura de transición/cámara .6; aparición 1; elevación 2; crecimiento 1; temblor 1; flash .5; premio 3; salida .7. Total **10,5 s**. OpeningTimeline valida modo, números finitos, rangos y plazo máximo; configuración inválida bloquea aperturas.

Mode="Spin" conserva el backend y los eventos Reveal/World originales, deshabilita el prompt y no inicia stand cinematic. StandCinematic exige StandId real y distancia validada. Un Remote no puede elegir modo, exclusividad, plazo, resultado, stock, precio o posición.

Cambiar modo/exclusividad en Edit y comenzar una **sesión nueva**, porque require cachea la configuración. Mantener fuente local y módulo de Studio iguales; usar Rojo SAFE para scripts. No importar un build completo sobre tus cambios artísticos.

## 3. Stand físico y ubicación

Ruta: **Workspace.CrateStands.MainCrateStand**, atributo StandId="Main", Enabled=true. Base inicialmente cerca del SpawnLocation de lobby observado, centro aproximado **(-46.56, 16.08, 197.23)**. Es ubicación provisional, no validada caminando. Podés mover/rotar el modelo completo; ninguna posición cinematográfica depende de esas coordenadas.

```
Workspace.CrateStands.MainCrateStand
├── Base / Pedestal
├── InteractionPart.ProximityPrompt
├── SpawnPoint / CameraPoint / RewardPoint
├── BillboardAnchor.BillboardGui (Title, Price, Status)
├── PreviewAnchors
│   ├── Preview_1 (CrateId=Basic).Decoration + BillboardGui
│   ├── Preview_2 (Common).Decoration + BillboardGui
│   └── Preview_3 (Uncommon).Decoration + BillboardGui
├── Effects (carpeta reservada para diseño)
└── PresentationTemplate
    ├── Effects.FXAnchor
    │   ├── EnergyFrom / EnergyTo / EnergyBeam
    │   ├── Particles.Soft / Light
    │   └── Start, Appear, Rise, Growth, Shake, Flash, Reward, Special, Outro
    ├── RewardAnchor
    └── RewardBillboard (Title, Slap, Variation)
```

Base es el único Part collidable del recurso provisional; todos están Anchored y sin touch/query. Decoración, anchors y efectos no colisionan. No se modificó geometría previa del lobby. La plantilla de presentación contiene anchors invisibles, Billboard deshabilitado y efectos apagados hasta clonar.

## 4. Prompt, Shop e Idle

ObjectText="CAJAS", ActionText="Abrir tienda", HoldDuration=0, MaxActivationDistance=10, RequiresLineOfSight=false; interacción nativa PC/móvil. Triggered y Open verifican el mismo stand en servidor, Character vivo, distancia y lobby. IDs inexistentes o duplicados fallan cerrados. Access abre Shop > Cajas existente y conserva el StandId para Open; compras siguen usando el flujo normal.

Tres modelos decorativos proceden de CrateEffects y tienen CrateId registrado. El cliente los rota/flota sin crear uno por frame. Billboards físicos usan catálogo para nombre, color, precio aprobado y estado comercial. MaxIdleCrates limita los visibles; durante apertura exclusiva se ocultan localmente según OpeningState replicado. En privado el stand permanece Idle. No se cambian los precios oficiales, orden ni aprobaciones.

## 5. Transacción, reservas y recuperación

StandOpeningService envuelve la llamada existente de Open dentro del lock de Shop por jugador. StandOpeningLedger solo administra leases; no entrega Coins ni premios. Tras la validación de elegibilidad que puede yield, CrateService vuelve a comprobar lease, Character, distancia e ID antes de Stage. El motor existente verifica caja, Quote, distribución/stock, reserva y commit. La recompensa queda adjudicada antes de Present.

Fallos de autorización/Quote/stock liberan la reserva sin consumir. Fallos visuales no revierten el premio. Repetir OperationId conserva el journal/UnitId existente, no vuelve a consumir, sortear o anunciar. Un reintento durante la misma secuencia no la cancela. El cliente Stand nunca activa el fallback Spin para ese resultado.

Reservas sin completar vencen a los 25 s. Secuencias confirmadas liberan al acabar la duración autorizada; el servidor no confía en un acuse de fin del cliente. Heartbeat inspecciona cada .25 s. Desconexión, Character nuevo/muerto, entrada a sesión o alejamiento cancelan presentación y liberan; si el cliente falla visualmente, su limpieza es inmediata y el lease de servidor vence por tiempo/contexto. Ningún permiso visual es requisito para conservar una unidad ya adjudicada.

## 6. Exclusividad, privado y multistand

ExclusiveOpening=true: lock por StandId, uno por jugador y mismo OpeningId/RewardId para comprador y observadores cercanos en lobby. El comprador tiene cámara privada; los observadores solo modelos locales sincronizados por StartedAt, sin HUD privado ni cámara ajena. Observadores que se acercan durante la secuencia reciben el estado temporal vigente. El indicador global usa Reserved/Opening/Revealing/Finishing/Idle.

Al liberar una secuencia confirmada comienza cooldown personal **UserId original + StandId, 5 s**; el stand queda disponible para otra persona inmediatamente. No usa math.abs ni cambia IDs negativos de Studio. No hay cola obligatoria.

ExclusiveOpening=false: leases por jugador, sin lock global ni cambio visual a ocupado. Solo el comprador recibe su paquete; cada cliente tiene escena/cámara independiente. La economía sigue usando el mismo motor/stock. No se habilitaron modalidades XvX ni concurrencia de partidas.

Para otro stand, clonar el modelo completo y asignar StandId único. El servidor descubre/valida stands y prompts sin editar CrateService; duplicar el mismo ID bloquea ambos hasta corregirlo. Configuración compartida aplica a todos los stands.

## 7. Cámara, transición, controles y limpieza

CrateStandCinematicController utiliza CameraLease. Rechaza cámara ya Scriptable o de otro propietario y no se inicia durante MatchId, ResultsSessionId o EndCinematic.IsPlaying. Cierra Shop y panel; overlay CrateOpeningHUD hace fade con TweenService, cambia a Scriptable con pantalla cubierta, abre transición y apunta desde CameraPoint hacia SpawnPoint/RewardPoint con movimiento/FOV moderados. Es local al comprador.

En salida cierra transición, restaura y abre de nuevo. Restaura tipo, sujeto, CFrame y FOV solo para la misma vida y propietario; Character nuevo obtiene sujeto actual y no recibe posición/FOV viejos. Muerte no restaura el estado del Character muerto. Cambio de cámara o prioridad de EndCinematic limpia el lease sin sobrescribir la nueva cámara. La acción de ContextActionService se desliga al terminar/cancelar; no hay flags físicos que herede respawn.

MusicController se suspende/reanuda con razón/token propios y conserva preferencias y suspensiones ajenas. No se ocultan otros HUDs ni se restauran estados antiguos de otras interfaces. Errores de presentación se capturan; la limpieza es idempotente y destruye objetos/tweens aun si falla una restauración.

## 8. Animación y premio

La secuencia clona la caja del catálogo y una plantilla previamente creada en Edit. Aparece pequeña, asciende en el eje local de SpawnPoint, gira, crece, tiembla alrededor de la pose estable, emite partículas limitadas/Beam/luz/flash de pantalla y oculta la caja. No hay Explosion, fuerzas, daño, teletransporte ni modificación permanente del mundo.

El premio usa Catalog.Rewards[RewardId] confirmado por servidor: preview exacto SlapId/VariationId con fallback al preview del Slap y Appearance.Apply del perfil autorizado. Billboard muestra DisplayName real del slap y variación/color; flota y gira en RewardPoint. No hay sorteo cliente. SFX de variación reutilizan el perfil existente si tiene SoundId.

## 9. Objetos editables y audio pendiente

Se añadieron CrateStands, CrateOpeningHUD (Transition/Flash) y ReplicatedStorage.Remotes.Crates.StandPresentation. Fuente de recursos: src/assets/CrateStands.project.json y src/ui/CrateOpeningHUD.project.json; default.project.json los incluye. SAFE conserva recursos físicos y solo sincroniza scripts.

Inspección MCP Edit: **72 instancias, 370 propiedades, 18 Parts, 12 Sounds sin SoundId**; jerarquías, propiedades seguras, previews registrados, referencias Beam y nombres únicos verificados. La Remote nueva se verificó aparte. No se reconstruyó ShopHUD ni se modificaron tamaños/posiciones de UI previa. No se cerró/guardó/sobrescribió el place: guardalo normalmente para conservar cambios entre sesiones.

Los nueve Sounds de secuencia y tres Reveal decorativos son editables y vacíos. No se inventaron IDs ni se afirma que el audio esté aprobado o escuchado. El Sound Special está preparado para diseño posterior; no se le asignó una regla de rareza comercial. La apariencia final, texturas, volumen y ubicación son trabajo artístico del desarrollador y validación manual.

## 10. Archivos y protección

Nuevos módulos: OpeningConfig, OpeningTimeline, Crates/StandOpeningLedger, Crates/StandOpeningService, cliente CrateOpening/CameraLease y Controllers/CrateStandCinematicController.

Fuentes existentes modificadas: CrateService (composición/ruta), CrateController (StandId/fallback), ShopController (OpenCategory) y CrateShopView (errores). Proyectos default/studio-safe y recursos nuevos; tests/constructores/validadores/informes V2. El generador de specs económicos incorpora un adaptador Spin de prueba para conservar su regresión histórica sin ejecutar el nuevo stand en esos fixtures.

Backups: tests/assets/backups/SlapCratesV2. **140 archivos originales src mantienen SHA-256**, incluidos economía 150/30, precios y probabilidades comerciales, inventario, stock/motor, habilidades, SlapService, combate, ragdoll, Muerte Súbita, RoundService, EndCinematic y recursos cosméticos. _spin y _world permanecen idénticos al respaldo.

## 11. Resultados y límites de evidencia

| Validación | Resultado |
|---|---|
| Crates V2 + regresión V1.3 | PASS: 283 aserciones deterministas |
| Economía 150/30 | PASS: 30 |
| Combate/protección/tres golpes/StrongSlap | PASS: 150 |
| Habilidades multijugador aislado | PASS: 164 |
| Registry | PASS: 89 |
| Shop habilidades | PASS: 86 |
| Slap Variations | PASS: 19 |
| Total | **821 aserciones aisladas** |
| Compilación Luau | PASS: 122 scripts runtime + spec V2 |
| Rojo default + SAFE | PASS ambos |
| git diff --check | PASS |
| Sources y buffers del editor | PASS: 10 módulos sincronizados con hashes |
| Objetos físicos Edit | PASS: jerarquía/propiedades/referencias inspeccionadas |
| Play / render real / PC-móvil / participantes reales | NOT RUN |
| Audio con recursos finales | NOT RUN; IDs pendientes |

La suite ejecuta Ledger/Service/CrateService reales con perfiles y geometría simulados: modos, invalid config, prompt y distancia, exclusividad, privados simultáneos, multistand, fallo y reintento, consumo/stock y premio único, público/privado, cooldown exacto y timeout. Cámara real como módulo probado con objetos falsos: tipo/sujeto/FOV, pérdida de propietario, respawn y prioridad. Presentador real con geometría determinista prueba fases, escala/elevación, emisión, revelación, limpieza, eventos tardíos y selección Stand/Spin. No sustituye observar animación/cámara/input en Studio.

Persistencia Studio/InMemory/WritesToCloud=false: rama física preservada e inspeccionada estáticamente; no se inició runtime ni se accedió a DataStores. PRODUCTION_UNIVERSE_ID intacto. Las 12 cajas siguen PriceApproved=true, OddsApproved=false, Enabled=false; StudioTest sigue 1 Coin y elegibilidad PolicyService fail closed. Reproducir con tests/tools/validate_slap_crates_v2.py. Logs y evidencias: SlapCratesV2.checks.json, .integrity.json, .studio-edit.json.

## 12. Pendientes y aceptación

Seguir SlapCratesV2.manual.md para ambos modos. Deben observarse realmente el acceso caminando, cámaras/controles, timing, solapamiento con otras secuencias, espectadores, dos compradores, dispositivos móviles, cleanup y audio. Si PolicyService no verifica jugadores sintéticos, compras quedan BLOCKED; no eludir restricciones. Stock productivo/global y persistencia durable siguen fuera del alcance.

No se declara PASS funcional. La implementación queda detenida hasta resultados del desarrollador.
