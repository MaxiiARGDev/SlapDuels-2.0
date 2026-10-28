# Slap Variations V1 — preview y validación del desarrollador

No se ejecutaron partidas. El agente instaló los recursos en Edit y probó el aplicador únicamente sobre clones aislados sin parent en el DataModel. La aprobación visual/jugabilidad queda pendiente.

## Rutas y edición

Perfiles: `ReplicatedStorage.SlapVariationEffects.<VariationId>`.

Previews: `ReplicatedStorage.SlapVariationPreviews.Classic.<VariationId>.Hand`.

IDs: Basic, Common, Uncommon, Rare, Gold, Arcoiris, Emote, Wings, Epic, Legendary, Blood, Galaxy.

Cada perfil tiene atributos Tint (Color3), ApplyTint, Material (nombre Enum.Material), ApplyMaterial, Intensity y DesignPending. En CosmeticOrigin.Energy se editan Color, Size, Transparency, Texture, Rate, Lifetime y Speed. Wings tiene WingLeft/WingRight; Emote incluye un BillboardGui decorativo; Rare/Epic/Legendary/Galaxy tienen PointLight tenue.

Intensity se aplica al copiar el perfil, entre 0 y 2, con máximo 24 partículas/s por emisor. No es un bucle que cambie propiedades del servidor. En la maqueta por defecto el total máximo por slap es 16/s. Basic y Common tienen emisores desactivados a Rate=0.

Attachments tienen ScaleToHand=true y NormalizedPosition de tipo Vector3. El aplicador calcula Position=Hand.Size*NormalizedPosition. Para una posición artística fija, poner ScaleToHand=false y editar Position. Un futuro Slap debe exponer su parte visual Hand; no se crean juntas ni se modifica su hitbox. Basic conserva el color y material originales de cada base.

Hit y Reveal son slots de audio VACÍOS. No se aprobó ni se inventó ningún SoundId. Hit original de Classic permanece en uso. Asignar un audio al perfil requiere aprobación; no se considera funcional un Sound vacío.

## Ver una variación en Edit

Los modelos de ReplicatedStorage son plantillas seguras, no objetos de combate ni propiedad concedida. Para ver una copia delante de la cámara de edición, ejecutar en Command Bar Edit (cambiar solo `id`):

```lua
local run = game:GetService("RunService")
assert(run:IsStudio() and not run:IsRunning(), "Solo Edit")
local id = "Galaxy"
local rs = game:GetService("ReplicatedStorage")
assert(not workspace:FindFirstChild("SlapVariationPreview_Edit"), "Ya hay una preview; conservála o retirala primero")
local model = assert(rs.SlapVariationPreviews.Classic:FindFirstChild(id)):Clone()
model.Name = "SlapVariationPreview_Edit"
model:SetAttribute("OwnedEditPreview", true)
require(rs.Shared.SlapCrates.Appearance).Apply(model.Hand, rs.SlapVariationEffects[id])
model:PivotTo(workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -8))
model.Parent = workspace
```

Podés seleccionar la copia, enfocar con F y editar el perfil original. Para refrescar la copia después de editar el perfil:

```lua
assert(not game:GetService("RunService"):IsRunning())
local rs = game:GetService("ReplicatedStorage")
local model = assert(workspace:FindFirstChild("SlapVariationPreview_Edit"))
assert(model:GetAttribute("OwnedEditPreview") == true)
require(rs.Shared.SlapCrates.Appearance).Apply(model.Hand, rs.SlapVariationEffects[model:GetAttribute("VariationId")])
```

Revisá: original neutro de Basic; plateado Common; verde/azul; Metal dorado; gradiente multicolor Arcoiris; símbolo rosa; dos focos celestes Wings; violeta Epic; aura naranja Legendary; energía roja/negra sin gore; estrellas Galaxy. La visualización de partículas en Edit depende de los controles de preview/renderizado de Studio; no requiere iniciar una partida para modificar los recursos.

Antes de ejecutar tus pruebas, retirar SOLO esa copia de preview:

```lua
assert(not game:GetService("RunService"):IsRunning())
local model = workspace:FindFirstChild("SlapVariationPreview_Edit")
if model then
    assert(model:GetAttribute("OwnedEditPreview") == true, "No borrar un recurso ajeno")
    model:Destroy()
end
```

No borrar ServerStorage.SlapVariationsV1_Backup: conserva los perfiles previos. Los modelos originales de Classic y los demás elementos del escenario se preservaron.

## Persistir cambios artísticos

Los .project.json del repositorio son la fuente de los builds. SAFE deja los assets físicos fuera de su sincronización; default los gestiona desde esos archivos. Antes de aceptar un sync de default después de editar los perfiles en Studio, sincronizar esos cambios artísticos al repositorio. No aceptar sobrescrituras de esos recursos sin revisar el diff. El agente puede realizar esa sincronización en Edit cuando se solicite.

## Prueba de juego a cargo del desarrollador

1. Confirmar Studio/InMemory/WritesToCloud=false antes de operar con perfiles. Se conserva el procedimiento de SlapCratesV1.manual.md.
2. Usar una combinación SlapId+VariationId ya poseída. No se concedieron variaciones, no se cambió stock/precio/peso ni se añadió un botón para saltar propiedad. Las cajas comerciales siguen bloqueadas; si una variación no es obtenible con el contenido de prueba aprobado, su prueba equipada queda pendiente, no se inventa una concesión.
3. Equipar la variación en lobby, entrar al combate y comprobar material/colores/partículas sobre Classic. No debe haber slot ni herramienta en mano fuera del combate.
4. Verificar Swing, sonido Hit original, knockback, ragdoll de 3 s, inmunidad de víctima durante esos 3 s, recuperación .15 acierto/.45 fallo y eliminación por tres golpes válidos.
5. Reequipar/repetir ronda: no debe duplicar partículas, luces o símbolos. Basic no conserva efectos de una skin anterior.
6. Abrir una caja de prueba autorizada: su preview 3D debe corresponder a la variación confirmada, con una sola geometría y sin duplicar efectos. El comprador conserva HUD privado y los observadores solo ven la escena local válida.
7. Evaluar rendimiento con dos clientes y varios slaps, visibilidad de hitboxes/avatares y brillo. No modificar balance para compensar un problema visual.

Enviar capturas/Output y VariationId si algo no coincide. Ninguna variación se declara aprobada funcionalmente hasta esa validación.
