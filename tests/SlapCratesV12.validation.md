# Slap Crates V1.2 — implementación y validación

Implementado y sincronizado en Studio Edit. **Pendiente de aceptación manual**. No se ejecutó Play, Run, Team Test, Start Server, publicación, commit, push ni acceso cloud.

## Diagnóstico

ShopController ordenaba todas las categorías por Price y luego Id. Las cajas pendientes tenían Price=0 como valor del esquema del provider; el empate terminaba ordenándolas alfabéticamente, empezando por Arcoiris. Ese valor interno tampoco distinguía visualmente un precio pendiente de un producto gratuito. No había precios comerciales aprobados que recuperar.

Ahora CrateDefinitions declara SortOrder explícito y Catalog lo valida. El provider y la proyección pública conservan ese campo y las aprobaciones. Solo Cajas ordena por SortOrder ascendente y CrateId como desempate; otras categorías conservan su criterio. La UI muestra «Precio pendiente» y bloquea compras sin aprobación.

## Orden y economía

| Caja | SortOrder | Precio comercial | Probabilidades | Compra comercial |
|---|---:|---|---|---|
| Basic | 10 | Pendiente | Pendientes | Bloqueada |
| Common | 20 | Pendiente | Pendientes | Bloqueada |
| Uncommon | 30 | Pendiente | Pendientes | Bloqueada |
| Rare | 40 | Pendiente | Pendientes | Bloqueada |
| Gold | 50 | Pendiente | Pendientes | Bloqueada |
| Arcoiris | 60 | Pendiente | Pendientes | Bloqueada |
| Emote | 70 | Pendiente | Pendientes | Bloqueada |
| Wings | 80 | Pendiente | Pendientes | Bloqueada |
| Epic | 90 | Pendiente | Pendientes | Bloqueada |
| Legendary | 100 | Pendiente | Pendientes | Bloqueada |
| Blood | 110 | Pendiente | Pendientes | Bloqueada |
| Galaxy | 120 | Pendiente | Pendientes | Bloqueada |

StudioTest aparece después, SortOrder=1000. Mantiene su precio existente de **1 Coin** y pesos ilustrativos Basic=3/Common=1; no son precios ni probabilidades comerciales. Se habilitó ServerStorage.CrateStudioTestsEnabled en Edit y en default.project.json. El backend exige IsStudio, Environment=Studio, ProviderName=InMemory y WritesToCloud=false; no se habilitó stock global. PolicyService continúa siendo obligatorio y falla cerrado.

Falta aprobación humana de PriceCoins, Weights, PriceApproved, OddsApproved y Enabled por caja comercial. El backend productivo sigue bloqueado; aprobar esos campos no habilita automáticamente ventas productivas.

## Integración

VER PROBABILIDADES consulta Quote autoritativo con precio, distribución final, stock y vencimiento de 30 s. Comprar requiere elegibilidad, aprobaciones, distribución verificable, Quote vigente y saldo. Abrir requiere Quote vigente y caja propia; no necesita Coins adicionales. Inventario conserva las cajas cerradas y unidades SlapId + VariationId existentes.

El servidor sigue debitando y entregando mediante CrateEngine, el journal y la reserva de stock existentes. No acepta precios del cliente. Los reintentos con respuesta incierta conservan OperationId y QuoteToken originales y bloquean otra operación hasta resolver. La respuesta confirmada y DataUpdated refrescan saldo/cantidad, protegidos frente a respuestas tardías. No hay actualización optimista de propiedad.

Open usa exactamente el premio confirmado por servidor. Se mantienen la ruleta, escena 3D, equipamiento y filtrado de observadores existentes. Las funciones _spin y _world permanecen idénticas al respaldo de esta fase. No se alteraron Slap Variation Effects ni mecanismos competitivos.

## Studio Edit

Se verificaron hashes SHA-256 tanto de Source como del buffer del editor para los siete ModuleScripts sincronizados. Las rutas originales contienen un solo objeto por nombre. Se conservaron tamaños y posiciones de los **75 GuiObjects originales**, comparados antes/después.

Cambios físicos en StarterGui.ShopHUD:

- CratePanel.Count/Status: textos; Count: alineación izquierda.
- CratePanel.Buy/Open: textos COMPRAR/ABRIR y bloqueo inicial.
- CrateActionsTemplate.Action: texto y bloqueo inicial.
- Nuevo CrateActionsTemplate.StockLabel.
- Nuevo CratePreviewTemplate (ViewportFrame oculto) con WorldModel y Camera; las tarjetas clonan esta plantilla y los modelos existentes de ReplicatedStorage.CrateEffects.

No se reconstruyó ShopHUD ni se guardó/cerró/sobrescribió el place. Los cambios están en el DataModel Edit actual; guardá tu archivo normalmente para conservarlos entre sesiones. No se añadieron modelos temporales a Workspace. La responsividad real PC/móvil aún requiere observación manual.

## Archivos de implementación

- src/shared/SlapCrates/CrateDefinitions.luau
- src/shared/SlapCrates/Catalog.luau
- src/shared/SlapCrates/CrateShopView.luau (nuevo helper de presentación)
- src/server/Services/CrateService.luau
- src/server/Shop/ShopRemotes.luau
- src/client/Controllers/ShopController.luau
- src/client/Controllers/CrateController.luau
- src/ui/CratePanel.project.json
- src/ui/CrateActionsTemplate.project.json
- src/ui/CratePreviewTemplate.project.json (nuevo)
- default.project.json (preview y flag de fixture)

Se añadieron pruebas/constructores/validadores SlapCratesV12, evidencia de Edit, informes y respaldo tests/assets/backups/SlapCratesV12. Se actualizó el contrato de contenido con SortOrder y se señaló la guía histórica V1. studio-safe.project.json no necesitó cambios. La evidencia de integridad identifica 134 archivos originales src sin cambios y confirma _spin/_world intactos; no atribuye los cambios anteriores del Working Tree a esta tarea.

## Resultados automatizados

| Verificación | Resultado |
|---|---|
| Crates V1.2 y regresión de motor/política/stock | PASS: 187 aserciones aisladas |
| Protección de víctima/combate | PASS: 150 |
| Ability multijugador aislado | PASS: 164 |
| AbilityRegistry | PASS: 89 |
| Shop de habilidades | PASS: 86 |
| Slap Variations Appearance | PASS: 19 |
| Compilación Luau | PASS; cantidad de scripts en checks.json |
| Rojo default y studio-safe | PASS ambos |
| git diff --check | PASS |
| Fuentes/objetos en Edit | PASS; hashes y geometría conservada |
| Compras reales, ruleta, 3D, equipamiento, PC/móvil | NOT RUN; desarrollador |

**Total: 695 aserciones aisladas.** Incluyen orden/futura inserción, precios pendientes, compra válida, saldo, reintentos con misma operación y respuesta perdida, inventario, Open sin cobro extra, premio confirmado, equipamiento, expiración, cambios de distribución, stock agotado, política restringida, respuestas tardías y preview con cámara ausente/existente. La simulación de spin/world confirma el contrato de datos, no su apariencia visual real.

Corrección posterior al Output manual: el cliente no tenía Camera dentro del clon CratePreview, aunque sí existe en la plantilla Edit. _cratePreview resuelve la cámara por clase y crea una cámara local con FieldOfView=45 si falta; asigna CurrentCamera explícitamente. Conserva la cámara física de Edit. Se sincronizó el controlador corregido sin iniciar Play; falta repetir la apertura de Cajas para confirmar el resultado visual real.

Evidencias: SlapCratesV12.checks.json, .integrity.json, .studio-edit.json y logs por suite. La rama Studio/InMemory/WritesToCloud=false se verificó estáticamente en las fuentes físicas; no existe diagnóstico runtime nuevo porque no se inició Play. Ninguna operación de esta tarea accedió a persistencia real.

Seguir SlapCratesV12.manual.md. Si PolicyService no verifica jugadores sintéticos, la prueba de compra queda BLOCKED por elegibilidad; no se debe eludir esa validación. Esperar aceptación manual antes de otra implementación.
