# Shop Integration V1 — Fase 1

Implementación en repositorio y Studio Edit; pruebas funcionales pendientes del
desarrollador. Se leyó completo `tests/ShopKillEffects.audit.md` antes de editar.
No se inició Play, Run, Start Server ni se ejecutaron módulos, compras o perfiles.

## 1–4. Provider, Shop, inventario y equipamiento

Nuevo `src/server/Shop/Providers/DeathEffectProvider.luau`, registrado en
ShopService:_registerDefaultProviders bajo **DeathEffects**. Implementa el contrato
existente GetCategory/GetProducts/GetProduct/CanPurchase/CanEquip/OnPurchased/
OnEquipped/OnUnequipped y agrega GetDefaultProductId/GetResource/HasProduct/
GetEquippedEffectId para consulta autoritativa. No reproduce efectos ni crea objetos
en Workspace ni modifica Coins.

Reutiliza ShopRegistry, EquipProduct, UnequipProduct, PlayerService:GetInventory,
HasItem y SetEquippedItem y el snapshot Player.DataUpdated. El único inventario
continúa siendo Inventory.Owned[category][id] y Inventory.Equipped[category].
Se valida categoría, ID allowlisted, recurso Model con Origin BasePart, propiedad
y datos cargados antes de equipar. Un único ID activo por categoría.

ShopService Purchase/Equip/Unequip ahora exige IsShopDataReady: Player conectado,
runtime existente y PlayerDataService:GetLoadState(player)==Loaded. No se crea un
perfil desde una solicitud de Shop sin datos listos. Esta guarda no pretende
resolver el journal/rollback/cierre transaccional de la fase siguiente.

En esta fase CanPurchase devuelve AlreadyOwned para BasicKill y PurchasesNotEnabled
para otro producto de DeathEffects elegible; OnPurchased también rechaza. No se
habilitan ventas pagadas de Kill Effects ni se ejecuta una compra sintética de cero.
La infraestructura existente de PointEffects continúa para productos con recursos.

## 5. BasicKill inicial gratuito

BasicKill tiene metadatos Shop IsShopProduct=true, Price=0, Rarity=Common y descripción;
no se cambiaron nombre visual «Propulsión», partículas, duración ni sonidos del efecto.
PlayerService:HasItem reconoce acceso inicial implícito, igual a la convención de
PointEffects.Basic. Defaults runtime y PlayerDataService reflejan Owned.DeathEffects.
BasicKill=true y Equipped.DeathEffects=BasicKill. No se llama AddItem ni Purchase
por entrar y no se descuentan Coins.

Normalización aditiva dentro del esquema2: añade la propiedad inicial y sólo repone
selección ausente/inválida como DefaultFall. Conserva otras categorías y selecciones
futuras poseídas; no elimina compras ni aumenta Version o cambia nombres de stores.
La lectura del provider usa fallback BasicKill si una selección no está disponible,
sin sobrescribir en disco la selección futura retenida.

**Estado inicial esperado en UI: EQUIPADO**, porque ya es el cosmético por defecto.
No hay que comprarlo ni forzar un desequipado artificial para poder pulsar Equipar.
El endpoint de equipamiento existe para volver a BasicKill desde otro cosmético
válido cuando esa selección exista en una fase futura.

## 6. DefaultFall

IsShopProduct=false; no aparece en GetProducts/GetProduct del provider ni se obtiene
como recurso equipable. SetEquippedItem de DeathEffects también valida el producto,
por lo que no permite equipar DefaultFall ni IDs arbitrarios. El contrato de caída
sin atacante permanece literalmente sin cambios: devuelve DefaultFall antes de
consultar selección o propiedad. No se cambió atribución de Kill.

## 7. Frost y Void

PointEffectProvider calcula IsAvailable según la presencia real de un Model en
ServerStorage.PointEffects. No hay modelos Frost/Void en la inspección Edit.
Sus definiciones/precios permanecen intactos, pero el catálogo los expone bloqueados:
UI usa NO DISPONIBLE y desactiva el botón. CanPurchase/CanEquip y callbacks de entrega/
equipamiento comprueban recursos; ShopService rechaza equipar productos no disponibles;
PlayerService:SetEquippedItem también bloquea un ID PointEffects sin recurso.
No se llega a DeductCoins por esas compras. No se crearon modelos ficticios ni se
usó BasicKill para simular sus efectos. Una selección antigua sin recurso conserva
su dato pero el getter de PointEffects devuelve su fallback Basic, sin modificar
reglas del efecto de muerte.

## 8–9. Categorías y objetos físicos en Edit

Ruta raíz: `StarterGui.ShopHUD.MainFrame.Tabs`.

| Botón | Atributo Category | Cambio |
|---|---|---|
| PointEffectsTab | PointEffects | Sólo atributo nuevo |
| SlapsTab | Slaps | Sólo atributo; sigue sin provider/productos de Shop |
| TrailsTab | Trails | Sólo atributo; sigue sin provider/productos |
| DeathEffectsTab | DeathEffects | Nuevo clon del estilo PointEffectsTab; texto KILL EFFECTS |

El nuevo tab conserva tamaño177×54 y usa LayoutOrder=1 para agregarse después de
los tres anteriores (LayoutOrder=0). No se cambiaron Position, Size ni orden de los
botones existentes. UIListLayout continúa organizando la misma fila. En el viewport
Edit observado MainFrame mide881×471 y los cuatro tabs caben; móvil requiere prueba.

ShopController ya filtraba productos por Category y clonaba ProductCardTemplate;
no se reemplazó esa UI. Se añadió color ImageColor3 de selección porque los tabs
son ImageButtons con BackgroundTransparency=1: cambiar sólo BackgroundColor3 no
mostraba selección. El color original de la imagen se restaura al deseleccionar.
Se añadieron mensajes DataNotLoaded/PurchasesNotEnabled; no cambian posiciones/diseño.

MCP comprobó **un solo ShopHUD**. Original:81 descendientes; final:86, diferencia
correspondiente al nuevo tab y sus cuatro descendientes. Se compararon los 81 nodos
anteriores con el backup (clase, geometría GUI, textos, imágenes, fuentes, colores,
layouts, paddings, constraints y atributos existentes): sin cambios visuales.
Sólo se agregaron los atributos Category solicitados y el tab. No se modificaron
modelos de DeathEffects, mapas ni escena/cámaras cinematográficas.

## 10. Respaldo y Rojo

Antes de tocar HUD se verificó Archivable en raíz y todos sus objetos y se clonó
completo, persistente en Edit, en:

`ServerStorage._ShopIntegrationV1Backups.ShopHUD_before_V1_20261017_023953`

También se exportó el original mediante la API nativa
[SerializationService de Roblox](https://create.roblox.com/docs/reference/engine/classes/SerializationService),
que serializa/reconstruye instancias `.rbxm`. No se regeneró una UI desde JSON manual.
La reconstrucción temporal, sin Parent y destruida tras inspección, conservó81
descendientes. No se ejecutó contenido ni se guardó/cerró/reemplazó el lugar abierto.

- Backup completo: `tests/assets/backups/ShopHUD.before-V1-20261017_023953.rbxm`
  (25681 bytes).
- SHA256 backup: `D23A10661CE3676A5CCD82DD4FCCE58CA8AE5C2A9528A03CDE58993C004C35A5`.
- Export final: `src/ui/ShopHUD.rbxm` (25945 bytes,86 descendientes), reconstrucción
  nativa verificada con los cuatro atributos Category.
- SHA256 final: `086DE79F6E81C05EEF9316EBF5E67C0E63FE58F83564D1F83C66FE412BB60F32`.
- default.project.json ahora mapea StarterGui.ShopHUD a ese `.rbxm`; build PASS.

Studio era la fuente de verdad del diseño y se exportó desde su estado actual.
Ahora Rojo tiene una instantánea completa, no un HUD alternativo. La conexión actual
no estaba sincronizando scripts: se detectó y se instalaron por MCP los Sources.
Antes de escribir se verificó SHA256 de las seis fuentes existentes de Studio contra
el estado inicial del repositorio: todas coincidían. Las siete fuentes nuevas se
verificaron contra sus archivos antes de instalarlas. No se sobrescribió una edición
divergente. Dos DeathEffectDefinitions homónimos preexistentes se conservaron y
actualizaron a la misma fuente, sólo tras comprobar que eran la versión inicial
idéntica o la nueva; no se borraron módulos.

**Flujo de autoría posterior:** si se edita ShopHUD artísticamente en Studio, exportar
su estado actual a ShopHUD.rbxm antes de reconectar/sincronizar desde una instantánea
anterior. Rojo no hace exportación inversa automática de esas ediciones. Mantener
el backup original hasta autorización para retirarlo. No mover el backup a StarterGui
sin retirar/proteger primero el HUD activo: crearía una interfaz duplicada.

## 11. Conexión al efecto de la víctima

Se conserva el punto existente `DeathFeedbackContract.ResolveEffect`→
`PlayerService:GetEquippedItem(victim,"DeathEffects")`. Ese getter ahora delega al
provider registrado: lee el mismo inventario, valida producto/propiedad/recurso y
resuelve el fallback. No hay dependencia del HUD ni parámetros de cliente para VFX.

La resolución continúa antes de la retirada en EliminationService y queda en el
snapshot estable que consume DeathEffectService. No se cambió ese orden por una
segunda consulta tardía, ni se leyó el efecto del atacante. DeathEffectService,
DeathFeedbackContract, EliminationService y distribución privada por sesión no se
modificaron. DefaultFall y recompensas de Kill/gol siguen por sus rutas existentes.

## 12. Archivos

- NUEVO: `src/server/Shop/Providers/DeathEffectProvider.luau`.
- MODIFICADOS: `src/server/Services/ShopService.luau`, `PlayerService.luau`,
  `PlayerDataService.luau`, `src/server/Shop/Providers/PointEffectProvider.luau`,
  `src/shared/DeathEffectDefinitions.luau`, `src/client/Controllers/ShopController.luau`.
- NUEVO asset: `src/ui/ShopHUD.rbxm`; mapeo añadido en `default.project.json`.
- NUEVO backup: `tests/assets/backups/ShopHUD.before-V1-20261017_023953.rbxm`.
- NUEVOS: `tests/ShopIntegrationV1.spec.luau` (preparado, no ejecutado),
  este informe y `tests/ShopIntegrationV1.edit-evidence.json`.

Las funciones AddCoins, AwardConfirmedKill y DeductCoins se compararon contra las
fuentes iniciales y permanecen idénticas. Config, persistencia/proveedores,
DeathFeedback/EndCinematic, respawn, fuerza y modalidades/concurrencia no cambiaron.
El diff contra HEAD contiene además el trabajo anterior del desarrollador.

## 13. Objetos modificados

Los tres atributos de tabs existentes; nuevo DeathEffectsTab con su jerarquía
clonada; backup completo en ServerStorage; nuevo ModuleScript DeathEffectProvider;
Sources de los seis módulos existentes indicados arriba (y ambas copias iguales
del catálogo compartido). No se agregaron remotes, modelos de efectos ni objetos
de combate. Remotes.Shop sigue vacío en Edit, coherente con creación existente en
ShopRemotes:Init sólo durante ejecución.

## 14–15. Checks

- `rojo build default.project.json --output <TEMP>/SlapDuels-ShopIntegrationV1.rbxlx`: PASS.
- `git -c core.safecrlf=false diff --check`: PASS.
- Source/jerarquía inspeccionados en Edit; no módulo requerido para ejecutar tests.
- Exportación nativa y reconstrucción de modelo: verificadas como autoría de asset,
  no prueba de gameplay ni compra.
- No se ejecutó analizador Luau ni las suites aisladas; build no demuestra física,
  remotes, perfiles cargados o funcionamiento de una compra.

## 16. Matriz A1–A20

| Caso | Evidencia actual | Funcional/contrato ejecutado |
|---|---|---|
| A1 DeathEffects válido | Provider y registro inspeccionados | NOT RUN; suite preparada |
| A2 PointEffects conservado | Registro previo conservado | NOT RUN; suite preparada |
| A3 Category físico | Cuatro atributos observados en MCP Edit | Verificación estática realizada |
| A4 BasicKill inicial gratis | Entitlement/defaults/Price0 inspeccionados | NOT RUN; suite preparada |
| A5 DefaultFall fuera de Shop | Provider filtra explícitamente | NOT RUN; suite preparada |
| A6 Frost/Void no comprables | Modelos ausentes, IsAvailable y guardas inspeccionados | NOT RUN; suite preparada |
| A7 Frost/Void no equipables | Guardas provider y setter servidor | NOT RUN; suite preparada |
| A8 IDs/recurso válidos | BasicKill/Origin presentes, lookup allowlisted | NOT RUN; suite preparada |
| A9 ID desconocido rechazado | Lookup catálogo inspeccionado | NOT RUN; suite preparada |
| A10 propiedad obligatoria | Guardas provider/PlayerService | NOT RUN; fixture de contrato preparada |
| A11 selección de víctima | Getter existente delega al provider | NOT RUN; suite preparada |
| A12 caída universal | Contrato sin cambios | NOT RUN; suite preparada |
| A13 sin otra economía | Métodos económicos idénticos, no nuevos servicios | Verificación estática; fixture preparada |
| A14 sin remotes duplicados | No cambios en ShopRemotes, carpeta Edit sin remotes nuevos | Verificación estática |
| A15 recompensas intactas | Config/funciones económicas sin cambios | Verificación estática; gameplay NOT RUN |
| A16 Death Feedback intacto | Servicios/contrato/efectos sin cambios de funcionamiento | Regresión funcional NOT RUN |
| A17 EndCinematic intacto | Fuentes sin cambios | Regresión funcional NOT RUN |
| A18 conserva HUD | 81 nodos originales comparados, una raíz y86 finales | Verificación Edit/nativa realizada |
| A19 build | PASS | Comando ejecutado |
| A20 diff check | PASS | Comando ejecutado |

## 17. Guía manual exacta

1. Reiniciá TU prueba local con dos clientes para cargar los scripts instalados.
   Antes de continuar, confirmá en Output del servidor:
   `PersistenceEnvironment=Studio PersistenceProvider=InMemory WritesToCloud=false`.
   Si difiere, detener la prueba. No habilitar cloud ni editar perfiles para probar.
2. En cada cliente, pulsá TIENDA y luego KILL EFFECTS. Debe verse únicamente BasicKill
   (nombre de catálogo «Propulsión»), gratuito y normalmente **EQUIPADO desde el inicio**.
   DefaultFall no debe aparecer. No comprar BasicKill: ya es un derecho inicial.
3. Si BasicKill aparece poseído pero no equipado en un perfil de prueba legítimo,
   pulsá EQUIPAR y esperá DataUpdated→EQUIPADO. Si ya está EQUIPADO, ese botón queda
   desactivado por diseño; no modificar el perfil para fabricar otro estado. El
   regreso desde otro efecto poseído se probará cuando exista uno autorizado.
4. Anotá Coins; cambiá a EFECTOS DE PUNTO y regresá a KILL EFFECTS. BasicKill conserva
   estado; seleccionar/equipar no cambia Coins. La pestaña elegida se distingue por
   el color de imagen. Slaps/Trails muestran categoría futura vacía; no productos ajenos.
5. En PointEffects, Frost/Void deben figurar NO DISPONIBLE, sin acción de compra o
   equipamiento. No deben descontar Coins. Basic, Inferno y Thunder conservan sus
   precios existentes; esta fase no requiere ejecutar compras pagadas de regresión.
6. Entrá a matchmaking con ambos clientes, votá y esperá Go. Hacé una Kill válida:
   efecto BasicKill de la víctima, notificación y premio +50 únicamente al atacante.
   La selección de Shop no reemplaza el efecto por el del atacante.
7. Sin recibir golpes durante más de10s, hacé caer a un jugador sin atacante:
   DefaultFall, ninguna recompensa por Kill. No Health=0 ni comandos de fabricación.
8. Anotá un gol válido: +50 se conserva. Terminá la partida y verificá regreso/lobby
   y EndCinematic normal. Abrí Shop de nuevo: BasicKill y categorías coherentes.
9. Revisá Output de servidor y ambos clientes: provider DeathEffects registrado,
   sin errores de require, Category, recursos, DataNotLoaded persistente o UI.
   Durante carga inicial, DataNotLoaded es rechazo seguro; no una compra confirmada.
10. Repetí apertura/cambio de categorías en PC y móvil usados en el proyecto.
    No se rediseñó la ventana para móvil; el mínimo420px anterior sigue vigente.

Registrar por paso PASS/FAIL/BLOCKED/NOT RUN, Output y clip. La persistencia entre
ejecuciones nuevas de Studio no se promete: InMemory se reinicia con el servidor.

## 18. Riesgos pendientes

Pagos DeathEffects deshabilitados. No se corrigieron en esta fase journal durable,
finally/rollback de compras anteriores, coordinación de compra con cierre/guardado,
rate limit de GetCatalog ni garantías de servidor productivo. Los cambios de datos
se mantienen en runtime y se guardan mediante los hooks existentes cuando corresponde;
no equivalen a compra durable. APPROVED_PRODUCTION_UNIVERSE_ID continúa sin aprobar.

Los estados de selección actuales son seguros y aditivos; futuros productos requieren
metadatos aprobados, recurso real y propiedad válida, además de la siguiente fase
transaccional. Los tabs PC/móvil y la cadena completa víctima/efecto esperan prueba
humana. No se declara completada la aceptación funcional sólo por este informe.

## 19. Restricciones y cierre

No Play, Run, Start Server, control de personajes, compras de prueba, escrituras
cloud, commits, push ni publicación. No se cerró/guardó/reemplazó el lugar con cambios
del desarrollador. Se conserva el Working Tree previo y el respaldo existente.
Detenerse después de esta fase y esperar validación, sin nuevos efectos ni pagos.
