# Slap Crates V2.2 — informe de implementación

Fecha: 2026-10-19. Implementado y sincronizado mediante MCP en Studio **Edit**, PlaceId 107328891970677. No se inició Play, Run, Team Test ni servidor de pruebas. Aceptación visual/multijugador: **PENDING**, a cargo del desarrollador.

## Archivos y alcance

- Nuevo `src/client/CrateOpening/CharacterVisibility.luau`.
- Integración mínima en `src/client/Controllers/CrateStandCinematicController.luau`.
- `studio-safe.project.json` regenerado: 127 scripts, incluye el módulo nuevo.
- Pruebas: `tests/CrateVisibilityV22.spec.luau`, `tests/tools/validate_crate_visibility_v22.py`, `tests/tools/crate_visibility_v22_sync.py`.
- Fixtures compartidos: `tests/tools/run_ability_unit_tests.py`, `tests/SlapCratesV2.extension.luau`; sus specs compuestos se regeneraron.
- Evidencia: `tests/CrateVisibilityV22.checks.json`, `tests/CrateVisibilityV22.studio-edit.json`, resultados/logs con el mismo prefijo.
- Copia del controlador previo y estado Git: `tests/assets/backups/CrateVisibilityV22/`. Los respaldos V2.1 siguen intactos.

No se modificaron servidor, persistencia, combate, ragdoll, economía, compras, inventario, probabilidades, exclusividad, cooldown, timeline, CameraLease ni recursos visuales físicos. El Working Tree ya contenía cambios y archivos sin rastrear de tareas anteriores; no se hicieron commits, limpieza ni restauraciones.

## Activación y restauración

`_phase(CameraReveal)` adquiere el lease únicamente con `run.Private == true`, antes de escribir CameraType y abrir la transición. Intro y navegación del Shop no lo adquieren. `_update` tiene una adquisición equivalente antes de la primera escritura de cámara cuando un paquete tardío salta CameraReveal.

En Outro, el lease continúa activo hasta `_restore`: primero se llama al CameraLease existente para devolver o ceder la cámara y después se libera la visibilidad. `_stop` contiene también una liberación idempotente independiente del resultado de `_restore`, incluso ante un error al restaurar la cámara o música. Los caminos existentes de muerte, cambio de personaje, prioridad de Match/EndCinematic, pérdida de cámara, cancelación, final y Destroy convergen en esa limpieza. No se reclama una cámara que pertenece a un sistema de mayor prioridad.

El lease utiliza OpeningId y una identidad de objeto por adquisición. Adquirir otra apertura libera la anterior; una liberación antigua no puede limpiar la nueva. No se agregaron tareas retardadas ni recorridos por frame.

## Alcance local y objetos

Solo se recorren Characters obtenidos mediante Players, nunca todo Workspace. Se usan PlayerAdded/Removing, CharacterAdded/Removing y DescendantAdded/Removing. Herramientas, guantes y accesorios quedan incluidos por ser descendientes del Character. Objetos desprendidos y vidas anteriores se restauran y dejan de retenerse.

- BasePart/MeshPart: LocalTransparencyModifier=1; no se escribe BasePart.Transparency.
- ParticleEmitter, Trail, Beam, BillboardGui, SurfaceGui, Highlight, Light, Fire, Smoke y Sparkles: Enabled=false local.
- ParticleEmitter y Trail: Clear local para retirar geometría previamente emitida. Al liberar se restaura Enabled, **no se reconstruyen partículas ni trazos pasados**.
- Decal/Texture: Transparency local; ForceField: Visible local; Humanoid: DisplayDistanceType=None local.

No hay RemoteEvents nuevos ni cambios replicados de visibilidad. Stand, caja, recompensa y PresentationTemplate quedan fuera del conjunto elegible. ExclusiveOpening no cambia: espectadores no adquieren el lease. Aperturas privadas son locales a cada VM cliente. Spin sale antes de esta integración.

## Conflictos de transparencia

La inspección encontró LocalTransparencyModifier en AbilityPresentationProfiles y en el idle de cajas. El segundo opera sobre decoraciones, fuera de Characters. AbilityPresentation solo aplica presentaciones de la sesión del participante en Playing; la apertura usa lobby y se cancela al adquirir prioridad de combate. No se modificó ninguno de esos sistemas.

Cada propiedad guarda su valor previo, no presupone cero. Una señal de cambio registra el último valor externo diferente del aplicado y mantiene el ocultamiento hasta liberar. La restauración es condicional: no reemplaza un valor posterior diferente que ya haya ganado al liberar. Como con cualquier observador de propiedades, una escritura externa del **mismo** valor no genera un cambio distinguible y no permite inferir la intención de otro propietario. El módulo no pretende ser un árbitro universal para futuros sistemas de invisibilidad; un nuevo propietario simultáneo debe integrarse a un contrato compartido, no guardar ciegamente el valor ya enmascarado. Primera persona y transición a combate requieren comprobación real del desarrollador.

## Matriz automatizada

Todos los resultados siguientes son de **pruebas aisladas con señales/objetos simulados**, no PASS funcional en Roblox.

| Caso solicitado | Evidencia aislada | Estado funcional |
|---|---|---|
| 1–3. Personajes actuales, propio y ajenos | Modificadores locales aplicados a ambos Characters | NOT RUN |
| 4. Herramientas/accesorios | Handles y guante ocultos/restaurados | NOT RUN |
| 5. Partes dinámicas | DescendantAdded y desprendimiento | NOT RUN |
| 6. Characters nuevos | Ingreso, CharacterRemoving/Added, respawn | NOT RUN |
| 7–8. Stand y premio | Objetos externos no se modifican | NOT RUN |
| 9. Efectos adheridos | Diez clases Enabled, partículas/estelas, decals, nombres y ForceField | NOT RUN |
| 10. Espectador | `_phase` real sin adquisición con Private=false | NOT RUN |
| 11. Privado independiente | Propiedad local y tokens; no hay replicación en el harness | NOT RUN multicliente |
| 12. Spin | `Play` real retorna sin adquirir | NOT RUN |
| 13–16. Restauración, cancelación, muerte, interrupción | `_restore`, `_stop` y `_update` reales; cámara antes de liberar; error inyectado; prioridad Match | NOT RUN |
| 17. Conexiones | Todas desconectadas al liberar | NOT RUN |
| 18. Aperturas consecutivas | Adquisiciones repetidas y liberaciones tardías | NOT RUN |
| 19. Invisibilidad residual | Restauración no cero, cambios externos y efectos inicialmente deshabilitados | NOT RUN |
| 20. Referencias temporales | Tablas Saved/Players/Characters/Owners y conexiones vacías | NOT RUN |

Resultados: 108 aserciones nuevas + 1172 cajas/V2.1 + 30 economía + 150 combate + 164 habilidades + 89 registry + 86 Shop = **1799 aserciones aisladas aprobadas**. Compilación Luau de **127 scripts runtime** y spec V2.2 aprobada. Ambos builds Rojo aprobados e inspeccionados: exactamente un CharacterVisibility ModuleScript, con su Source. `git diff --check` aprobado (advertencias existentes LF/CRLF). Los tres snapshots V2.1 del repositorio mantienen sus SHA-256.

## Inspección de Edit y discrepancia del stand

MCP verificó fuente persistente y editor idénticos:

- `StarterPlayer.StarterPlayerScripts.CrateOpening.CharacterVisibility`: SHA-256 normalizado `085afdb336c737364aa009261ff6b6d59e3dc20599e6aa973068ee6ca3b52bd7`.
- `StarterPlayer.StarterPlayerScripts.Controllers.CrateStandCinematicController`: `d4e405761b0e9f28a86b92114728021eebabd7cd66cc006ecc1cef9d93832c8f`.

Hay exactamente un módulo nuevo. No se guardó, cerró ni publicó el lugar. Guardar normalmente desde Studio conserva estos cambios en disco.

ShopHUD (172 descendientes), CrateOpeningHUD (24) y respaldo interno (108) coinciden byte a byte con sus hashes V2.1. **El stand actual conserva 177 descendientes pero su serialización tiene hash `02ab3968189bbd7b98ec5602265cf4ca17fa68663326f6fd725ee01e1b7f6f3d`, distinto del snapshot del repositorio.** No se estableció la causa ni se sobrescribió/exportó el stand en esta tarea. No asumir que ambos recursos son equivalentes: usar SAFE para scripts y actualizar/verificar el snapshot antes de una futura sincronización completa.

La prueba fallida inicial del comparador de builds fue un selector XML de Source demasiado específico; corregido para aceptar la representación emitida por Rojo. La ejecución completa posterior pasó. Ninguna prueba accedió a perfiles reales ni ejecutó el código en un servidor de Roblox.
