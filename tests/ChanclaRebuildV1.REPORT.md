# Chancla — reconstrucción de doce variaciones

Se clonó el modelo base actualizado por el desarrollador: ServerStorage.Slaps.Slap_Chancla. La carpeta ServerStorage.SlapVariations.Chancla estaba vacía y se crearon Basic, Common, Uncommon, Rare, Gold, Arcoiris, Emote, Wings, Epic, Legendary, Blood y Galaxy.

Antes de clonar se encontró un WeldConstraint con Part0=ServerStorage.Slaps.Classic.Hand y Part1=Slap_Chancla.Handle. Se corrigió únicamente Part0 para apuntar a la propia Slap_Chancla.Hand. Sin esa corrección la base y las copias conservaban una referencia externa que impedía asegurar la unión correcta del modelo al Handle.

Se conservaron todos los demás ajustes de la base, incluidos Grip, RequiresHandle, tamaños, CFrames, piezas, uniones internas, configuración y la nueva posición artística de Hand.SlapBackAttachment. Las doce copias cambian únicamente nombre/identidad de variante, color de Hand y RarityHighlight según VariationDefinitions. Cada Highlight tiene Adornee apuntando a su propia Hand y el estilo vigente de las otras variaciones. No se modificó código de producción ni otros modelos base.

Respaldo: tests/assets/backups/ChanclaRebuildV1/. Incluye el modelo nativo antes de corregir la unión y los binarios locales previos.

Los recursos completos actualizados se exportaron por fragmentos con verificación SHA-256 a src/assets/SlapBaseToolsV3.rbxm y src/assets/SlapVariationToolsV3.rbxm, ya usados por ambos proyectos Rojo.

## Verificación

- 315 comprobaciones aisladas en Studio Edit: trece Tools, doce variaciones, piezas sin anclar, referencias de uniones internas, conectividad completa desde Handle, preservación de geometría/Grip/configuración/montaje, colores, Highlight e identidad.
- Las comparaciones de CFrame usan tolerancia 1e-5 para admitir el redondeo de precisión de Clone.
- Ambos builds Rojo PASS.
- git diff --check PASS.
- No Play, Run, control de jugadores, commits, push, publicación ni escrituras cloud.

La verificación del equipamiento real queda para el desarrollador: iniciar sesión nueva, equipar Chancla desde inventario y probar una partida/área de prueba. Confirmar que aparece en la mano, que no quedan piezas en la ubicación de edición y que al retirarla vuelve correctamente a la espalda. La inspección Edit verifica la conectividad; no sustituye esa prueba de gameplay.
