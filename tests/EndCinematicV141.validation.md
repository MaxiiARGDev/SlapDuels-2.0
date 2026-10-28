# End Cinematic V1.4.1 — entrega y validación manual

Actualización posterior: instalación física completada y verificada mediante MCP en Edit
con nueva autorización del usuario. Ver EndCinematicV141.edit-installation.md.
Las pruebas de Play/Run y el guardado local del lugar siguen pendientes del desarrollador.
El informe siguiente conserva el estado histórico anterior a esa instalación.

Estado: **implementación de repositorio lista; instalación física y validación Studio PENDIENTES del desarrollador**.
No se abrió Play/Run, no se ejecutaron scripts ni pruebas en Studio y no se alteró su estado.
La regla permanente es que el desarrollador ejecuta todas las pruebas de Studio.
Maps vacío fue intencional: no se investigó, corrigió ni se considera un defecto de esta entrega.
Este documento reemplaza esa interpretación del bloqueo anotado en el informe histórico V1.4.

## Informe técnico (16 puntos)

1. **Arquitectura anterior.** EndCinematicBillboards clonaba
   ReplicatedStorage.UIAssets.EndCinematicBillboardTemplate por rig, lo parentaba al avatar,
   asignaba Adornee a Head/PrimaryPart y sobreescribía dimensiones, offset y estilo.
   Al limpiar destruía esas interfaces. La plantilla visual ya existía como .rbxmx.
2. **Arquitectura nueva.** El módulo recibe run.Scene mediante el contexto existente del controller.
   Resuelve Players/SlotPlayer_1..5/BillboardAnchor/BillboardGui/MainFrame.
   Cada anchor debe ser Part; cada slot, BasePart; MainFrame conserva CanvasGroup.
   No crea ni clona interfaces, no las parenta a rigs y no cambia CFrame, Adornee ni offsets.
3. **Persistencia.** default.project.json no contiene la ruta de ScenarioFinal:
   Rojo no administra esa escena física. La ubicación prevista sigue siendo
   ServerStorage["EndGames-Scenario"].ScenarioFinal, guardada por el desarrollador en su lugar.
   El nuevo recurso versionable src/ui/EndCinematicBillboardAnchor.rbxmx se sincroniza como
   ReplicatedStorage.UIAssets.EndCinematicBillboardAnchor. Es una fuente de instalación, no un fallback runtime.
   Rojo build por sí solo NO exporta ni respalda el ScenarioFinal artístico del lugar.
4. **Creación.** Los cinco anchors NO se instalaron automáticamente.
   El instalador manual está listo y exige Studio Edit. Valida conflictos antes de añadir;
   solo añade subárboles ausentes, conserva propiedades y posiciones existentes, y ante fallo revierte
   únicamente sus propias adiciones. Una clase incorrecta o nombres duplicados abortan.
   La existencia actual de anchors en el lugar no se verificó mediante herramientas de Studio.
5. **Diseño.** El recurso deriva del XML V1.4, conservando tipografías, etiquetas, canvas 196x108,
   colores, UIGridLayout, UICorner, UIStroke y UIScale. Se trasladó el soporte al Part:
   GUI de 3.4x1.874 studs, offset mundial cero, Enabled=false. Los anchors nuevos reciben
   una posición inicial slot.CFrame + Vector3(0,7.1,0), SOLO durante instalación.
   Esa altura es una semilla editable, pendiente de ajuste artístico manual; no se sigue al avatar.
   El módulo conserva dimensiones, posición, distancia, fondo y estilos del recurso físico.
   UIScale adapta el canvas existente al tamaño proyectado del GUI mediante eventos de tamaño,
   sin modificar el layout ni usar un bucle por frame. Se restaura al limpiar.
   DynamicColors=false permite conservar también los colores artísticos de rango/equipo/borde.
6. **Módulo.** Valida clases/rutas, propiedades seguras del Part y Adornee nulo o el propio anchor.
   Falta de recursos produce PhysicalResourceMissingOrInvalid con ruta y clase esperada,
   sin interfaz alternativa. Se conservan los nombres reales: MatchPointsLabel, Username,
   TeamLabel y PreviewLabel, además de RankLabel, PlayerName, MVPLabel y las otras estadísticas.
   MatchPointsLabel representa PointsLabel del pedido; no se renombró el recurso funcional.
7. **Asignación.** entry.Participant.CinematicSlot selecciona exactamente SlotPlayer_N;
   el rango competitivo no determina el anchor. Slots fuera de 1..5 o duplicados se rechazan.
   Una entrada sin Participant no ocupa slot ni hereda datos; nombre ausente usa su propio UserId.
   Estadística ausente se oculta, cero sí se presenta.
8. **Transformación.** _populateCinematicScene ya clona recursivamente la escena y aplica
   delta * object.CFrame a cada BasePart una sola vez. Los anchors anidados entran en ese recorrido:
   mover el padre BasePart por CFrame no transforma por segunda vez sus hijos BasePart.
   No se añadió PivotTo ni un segundo desplazamiento. Preview utiliza el mismo método con identidad.
9. **Visibilidad/limpieza.** El servidor fuerza Enabled=false en los GUI hijos de BillboardAnchor
   antes de parentar la escena clonada. Solo el cliente autorizado activa los slots ocupados.
   El módulo valida escena en Workspace, identidad del contexto y SessionId real o propietario
   de preview Studio. Conserva los controles existentes de Token/StateVersion/PlaybackId del controller.
   La propiedad local por reproducción impide limpiar interfaces apropiadas por otra reproducción.
   Cleanup cancela sus tweens/conexiones, oculta los cinco GUI, borra textos de participante/estadísticas
   y restaura colores/transparencia/escala; no destruye anchors ni GUI físicos.
   El destructor existente de la sesión continúa eliminando su escena clonada completa.
10. **Ranking/MVP.** Se consume el snapshot existente sin recalcularlo ni modificar sus reglas.
    Ranking completo y selección visible de hasta cinco participantes se conservan.
    ShowIn1v1=false sigue ocultando billboards en 1v1. Preview y partida usan el mismo módulo.
    No se modificaron cámaras, FloatingFollow, música, Whoosh, transición ni puntuación.
11. **Archivos de esta entrega.**
    - src/client/EndCinematic/Modules/EndCinematicBillboards.luau
    - src/shared/EndCinematicConfig.luau (solo opciones de billboards)
    - src/server/Services/MatchInstanceService.luau (solo desactivación inicial de GUI clonados)
    - default.project.json (fuente de anchor)
    - src/ui/EndCinematicBillboardAnchor.rbxmx (nuevo)
    - tests/InstallEndCinematicBillboardsV141.commandbar.luau (nuevo, ejecución manual)
    - tests/EndCinematicV141.validation.md (este informe)
    Los cambios locales anteriores siguen presentes. La plantilla V1.4 original no se reemplazó.
12. **rojo build — PASS estático.** Comando:
    rojo build default.project.json --output "$env:TEMP/SlapDuels-EndCinematic-V141.rbxlx".
    Exit 0: Building project 'SlapDuels-2.0'; Built project to SlapDuels-EndCinematic-V141.rbxlx.
    La compilación verifica empaquetado/rutas; no prueba ejecución Luau ni incluye la escena artística no mapeada.
13. **git diff --check — PASS estático.** git -c core.safecrlf=false diff --check,
    exit 0, sin salida. core.safecrlf=false solo evita avisos de conversión de finales de línea.
    Git no incluye archivos no rastreados en diff; esos recursos se revisaron directamente.
    Los primeros intentos de ambos comandos fallaron por restricciones del sandbox;
    la repetición con acceso autorizado terminó correctamente.
14. **Pruebas pendientes.** Toda la matriz Studio de abajo está PENDIENTE manual.
    Hasta instalar/guardar los recursos, las previews con la estructura incompleta quedan BLOCKED
    por recurso físico faltante. No se trasladan los PASS históricos de V1.4 a V1.4.1.
15. **Guía precisa.** Seguir instalación y pasos A–M a continuación.
16. **Límites.** Sin commits, push, publicación, escrituras cloud, cambios de persistencia,
    habilitación de modalidades, aumento de concurrencia, matchmaking ni Shared Team Spawns.
    No se borró Workspace.EndCinematic ni se tocó el respaldo externo. No se inicia otra fase.

## Instalación manual persistente (antes de Play)

1. En Studio, detener cualquier ejecución y permanecer en Edit. Guardar una copia LOCAL del lugar
   con Archivo > Guardar en archivo como, antes de instalar. No publicar.
2. Sincronizar el código y UIAssets con Rojo mediante el flujo habitual.
   Verificar ReplicatedStorage/UIAssets/EndCinematicBillboardAnchor (Part).
   Alternativa independiente de Rojo: insertar src/ui/EndCinematicBillboardAnchor.rbxmx desde archivo
   en ReplicatedStorage. El Part importado se llama BillboardAnchor: seleccionarlo SOLO a él
   en Explorer antes de ejecutar el instalador. No necesita UIAssets ni renombrarlo para esta vía.
   La selección explícita de una plantilla externa a ScenarioFinal tiene prioridad sobre la ruta Rojo.
3. Abrir View/Vista > Command Bar/Barra de comandos. Copiar el contenido completo de
   tests/InstallEndCinematicBillboardsV141.commandbar.luau y ejecutarlo UNA vez en Edit.
   No ejecutar el archivo como Script durante Play.
4. Esperar el mensaje "[EndCinematic V1.4.1] Additions applied" y las cinco rutas impresas.
   Revisar Explorer y propiedades según A–D. Una segunda ejecución sin faltantes debe informar
   added subtrees: 0; no debería mover anchors ni sobrescribir etiquetas.
   Ese mensaje no constituye aprobación de instalación: falta confirmar visualmente los cinco anchors.
5. Guardar el lugar LOCAL después de ajustar el diseño. Cerrar y reabrir esa copia guardada,
   y verificar que siguen los cinco anchors: esa es la comprobación de persistencia.
   Mantener la copia previa hasta aprobar la entrega. Rojo no guarda esos cambios artísticos por sí solo.

## Guía manual A–M

A. Explorer > ServerStorage > EndGames-Scenario > ScenarioFinal > Players.
   Expandir SlotPlayer_1 a SlotPlayer_5. No usar Workspace.EndCinematic como plantilla.
B. Cada slot debe tener UN BillboardAnchor (Part), con UN BillboardGui (BillboardGui);
   este contiene MainFrame (CanvasGroup) y la jerarquía listada en el punto 6.
C. Properties del anchor: Anchored=true, Transparency=1, CanCollide=false, CanTouch=false,
   CanQuery=false y CastShadow=false. GUI: Enabled=false al guardar, Adornee vacío o el propio
   anchor, StudsOffset y StudsOffsetWorldSpace cero. Size, MaxDistance y estilo se editan allí.
D. En Edit, seleccionar SOLO SlotPlayer_2/BillboardAnchor, activar Move y desplazarlo,
   por ejemplo +1 stud en X. Registrar su CFrame antes/después. No mover SlotPlayer_2.
   Para ver el diseño en Edit si el GUI no se renderiza en ServerStorage, copiar temporalmente
   el anchor a Workspace, habilitar su GUI, editarlo allí y transferir SOLO los ajustes artísticos
   al anchor persistente; eliminar únicamente esa copia temporal propia y guardar Enabled=false.
E. El desarrollador inicia Play manualmente. Antes de preview, verificar Output/atributos del servidor:
   PersistenceEnvironment=Studio, PersistenceProvider=InMemory y WritesToCloud=false.
   Si difieren, detener la prueba. En el panel existente, pulsar PREVIEW · 1v1;
   comprobar cinemática, FloatingFollow y retorno. Billboards ocultos en este modo por ShowIn1v1=false.
F. Pulsar PREVIEW · 2v2; esperar resultados. Repetir con PREVIEW · 3v3 y PREVIEW · XvX (5).
   Son previews de presentación; no habilitan modalidades competitivas.
G. En Explorer del CLIENTE, abrir Workspace/EndCinematicPreviews/Preview_<UserId>_<guid>/Players.
   Comparar por CinematicSlot los nombres/rangos/GOLES/KILLS/BAJAS con las filas de demostración
   de EndCinematicPreview.client.luau y su orden de EndCinematicRanking.
   Verificar MVP del ranking global y distintivo DATOS DE PREVIEW. MatchPoints ausente
   debe permanecer oculto. 3v3 conserva seis filas de ranking y como máximo cinco representaciones;
   XvX(5) conserva diez filas y como máximo cinco representaciones.
H. Iniciar otra preview y observar el desplazamiento del avatar: el Part no debe acompañarlo.
   Registrar CFrame del anchor del clon al inicio y al final de la caminata: debe ser idéntico.
   El cambio +1 X del paso D debe mantenerse. La orientación visual del BillboardGui hacia cámara
   y el movimiento de FloatingFollow no implican movimiento del Part.
I. En 2v2 deben activarse los cuatro slots ocupados y el quinto quedar Disabled con textos
   de datos vacíos. En 1v1 todos ocultos por configuración. No confundir slot competitivo con CinematicSlot.
J. Usar DETENER durante entrada, durante fade y durante resultados; comprobar cámara/HUD restaurados,
   ausencia de rigs locales y de la escena Preview propia. Repetir usando retorno del HUD.
   Usar Stop de Studio: el lugar en Edit conserva la plantilla y sus cinco anchors.
K. Hacer 3v3, DETENER y luego 2v2: el quinto slot no conserva nombre ni estadísticas.
   Alternar BILLBOARDS OFF/ON: reaparecen los ocupados, sin duplicados y con sus mismos CFrames.
   Alternar FloatingFollow solo para comprobar compatibilidad del comportamiento existente.
L. Si falta un anchor o un hijo, en Edit repetir el instalador: añade únicamente lo ausente.
   Un anchor existente conserva su posición; si faltaba el Part completo, reajustar la nueva semilla.
   Para clases incorrectas/duplicados, corregir manualmente el objeto señalado conservando una copia;
   no borrar ScenarioFinal ni reemplazar cámaras/slots/efectos. Recuperar arte propio desde la copia local.
   Para comprobar el diagnóstico sin pérdida, renombrar temporalmente un GUI en una COPIA del lugar,
   ejecutar preview manual y esperar error claro sin GUI alternativo; restaurar el nombre al terminar.
M. Ante fallo, copiar Output completo de cliente y servidor con stack trace, modo/botón/secuencia,
   captura de Explorer de la plantilla y del clon, clases/Enabled/Adornee/CFrame de los anchors,
   SessionId o PreviewOwnerUserId y estado de Workspace.ActiveMatches/EndCinematicPreviews.
   Anotar si ocurrió antes/después de DETENER o de una segunda preview. No incluir secretos.

## Matriz para completar por el desarrollador

| Comprobación | Resultado actual | Evidencia requerida |
|---|---|---|
| Rutas y empaquetado Rojo | PASS estático | Build exit 0 |
| Espacios del diff rastreado | PASS estático | Diff check exit 0 |
| Instalación aditiva, segunda ejecución sin cambios | PENDIENTE manual | Output del instalador + Explorer |
| Persistencia tras guardar/reabrir | PENDIENTE manual | Cinco anchors en Edit |
| Propiedades, independencia y diseño editable | PENDIENTE manual | A–D, CFrames y captura |
| Proveedor seguro antes de Play | PENDIENTE manual | E, Output/atributos |
| Preview 1v1 / 2v2 / 3v3 / XvX | PENDIENTE manual | E–G, Output por modo |
| Ranking, MVP, estadísticas y datos ausentes | PENDIENTE manual | G, datos esperados/observados |
| Anchor fijo durante caminata | PENDIENTE manual | H, dos CFrames iguales |
| Slots vacíos sin datos anteriores | PENDIENTE manual | I y K |
| Cancelación, retorno, Stop y toggles | PENDIENTE manual | J–K, recursos antes/después |
| Diagnóstico por recursos faltantes y reparación | PENDIENTE manual | L–M |
| Partida real: ArenaTransform único, limpieza y cliente ajeno sin billboards | PENDIENTE manual | CFrame clon = ArenaTransform * CFrame plantilla; Output servidor/cliente |

No hay PASS de Studio en esta entrega. No se ejecutaron suites Luau.
