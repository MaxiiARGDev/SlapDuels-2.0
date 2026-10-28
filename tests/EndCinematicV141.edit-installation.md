# EndCinematic V1.4.1 — instalación MCP en Edit

Instalación física realizada y verificada mediante MCP en el DataModel **Edit** de
SlapDuels 2.0 [EVENTOS DE HALLOWEEN], PlaceId 107328891970677.
No se inició Play, Run, Start Server ni se ejecutaron pruebas de jugabilidad.

El usuario aclaró el protocolo permanente: el agente implementa código y objetos físicos
mediante MCP en Edit; el desarrollador ejecuta Play/Run, simulaciones y pruebas de jugabilidad.
Esta autorización reemplaza la interpretación anterior que impedía al agente instalar objetos en Edit.

## Ubicación exacta

- game.ServerStorage["EndGames-Scenario"].ScenarioFinal.Players.SlotPlayer_1.BillboardAnchor
- game.ServerStorage["EndGames-Scenario"].ScenarioFinal.Players.SlotPlayer_2.BillboardAnchor
- game.ServerStorage["EndGames-Scenario"].ScenarioFinal.Players.SlotPlayer_3.BillboardAnchor
- game.ServerStorage["EndGames-Scenario"].ScenarioFinal.Players.SlotPlayer_4.BillboardAnchor
- game.ServerStorage["EndGames-Scenario"].ScenarioFinal.Players.SlotPlayer_5.BillboardAnchor

Cada Part contiene un BillboardGui llamado BillboardGui, inicialmente Disabled, con Adornee vacío.
Los Parts tienen Anchored=true, Transparency=1, CanCollide=false, CanTouch=false,
CanQuery=false, CastShadow=false y Size=(1,1,1).
Cada CFrame inicial corresponde a su slot con +7.1 studs en Y mundial, conservando su orientación.
No hay reposicionamiento continuo ni unión al avatar. Las posiciones artísticas quedan editables.

## Diseño y componentes verificados

Se clonó directamente ReplicatedStorage.UIAssets.EndCinematicBillboardTemplate,
la plantilla física V1.4 ya existente, sin reconstruir sus etiquetas.
Solo se ajustaron nombre del GUI, tamaño mundial 3.4x1.874 y offsets a cero,
como en el recurso preparado src/ui/EndCinematicBillboardAnchor.rbxmx.
No se alteró la plantilla fuente ni se crearon plantillas auxiliares.

Cada BillboardGui tiene los mismos 16 descendientes:

- MainFrame (CanvasGroup).
- RankLabel, PlayerName, Username, TeamLabel, MVPLabel, PreviewLabel (TextLabel).
- StatsFrame (Frame), con GoalsLabel, KillsLabel, DeathsLabel y MatchPointsLabel (TextLabel).
- UIGridLayout dentro de StatsFrame.
- UICorner, UIStroke y UIScale dentro de MainFrame.

MatchPointsLabel conserva el nombre real esperado por EndCinematicBillboards; representa PUNTOS.
La inspección comparó clases, tamaños, posiciones, fondos, visibilidad, orden,
AnchorPoint, texto, tipografía, colores, tamaños de letra, bordes, esquinas, escala y grid
contra la plantilla fuente. Coinciden en los cinco GUI.

## Evidencia de Edit y preservación

- get_studio_state: Current Studio Mode: Edit; Available DataModels: Edit.
- Cada operación exigió RunService:IsRunning()==false y utilizó datamodel_type=Edit.
- Inspección independiente posterior: AnchorCount=5, GuiCount=5.
- Un anchor por slot y un BillboardGui por anchor; sin nodos visuales adicionales.
- Se registraron antes/después los 47 descendientes preexistentes de ScenarioFinal.
  Coinciden las rutas, clases, atributos y, para Parts, CFrame, Size, Anchored,
  CanCollide, CanTouch, CanQuery y Transparency. Cámaras y slots conservados.
- No se crearon recursos temporales dentro del DataModel.
- Los cinco anchors quedaron seleccionados para facilitar su ubicación en Explorer.

La instalación vive en el modelo editable del lugar abierto, no en una sesión de Play
ni en scripts que necesiten ejecutarse al comenzar una partida.
**No se cerró, guardó ni sobrescribió el lugar para preservar los cambios no guardados del usuario.**
El guardado local en disco y la comprobación tras reabrir quedan pendientes del desarrollador.
Rojo no administra ScenarioFinal y no sustituye ese guardado local.

## Comprobaciones estáticas

rojo build default.project.json --output "$env:TEMP/SlapDuels-EndCinematic-V141-edit-install.rbxlx"
y git -c core.safecrlf=false diff --check: PASS estático, exit 0.
No son pruebas de ejecución de la cinemática.

## Preview manual del desarrollador

1. En Edit, revisar los cinco anchors seleccionados y guardar una copia local del lugar
   que conserve también tus cambios artísticos. No publicar.
2. Iniciar Play manualmente y comprobar el proveedor Studio/InMemory y WritesToCloud=false.
3. Pulsar PREVIEW · 2v2. Esperar resultados: cuatro billboards ocupados y quinto oculto.
   Revisar ranking, nombre, MVP y GOLES/KILLS/BAJAS. PUNTOS se oculta si el dato no existe.
4. Usar DETENER, luego PREVIEW · 3v3 y PREVIEW · XvX (5): como máximo cinco billboards.
   Comprobar que el anchor no camina con el avatar y que reiniciar no conserva datos anteriores.
5. PREVIEW · 1v1 conserva ShowIn1v1=false: los billboards deben estar ocultos.
   Al detener Studio, los cinco anchors deben seguir en ServerStorage.

Validación visual y jugabilidad: PENDIENTE del desarrollador.
Sin commits, push, publicaciones, escrituras cloud ni modificaciones de otros sistemas.
