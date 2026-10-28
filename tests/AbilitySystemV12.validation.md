**Ability System V1.2 — implementación modular e informe de validación.** Fecha: 2026-10-17.

Implementada en repositorio y Roblox Studio **Edit**. Se migraron las cinco habilidades; no se creó una sexta habilidad competitiva. La jugabilidad y la aceptación visual permanecen pendientes del desarrollador.

**Estructura y fuente de verdad.** `ServerScriptService.Abilities` contiene las cinco habilidades existentes, MovementGuard y los nuevos AbilityManifest, AbilityCallbacks, AbilityInputAdapter y AbilityAssetValidator. La plantilla documental está en `Abilities.Templates.AbilityTemplate`. `Services.AbilityRegistry` construye y sella el catálogo antes de que Bootstrap cargue/inicialice ShopService. `ReplicatedStorage.Shared.AbilityDefinitions` conserva sólo opciones globales; `AbilityCatalog` es un caché cliente del DTO del servidor. En `StarterPlayerScripts.Abilities`, AbilitySelection, AbilityPresentation y el nuevo AbilityPresentationProfiles consumen ese catálogo. Los módulos autoritativos no se replican al cliente.

El manifiesto explícito conserva DashAbility, StrongSlapAbility, AirJumpsAbility, DevilSpeedAbility e InvisibilityAbility, en ese orden. No carga por exploración de carpetas. Resolve verifica nombres físicos únicos; IsModule exige ModuleScript hijo directo de la carpeta aprobada antes de require. MovementGuard y Templates quedan fuera.

**Registro y contrato.** Cada módulo declara Descriptor, Enabled, Config/ConfigSchema, Assets, Shop, Dependencies y Input; Start/Cancel son obligatorios, Step/ValidateActivation/OnAction opcionales. Actions y Hooks describen capacidades revisadas. El registro comprueba IDs, tipos, valores finitos/rangos, esquema de configuración, funciones, dependencias, perfiles, referencias físicas y flags/precio comercial. Rechaza las dos entradas de un ID duplicado. Un require fallido o contrato/recurso inválido se diagnostica y no impide registrar las otras habilidades. Un nombre repetido en el manifiesto se diagnostica sin una segunda ejecución.

No existe API de registro adicional durante partidas; una segunda Initialize devuelve RegistryAlreadySealed. Entradas, configuración, catálogo y diagnósticos se congelan recursivamente. El DTO público proyecta sólo descriptor seguro, bindings de input y claves/perfiles/cues visuales; excluye Config, esquema, dependencias, funciones, Instances y estado de compra. Se entrega en el primer snapshot privado y al solicitar Sync. Shop obtiene su proyección comercial directamente del mismo registro; no mantiene otra lista de habilidades.

**Migración y adaptadores.** Los módulos reciben un runtime por activación con identidad inmutable y estado propio mutable. No reciben Session, Player, servicios, inventario ni acceso económico inyectado. MovementGuard usa World con las mismas referencias necesarias de límite/KillParts. Se preservaron sus barridos, márgenes, control de ownership y límites de movimiento.

| Habilidad | Duración / cooldown | Parámetros preservados |
|---|---|---|
| Dash | 0,2 / 11 s | 24 studs, normalización horizontal/orientación, sweep, corte de frame largo y restauración de ownership |
| StrongSlap | 15 / 25 s | Carga Armed, consumo por impacto confirmado, elevación visual de 25 studs |
| AirJumps | 15 / 20 s | Fuerza 32, intervalo 0,8 s, cuatro extra, máximo Y 38, ascenso 24 studs, ownership 0,15 s |
| DevilSpeed | 5 / 14 s | Multiplicador 2,4, máximo 48, aceleración 100, restauración respetando otro propietario |
| Invisible | 5 / 35 s | Avatar/accesorios/Slap ocultos localmente, traza y restauración de valores originales |

AbilityInputAdapter valida None/Direction. Las acciones secundarias y bindings activos/salto se derivan de Input/Actions; los controladores no comparan IDs concretos. Los callbacks no pueden yield; errores/suspensiones se contienen y generan diagnóstico con ID/callback. CancelPlayer retira el registro activo antes de limpiar para impedir doble Cancel; se cancela también tras Start parcial fallido. No se gasta cooldown si Start no fue aceptado.

StrongSlap declara hooks BeforeHit/Consume y el perfil ImmediateElimination. SlapService captura un ticket por referencia/ActivationId después de sus validaciones normales y llama al CombatService existente; sólo luego permite consumirlo. El adaptador HandleAbilityHit de EliminationService valida razón y atacante acreditado, reutilizando la ruta existente de eliminación, Zero-Death, estadísticas y recompensa. No se incorporó un segundo pago. PresentCue sólo se ejecuta tras confirmación real de eliminación. El cliente resuelve VerticalLaunch desde Assets.Cues; no aplica fuerzas al personaje competitivo. La razón histórica StrongSlap se conserva.

Invisible declara InvisibleAvatar. AbilityPresentationProfiles aplica/restaura propiedades locales y maneja accesorios tardíos sin capturar sus propios efectos. Si otro propietario visual cambia una propiedad después, la limpieza respeta ese valor. AttachmentEffect conserva clonación de Origin y reproducción de sonidos existentes no vacíos. No se editaron VFX, SFX ni HUDs físicos; iconos/precios/audio pendientes de fases anteriores no se inventaron ni aprobaron.

**Shop, selección e inventario.** AbilityProvider deriva productos del registro habilitado. Los cinco precios siguen sin aprobación y PurchaseEnabled=false. Se mantiene compra atómica, propiedad y preferencia mediante PlayerService/ProfilePurchase existentes, sin otra tienda ni inventario. Los IDs persistidos permanecen intactos. Una entrada inválida/deshabilitada no aparece como seleccionable ni comprable. Una nueva entrada válida y habilitada se incorpora a Shop/selector por el catálogo; su propiedad sigue dependiendo del inventario.

La selección conserva tokens de sesión/preparación/ventana, StateVersion, deadline y confirmación individual. PrepareSelection sigue retornando sin esperar dentro de los countdowns existentes de 5/3 s; el menú sólo se abre al pulsar Cambiar habilidad. Las cards se construyen cuando llega la versión del catálogo, sin listas estáticas. Se conservaron E, botón móvil, cierre automático, preferencias y cooldown por ronda. RoundService no se modificó.

**Cambios de esta tarea frente a su respaldo inicial.** Se modificaron 15 fuentes existentes: las cinco habilidades y MovementGuard; AbilityDefinitions; AbilityService; AbilityProvider; AbilityController; AbilitySelection; AbilityPresentation; Bootstrap; SlapService; EliminationService. Se agregaron ocho fuentes: AbilityRegistry, AbilityCatalog, AbilityManifest, AbilityCallbacks, AbilityInputAdapter, AbilityAssetValidator, AbilityPresentationProfiles y Templates/AbilityTemplate. Se regeneró studio-safe.project.json y se amplió el runner aislado. El resto son pruebas, guías, evidencias y build bajo tests.

El cambio de SlapService se limita al enlace genérico PrepareHit/ConsumeHit/PresentCue; el de EliminationService, al nombre/contrato del adaptador y razón de impacto. Config, RoundService, CombatService, PlayerService, PlayerDataService, ProfilePurchase, ShopService/ShopRegistry, persistencia, mapas, UI, Death Feedback y EndCinematic conservaron sus hashes previos dentro de los **92/92 archivos protegidos**. Los 16 archivos del respaldo de esta tarea verifican sus SHA-256. La lista exacta está en `AbilitySystemV12.file-integrity.json`; no confundir cambios preexistentes de git status con modificaciones de esta entrega.

Respaldo de tarea: `H:\repos-github\SlapDuels-2.0\tests\assets\backups\AbilitySystemV12`. No sustituye ni borra el respaldo integral anterior. No se ejecutaron reset, stash, clean, checkout, commits ni push. El lugar no se cerró, publicó ni guardó forzosamente encima de tus cambios.

**Verificaciones ejecutadas.**

| Comprobación | Resultado | Evidencia y límite |
|---|---|---|
| Registro/seguridad | PASS aislado, 89 aserciones | AbilitySystemV12.registry-results.txt: cinco contratos, errores, ausencia, duplicados, require, config, assets, habilitación, compra, manifest, sellado, metadatos y yield |
| Regresión de lógica | PASS aislado, 121 aserciones | AbilitySystemV12.regression-results.txt: autoridad/vida/ronda, movimiento, ownership, Shop/compra, acciones secundarias, error/yield, remotes y cierre |
| Selección | PASS aislado, 54 aserciones | AbilitySystemV12.selection-results.txt: ventanas 5/3, confirmación, apertura explícita, rechazo/expiración, aislamiento y limpieza |
| Presentación/recursos | PASS aislado, 18 aserciones | AbilitySystemV12.presentation-results.txt: restauración Invisible, accesorios/Slap, propietario posterior, recursos inseguros/ausentes |
| Total | **282 aserciones aisladas** | Fuera de Roblox, con mocks; no demuestra jugabilidad real |
| Registro contra recursos físicos reales | PASS de contrato en Edit | Cinco entradas, cero diagnósticos; require sobre copias temporales fuera del DataModel, destruidas después; no se llamó a Start/Step de habilidades |
| Fuentes frente a Studio | PASS, 23/23 SHA-256 normalizados | AbilitySystemV12.studio-edit-verification.json: GetEditorSource; conflictos y rutas duplicadas abortan la escritura |
| Remotes físicos | PASS estructural | AbilityRequest y AbilityState: un RemoteEvent de cada uno |
| HUD | PASS estructural | Activación Position `{1,-28},{1,-175}`, Size `148×120`; Cambiar Position `{1,-28},{1,-303}`, Size `148×36`; sin cambios físicos |
| Perfil Rojo SAFE | PASS de auditoría GET | 97/97 fuentes servidas coinciden; 142 nodos preservan desconocidos, cero rutas duplicadas |
| Compilación Luau | PASS | 97 fuentes de src y cinco archivos de pruebas; compilación no ejecuta gameplay |
| rojo build default.project.json | PASS | tests/AbilitySystemV12.build.rbxlx |
| rojo build studio-safe.project.json | PASS | tests/AbilitySystemV12.safe-build.rbxlx |
| git diff --check | PASS | Sin errores; Git advierte conversión LF→CRLF por configuración existente |
| Integridad | PASS, 92/92 protegidos y respaldo 16/16 | AbilitySystemV12.file-integrity.json |
| Persistencia resuelta en Edit | Studio / InMemory / WritesToCloud=false | IsStudio=true, IsRunning=false; sin servidor de juego iniciado por el agente |
| Producción | Bloqueada, sin cambios | APPROVED_PRODUCTION_UNIVERSE_ID sigue nil; código de persistencia conserva SHA-256 |
| Workspace.ActiveMatches en Edit | 0 | No indica que se haya probado limpieza de una partida real |

El servidor Rojo SAFE propio fue reiniciado tras regenerar sus rutas; escucha 127.0.0.1:34873. No es un servidor de juego de Roblox. El nombre del proyecto sigue **SlapDuels-2.0 Scripts Only SAFE**. El perfil completo sirve sólo como build en esta tarea; no se usó para sobrescribir objetos físicos de Studio.

**Matriz funcional pendiente.** Todos estos resultados requieren observación del desarrollador y no se infieren de inspección de código:

| Caso | Estado | Evidencia requerida |
|---|---|---|
| Matchmaking, votación, spawn y Slap | NOT RUN | Output servidor y video de ambos clientes |
| Shop, propiedad y preferencia reales | NOT RUN | Cards/inventario y compra rechazada sin descontar Coins |
| Selector cerrado por defecto, ventanas 5/3 | NOT RUN | Video de ambos HUDs y confirmación/deadline |
| E y botón móvil | NOT RUN | Activación real de cada habilidad |
| Dash y límites de arena | NOT RUN | Pared, borde, dirección, ragdoll y CD 11 |
| AirJumps y DevilSpeed | NOT RUN | Fuerza/límites, restauración, cancelación y cooldowns |
| StrongSlap sin doble Kill/Coins | NOT RUN | Antes/después de carga/impacto, incluido tercer golpe normal |
| Invisible y restauración completa | NOT RUN | Ambos clientes; Slap, accesorios, eliminación y lobby |
| Callback viejo/respawn y desconexión | NOT RUN | Generaciones/Output y ausencia de efectos residuales |
| Reloj 3:00, Muerte Súbita y timeout | NOT RUN | Secuencia temporal sin editar configuración |
| KillPart y Zero-Death | NOT RUN | Una salida/recompensa; sin Humanoid death involuntaria |
| Gol +50 Coins | NOT RUN | Balance antes/después separado de Kill |
| Quinto punto y EndCinematic | NOT RUN | Cinemática y retorno sin efectos de habilidad |
| Lobby ajeno y limpieza | NOT RUN | Cliente adicional sin feedback; ActiveMatches/sesiones tras cierre |
| Segunda partida | NOT RUN | Flujo completo repetido, sin conexiones/estado residual |

Los pasos exactos y comandos de preparación InMemory están en `tests/AbilitySystemV12.manual.md`. La guía de incorporación de módulos está en `tests/AbilitySystemV12.add-ability.md`.

**Límites y recomendación.** La extensibilidad para capacidades existentes está implementada: módulo + recursos + una entrada del manifiesto; la regeneración de rutas SAFE es automática. Una capacidad nueva exige un adaptador revisado. El manifiesto aprueba código confiable antes de require: la validación del resultado y el runtime limitado no son un sandbox contra un ModuleScript de servidor hostil que acceda directamente al motor. No deben aprobarse cuerpos de módulo con efectos laterales, acceso autónomo a economía/sesiones o tareas fuera del lifecycle.

No se declara aceptación funcional de las cinco habilidades ni se autoriza publicación con estas comprobaciones. La implementación queda lista para la regresión manual descrita. No continuar con una habilidad nueva u otra implementación hasta recibir validación/autorización del desarrollador. No hubo Play, Run, Start Server, control de personajes, commits, push, publicaciones ni escrituras cloud.
