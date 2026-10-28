# Slap Crates — matriz inicial V1.3 integrada sobre V2

Implementación y sincronización terminadas en Studio **Edit**. Aceptación funcional **PENDING**. No se ejecutó Play, Run, Start Server, Team Test, partidas, compras reales ni control de personajes. Sin publicación, commit, push o escrituras cloud.

## Auditoría y cálculo conservado

Registros reales: ReplicatedStorage.Shared.SlapCrates.Catalog/Registry, CrateDefinitions, VariationDefinitions y SlapDefinitions. No existe otro RewardDefinitions: Catalog genera RewardId=SlapId:VariationId. Actualmente solo Classic admite las 12 variaciones. CrateService usa Quote, Odds.Resolve y Crates.CrateEngine.Stage; InMemoryStock/StockLedger conservan reservas, última unidad y reconciliación. Las mutaciones conservan el lock de Shop y el mismo Inventory del perfil.

Odds.Resolve conserva el algoritmo: peso por variación, candidatos SlapId elegibles, exclusión por propiedad bajo UniquePerPlayer, recursos/stock, división del peso entre candidatos y normalización global. Odds.Roll y el RNG autoritativo no se reemplazaron. No se redondean los pesos ni las probabilidades antes del sorteo. La modificación de Odds agrega únicamente información de exclusión para presentación; no cambia el cálculo.

Quote sigue teniendo token de 30 s y firma de distribución + stock. _transact recalcula y compara antes de Stage; si cambia la distribución o stock exige consulta nueva. Stock desconocido bloquea; sin resultados no se consume caja. El cliente no puede enviar pesos, resultado, stock ni cantidades para aprobar un premio.

## Matriz configurada

Fuente: **src/shared/SlapCrates/InitialOdds.luau**. Transcripción exacta del CSV del pedido, sin redondeo ni ajustes. CrateDefinitions obtiene una copia de WeightsFor(CrateId); Catalog valida variaciones, números finitos/no negativos y suma 100 para MatrixVersion="InitialV13Review".

Orden de columnas: Basic, Common, Uncommon, Rare, Gold, Arcoiris, Emote, Wings, Epic, Legendary, Blood, Galaxy. Las 12 filas originales suman **100.00 %**, comprobadas con Decimal y mediante Luau. Pesos 0.01 siguen siendo positivos y tienen un intervalo seleccionable en Odds.Roll.

Datos completos: **CrateOddsV13.matrix.csv** y **CrateOddsV13.decimal.json**. No se duplica la matriz en un controlador cliente. La fixture de pruebas compara independientemente los valores del CSV con los del módulo cargado.

| Caja | Precio Coins intacto | Suma original | PriceApproved | OddsApproved | Enabled | Política |
|---|---:|---:|---|---|---|---|
| Basic | 500 | 100 % | true | false | false | UniquePerPlayer |
| Common | 1000 | 100 % | true | false | false | UniquePerPlayer |
| Uncommon | 1750 | 100 % | true | false | false | UniquePerPlayer |
| Rare | 3000 | 100 % | true | false | false | UniquePerPlayer |
| Gold | 4500 | 100 % | true | false | false | UniquePerPlayer |
| Arcoiris | 7000 | 100 % | true | false | false | UniquePerPlayer |
| Emote | 10000 | 100 % | true | false | false | UniquePerPlayer |
| Wings | 13500 | 100 % | true | false | false | UniquePerPlayer |
| Epic | 19000 | 100 % | true | false | false | UniquePerPlayer |
| Legendary | 27500 | 100 % | true | false | false | UniquePerPlayer |
| Blood | 37500 | 100 % | true | false | false | UniquePerPlayer |
| Galaxy | 50000 | 100 % | true | false | false | UniquePerPlayer |

StudioTest conserva 1 Coin, pesos Basic=3/Common=1 y AllowDuplicates. SortOrder de todas las cajas intacto. Gol=150 y Kill=30, habilidades y Death Effects sin cambios.

## Probabilidades finales y propiedad inicial

La matriz es una distribución original por variación, no una promesa por RewardId. El porcentaje mostrado corresponde a la distribución efectiva de ese jugador/stock/catálogo. Con dos SlapIds elegibles para Galaxy en Basic, cada uno recibe 0.005 % si todos los demás resultados originales están disponibles. Si se excluye uno, el restante recibe el peso Galaxy completo antes de la normalización global.

**Todos los perfiles reciben Classic:Basic por Inventory.Extend.** Como la política comercial existente es UniquePerPlayer, ese resultado se excluye en el catálogo actual Classic-only. Un perfil inicial no ve Basic al 60 % en Caja Basic: los pesos restantes suman 40, por lo que Common=60 % y Galaxy=0.025 %. Se conserva la política, no se fuerza AllowDuplicates para hacer coincidir la tabla original con el perfil real.

**CrateOddsV13.effective-quotes.csv** contiene 132 resultados finales exportados desde CrateService.Quote real en el harness: las 12 cajas, perfil que posee solo Classic:Basic, stock ilimitado y Classic como único SlapId. Classic:Basic figura como excluido en UI, no como resultado sorteable. Ese CSV es un ejemplo reproducible de ese estado, no porcentajes fijos para todo jugador.

## Quotes de revisión, disponibilidad y seguridad

La consulta de matriz se permite como **Quote de revisión solo en el backend Studio/InMemory existente**, conservando lobby, perfil cargado y PolicyService. Quote devuelve ReviewOnly=true y PurchaseAllowed=false para las comerciales; tener token no habilita pago/apertura. _transact usa _eligible sin permiso de revisión y devuelve CommercialApprovalPending. Las pruebas verifican que tampoco cambia nada si el cliente envía OddsApproved=true.

No se habilitaron las 12 cajas comerciales ni se cambió OddsApproved a true. Para revisar balance no fue necesario crear otra fixture de pago ni habilitar un bypass de política: las simulaciones usan tablas/perfiles desechables y Stage con una copia aprobada únicamente dentro del test aislado. Ninguna copia aprobada se instala en Studio.

Producción continúa bloqueada por la selección de backend y Catalog.ProductionCommerceEnabled=false. Quedan pendientes aprobación expresa de probabilidades, habilitación comercial, backend durable/propiedad del perfil, stock global validado entre servidores y elegibilidad de cada comprador. Un error de PolicyService bloquea incluso la consulta de revisión; no se asume que Coins estén fuera de las restricciones de compras aleatorias.

## Shop y UI física

Nuevo **StarterGui.ShopHUD.CratePanel.OddsList**, ScrollingFrame con UIListLayout y RowTemplate editable. Sus tres instancias se crearon en Edit, usando exactamente Position/Size de Outcomes. No se reconstruyó ShopHUD ni se cambiaron dimensiones/posiciones del panel o de Outcomes. El RowTemplate hereda la FontFace existente; la lista se desplaza verticalmente y usa el mismo espacio, también para pantallas pequeñas.

CrateService describe cada recompensa con SlapName, VariationName, Color, SortOrder, porcentaje y stock. OddsPresentation solo formatea el Quote, ordenando por variación y RewardId; no estima ni sortea. Se muestran nombres, color, porcentaje efectivo con %.10g, stock ilimitado/remanente y exclusiones: AGOTADO, YA ADQUIRIDO o RECURSO NO DISPONIBLE. Las filas excluidas muestran 0 % y no participan del sorteo.

El encabezado indica REVISIÓN · COMPRA BLOQUEADA y el precio real. Los botones siguen bloqueados por los metadatos comerciales. Al vencer se marca QUOTE VENCIDO; tras abrir o recibir un rechazo se limpia la distribución anterior y se solicita una consulta nueva. Quote sin resultados muestra el motivo y exclusiones disponibles. La precisión visual no afecta la utilizada por el motor.

## Compatibilidad

No se modificaron _spin ni _world: comparación de texto con respaldo. El resultado final sigue siendo op.RewardId adjudicado por el servidor; las tarjetas intermedias del spin son decorativas. StandCinematic, modo privado/exclusivo, cámara, controles, prompts y recursos V2 conservan sus hashes. Recompensas, perfiles, motor, stock, slaps, habilidades, combate, RoundService, EndCinematic y persistencia tampoco cambiaron.

## Pruebas deterministas y estadísticas

| Verificación | Resultado |
|---|---|
| Matriz/Quote/UI + regresión Crates V1/V2 | PASS: 1118 aserciones |
| Economía 150/30 | PASS: 30 |
| Combate/protección/tres golpes | PASS: 150 |
| Habilidades | PASS: 164 |
| AbilityRegistry | PASS: 89 |
| Shop de habilidades | PASS: 86 |
| Variaciones cosméticas | PASS: 19 |
| Total | **1656 aserciones aisladas** |
| Suma original decimal | PASS: 12 filas × 100.00 % |
| Simulación matemática | PASS: 200000 sorteos por caja, 2400000 total |
| Compilación Luau | PASS: 124 scripts runtime + spec |
| Ambos builds Rojo | PASS default y SAFE |
| git diff --check | PASS |
| Sincronización Source/editor | PASS: 7 módulos con hashes |
| UI física Edit | PASS: 3 nodos, dimensiones/font heredadas verificadas |
| Jugabilidad, visual real PC/móvil y compras | NOT RUN |

La simulación usa Odds.Resolve/Odds.Roll reales, semilla fija 8675309 y un generador de unidades exclusivo del test, sin cambiar el RNG de producción. Se simula el catálogo matemático Classic con las 12 variaciones elegibles y stock ilimitado para comparar las matrices originales. Es distinto del perfil inicial real, que ya posee Basic; las pruebas de Quote y Stage cubren esa exclusión separadamente.

En las 144 frecuencias, desvío absoluto máximo Z=**3.11157**; criterio de comprobación |observado−Np| ≤ 7√(Np(1−p))+2. Ejemplo Basic→Galaxy: 19/200000 (0.0095 %) frente a 0.01 % teórico y 20 esperados. Esto es una comprobación matemática con semilla fija, no una garantía comercial ni exigencia de que aparezca un raro en un lote pequeño. Detalle: CrateOddsV13.statistics.csv/.json.

También se probaron uno/varios SlapIds, peso ínfimo seleccionable, exclusiones por propiedad/stock/recursos, normalización, todos adquiridos/sin resultados, negativos/NaN/infinito/IDs inexistentes, coincidencia de intervalos con Engine.Stage y presentación real del controlador con mocks. La regresión incluida conserva Quote expirado/cambiado, última unidad, reintentos, stock sin duplicación y modos Spin/Stand.

## Archivos y recuperación

Fuentes existentes modificadas: CrateDefinitions.luau, Catalog.luau, Odds.luau, CrateService.luau y CrateController.luau. Nuevas: InitialOdds.luau, OddsPresentation.luau y src/ui/CrateOddsList.project.json. Proyectos default/SAFE actualizados para recursos/módulos. Se añadieron tests, CSVs, estadísticas y validadores CrateOddsV13; se adaptó el generador de expectativas actuales para las matrices en revisión, conservando specs históricos.

Respaldo previo: tests/assets/backups/CrateOddsV13. **147 archivos originales src conservan SHA-256**; los cinco modificados son los del alcance. Pruebas/evidencia: CrateOddsV13.checks.json, .integrity.json y .studio-edit.json. Reproducir con tests/tools/validate_crate_odds_v13.py.

La rama de persistencia física se verificó estáticamente Studio/InMemory/WritesToCloud=false, sin inicializar servicios. Diagnóstico runtime pendiente porque no se inició Play. PRODUCTION_UNIVERSE_ID intacto, sin DataStores reales. Guardá el place normalmente para conservar los objetos de Edit entre sesiones; no se sobrescribió ni cerró tu lugar.

Seguir CrateOddsV13.manual.md. Esperar validación humana antes de declarar PASS funcional o aprobar ventas.
