# Persistencia de la experiencia privada — V1

Destino autorizado por el propietario: Universe **10769217377**, Place observado **107328891970677**. No se publicó ni se ejecutó Play/Run/Start Server. Las pruebas utilizaron proveedores inyectados en memoria; **cloud real todavía NOT RUN**.

## Configuración y datos protegidos

| Contexto | Proveedor | Escrituras cloud |
|---|---|---|
| Cualquier Studio | InMemory | false |
| Servidor publicado del Universe aprobado | RobloxDataStore | true |
| Otro Universe o inicialización fallida | Bloqueado | false |

Se conserva el nombre existente `SlapDuels_PlayerData_v1`, con claves `Player_<UserId>`. No se renombraron perfiles ni se borró ningún dato. Versión del perfil elevada de 2 a **3**, mediante migración aditiva: las versiones anteriores del escritor rechazan perfiles con versión superior, evitando un rollback inseguro.

Un perfil conserva Coins, Wins, Losses, Kills, rachas, EXP permanente, edición/EXP/reclamos del pase, Owned/Equipped de Slaps/Abilities/PointEffects/DeathEffects, unidades individuales de Slaps, cantidades de cajas, journal de aperturas y campos de recibos existentes. Se añadieron preferencias de música activada/volumen, validadas en servidor.

Se corrigió `snapshotInventory`, que antes copiaba solo Owned y Equipped y descartaba los datos extendidos al guardar. Los snapshots son ahora copias profundas, no referencias susceptibles de mutaciones durante un yield.

## Ciclo del perfil publicado

- Adquisición exclusiva con UpdateAsync y GUID de sesión, lease de 180 segundos.
- Un servidor diferente no puede cargar un perfil con lease vigente. Una reconexión debe esperar a que termine el guardado/liberación anterior; si el servidor cae, el lease puede expirar.
- Cola de guardado por jugador. Captura del estado después de obtener la cola, no antes de esperar otro guardado.
- Autosave con jitter cada 45–55 segundos y guardado final/liberación en PlayerRemoving y BindToClose.
- Escrituras con ID de operación. Ante resultado desconocido se conserva la operación y se reintenta exactamente ese payload antes de guardar datos posteriores.
- Un escritor anterior no puede sobrescribir al servidor que tomó el perfil. Ante pérdida de propiedad se bloquean las transacciones; el autosave expulsa al jugador si no conserva una sesión válida.
- Fallos de carga en producción impiden jugar con un perfil ficticio que luego sobrescriba datos reales.
- Compras con Coins, commits de cajas y EXP/reclamos usan checkpoint productivo. Recompensa y marca de reclamo se escriben juntas en la misma clave. No se informa éxito si el checkpoint no quedó confirmado: `PersistencePending` conserva el estado pendiente para reintento, sin una compensación insegura ni liberar reservas tras resultado desconocido.
- Recompensas habituales de gameplay, equipamiento, grants administrativos y preferencias se conservan mediante autosave/salida. Un cierre abrupto puede perder cambios posteriores al último checkpoint confirmado; no se promete durabilidad instantánea de cada golpe o ajuste del slider.

## Pase global

La definición y edición activas se almacenan en `Progression:Season:Production:v1` del mismo proveedor aprobado. No se reutiliza la clave Studio. Lecturas de control sin caché; cada servidor consulta con jitter cada 15–20 segundos y antes de reclamar/administrar/liquidar EXP.

El catálogo **Temporada inaugural** reutiliza las 30 recompensas gratuitas probadas: 800 EXP por etapa, con duración elegida por Admin. Sus 30 recursos fueron encontrados en Studio Edit. No se inicia automáticamente en producción. Los catálogos StudioOnly no se pueden activar en producción.

Iniciar/reiniciar/finalizar requiere autorización server-side y confirmación con revisión esperada. Un comando administrativo viejo no reemplaza una edición creada desde otro servidor. Un reinicio conserva nivel permanente y premios entregados; progreso y premios pendientes pertenecen a la edición anterior y dejan de estar disponibles. Los reclamos se validan contra la edición activa al comenzar su transacción; una entrega ya iniciada no se revierte al cambiar de edición.

## Cajas y alcance comercial

El catálogo actual tiene suministro ilimitado. Se habilitó un adaptador productivo para ese contrato: sus unidades y operaciones viven de forma duradera en los perfiles, no en un stock ficticio por servidor. Reintentos mantienen UnitId y OperationId; cargar el perfil reconcilia operaciones GrantCommitted sin volver a sortear.

Se conservan las restricciones de PolicyService, los precios/probabilidades aprobados y las cantidades x1/x5/x10. Una configuración futura de suministro limitado bloqueará el catálogo hasta tener un backend global adecuado; no se lo simula con memoria local.

**No habilitado por esta entrega:** compras reales con Robux, Premium del pase, recibos offline ni commit de trade entre dos perfiles. Los interruptores anteriores se mantienen cerrados. Implementar durabilidad de un perfil no equivale a una transacción atómica entre dos jugadores ni a una integración comercial completa. El trade requiere su protocolo de recuperación propio; los productos de Robux requieren backend de recibos e IDs verificados. No se deben abrir al público todavía.

El journal de cajas conserva el límite existente de 256 operaciones por perfil, con rechazo al alcanzar capacidad. No se borraron entradas para aparentar capacidad ilimitada; antes de uso público prolongado requiere compactación y anti-replay diseñados juntos.

## Evidencia automatizada

| Prueba | Resultado |
|---|---|
| Nuevo motor de sesiones: exclusión entre servidores, reconexión, lease expirado, rechazo de escritor viejo, retries ambiguos, snapshots | PASS — 24 aserciones |
| Servicios reales con ruta Production simulada y proveedor inyectado: perfil, inventario extendido, preferencias, reclamos y CAS de temporada entre dos servicios | PASS — 27 aserciones |
| Modelo de progresión y reclamos existente | PASS — 508 aserciones |
| Integración anterior de ProgressionService en Studio | PASS — 29 aserciones |
| PlayerDataService guardar/recuperar anterior | PASS — 11 aserciones |
| PlayerService commit/snapshot anterior | PASS — 7 aserciones |
| Inicio automático Studio | PASS — 8 aserciones |
| Presentación/privacidad/indicador del pase | PASS — 19 aserciones |
| Total | **633 aserciones aisladas** |
| Todos los scripts src | Compilación Luau — 209 scripts |
| default.project.json y studio-safe.project.json | Rojo build PASS |
| git diff --check | PASS |

La prueba de presentación detectó que el botón del pase fue rediseñado como ImageButton y ya no tenía ClaimDot. Se restauró solo el indicador rojo, conservando el botón y sus imágenes/propiedades. No se sustituyó su diseño por el JSON anterior. Los builds no certifican equivalencia visual con todos los cambios físicos que el propietario haya hecho en Studio: publicar el lugar vigente de Studio preserva esos cambios.

## Prueba manual publicada (todavía NOT RUN)

1. Guardar el lugar actual y publicar **esta misma experiencia privada**, verificando el destino. No habilitar acceso de Studio a APIs para probar la nube.
2. Entrar desde Roblox. En F9 → servidor deben aparecer `PersistenceEnvironment=Production PersistenceProvider=RobloxDataStore WritesToCloud=true` y `[ProfilePersistence] Loaded UserId=1522376993 fenced=true`.
3. Abrir Admin → Temporadas → Temporada inaugural. Elegir días, Iniciar y Confirmar. Salir y volver: misma edición y fecha de fin, sin reinicio automático.
4. Obtener Coins, Slaps, efectos y habilidades; equiparlos; comprar/abrir cajas. Registrar inventario, unidades y saldos antes de salir. Esperar a que termine cada respuesta transaccional.
5. Completar una partida válida de al menos 60 s con participación. Revisar nivel/EXP y etapa del pase; reclamar una recompensa. Repetir el reclamo: no se duplica.
6. Cambiar música/volumen y esperar un segundo. Salir normalmente, volver desde Roblox y comparar todos los datos.
7. Revisar `[ProfilePersistence] Saved ... release=true` al salir. Un cierre abrupto tiene la ventana de autosave descrita arriba.
8. Con testers, validar otra instancia de servidor y comprobar propagación del pase en hasta 20 s. Probar conflicto de dos confirmaciones administrativas, reconexión rápida y caída de conexión.
9. Probar finalizar/reiniciar el pase: nivel y premios entregados permanecen; el nuevo pase parte de cero. Premium/Robux/trade deben seguir rechazando operaciones no habilitadas.
10. Capturar Output/F9 ante cualquier `Save pending`, `Load rejected`, `PersistencePending`, error de servicio o diferencia de datos. No considerar cloud validada solo por los tests simulados.

No realizar todavía reset de datos ni rollback a escritores anteriores a esta versión. Un eventual reset de tus datos de prueba se hará aparte, con servidores detenidos y una solicitud explícita.

## Recuperación y archivos

Respaldo de archivos intervenidos: `tests/assets/backups/CloudPersistenceV1/20261024-180420`. El respaldo principal corresponde al estado previo; las copias adicionales de Types y Config se identifican en su manifiesto final. No es un nuevo respaldo integral de todo el repositorio ni reemplaza el respaldo integral anterior.

Hashes finales: `tests/CloudPersistenceV1.source-hashes.json`. Las fuentes instaladas y los documentos abiertos en ScriptEditor fueron comparados con los hashes locales. Builds: `tests/CloudPersistenceV1.rbxlx` y `tests/CloudPersistenceV1.safe.rbxlx`.

No hubo commit, push, publicación ni reset. Ningún test consultó o escribió DataStoreService real.
