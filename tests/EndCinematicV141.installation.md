# Instalación física V1.4.1 — procedimiento manual alternativo

Actualización: el usuario autorizó posteriormente la implementación MCP en Edit.
Los cinco anchors ya se instalaron y se inspeccionaron directamente en Edit.
Ver EndCinematicV141.edit-installation.md para evidencia y estado vigente.
El guardado local del lugar queda pendiente; este procedimiento se conserva para recuperación.
El texto de estado pendiente más abajo describe la entrega anterior a esa instalación.

El agente no ejecutó el instalador, Play ni pruebas en Studio.
No modificó ni borró componentes existentes de ScenarioFinal.

## Hallazgo y corrección

El recurso XML contiene un Part llamado BillboardAnchor con su BillboardGui completo.
Rojo lo publica bajo otro nombre: ReplicatedStorage.UIAssets.EndCinematicBillboardAnchor.
El instalador anterior exigía esta última ruta; una importación directa conservaba BillboardAnchor
y no satisfacía esa búsqueda sin mover/renombrar el recurso.
Además, sincronizar el recurso no instala automáticamente los cinco anchors:
ScenarioFinal no está mapeado en default.project.json.

El instalador revisado permite seleccionar explícitamente el Part importado,
sin depender de UIAssets ni de objetos creados en Play. Si no hay una plantilla seleccionada,
busca la ruta Rojo anterior. Imprime la ruta exacta de la plantilla usada.
Valida el diseño completo antes de añadir componentes. Siempre asigna BillboardAnchor como
nombre de destino, independientemente del nombre de la fuente.

El MainFrame y todos sus descendientes/propiedades del nuevo .rbxmx se compararon como XML
con EndCinematicBillboardTemplate.rbxmx: son idénticos. No se regeneró ni rediseñó la interfaz.
La diferencia exterior intencional es el soporte Part, el nombre BillboardGui, el tamaño
mundial 3.4x1.874 y el offset cero; la altura inicial está en el Part editable.

## Pasos exactos sin depender de Rojo

1. Permanecer en **Edit**, sin Play/Run. Guardar una copia local del lugar antes de instalar.
2. En Explorer seleccionar **ReplicatedStorage**. Usar **Insert from File / Insertar desde archivo**
   e importar:
   H:\repos-github\SlapDuels-2.0\src\ui\EndCinematicBillboardAnchor.rbxmx
3. Debe aparecer **ReplicatedStorage > BillboardAnchor** (Part).
   Expandirlo: debe contener **BillboardGui > MainFrame** y las etiquetas.
   Seleccionar únicamente ese **Part BillboardAnchor** importado, no uno de los SlotPlayer.
   No hace falta crear UIAssets ni cambiar su nombre.
4. Abrir este archivo local en el editor y copiar **TODO** su contenido:
   H:\repos-github\SlapDuels-2.0\tests\InstallEndCinematicBillboardsV141.commandbar.luau
   Abrir Command Bar / Barra de comandos de Studio, pegarlo completo y ejecutarlo en Edit.
   No pegar la ruta como si fuera un comando y no usar loadfile, require externo ni Script de Play.
5. Output debe indicar **Template source: ReplicatedStorage.BillboardAnchor**,
   cinco líneas **Review in Explorer** y **Additions applied**.
   El BillboardGui procede del hijo del Part importado desde el .rbxmx; se clona ese subárbol,
   no se construyen etiquetas mediante código.
6. Expandir:
   ServerStorage > EndGames-Scenario > ScenarioFinal > Players >
   SlotPlayer_1, SlotPlayer_2, SlotPlayer_3, SlotPlayer_4, SlotPlayer_5.
   Cada uno debe contener exactamente **BillboardAnchor > BillboardGui > MainFrame**.
   Confirmar manualmente los cinco en Explorer antes de considerar instalada esta entrega.
7. Cada anchor: Anchored=true, Transparency=1, CanCollide=false, CanTouch=false,
   CanQuery=false, CastShadow=false. GUI: Enabled=false y Adornee vacío.
   Son físicamente editables; para nuevas piezas la semilla inicial es 7.1 studs encima del slot.
   No se modifica el CFrame de ninguna pieza existente.
8. Guardar el lugar **localmente** después de instalar/ajustar, sin publicar.
   Cerrar y reabrir esa copia: verificar otra vez los cinco anchors.
   Los cambios de Command Bar en Edit necesitan ese guardado para persistir entre aperturas.

Si ya se sincronizó Rojo y existe ReplicatedStorage/UIAssets/EndCinematicBillboardAnchor,
puede omitirse la importación: deseleccionar todo y ejecutar el mismo archivo completo.
No hay descarga de assets, dependencia HTTP ni acceso a persistencia cloud.

El instalador solo añade lo ausente. Si ya hay un anchor conserva su CFrame y diseño;
si falta únicamente un hijo, añade ese subárbol. Clases incorrectas, propiedades inseguras
o nombres duplicados abortan sin reemplazar piezas existentes. No borra ScenarioFinal.
Ante error, enviar el Output completo y la ruta del Part seleccionado; no iniciar Play para corregirlo.

Estado final: **PENDIENTE de confirmación del desarrollador de los cinco anchors en Explorer
y de su persistencia tras guardar/reabrir**.
