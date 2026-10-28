# Shop Integration V2 — implementación y validación pendiente

Fecha: 2026-10-17. Repositorio: H:\repos-github\SlapDuels-2.0.

Se leyeron íntegros ShopKillEffects.audit.md y ShopIntegrationV1.validation.md.
Las siete comprobaciones V1 son PASS **informados por el desarrollador**; no se repitieron.
V2 está implementada en repositorio y Studio **Edit**. Compras, equipamiento,
reproducción, respawn y regresión multicliente: **NOT RUN** por el agente.
Aceptación funcional V2: PENDIENTE. Audio Frost/Void: BLOCKED por assets faltantes.

## 1. Modelos físicos creados

- ServerStorage.DeathEffects.Frost: Model único,57 descendientes,8 Parts,25 ParticleEmitters.
- ServerStorage.DeathEffects.Void: Model único,97 descendientes,8 Parts,45 ParticleEmitters.
- DefaultFall y BasicKill siguen siendo los modelos previos de16 descendientes cada uno.

Se comprobaron directamente sus instancias y propiedades mediante MCP Edit, sin
requerir servicios ni ejecutar perfiles. No son recursos creados únicamente durante Play.
No se guardó, cerró ni reemplazó el lugar abierto; guardá vos el lugar local cuando
corresponda para conservar también tus cambios artísticos pendientes.

## 2. Frost

```text
Frost (Model; PrimaryPart=Origin; Duration=3.2)
├── Origin (Part)
├── VFX (Folder)
│   ├── Flash → FlashBurst, ImpactLight
│   ├── VerticalJet → UpwardColumn
│   ├── IceShards → Crystals
│   ├── FrostMist → Dispersal
│   ├── FallingParticles → SecondaryParticles
│   └── Shockwave → Wave1_1…Wave1_20 (Attachments), cada uno con RingParticle
└── SFX → Impact (Part) → FrostImpact (Sound, SoundId vacío)
```

Paleta celeste/azul/blanco, columna ascendente, fragmentos radiales, onda circular,
bruma translúcida y partículas descendentes desde8 studs. Apariencia real pendiente
de prueba humana; no se declara calidad visual aprobada por inspección de instancias.

## 3. Void

```text
Void (Model; PrimaryPart=Origin; Duration=3.6)
├── Origin (Part)
├── VFX (Folder)
│   ├── Flash → FlashBurst, ImpactLight
│   ├── VioletJet → UpwardColumn
│   ├── VoidParticles → DarkFragments
│   ├── DarkCore → Dispersal
│   ├── RisingEnergy → SecondaryParticles
│   └── EnergyRings → Wave1_1…20, Wave2_1…20; cada Attachment con RingParticle
└── SFX → Impact (Part) → VoidImpact (Sound, SoundId vacío)
```

Paleta violeta/púrpura/negro, núcleo oscuro de baja opacidad, columna y secundarios
ascendentes, dos ondas concéntricas separadas0.18s. No hay portales funcionales,
daño, fuerza, scripts internos ni teletransporte.

## 4. Partículas y Parts

Todas las Parts nuevas: Anchored=true, Transparency=1, CanCollide=false,
CanTouch=false, CanQuery=false, CastShadow=false. Ningún cambio a colisiones de jugadores/mapas.

Todos los emitters: Enabled=false, Rate=0; emisión mediante Emit() del reproductor existente.
Texturas locales de Roblox: sparkles_main.dds y smoke_main.dds. No IDs externos inventados.
Color/Size/Transparency/Lifetime/Speed/SpreadAngle/Acceleration son editables físicamente.
La transparencia termina en1 y el tamaño en0. La niebla empieza en0.6 de transparencia.
Las ondas son20 emisores orientados radialmente por anillo; no nombres vacíos ni
discos sólidos con colisiones. No se agregó un renderer de geometría ni postprocesado global.

## 5. Duraciones, emisión y limpieza

| Componente por efecto | EmitCount | EmitDelay | Lifetime máxima | Speed máxima |
|---|---:|---:|---:|---:|
| FlashBurst | 2 | 0 | 0.22 | 0 |
| UpwardColumn | 34 | 0.025 | 1.2 | 27 |
| Crystals / DarkFragments | 28 | 0.07 | 1.65 | 22 |
| Dispersal | 10 | 0.1 | 1.7 | 4 |
| SecondaryParticles | 22 | 0.35 | 2 | Frost2 / Void7 |
| RingParticle, cada emisor | 1 | 0.04 / segunda onda0.22 | 0.8 | 16 / segunda13 |

Frost:116 partículas totales por reproducción, Duration3.2s.
Void:136 partículas, Duration3.6s. ImpactLight LightPeak4, Range24, fade existente0.25s.
Todos los delays+lifetimes caben dentro de Duration y del límite global4s.
DeathEffectPlayer/Scope existentes controlan Delay/Emit/Tween/Destroy del clon local;
no se modificaron. El límite existente de6 efectos concurrentes se conserva;
rendimiento en móvil y visibilidad deben comprobarse manualmente.

## 6. Sonidos

Se inspeccionaron Sounds del proyecto antes de crear los recursos. Hay sonidos de
matchmaking, Slap, countdown, PointEffects, feedback/cinemática y packs importados.
No se identificó un sonido específico Frost/Void con adecuación y permisos comprobados.
La presencia de un ID en un pack no demuestra licencia ni acceso para esta experiencia.

Por la alternativa expresamente autorizada, los dos Sounds físicos existen con SoundId="".
Faltan exactamente:
- ServerStorage.DeathEffects.Frost.SFX.Impact.FrostImpact: impacto/cristal glacial.
- ServerStorage.DeathEffects.Void.SFX.Impact.VoidImpact: ruptura/energía del vacío.

PlayDelay=0, Volume0.65, Looped=false, PlayOnRemove=false,
RollOffMode=InverseTapered, min12/max110 studs.
Ambos son hijos de una Part ubicada en el origen; el renderer trasladará esa Part
al impacto. La arquitectura espacial existe, pero **no hay audio audible aprobado**.
Asignar IDs autorizados y reexportar los modelos es el pendiente de audio.
No se tocaron sonidos anteriores ni se reprodujo audio para probarlos.

## 7. Precios, rarezas e identidad

| Producto DeathEffects | ProductId preservado | Coins | Rareza |
|---|---|---:|---|
| Frost | Frost | 750 | Rare |
| Void | Void | 3000 | Legendary |
| Propulsión | BasicKill | 0 | Common |

Las definiciones comerciales Frost/Void se derivan de PointEffectDefinitions existentes
para mantener nombre, ID, precio y rareza sin dos precios manuales divergentes.
RequiredOwnership=true para Frost/Void; BasicKill sigue siendo derecho inicial gratuito.
DefaultFall IsShopProduct=false; no compra ni equipamiento.

Conflicto resuelto: Frost/Void ya estaban definidos como PointEffects sin modelo.
No se borraron, renombraron, trasladaron ni convirtieron sus propiedades/selecciones antiguas.
ShopRegistry ahora usa la pareja **Category + Id** como identidad. PurchaseProduct y
EquipProduct reciben (productId, category opcional). La UI envía ambos; el servidor
resuelve exclusivamente el provider registrado y su precio. Una llamada antigua sólo
con ID sigue funcionando si es inequívoco; Frost/Void sin categoría se rechazan.
La propiedad PointEffects.Frost NO otorga DeathEffects.Frost ni se cobra por migración.
Los PointEffects Frost/Void continúan NO DISPONIBLES hasta tener sus propios modelos.
Basic/Inferno/Thunder mantienen definición, precio, categoría y recursos.

## 8. Catálogo

DeathEffectDefinitions suma Frost/Void. ShopRegistry:GetProduct y GetCatalog consultan
el provider actual para refrescar disponibilidad, en vez de confiar en una copia
inicial de IsAvailable. No se registraron productos Robux ni IDs de Marketplace.
Los identificadores de inventario se mantienen exactamente iguales, por categoría.

## 9. Provider

DeathEffectProvider habilita CanPurchase tras comprobar datos listos, definición,
recurso y ausencia de propiedad. GetResource exige Model+Origin BasePart, Duration
finita y permitida, partículas reales con textura, Rate0, Enabled=false, Count1–80,
delays/lifetimes válidos, Parts ancladas sin colisiones y ausencia de scripts/Explosion.
La ausencia de SFX autorizado queda explícita como pendiente; no se simula audio.

CanEquip exige propiedad; OnEquipped vuelve a validar y usa PlayerService.
OnUnequipped restaura BasicKill. La consulta conserva fallback no destructivo a
BasicKill ante recurso ausente; no sobrescribe selecciones guardadas desconocidas.
OnPurchased del provider delega a CommitShopPurchase con producto resuelto.
El orquestador Coins usa directamente esa misma primitiva coherente para cosméticos,
sin invocar callbacks arbitrarios de entrega después de descontar.

## 10. Compra integrada

ShopService comparte lock por Player para compra/equip/desequip. Lo toma antes de
CanPurchase y lo libera con pcall incluso ante excepción. Reconsulta catálogo tras
validación del provider. Sólo ID/categoría viajan desde cliente, nunca precio/saldo.
Coins cosméticos pasan a PlayerService:CommitShopPurchase; no DeductCoins+AddItem
separados ni reembolso que conserve propiedad entregada. Consumibles no implementados
se rechazan como UnsupportedProduct; Robux continúa pendiente.

La UI conserva tarjetas y panel físicos; lookup por categoría evita confundir los dos
Frost/Void. Compra no equipa automáticamente; DataUpdated conduce a TUYO/EQUIPAR.
La señal del cliente no es autoridad de propiedad. Rate limit0.3s anterior conservado.

## 11. Garantías y límites de transacción

ProfilePurchase.Stage sólo prepara tablas temporales: precio finito entero>=0,
saldo válido/suficiente, producto cosmético Coins disponible, inventario válido y
no poseído. Copia el perfil y la rama Owned antes de descontar/conceder en esa copia.
Una excepción al preparar no altera el perfil original.

CommitShopPurchase exige Player conectado, perfil Loaded y sin barrera de cierre.
Revalida identidad del perfil y readiness y sustituye el perfil completo sin ceder.
Coins e inventario se confirman juntos; sincroniza aliases. Duplicados posteriores
ven Owned=true y no vuelven a descontar. Un fallo de notificación se registra y NO
convierte el commit válido en fallo ni ejecuta un refund ambiguo.
La UI puede necesitar cerrar/reabrir Shop para solicitar snapshot tras fallo de entrega
o respuesta perdida; reintentar no duplica pago. No existe receipt durable de red.

PlayerRemoving marca Closing antes del primer guardado/yield. BindToClose activa
BeginShopShutdown antes de SaveAllPlayers. Equip/desequip también exigen readiness.
SavePlayer copia Coins y todo Owned/Equipped antes de esperar otro save o UpdateAsync;
una compra posterior no modifica el snapshot en vuelo.
Fallos de save siguen devolviendo error y se advierten al salir; no se promete recuperación
durable tras crash/desconexión. No se añadió journal, session locking entre servidores,
autosave ni un guardado cloud por compra. Eso requiere otra fase autorizada.

## 12. Persistencia aislada

Studio observado IsStudio=true, IsRunning=false. Se inspeccionó PersistenceEnvironment:
la rama Studio selecciona InMemory y WritesToCloud=false; producción sigue bloqueada
con APPROVED_PRODUCTION_UNIVERSE_ID=nil. PlayerDataService conserva exclusivamente
el proveedor inyectado, sin fallback. No se inicializó Bootstrap ni se abrió un perfil
para fabricar un log runtime. La confirmación de Output queda para tu prueba.

Éxito de compra significa estado coherente EN MEMORIA. Nueva ejecución de Studio,
otro servidor o reinicio no conserva ese adaptador. No hubo escrituras cloud, cambios
de Universe ID, nombres de stores o proveedor productivo.

## 13. Equipamiento, KillPart y recompensas

Un único Inventory.Equipped.DeathEffects, propiedad obligatoria, sin cargo al equipar.
El inventario reside en PlayerService, no Character; no se añadió reset al respawn.
DeathFeedbackContract conserva resolución de la víctima; caída sin atacante retorna
DefaultFall antes de consultar su selección. El snapshot previo a retirar Character,
atribución, KillPart y respawn no se modificaron.

DeathEffectService sigue enviando únicamente a miembros de MatchSession con SessionId,
participación/versión/edad válidas y deduplicación de EliminationId. El renderer recibe
el mismo payload y clona el modelo elegido. Ningún efecto otorga Coins.

Comparación contra las fuentes iniciales V2: AddCoins, AwardConfirmedKill y DeductCoins
permanecen idénticos. Config.Economy.KillRewardCoins50 y Config.Match.PointReward50 no
fueron modificados. Verificación funcional de recompensas: NOT RUN.

## 14. Studio Edit y exportación

Instancia ab01cdbb-f911-49b1-87b1-c311e6160909; place107328891970677.
Los9 Sources de archivos nuevos/modificados se instalaron por MCP (10 instancias:
DeathEffectDefinitions tenía2 copias preexistentes idénticas). Antes de escribir
se compararon las8 fuentes existentes con el repositorio inicial; todas coincidían.
Se conservaron ambas copias, sin sumar duplicados. Cada Source instalado se verificó
contra su archivo, incluyendo la categoría en compra y equipamiento.

Backup de fuentes previas: tests/assets/backups/ShopIntegrationV2.sources.before.json.
El respaldo integral previo externo no se tocó.
Modelos exportados por SerializationService nativo y deserialización temporal
verificada; copias temporales destruidas sin ejecutar contenido. Mapeo agregado al
DeathEffects.project.json ya existente; no otra carpeta de assets ni modelos duplicados.

| Archivo nativo | Bytes | SHA256 |
|---|---:|---|
| src/assets/Frost.rbxm | 10241 | F6402F7AEB0C29754C2350B8A16B1C78B61A8E77D6A5F3011FF4BAD8EADA6254 |
| src/assets/Void.rbxm | 10489 | E61992E0CD44A00D7317749B76963B279A995BFF7958CC81BF73650C8C3CD17F |

El script tests/ShopIntegrationV2.assets.edit.luau documenta la autoría inicial.
NO volver a ejecutarlo: aborta si los modelos existen para proteger ajustes artísticos.
Los modelos nativos son los recursos de Rojo; el script no es dependencia runtime.

## 15. ShopHUD

Un único StarterGui.ShopHUD,86 descendientes; DeathEffectsTab Category=DeathEffects.
No se modificó Position, Size, botones, estilos, plantilla ni layout físico.
src/ui/ShopHUD.rbxm conserva SHA256:
086DE79F6E81C05EEF9316EBF5E67C0E63FE58F83564D1F83C66FE412BB60F32.
La integración usa ProductCardTemplate/DetailPanel existentes; no HUD ni inventario nuevos.
No se incluyeron iconos externos nuevos; continúa la preview gráfica existente.
Si modificás artísticamente los assets en Studio, exportarlos antes de sincronizar
Rojo desde una versión anterior; Rojo no captura automáticamente tus ediciones.

## 16. Archivos de esta fase

NUEVO: src/server/Shop/ProfilePurchase.luau.
MODIFICADOS:
- src/server/Services/ShopService.luau
- src/server/Services/PlayerService.luau
- src/server/Services/PlayerDataService.luau
- src/server/Shop/ShopRegistry.luau
- src/server/Shop/ShopRemotes.luau
- src/server/Shop/Providers/DeathEffectProvider.luau
- src/client/Controllers/ShopController.luau
- src/shared/DeathEffectDefinitions.luau
- src/assets/DeathEffects.project.json

NUEVOS recursos: src/assets/Frost.rbxm, src/assets/Void.rbxm.
NUEVOS documentos/fixtures:
- tests/ShopIntegrationV2.spec.luau — preparado, NOT RUN.
- tests/ShopIntegrationV2.assets.edit.luau — autoría Edit realizada.
- tests/ShopIntegrationV2.edit-evidence.json — observaciones de instancias.
- tests/ShopIntegrationV2.validation.md — este informe.
- tests/assets/backups/ShopIntegrationV2.sources.before.json — fuentes previas.

El Working Tree ya contenía numerosos cambios y archivos no rastreados de fases
anteriores. Un diff contra HEAD incluye ese trabajo y no delimita por sí solo V2.
No se editaron mapas, HUD físico, KillPart, respawn, EndCinematic, modalidades o concurrencia.

## 17–18. Comprobaciones y matriz A1–A22

rojo build default.project.json --output <TEMP>/SlapDuels-ShopIntegrationV2.rbxlx: PASS.
git -c core.safecrlf=false diff --check: PASS.
Build valida ensamblado de recursos; no demuestra tipado Luau, compras o jugabilidad.
No hay analizador Luau ni suite de contratos ejecutados en esta fase.

| Caso | Evidencia | Resultado funcional |
|---|---|---|
| A1 Frost existe | MCP Edit:1 Model,57 descendientes | PASS estático; reproducción NOT RUN |
| A2 Void existe | MCP Edit:1 Model,97 descendientes | PASS estático; reproducción NOT RUN |
| A3 partículas reales | 25 y45 ParticleEmitters, texturas/properties inspeccionadas | PASS estático; visual NOT RUN |
| A4 Parts seguras | 8 por modelo, ancladas/sin colisiones/touch/query | PASS estático |
| A5 referencias | Catalog ModelName y recurso físico | Contrato preparado, NOT RUN |
| A6 precios servidor | 750/3000 heredados, Stage valida saldo/precio | Contrato preparado, NOT RUN |
| A7 BasicKill gratis | Price0 y entitlement previo | Contrato preparado; V1 PASS informado |
| A8 DefaultFall fuera Shop | IsShopProductfalse y filtro | Contrato preparado; V1 PASS informado |
| A9 producto desconocido | Registry resuelve pareja registrada | Contrato preparado, NOT RUN |
| A10 equipar sin propiedad | Provider/PS exigen Owned | Contrato preparado, NOT RUN |
| A11 compra repetida | Owned antes de commit | Contrato preparado, NOT RUN |
| A12 concurrencia | Lock antes de provider; fixture con coroutine pausada | Contrato preparado, NOT RUN |
| A13 excepción/consistencia | Staging, notify protegido, cierre y snapshot independiente | Fixtures preparados, NOT RUN |
| A14 exclusivo categoría | Un slot Equipped.DeathEffects | Contrato preparado, NOT RUN |
| A15 respawn | Sin dependencia Character en selección | Prueba humana NOT RUN |
| A16 cosmético víctima | Contrato/snapshot sin cambios | Contrato preparado, gameplay NOT RUN |
| A17 caída | DefaultFall temprano sin atacante | Contrato preparado; V1 PASS informado |
| A18 SessionId | Servicio sin cambios, validación/envío privado inspeccionados | Multicliente NOT RUN |
| A19 +50/+50 | Config y funciones de recompensa conservadas | Config fixture preparado, gameplay NOT RUN |
| A20 HUD físico | Una raíz,86 descendientes, export intacto | PASS estático; estados V2 NOT RUN |
| A21 build | Comando ejecutado | PASS |
| A22 diff check | Comando ejecutado | PASS |

La suite usa tablas desechables y adaptador falso para fallos, concurrencia, precio,
duplicados, equipamiento y snapshot. No llama Init ni toca perfiles reales; está
preparada para harness aislado del desarrollador, no ejecutada automáticamente.
No equivale a prueba real de respawn, red, cierre de servidor ni durabilidad.
La suite V1 se conserva como evidencia/contratos previos, no se anuncia reejecutada.

## 19. Guía manual exacta — sólo desarrollador

Antes de comenzar: guardá tus cambios locales como corresponda e iniciá vos el test.
Confirmá en Output del servidor **PersistenceEnvironment=Studio,
PersistenceProvider=InMemory, WritesToCloud=false**. Si difiere, detener la prueba.
Usá2 participantes y, para aislamiento, un tercer cliente en lobby sin entrar a sesión.
No activar otras modalidades/concurrencia. No cambiar Universe ID ni habilitar cloud.

1. Abrí TIENDA → KILL EFFECTS: Propulsión/BasicKill, Frost y Void; DefaultFall ausente.
2. Verificá Frost750 Coins/Rare y Void3000 Coins/Legendary; en PointEffects siguen
   bloqueados los homónimos sin modelo. Seleccionar el de muerte no debe mostrar el de puntos.
3. Con menos de750, intentá comprar Frost: rechazo InsufficientFunds, saldo e inventario intactos.
4. Obtené Coins por los premios existentes hasta>=750; anotá saldo y comprá Frost.
5. Saldo nuevo exactamente saldo anterior−750; no50 ni otro descuento extra.
6. Confirmá TUYO/EQUIPAR y ausencia de botón de recompra. Cerrar/reabrir Shop conserva el estado.
7. Equipá Frost sin costo; no lo equipa automáticamente el pago.
8. Confirmá EQUIPADO y BasicKill ya no equipado; otro cliente sin propiedad no puede equiparlo.
9. En 1v1, el jugador con Frost debe ser la VÍCTIMA de una Kill acreditada.
   No fabricar muertes con comandos ni cambiar perfiles.
10. Observar flash frío, columna ascendente, cristales, onda, niebla y partículas
    descendentes en impacto; ninguna geometría sólida ni residuos tras3.2s.
11. Reuní>=3000, comprá Void (−3000 una vez), equipalo sin costo; Frost queda poseído
    pero no equipado. Volver a Frost tampoco debe cobrar.
12. Kill sobre víctima con Void: núcleo oscuro, columna púrpura, partículas y dos ondas;
    ninguna oclusión extrema ni residuos tras3.6s.
13. Caída sin atacante: esperar fuera de la ventana de atribución previa antes de caer;
    DefaultFall,0 Coins por Kill. Kill válida sigue +50 al atacante; gol sigue +50.
14. Pulsaciones repetidas rápidas y dos peticiones de compra no deben provocar otro
    descuento; registrar RateLimited/TransactionInProgress/AlreadyOwned según escenario.
    Los fallos inyectados y simultaneidad precisa usan la suite aislada, no scripts productivos.
15. Tras respawn y regreso al lobby dentro del mismo servidor, selección/propiedad/saldo
    conservados. Reabrir Shop y registrar. Nuevo servidor InMemory empieza de nuevo.
16. Recorrer PointEffects/Slaps/Trails, Basic/Inferno/Thunder y volver; sin confusión
    de categorías, precios ni equipados. Validar también pantalla móvil habitual.
17. Audio Frost/Void: actualmente BLOCKED por SoundId vacío. No reportar PASS ni esperar
    oírlo. Con assets autorizados e instalados/reexportados, verificar origen espacial
    en impacto y caída de volumen con distancia, sólo en clientes de la sesión.
18. Tercer jugador en lobby: sin VFX, sonido o animación de Coins ajenos. Dentro de
    la sesión sólo el atacante acreditado recibe +50 y feedback de recompensa.
19. Repetir5 eliminaciones consecutivas con víctima equipada Frost: evento único por
    eliminación, +50 una vez, respawn normal y limpieza; capturar Output y clip.
20. Repetir5 con Void. Completar partida, regreso/cierre normal y sin errores; confirmar
    que EndCinematic y preferencias existentes continúan como estaban.

Por caso registrar PASS/FAIL/BLOCKED/NOT RUN, saldo antes/después, cliente víctima/
atacante/lobby, mensajes de servidor/cliente y clip. No informar datos secretos.
Para errores de red/notify, abrir nuevamente Shop solicita el snapshot real; no
repetir pagos esperando recibir otro producto. No se promete durabilidad entre tests.

## 20. Pendientes y cierre

- Assets SFX de Frost/Void autorizados: faltantes, audio BLOCKED.
- Calidad VFX, dirección/tamaño/performance, UI V2, compras, equipamiento y aislamiento:
  validación humana pendiente. No se realizaron compras, Play/Run/Start Server ni partidas.
- Consistencia en memoria implementada; no journal durable, receipts de compras,
  session locking entre servidores ni recuperación ante crash/agotamiento de saves.
  No habilitar producción para suplir esa limitación.
- API antigua con Frost/Void sin Category ahora rechaza por ambigüedad; consumidores
  externos personalizados deben pasar categoría. El controlador y remotes incluidos
  ya lo hacen. Búsqueda en src no encontró otros consumidores afectados.
- Dos catálogos homónimos preexistentes en Studio se preservaron iguales; no son nuevos.
- Sin escrituras cloud, publicaciones, commits o push. Sin nuevas fases.
Se detiene la implementación y se espera validación del desarrollador.
