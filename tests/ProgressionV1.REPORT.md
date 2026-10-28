# EXP y pase gratuito V1 — preparado para pruebas en Studio

## Alcance entregado

Implementado y sincronizado en Studio Edit: EXP permanente, nivel derivado, pase gratuito de 30 etapas, reclamación individual/Reclamar todo, contador de temporada y controles en el panel admin existente. El catálogo inicial es el aprobado para pruebas. Premium, x2 y compra completa NO están habilitados; sus beneficios requieren la futura integración de comercio verificado. No se publicaron cambios.

La funcionalidad se habilita únicamente si RunService:IsStudio(), PersistenceEnvironment=Studio, PersistenceProvider=InMemory y WritesToCloud=false. Se verificó la selección real del entorno en Edit. Producción permanece bloqueada expresamente; no basta cambiar un toggle para vender o conceder beneficios Premium.

## Reglas implementadas

- Inicio en nivel permanente 0 y EXP 0 para perfiles sin progresión, sin alterar estadísticas o inventarios anteriores.
- Coste de subida: 100 + 25 por nivel, con máximo de 1000 EXP por subida. EXP sobrante y subidas múltiples se conservan. El nivel se deriva de TotalXP y no es una segunda fuente de verdad.
- Completar: 40 EXP; victoria: +40; gol: +15; Kill acreditada: +10. No cambian las Coins existentes.
- Liquidación al cierre autoritativo de la partida, con identidad de sesión y recibo persistido para no duplicar EXP.
- Elegibilidad: 60 segundos acumulados en Playing, excluyendo countdowns, más un gol, una Kill o dos ataques aceptados por el servidor separados al menos 10 segundos. Los ataques fallidos aceptados pueden demostrar participación; solicitudes rechazadas y maniquí no cuentan.
- Abandono/desconexión, cancelación o falta de elegibilidad: sin EXP. Se informa al jugador conectado del motivo de cero EXP.
- La misma EXP suma a nivel permanente y pase activo, sin multiplicador en esta versión gratuita. Las etapas se limitan a 30, pero la EXP registrada de la edición puede seguir acumulándose.
- Se captura la edición al comenzar Playing. Si al liquidar terminó o cambió, solo se concede EXP permanente. No se traslada EXP de una partida anterior al pase nuevo.
- 800 EXP por etapa, 24.000 para la etapa 30. La meta de 15–20 horas es un objetivo de balance que todavía requiere mediciones reales.

## Temporadas y administración

Ruta física: StarterGui.AdminHUD.MainFrame.SeasonPanel, abierto mediante SeasonsButton/TEMPORADAS. El resto del panel conserva sus comandos actuales; el título se ajustó de ancho para acomodar el nuevo botón.

El administrador puede seleccionar catálogo, indicar de 1 a 365 días, iniciar, reiniciar o finalizar. Los tres cambios requieren una confirmación explícita de 30 segundos. Iniciar no reemplaza accidentalmente un pase activo. Reiniciar crea una EditionId nueva, conserva EXP permanente y premios entregados, y deja sin efecto EXP del pase y reclamos pendientes anteriores. La limpieza del perfil es diferida: una edición anterior nunca se usa como progreso de la nueva.

La autorización se comprueba en el servidor con AdminService:IsAdmin en cada llamada. Se usan revisión esperada, OperationId, token ligado al administrador y compare-and-swap en el proveedor; reintentar la misma confirmación no crea otra edición. El catálogo y los requisitos se copian a la edición al iniciarla, por lo que editar un módulo no modifica una temporada en marcha.

Todos los clientes del servidor de prueba reciben el mismo inicio/cierre UTC; el contador usa tiempo del servidor. Los cambios se consultan cada cinco segundos, y se vuelve a consultar el estado para reclamar/liquidar. La clave aislada del proveedor es Progression:Season:Studio:v1. No se inició ninguna temporada automáticamente.

**Límite deliberado:** InMemory vive en un solo servidor. No se declara implementada/validada la operación global en servidores de producción. Para habilitarla hacen falta un proveedor compartido aprobado, propiedad transaccional de perfiles, coordinación global y pruebas entre servidores. Ese trabajo y Premium quedan para una fase posterior, sin escrituras cloud en esta tarea.

## Catálogos y recompensas

src/shared/Progression/Passes/TestSeason.luau contiene los 30 premios aprobados: 10.350 Coins, 6 unidades de Slap y 6 efectos. Los efectos ya poseídos compensan 500/750/1500/3000 Coins según la recompensa. Cada premio se entrega junto con su marcador de reclamo en un commit runtime sin yield y bajo el lock existente de Shop. Repetir Reclamar o Reclamar todo no duplica unidades ni saldo. Al vencer la temporada se rechazan reclamos pendientes.

Las unidades de Slap tienen identidad determinista por edición/jugador/etapa y Origin=BattlePass. No se modificó la política existente de trade ni se habilitaron transferencias. La procedencia BattlePass no se hace comerciable automáticamente por esta implementación.

Para agregar otro tema: crear un ModuleScript hermano de TestSeason con el mismo contrato e incluir su nombre en PassManifest. PassCatalog requiere únicamente esos módulos autorizados, rechaza IDs/módulos duplicados y valida la estructura. El panel obtiene las opciones desde ese catálogo; no hay una lista adicional en el controlador cliente. Solo el pase de prueba está registrado actualmente; no se inventaron recompensas de Halloween/Navidad/etc.

## Perfiles e interfaz

Progression, con Schema=1, se incorpora de forma aditiva a la validación, carga, snapshot y guardado del perfil existente. Se conservan nombres de DataStore y claves Player_<id>. Los recibos de partidas están acotados a 128; un watermark evita volver a acreditar recibos antiguos eliminados del historial. El ciclo actual sigue siendo insuficiente para prometer transacciones durables de comercio en producción, por eso el bloqueo de entorno.

El nivel del NameTag ahora lee el atributo Level calculado en el servidor. StarterGui.ProgressionHUD contiene barra de nivel/EXP, botón PASE, galería horizontal de etapas, contador, estados de premio, Reclamar todo y avisos de EXP. Se integró con WindowNavigationController para ocultar/restaurar ventanas. En un entorno bloqueado no aparece el acceso al pase.

## Frost y Void de punto

La integración detectó que estaban definidos en el catálogo pero no tenían recursos físicos. Con autorización posterior se crearon:

- ServerStorage.PointEffects.Frost.
- ServerStorage.PointEffects.Void.

Son Models con Origin, VFX, cinco emisores por efecto, luz, columna Beam y SFX. Partes transparentes/ancladas y sin colisiones/contactos/consultas; emisores apagados y Rate=0 en la plantilla. Usan texturas integradas de Roblox y sonidos ya referenciados por Inferno, sin modificar ese recurso original. Se registraron explícitamente para reutilizar BasicController, cuya coreografía es por atributos. No se cambiaron marcador ni física de celebración del gol.

Se exportaron a src/assets/ProgressionV1/Frost.rbxm y Void.rbxm y se mapearon en ambos proyectos con preservación de otros efectos desconocidos. La disponibilidad de los 30 premios se comprueba antes de iniciar/reiniciar y al entregar, para no prometer recursos faltantes.

## Evidencias y límites

| Verificación | Resultado |
| --- | --- |
| Modelo de EXP, niveles, elegibilidad, ediciones y premios | 508 aserciones PASS |
| Métodos reales de ProgressionService con identidades simuladas y proveedor separado | 29 PASS |
| PlayerDataService: migración, guardado y recarga InMemory | 11 PASS |
| Recursos Frost/Void y registro de controller | 86 PASS |
| PlayerService: commit y snapshot con identidad de tabla | 7 PASS |
| Presentación del nivel del NameTag | 5 PASS |
| Regresión de inventario/equipamiento existente | 271 PASS |
| Total aislado | **917 PASS** |
| Compilación Luau de fuentes | 205 scripts PASS |
| Rojo default y seguro | PASS |
| Jerarquías dentro de ambos builds | PASS |
| git diff --check | PASS |
| SHA-256 Source y editor en Studio | 18/18 coincidentes |
| Vista del pase y panel admin en Edit | Capturas revisadas; previews retiradas |
| Gameplay, replicación real del nivel, AFK y dos clientes | NOT RUN |
| Reproducción animada/audio de nuevos efectos en partido | NOT RUN |
| Global entre servidores de producción/Premium | BLOCKED, fuera de esta habilitación de prueba |

Las pruebas de servicio usan métodos reales pero jugadores/proveedores aislados. No equivalen a partidas ni validan comportamiento multijugador. La creación de Player sintético no está permitida por las capacidades del entorno; esa comprobación se realizó con identidad de tabla y la replicación de atributos quedó para el desarrollador. No se cambiaron capacidades para eludir esa restricción.

Los únicos GetAsync/UpdateAsync ejecutados por las pruebas usaron instancias nuevas de InMemory. No hubo DataStoreService, publicaciones, commits ni push. No se inició ni detuvo Play/Run/Start Server ni se controlaron personajes. Se preservaron cambios locales y del lugar; respaldo: tests/assets/backups/ProgressionV1/.

## Prueba manual del desarrollador

1. Iniciar una prueba nueva. Confirmar Output: Studio / InMemory / WritesToCloud=false y `[Progression] Ready`.
2. Con el administrador 1522376993, abrir ADMIN → TEMPORADAS. Seleccionar pase de prueba, duración 60, INICIAR y CONFIRMAR INICIO. Los demás clientes deben ver el mismo pase y contador.
3. Completar una partida con al menos 60 segundos Playing y participación válida. Comprobar desglose 40/+40/+15/+10, barra y nivel del NameTag. Repetir una partida corta y una sin participación: cero EXP y motivo visible.
4. Verificar abandono, reinicio de ronda y segunda partida: sin duplicados ni EXP de partidas anteriores.
5. Al alcanzar etapas, reclamar una y luego Reclamar todo; repetir clics. Verificar saldo, unidades de Slap y efectos en inventario; comprobar compensación si el efecto ya se posee.
6. ADMIN → REINICIAR → confirmar: todos deben ver pase a cero, nivel y premios entregados intactos. ADMIN → FINALIZAR → confirmar: premios pendientes inaccesibles.
7. Equipar Frost/Void de punto desde inventario y anotar para validar sus VFX/SFX. Revisar también retorno al lobby, móvil y navegación entre ventanas.

**Atajo opcional para probar premios/UI sin jugar hasta etapa 30:** ejecutar manualmente el contenido de tests/ProgressionV1.studio-manual-fixture.luau en Command Bar del SERVIDOR, después de iniciar la edición. Está limitado al administrador aprobado, lobby, Studio/InMemory y pase de prueba. Desbloquea 24.000 EXP de prueba sin reclamar premios automáticamente. No se ejecutó durante esta tarea y NO valida ganar EXP por gameplay. Reiniciar Play permite hacer después una prueba limpia.

No habilitar producción ni compras Premium con esta versión. Esperar validación del desarrollador antes de ampliar el alcance.
