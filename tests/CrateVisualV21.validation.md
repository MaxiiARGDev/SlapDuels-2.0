# Slap Crates V2.1 — recuperación e integración visual

Implementación terminada en repositorio y Studio **Edit**. Aceptación visual/funcional **PENDING** hasta pruebas del desarrollador. No se ejecutó Play, Run, Start Server, Team Test, gameplay ni control de personajes; sin publicación, commit, push o escrituras cloud.

## Estado inicial y recuperación

El Working Tree contenía cambios previos extensos; se conservó sin reset/restore/clean/stash. Studio no coincidía con los recursos de V2 en archivos JSON. La inspección confirmó MainCrateStand.VisualDecor con **55 descendientes**, Backdrop con 19, nuevos emisores FlashSparks/SoftGlow/RiseStreaks, EnergyBeam restilizado y RewardOverlay con 15 descendientes. MainCrateStand tenía 177 descendientes; CrateOpeningHUD 20; ShopHUD 172. El respaldo interno ServerStorage._CrateVisualBackup_20261019 tenía 108 descendientes.

Los snapshots originales de Rojo no incluían esas mejoras. El proyecto completo seguía apuntando a CrateStands.project.json y CrateOpeningHUD.project.json, además de combinar el ShopHUD anterior con hijos explícitos. Aplicarlos sobre los recursos visuales nuevos podía restablecer propiedades o eliminar hijos.

OpeningConfig real mantiene nueve etapas y **10,5 s**, no 11,8. Se conserva esa duración, MaxSequenceDuration=25, modo StandCinematic y exclusividad actuales. No se cambiaron reglas de apertura ni concurrencia.

## Respaldo externo comprobado

Carpeta exacta: **H:\repos-github\_backups\SlapDuels-2.0\CrateVisualV21_20261019_155048**.

| Archivo anterior a modificaciones | Bytes |
|---|---:|
| MainCrateStand.before.rbxm | 27892 |
| CrateOpeningHUD.before.rbxm | 10312 |
| ShopHUD.before.rbxm | 35568 |
| InternalBackup.before.rbxm | 34957 |
| Recovery.before.rbxm | 58032 |

MCP no ofrece un comando directo de exportación a disco. Se usó SerializationService.SerializeInstancesAsync para generar archivos nativos; transferencia Base64 y decodificación local. Se verificaron cabecera `<roblox!`, tamaño y SHA-256 coincidentes con Studio y lectura real de los archivos externos. DeserializeInstancesAsync comprobó nombres y cantidades de descendientes en objetos sin parent, destruidos tras la verificación; no se importó nada encima del place.

Recovery contiene los cuatro recursos juntos. Existen copias y manifiestos en tests/assets/backups/CrateVisualV21. Los cinco archivos originales externos no se sobrescribieron. La subcarpeta externa **final** contiene además los tres snapshots finales y su manifest.

El respaldo interno permanece intacto: SHA-256 **7b838825c792e6ad7a4904961b3c48023c10dcb7b8677df94e961a08c8270b8a**. Se comprobó de nuevo al finalizar.

## Conservación de diseño y recursos integrados

Se compararon **372 instancias originales y 1673 propiedades visuales** con las exportaciones previas: jerarquías, geometría, colores/materiales, UI, textos/fonts, degradados, contornos, parámetros de partículas y Beam. Sin eliminaciones/recreación de MainCrateStand o HUDs. Todos los atributos anteriores, incluidos BurstCount, se conservaron.

El ShopHUD final es **binariamente idéntico** al exportado antes de intervenir: SHA-256 ce7a44b723f4881e1fb5c3a8bfac9d2f5e369c409393608d05f7dded80e39b57. No se tocó el CardTemplate compartido ni sus estilos/layouts. Las mejoras del panel de cajas, acciones y OddsList se recuperaron mediante el snapshot completo, sin restilizarlas desde cero.

Recursos finales del repositorio:

| Archivo en src/assets/CrateVisualsV21 | Bytes | Descendientes |
|---|---:|---:|
| MainCrateStand.rbxm | 28029 | 177 |
| CrateOpeningHUD.rbxm | 10798 | 24 |
| ShopHUD.rbxm | 35568 | 172 |

manifest.json registra hashes y cantidades. Se añadieron únicamente OpeningStages en cuatro emisores, IdleMotion en Shards/Ring, RevealScale dentro de RewardOverlay y CooldownLabel con su constraint/contorno reutilizado. No se alteraron geometría, cámaras físicas, estilos anteriores o poses artísticas. La captura de Edit permitió inspeccionar el stand; otros HUDs de preview estaban visibles, por lo que no constituye validación de la composición real durante gameplay.

## Sincronización Rojo verificada

Scripts/configuraciones siguen siendo fuente de verdad en src. El proyecto **studio-safe.project.json** contiene únicamente rutas .luau/.lua con ignoreUnknownInstances=true en todos sus nodos; Start-StudioSafeRojo.ps1 -GenerateOnly mantiene ese contrato. Es el flujo recomendado durante trabajo normal con scripts y diseño de Studio. No escribe ni reconstruye recursos físicos.

default.project.json conserva su estructura y cambia solo los límites de estos recursos:

- Workspace.CrateStands: Folder con ignoreUnknownInstances=true, MainCrateStand -> snapshot nativo.
- StarterGui.CrateOpeningHUD -> snapshot completo, sin overrides de hijos.
- StarterGui.ShopHUD -> snapshot completo, sin los overrides CratePanel/OddsList/MainFrame que ya están dentro del archivo.
- ServerStorage tiene ignoreUnknownInstances=true: el respaldo interno no se administra ni elimina desde el proyecto.

Esto evita duplicados: Rojo agrega hijos explícitos a los ya incluidos por un archivo; no sirve usarlos para reemplazar los mismos nombres. Se verificó el XML del build completo: cantidades exactas y ningún hermano duplicado dentro de los tres snapshots, con VisualDecor/Backdrop, RevealScale y OddsList presentes.

Los JSON históricos de recursos se conservan para recuperación, pero ya no son las rutas activas de esos tres recursos. El generador histórico slap_crates_v2_assets.py se bloquea si detecta los snapshots V2.1; no debe regenerar una versión anterior sobre ellos.

**Límite de protección:** el build completo representa el estado exportado actual. Si editás arte después en Studio, exportá/actualizá los snapshots y sus hashes antes de usar el proyecto completo. ignoreUnknownInstances de un límite no protege todas las propiedades conocidas ni todos los descendientes de futuras modificaciones sin exportar. SAFE evita esa escritura porque solo administra scripts. No se afirma protección general de recursos ajenos no mapeados; revisar preview de cualquier sincronización completa.

## RewardOverlay

El controlador existente compone RewardOverlayPresenter, sin otro controlador de cámara/apertura. Al alcanzar Reward usa el RewardId del paquete autoritativo, ya validado contra Catalog; Slap y variación provienen de sus definiciones registradas. No acepta nombres o premios nuevos del cliente.

El overlay privado muestra Title/SlapName/VariationName, aplica el color real de la variación y AccentStroke, entra con desplazamiento/UIScale/alpha y sale en Outro. Se conservan degradados, tipografías, tamaños y posición de diseño. La propiedad del overlay está asociada al OpeningId: una cancelación vieja no oculta uno más nuevo. Repetir la etapa no añade tweens o conexiones. Al cancelar se cancelan tweens, restauran propiedades y oculta el overlay. Espectadores y Spin no lo usan.

## Emisores y animación cinematográfica

VisualProfile selecciona tratamientos de presentación para las 12 variaciones usando su Color real y los recursos de SlapVariationEffects existentes. Basic/Common son sutiles; Uncommon/Rare aumentan intensidad; Gold/Arcoiris y Emote/Wings conservan sus perfiles temáticos; Epic/Legendary y Blood/Galaxy tienen más luz/partículas/énfasis y opción Special. No se relaciona esta intensidad con precios o probabilidades.

OpeningStages liga emisores físicos existentes:

- Soft: Appear.
- RiseStreaks: Rise, BurstCount original 6.
- SoftGlow: Appear/Growth/Reward, BurstCount original 2.
- FlashSparks: Flash, BurstCount original 24.

Se respetan atributos, con escalado visual acotado: máximo 32 por emisor y 64 partículas por etapa. No se duplican emisores. EnergyBeam conserva anchos de diseño, se activa en Growth/Shake, pulsa moderadamente y usa color de catálogo en la copia local. Partículas/luz son temporales; no se introducen fuerzas, daño o Explosion física.

Intro/CameraReveal usan fade con easing sinusoidal. Appear/Rise/Growth usan smoothstep; rotación integrada continua entre etapas, sin saltos de ángulo al cambiar velocidad. Shake aumenta amplitud gradualmente; Flash oculta el cofre antes de revelar el premio. Reward flota/gira con perfil, Billboard y overlay reales. Cámara suaviza foco, conserva composición del premio durante Outro y mantiene todas las posiciones relativas a anchors.

CameraLease permanece intacto: prioridad de Match/Results/EndCinematic, restauración de la misma vida y protección frente a propietarios/contextos nuevos. Controles siguen usando el mecanismo local existente. Las pruebas reales de FOV/sujeto después de muerte o cambios de cámara siguen pendientes; no se declara restauración funcional observada.

## Idle, estados y espera personal

Se cachean poses locales de Shards/Ring y brillo inicial de luces. Idle flota/rota/pulsa discretamente a máximo 30 Hz, omite stands lejanos y actualiza textos del catálogo cada .25 s. No crea modelos por frame ni usa un segundo loop. Destroy restaura poses/brillo cacheados.

StandOpeningService solo cambia textos y agrega metadatos visuales de cooldown; el Ledger, propiedad/exclusividad, plazos y adjudicación no se modificaron. Idle: CAJAS + «Abrí cajas y conseguí slaps exclusivos». Ocupado: APERTURA EN CURSO + «Esperá tu turno». Privado no marca ocupado global porque no hay lock de stand.

El comprador recibe el plazo personal ya calculado por Ledger; los espectadores no. CooldownLabel muestra segundos restantes solo para el StandId seleccionado, sin bloquear input ni otra persona. Al mostrarlo se mantienen ocultos overlay/transiciones para evitar pantalla negra. No es una nueva regla de cooldown ni un acuse que permita liberar anticipadamente.

## Audio pendiente

Los Sounds siguen sin IDs inventados. Rutas bajo PresentationTemplate.Effects.FXAnchor:

| Etapa | Sound |
|---|---|
| Intro | Start |
| Aparición | Appear |
| Elevación | Rise |
| Energía | Growth |
| Tensión | Shake |
| Explosión visual | Flash |
| Revelación | Reward |
| Premio destacado | Special |
| Salida | Outro |

Se reutilizan SFX aprobados del perfil de variación si existen. MusicController continúa con sus tokens Suspend/Resume y preferencias propias. Audio no se considera completo ni escuchado sin recursos finales y prueba humana.

## Archivos modificados y regresiones

Runtime existente: Controllers/CrateStandCinematicController.luau y Services/Crates/StandOpeningService.luau. Nuevos helpers: cliente CrateOpening/VisualProfile.luau y RewardOverlayPresenter.luau. Snapshots/manifiesto, mappings default/SAFE y pruebas/validadores/informes V2.1. El harness V2 incorpora dependencias visuales y contratos de emisor de prueba.

**153 archivos originales src conservan SHA-256**: economía 150/30, precios, matrices, aprobaciones, StudioTest 1 Coin, Inventario, Stock, Quote, DuplicatePolicy, motor, Slap Variations, equipamiento, habilidades/Death Effects, RoundService, EndCinematic y Spin clásico intactos. No se modificó PRODUCTION_UNIVERSE_ID. Se respaldaron fuentes anteriores y proyectos en tests/assets/backups/CrateVisualV21.

## Resultados

| Verificación | Resultado |
|---|---|
| Recuperación/overlay/perfiles + regresión de odds/cajas/V2 | PASS: 1172 aserciones aisladas |
| Economía | PASS: 30 |
| Combate/protección | PASS: 150 |
| Habilidades | PASS: 164 |
| Registry | PASS: 89 |
| Shop | PASS: 86 |
| Variaciones | PASS: 19 |
| Total | **1710 aserciones aisladas** |
| Compilación Luau | PASS: 126 scripts + spec |
| Rojo completo/SAFE | PASS ambos |
| Jerarquías del build y límites SAFE | PASS |
| git diff --check | PASS |
| Respaldo externo | PASS: existencia, tamaño, hashes y roundtrip |
| Studio/repo | PASS: 3 hashes de snapshots y fuentes/editor sincronizados |
| Gameplay, render de secuencia, PC/móvil, audio | NOT RUN |

También se repiten 2.4 millones de sorteos puramente matemáticos del harness anterior, sin compras reales. La prueba de overlay ejecuta el helper real con tweens simulados; comprueba nombres/color, entrada/salida, cancelación, repetición y ausencia en espectadores. No reemplaza observar la animación.

Evidencias: CrateVisualV21.checks.json, .integrity.json, .studio-edit.json, logs, manifiestos de snapshots y respaldo. Validación reproducible: tests/tools/validate_crate_visual_v21.py. Se inspeccionó la rama física Studio/InMemory/WritesToCloud=false sin inicializar persistencia; runtime pendiente. No se accedió a DataStores.

Pendientes: aprobación visual por el desarrollador, recursos de audio, comportamiento real PC/móvil/cámara y futuras exportaciones de arte. Ver CrateVisualV21.manual.md y CrateVisualV21.sync-recovery.md. Detenido hasta validación humana.
