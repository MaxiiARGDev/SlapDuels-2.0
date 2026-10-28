**Ability Shop V1.3 — compras con Coins, preferencia y selección.** Fecha: 2026-10-17.

Implementación completada en repositorio y Studio Edit. **Aceptación funcional pendiente del desarrollador.** No se inició Play, Run ni Start Server; no se controlaron personajes, hicieron compras reales, commits, push, publicaciones ni escrituras cloud.

**Auditoría y correcciones.** AbilityRegistry ya valida, deriva y sella el catálogo de módulos aprobados. AbilityProvider ya adapta ese registro a la Shop existente; ShopRegistry utiliza identidad categoría/Id. ShopService ya bloquea transacciones por jugador y PlayerService.CommitShopPurchase prepara un perfil por copy-on-write, verifica disponibilidad/identidad de perfil y sustituye Coins + propiedad sin yield. No se reconstruyeron esos mecanismos.

Había dos bloqueantes comerciales: Shop de cada habilidad tenía precio sin aprobación y compra deshabilitada; además ShopRemotes eliminaba toda Metadata al enviar el catálogo, mientras ShopController exigía Metadata.PurchaseEnabled. Cambiar únicamente los precios habría conservado PRÓXIMAMENTE. Ahora se transmite una whitelist de tres booleanos comerciales, sin funciones, contexto del servidor ni metadatos arbitrarios.

**Metadatos oficiales, configurables en una sola fuente.** Cada precio vive exclusivamente en `Shop` del ModuleScript correspondiente; no hay una tabla de precios en el controlador ni una excepción por AbilityId en ShopService. Los valores de esta tabla se usan como expectativas en pruebas/documentación, no como otro catálogo runtime.

| AbilityId | DisplayName | Price | PriceApproved | PurchaseEnabled |
|---|---|---:|---|---|
| Dash | Impulso | 0 | true | false |
| AirJumps | Saltos de Aire | 750 | true | true |
| DevilSpeed | Velocidad Diabólica | 1500 | true | true |
| Invisible | Invisible | 2250 | true | true |
| StrongSlap | Golpe Fuerte | 3000 | true | true |

Dash conserva ID, propiedad inicial y equipamiento gratuito. No es una oferta de compra ni se vuelve a conceder mediante una transacción. AbilityProvider deriva PriceApproved/PurchaseEnabled/PricePending del registro; sólo las ofertas pagas aprobadas se habilitan. El manifiesto autorizado y AbilityRegistry no se modificaron, ni se creó una sexta habilidad. Las futuras habilidades compatibles siguen usando módulo + recursos + entrada única del manifiesto.

**Compra autoritativa e idempotencia.** El cliente envía la identidad del producto mediante la API existente —Id y namespace de categoría—, nunca precio ni definición de producto. ShopRemotes valida tipos/longitudes y limita operaciones mutantes a una cada 0,3 s por jugador. ShopService resuelve producto/proveedor en el servidor bajo bloqueo por jugador, comprueba disponibilidad y vuelve a resolver el producto antes de commit.

AbilityProvider exige perfil listo, producto registrado/habilitado, ausencia de propiedad previa y permiso comercial derivado de aprobación válida. ProfilePurchase.Stage vuelve a exigir PurchaseEnabled y PriceApproved para Ability, precio entero no negativo/finito, inventario coherente y saldo suficiente. Prepara copia del perfil, conserva otros datos y registra débito + propiedad en una sola sustitución del perfil de PlayerService. Un error de staging no modifica el perfil; una desconexión/cierre impide commit. Una falla al notificar después del commit no revierte la propiedad ni permite un segundo cobro.

El bloqueo existente cubre validación y commit. Doble clic/spam tiene además el bloqueo cliente `_busy`; reintentos posteriores encuentran AlreadyOwned. No se agregó un segundo inventario, una economía paralela ni un DataStore. La idempotencia es respecto a la propiedad del producto: se conserva la operación ya confirmada y se rechaza un nuevo cobro, sin un sistema paralelo de recibos.

**Equipamiento y selección.** EQUIPAR valida propiedad y guarda exclusivamente `Inventory.Equipped.Abilities`. Si ya coincide, AbilityProvider devuelve éxito sin modificar datos ni notificar de nuevo. Desequipar vuelve a preferir Dash; si la definición de Dash no estuviera disponible, devuelve ProductUnavailable. Equipar/desequipar no descuenta Coins.

`Inventory.Owned.Abilities` continúa siendo propiedad; `Inventory.Equipped.Abilities`, preferencia; `AbilityService._sessions[sessionId].Players[player].AbilityId`, elección competitiva. Comprar/preferir durante Playing no modifica la última ni su cooldown. Una nueva habilidad adquirida sólo puede elegirse mediante la ventana autorizada. En reinicios se conserva la elección competitiva anterior mientras siga siendo válida; en una sesión nueva se utiliza la preferencia válida. AbilityService, AbilitySelection y los countdowns 5/3 permanecen sin cambios.

**ShopHUD y estado visible.** La interfaz actual ya tiene todos los controles necesarios. El controlador reutiliza cards, precio, saldo, ActionButton y StateBadge:

| Estado | Resultado implementado |
|---|---|
| No propia, saldo suficiente | Precio aprobado y COMPRAR activo |
| No propia, saldo insuficiente | Precio, Coins insuficientes y COMPRAR deshabilitado; handler evita enviar la operación |
| Propia, no preferida | TUYO y EQUIPAR |
| Preferida | PREFERIDA y acción deshabilitada |
| Compra pendiente | PROCESANDO… y bloqueo de doble solicitud |
| Compra confirmada | Propiedad/saldo desde DataUpdated, sin autoequipar |
| Precio futuro sin aprobación | Compra bloqueada; no se confía en flags del cliente |

Cerrar Shop no cancela ni repite la operación del servidor. El resultado actualiza los datos aunque la ventana esté cerrada, sin reabrirla. Los snapshots repetidos no ejecutan transacciones. Se preservaron iconos y la presentación de miles; por ejemplo, 1500 se muestra 1.500 Coins.

No se modificaron objetos visuales físicos. El ShopHUD actual de Studio tiene 91 descendientes y 53 GuiObjects: estructura/posición/tamaño/visibilidad/color y texto/fuente/tamaño de texto/imágenes inspeccionados conservaron el mismo SHA-256 antes y después: `b29a76d12c154258f969b0bfabe0e342dc53309b30b516bcd0e10910a5c9449b`. No se reimportó el archivo nativo ni se sobrescribieron ajustes visuales no guardados del lugar. Los textos/precios se asignan desde el catálogo cuando funciona el controlador; no se fijaron precios en ShopHUD.

**Archivos y objetos modificados.** Nueve fuentes runtime:

1. `src/server/Abilities/DashAbility.luau`: nombre Impulso y aprobación del precio gratuito, sin venta.
2. `src/server/Abilities/AirJumpsAbility.luau`: Shop 750 aprobado/habilitado.
3. `src/server/Abilities/DevilSpeedAbility.luau`: Shop 1500 aprobado/habilitado.
4. `src/server/Abilities/InvisibilityAbility.luau`: Shop 2250 aprobado/habilitado.
5. `src/server/Abilities/StrongSlapAbility.luau`: Shop 3000 aprobado/habilitado.
6. `src/server/Shop/Providers/AbilityProvider.luau`: metadatos derivados, readiness e idempotencia al preferir.
7. `src/server/Shop/ProfilePurchase.luau`: aprobación explícita requerida al preparar una compra Ability; compras Cosmetic mantienen su contrato.
8. `src/server/Shop/ShopRemotes.luau`: whitelist comercial pública.
9. `src/client/Controllers/ShopController.luau`: estados de compra/equipamiento y bloqueo con saldo insuficiente.

En Studio se actualizaron/verificaron los Source de esas mismas nueve instancias: las cinco bajo `ServerScriptService.Abilities`, `ServerScriptService.Shop.Providers.AbilityProvider`, `ServerScriptService.Shop.ProfilePurchase`, `ServerScriptService.Shop.ShopRemotes` y `StarterPlayer.StarterPlayerScripts.Controllers.ShopController`. No se creó ni eliminó un objeto físico visual, Remote, mapa, cámara o habilidad. No se guardó, cerró ni publicó forzosamente el lugar.

También se amplió `tests/tools/run_ability_unit_tests.py`; se agregaron suites/fixture V1.3, el helper de respaldo/verificación/transporte y las evidencias/guías/builds bajo tests. Se conservan las suites V1.2 históricas; sus expectativas de compra bloqueada fueron adaptadas en copias V1.3, sin reescribir la evidencia anterior. La auditoría Rojo SAFE compartida se refrescó para el código actual.

**Respaldo e integridad.** `H:\repos-github\SlapDuels-2.0\tests\assets\backups\AbilityShopV13` conserva nueve fuentes previas, sus hashes, estado Git inicial y manifiesto de los otros 106 archivos de src. Respaldo 9/9 íntegro, protegidos 106/106 idénticos. Una comparación adicional de los cinco módulos, excluyendo únicamente Shop y DisplayName, confirma que mecánicas, configuración de balance, duración y cooldown no cambiaron. No se tocó el respaldo integral anterior.

PlayerService, PlayerDataService, adaptadores de persistencia, AbilityRegistry/manifiesto, AbilityService, selección/HUD de habilidad, RoundService, ScoreService, SlapService, EliminationService, Kill Effects, EndCinematic, Config, ShopService/ShopRegistry, recursos y mapas permanecen fuera de las nueve fuentes modificadas y conservaron su hash. Los cambios anteriores del Working Tree no se descartaron.

**Estado de datos.** Se utiliza el esquema existente Owned/Equipped, compatible con la normalización actual. La propiedad/preferencia forma parte del perfil que usa el guardado existente; no se habilitó almacenamiento real. La resolución observada en Edit es **Studio / InMemory / WritesToCloud=false**, IsRunning=false, ActiveMatches=0. La producción permanece bloqueada por la configuración existente de Universe ID sin aprobar, cuyo archivo no cambió. No hubo lecturas/escrituras de perfiles reales ni afirmación de persistencia entre servidores o reinicios. Confirmar también el Output del servidor cuando el desarrollador inicie su prueba.

**Verificación ejecutada, exclusivamente aislada/estática.**

| Suite o comprobación | Resultado | Alcance/evidencia |
|---|---|---|
| Shop/economía | PASS aislado: 86 | AbilityShopV13.shop-results.txt; funciones reales sobre perfiles descartables: precios, débito, insuficiencia, concurrencia, duplicados, errores, cierre, respawn, preferencia, normalizador y cosméticos |
| Remotes/catálogo | PASS aislado: 31 | AbilityShopV13.remote-results.txt; proyección segura, precio manipulado, rate limit, reintento, equipamiento y reutilización de handlers |
| UI Shop | PASS aislado: 23 | AbilityShopV13.ui-results.txt; botones/textos/saldo, doble clic, compra pendiente al cerrar, respuesta y snapshots repetidos |
| Compra ↔ selección | PASS aislado: 15 | AbilityShopV13.selection-results.txt; propiedad nueva, ventanas 5/3, Playing, cooldown y elección previa |
| Registro V1.2 adaptado | PASS aislado: 89 | AbilityShopV13.registry-results.txt; contratos, invalidaciones, sellado, metadatos y aprobaciones actuales |
| Regresión de habilidades adaptada | PASS aislado: 121 | AbilityShopV13.regression-results.txt; autoridad, vida, cooldown, movimiento, ownership, callbacks, remotes y cierre |
| Selector V1.1/V1.2 sin cambios | PASS aislado: 54 | AbilityShopV13.selection-regression-results.txt; apertura explícita, recibos, plazo exacto y limpieza |
| Presentación/recursos sin cambios | PASS aislado: 18 | AbilityShopV13.presentation-regression-results.txt; restauración Invisible y validación de recursos |
| Total | **437 aserciones aisladas** | No equivalen a pruebas funcionales con jugadores |
| Compilación Luau | PASS | 97 fuentes src + siete archivos de pruebas V1.3 |
| Build default.project.json | PASS | AbilityShopV13.build.rbxlx y .build.log |
| Build studio-safe.project.json | PASS | AbilityShopV13.safe-build.rbxlx y .safe-build.log |
| git diff --check | PASS | AbilityShopV13.git-diff-check.log; avisos de conversión LF/CRLF existentes |
| Whitespace de archivos nuevos/no rastreados | PASS | Verificación adicional en AbilityShopV13.file-integrity.json, dado que git diff no los incluye |
| Studio Edit vs repositorio | PASS: 9/9 | SHA-256 normalizado de GetEditorSource, guardas contra conflictos o nombres duplicados |
| Registro sobre recursos reales en Edit | PASS de contrato | Cinco entradas, cero diagnósticos, precios/flags originales de módulos; sin activar habilidades/comprar |
| ShopHUD físico | PASS estructural | SHA antes/después idéntico; diseño preservado |
| Rojo SAFE servido | PASS | 97/97 fuentes coinciden, 142 nodos preservan desconocidos, cero rutas duplicadas |

Los dobles de prueba sólo simulan disponibilidad física de recursos de cosméticos; no reproducen su ejecución visual. Los callbacks y RemoteFunctions probados usan tablas descartables y un reloj/scheduler de fixture fuera de Roblox. Ningún IsRunning de fixture inició un proceso de Studio. Los builds son artefactos de verificación, no lugares publicados ni importados sobre el proyecto abierto.

**Matriz funcional pendiente del desarrollador.**

| Caso | Estado real | Evidencia requerida |
|---|---|---|
| Precios/COMPRAR/saldo insuficiente en Shop real | NOT RUN | Capturas de ambos clientes y saldo del servidor |
| Compra de las cuatro habilidades | NOT RUN | Débito y propiedad exactos, sin autoequipar |
| Doble clic, cierre/reapertura, reintento | NOT RUN | Un único cobro; si no se observa latencia, indicar no observado |
| EQUIPAR/PREFERIDA y Dash gratuita | NOT RUN | Preferencia/saldo antes y después |
| Compra/equipamiento durante Playing | NOT RUN | Elección competitiva y deadline de cooldown sin cambios |
| Selector adquirido/no adquirido y 5/3 | NOT RUN | Video de ambos HUDs y confirmación/deadline |
| Cinco mecánicas de habilidades | NOT RUN | Uso real, cancelación y restauración |
| Respawn/desconexión durante compra | NOT RUN | Propiedad/balance coherentes o rechazo sin mutación |
| Otras categorías y Kill Effects | NOT RUN | Compra/equipo y visuales existentes |
| Coins por gol y Kill, Zero-Death | NOT RUN | +50 independiente en cada evento válido, sin duplicados |
| Ronda 3:00, Muerte Súbita, EndCinematic y lobby | NOT RUN | Secuencia completa con limpieza |
| Segunda partida | NOT RUN | Repetición sin estados residuales |
| Persistencia entre servidores/producción | NOT RUN; infraestructura bloqueada | Validación separada futura, fuera de esta fase |

Los pasos exactos y el comando de financiación **únicamente InMemory** están en `H:\repos-github\SlapDuels-2.0\tests\AbilityShopV13.manual.md`. No utilizar los comandos antiguos que concedían propiedad o esperaban compras bloqueadas.

**Riesgos y cierre.** Queda pendiente la aceptación visual/funcional con dos clientes, incluida latencia y carreras reales de desconexión. InMemory sólo confirma el estado de esa sesión; éxito de compra no implica durabilidad entre servidores. Los iconos/audio previamente pendientes no se inventaron ni cambiaron. El manifiesto sigue aprobando código confiable, no módulos hostiles arbitrarios. No se detectaron errores en las comprobaciones ejecutadas ni diferencias en archivos protegidos.

La implementación queda lista para tu prueba manual. No se avanzará a nuevas habilidades ni otra implementación antes de tu validación/autorización.
