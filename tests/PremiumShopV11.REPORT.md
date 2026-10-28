# Premium Shop V1.1 — informe de implementación

Fecha: 2026-10-20. **Lista para revisión de código y preview bloqueada; NO lista para activar ventas.** No hubo Play, Run, Team Test, compras, publicación ni acceso cloud. No se cambió el Universe aprobado.

## Resultado y arquitectura

Se conectó el HUD existente a PromptProductPurchase y a precios consultados en el cliente. El servidor recibe ProductKey, verifica registro, aprobaciones, entorno, perfil, lobby, PolicyService, pertenencia del Developer Product a la experiencia y quotes vigentes para cada caja. No acepta cantidades ni ProductIds arbitrarios del cliente.

Hay cinco paquetes, tres combos en módulos individuales y las mismas tres cajas Premium. Los once IDs son placeholders reservados; ninguno consulta Marketplace ni abre un prompt. CoinPackages conserva premios de 1000/2500/6000/15000/40000 y sugerencias 19/39/79/149/299. Combos vacíos no aprobados: 99/249/499. Cajas no aprobadas: 49/99/199. Tabla completa e instrucciones en PremiumShopV11.setup.md.

PremiumShopService conserva la única asignación ProcessReceipt. ReceiptCoordinator solo confirma una respuesta durable con identidad coincidente. PremiumGrantPlan prepara una copia completa del premio; ProfileReceiptStore aplica saldo, inventario y recibo Applied en un único UpdateAsync del perfil existente. Soporta leases, revisiones, error ambiguo, reintento, rechazo de saves antiguos y replay sin repetir premios. Las cajas permanecen cerradas y siguen usando el motor existente. Se preservan Kills, recompensas, precios normales y preferencias.

La UI presenta Processing, Purchasing, AwaitingConfirmation, Credited, TemporaryError, Restricted y estados de configuración/precio. PromptProductPurchaseFinished solo cambia presentación; nunca concede ni confirma entrega. Delivery/Status del servidor deduplican PurchaseId. SuggestedRobux no fija el precio de compra; una variación detectada exige renovar la acción.

## Bloqueante durable explícito

**El puente entre el nuevo motor transaccional y TODO el ciclo de mutaciones/saves PlayerDataService/PlayerService no está implementado.** DurableReceiptBackend no se activa con el servicio legacy: ProfileLifecycleIntegrationPending. Studio se bloquea antes por TestingOrUnapprovedEnvironment. PurchasesEnabled=false y DurableCommerceValidated=false permanecen intactos. No hay acreditación real ni actualización real de PlayerHUD por compras validada.

No existen EconomyService o InventoryService independientes en este proyecto: PlayerService y PlayerDataService mantienen ese estado. Integrar solo una llamada AddCoins después de guardar un recibo sería inseguro; otro save podría borrar la compra o perder ganancias de gameplay ocurridas durante el yield. La migración debe serializar todas esas rutas y publicar el snapshot confirmado bajo el mismo lock. El contrato de puente futuro está documentado, sin un stub que declare una garantía inexistente.

PlayerDataService ahora rechaza cargar o guardar por la ruta legacy perfiles con marcador _PremiumProfile. Los perfiles actuales sin marcador no migran ni cambian de proveedor. Antes de migrar hay que retirar servidores de versiones antiguas que desconocen ese marcador, completar el puente offline/PlayerRemoving/BindToClose, verificar límites de tamaño y retención del journal, stock durable y contratos históricos. No se ha demostrado durabilidad cloud: el motor fue probado con adaptador local.

## Verificaciones ejecutadas

- 93 aserciones Premium nuevas, módulos reales con adaptador local, reloj y APIs Marketplace simuladas.
- Regresiones: batch 1375; reveal 2956; gallery 88; cinematic 1931; economy 30; protección de víctima 150; abilities 164; registry 89; shop/economy 86. **Total 6962**.
- Compilación Luau de 161 scripts y spec Premium; builds default.project.json y studio-safe.project.json; git diff --check: PASS.
- SAFE regenerado: 161 scripts, ignoreUnknownInstances y sin recursos físicos mapeados. default.project.json idéntico al comienzo de esta tarea.
- Comparación SHA-256 de los 207 archivos src preexistentes: solo diez scripts autorizados cambiaron; otros 197 archivos idénticos, incluidos todos los recursos físicos.
- MCP confirmó Edit (IsStudio=true, IsRunning=false). Resolve devolvió Environment=Studio, ProviderName=InMemory, WritesToCloud=false. Se sincronizaron/verificaron 18 fuentes por hash y se comprobaron editor drafts antes de escribir; ocho módulos nuevos y diez existentes. No se cerró ni sobrescribió el lugar.
- HUD nativo serializado antes/después, igualdad binaria: PremiumShopHUD 58 descendientes, ShopHUD 348 y PlayerHUD 58. Arte intacto.

Evidencia: PremiumShopV11.checks.json, PremiumShopV11.studio-edit.json, PremiumShopV11.*-results.txt y logs. Backup previo: tests/assets/backups/PremiumShopV11 (fuentes, hashes y HUDs). El respaldo integral anterior se conserva.

## Matriz solicitada

PASS aislado significa ejecución real del código bajo harness, no transacción Roblox. PASS Edit significa inspección efectiva del DataModel, no prueba visual de gameplay.

| # | Comprobación | Resultado | Evidencia y límite |
|---:|---|---|---|
| 1 | Cinco paquetes | PASS aislado | Cantidades, placeholders, registro de once productos |
| 2 | Tres combos | PASS aislado | Módulos independientes, vacíos y sin aprobación |
| 3 | Tres cajas | PASS aislado | Catálogo real existente; sin nuevas cajas/odds |
| 4 | Placeholders | PASS aislado | Cero llamadas API; número reservado también bloquea aunque se quite flag |
| 5 | ProductIds duplicados | PASS aislado | Registry.Build rechaza colisión |
| 6 | Producto no configurado | PASS aislado | ProductIdPending y bloqueo por configuración |
| 7 | Precio no disponible | PASS aislado | Price falla cerrada, sin prompt |
| 8 | Compra bloqueada | PASS aislado | Autorización negativa y backend Studio/legacy rechazados |
| 9 | Solicitud Marketplace | PASS aislado / NOT RUN real | PromptProductPurchase invocado contra fake con ID autorizado; ningún cobro |
| 10 | Resolver ProductId | PASS aislado | Registro y enumeración de experiencia; ajeno desconocido rechazado |
| 11 | Entrega Coins | PASS aislado / BLOCKED runtime | Perfil +1000 y journal en un commit; falta puente |
| 12 | Entrega cajas | PASS aislado / BLOCKED runtime | Tres cajas cerradas sin apertura automática |
| 13 | Entrega Slaps | PASS aislado / BLOCKED runtime | Owned/SlapUnits preservados en transacción |
| 14 | Entrega KillEffects | PASS aislado / BLOCKED runtime | Owned.DeathEffects en mismo commit |
| 15 | Combo completo | PASS aislado / BLOCKED runtime | Cuatro clases de premio en un commit; fallo no deja parcial |
| 16 | Recibo duplicado | PASS aislado | Replay conserva saldo y contenido |
| 17 | ProductId desconocido | PASS aislado | NotProcessedYet |
| 18 | Desconexión | PASS aislado / BLOCKED integración | Coordinador offline y replay sin handle; adquisición offline del puente pendiente |
| 19 | Reintento | PASS aislado | Error después de commit se resuelve sin duplicar |
| 20 | Fallo persistencia | PASS aislado | Antes de commit no modifica perfil; no concede PurchaseGranted |
| 21 | Fallo entrega | PASS aislado | Duplicado permanente rechazado sin Coins/journal parcial |
| 22 | Dos recibos simultáneos | PASS aislado | Intercalación CAS, revisión antigua rechazada y recuperada |
| 23 | Dos servidores | PASS aislado | Lease exclusivo; servidor viejo no guarda; transferencia tras expiración |
| 24 | Idempotencia durable | PASS adaptador / BLOCKED cloud | Dato persistido en fake compartido entre motores; cloud no probado |
| 25 | Sin confirmación prematura | PASS aislado | Cierre de prompt deja Awaiting; backend no durable queda Pending |
| 26 | Perfiles actuales | PASS parcial / BLOCKED migración | Campos heredados preservados; regresión shop/economy; ciclo cercado pendiente |
| 27 | PolicyService | PASS aislado | Error fails closed, perfil/lobby obligatorios |
| 28 | Odds obligatorias | PASS aislado | Registro rechaza cajas sin aprobación; motor batch cotiza resultados reales |
| 29 | Aleatorios pagados | PASS aislado | Combo aleatorio restringido; motor normal conserva Policy y quote |
| 30 | Tienda normal | PASS aislado | Suites economy/shop/batch; recursos y balance sin cambios |
| 31 | Diseño PremiumShopHUD | PASS Edit | SHA-256 binario idéntico; revisión visual del desarrollador pendiente |
| 32 | Studio sin cloud | PASS Edit + aislado | Resolve InMemory/false; backend real rechaza Studio; no compras ni accesos cloud |

No se ejecutó transacción real, precio personalizado real, reingreso multiserver real, PlayerHUD con compra real ni prueba visual en Play. No se declaran aprobados.

## Archivos de implementación

Modificados:

- src/client/Controllers/PremiumShopController.luau
- src/server/PremiumShop/PremiumGrantPlan.luau
- src/server/PremiumShop/PremiumProductRegistry.luau
- src/server/PremiumShop/ReceiptCoordinator.luau
- src/server/Services/PremiumShopService.luau
- src/server/Services/CrateService.luau (quotes independientes para cada tipo dentro de un combo)
- src/server/Services/PlayerDataService.luau (rechazo del marcador por ruta legacy)
- src/shared/PremiumShop/Catalog/CoinPackages.luau
- src/shared/PremiumShop/Catalog/PremiumCombos.luau
- src/shared/PremiumShop/Catalog/PremiumCrates.luau

Nuevos:

- src/client/PremiumShop/PremiumPurchaseFlow.luau
- src/server/PremiumShop/ProfileReceiptStore.luau
- src/server/PremiumShop/DurableReceiptBackend.luau
- src/server/PremiumShop/ProductVerifier.luau
- src/shared/PremiumShop/PlaceholderProductIds.luau
- src/shared/PremiumShop/Catalog/Combos/PremiumCombo_01.luau, PremiumCombo_02.luau y PremiumCombo_03.luau

También se amplió el loader tests/tools/run_ability_unit_tests.py para incluir módulos anidados, se creó spec/validador V11, evidencia/documentación y se regeneró studio-safe.project.json. No se borraron cambios previos, recursos, mapas, HUDs ni respaldos.

## Siguiente validación humana

Conservar flags e IDs actuales. Ejecutar vos la preview y revisar categorías (5/3/3), entradas/cierre y mensajes de compra deshabilitada; ningún placeholder debe abrir un prompt. Confirmar Output Studio/InMemory/false y funcionamiento de la tienda normal. No autoriza activar ventas. La implementación se detiene para tu revisión; completar el puente y las verificaciones productivas es trabajo pendiente previo a monetizar.
