# Classic: doce variaciones completas

Instalado en Studio Edit y repositorio. No Play, Run, Start Server, personajes, publicaciones, commits, push ni escrituras cloud.

## Plantillas físicas

`ServerStorage.SlapVariations.Classic.<Id>` contiene doce Tools completos clonados de `ServerStorage.Slaps.Classic`: Basic, Common, Uncommon, Rare, Gold, Arcoiris, Emote, Wings, Epic, Legendary, Blood y Galaxy.

Únicos cambios visuales: Hand.Color según VariationDefinitions.Color y Hand.RarityHighlight. Highlight usa el mismo color en FillColor/OutlineColor, transparencias .88/.2, DepthMode=Occluded y Adornee=Hand. Arcoiris usa el blanco registrado en su rareza: no se agregó animación de color ni partículas nuevas.

Todos conservan geometría, MeshPart, MeshId/TextureID, material, tamaño, transformación, Handle, Swing, Configuration y audio originales. Se agregaron atributos de identificación y Hand.SlapVariationAuthored=true. El original Classic conserva exactamente su hash serializado previo: `16f7ac4d86c65b8e3666f7e5e155857d79aec59d8fe01b5b03ef0c2a7e5ebe8d`.

Previews completas en `ReplicatedStorage.SlapVariationPreviews.Classic.<Id>`; fallback completo en `ReplicatedStorage.CrateRewardPreviews.Classic`. Son Models que contienen todos los hijos del Tool, con las piezas ancladas y sin colisiones para presentación. No son la reconstrucción antigua de una única mano. Los efectos propios de la cinemática existente permanecen intactos.

## Equipamiento y futuras ediciones

CrateService:GetRewardTemplate busca primero SlapVariations/SlapId/VariationId y conserva fallback al modelo base. SlapService y TrainingService clonan esa plantilla completa; la copia equipada conserva su nombre base Classic para compatibilidad. Appearance y ApplyVariation reconocen Hand.SlapVariationAuthored y no superponen perfiles cosméticos generados, no eliminan efectos físicos ni reemplazan su audio. Configuration y lógica de combate no cambian.

Para personalizar una variante, editar su Tool físico en SlapVariations.Classic. Los ParticleEmitter, Attachment, Sound y demás componentes agregados se conservarán al clonar/equipar. Los emisores Enabled se comportan según sus propiedades; reproducir sonidos nuevos por eventos específicos todavía exige definir esos eventos. El sonido existente Hand.Hit sigue usando el flujo actual. No se implementó un reproductor automático de cualquier Sound.

Las previews exportadas son snapshots de estas plantillas: tras futuras ediciones deben regenerarse para mostrar esos cambios; no se afirma sincronización artística automática. No reejecutar el instalador sobre variantes editadas: rechaza sobreescribir SlapVariations. No se activaron cajas/comercio ni se alteraron probabilidades, inventarios o reglas del panel admin.

## Verificación

- 400 aserciones en Edit: doce Tools, doce Models, geometría/configuración/audio, colores, un Highlight por Tool, referencias internas, protección de efectos futuros en copia descartable y hash del original.
- 5 aserciones aisladas del resolver de plantillas/fallback y preservación de componentes.
- 150 aserciones aisladas SlapVictimProtection.
- 199 aserciones aisladas SlapCratesV13.
- 73 aserciones aisladas AdminTrainingV1.
- 19 aserciones aisladas del adaptador Appearance.
- 188 scripts compilados; ambos builds Rojo y git diff --check PASS.
- Jugabilidad, render visual final en cliente y reproducción de audio: NOT RUN, corresponde al desarrollador.

## Archivos

Modificados: src/shared/SlapCrates/Appearance.luau, src/server/Services/CrateService.luau, SlapService.luau, TrainingService.luau y ambos proyectos JSON. Agregados: src/assets/ClassicVariationTools.rbxm, ClassicFullVariationPreviews.rbxm, ClassicFullRewardPreviews.rbxm y evidencias/pruebas en tests/ClassicVariationsV2.*. Los assets declarativos viejos quedaron preservados pero ya no son las rutas de previews activas.

Respaldo específico: tests/assets/backups/ClassicVariationsV2, incluyendo scripts previos, proyectos y exportaciones base64 del Classic original y ambas carpetas de previews previas. No se tocó el respaldo integral anterior.

## Validación manual

En Explorer expandir SlapVariations.Classic y revisar los doce Tools y Hand.RarityHighlight. En una prueba iniciada por el desarrollador, usar ADMIN para conceder una variación, seleccionarla en inventario y entrar a práctica/combate. Comprobar mano y Handle completos, color, Highlight, animación y Hit originales. Abrir una caja de prueba ya autorizada para comprobar también la presentación completa; no habilitar cajas comerciales para esta revisión. Guardar el lugar abierto cuando corresponda: no se cerró ni se sobrescribió el archivo de Studio.
