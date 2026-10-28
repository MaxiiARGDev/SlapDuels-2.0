# Sincronización y recuperación V2.1

## Trabajo normal

Usar Start-StudioSafeRojo.ps1. El proyecto studio-safe.project.json administra **solo scripts**, con ignoreUnknownInstances=true. La geometría y UI permanecen como recursos del place durante ese flujo. Guardar normalmente el place; no publicar para guardar una copia local.

Los archivos definitivos de recursos son src/assets/CrateVisualsV21/MainCrateStand.rbxm, CrateOpeningHUD.rbxm y ShopHUD.rbxm. default.project.json los mapea como raíces completas; no agregar hijos explícitos que ya estén dentro de esos modelos. El build verificado conserva sus jerarquías y no tiene hermanos duplicados.

Después de modificar arte en Studio, antes de una sincronización completa:

1. Volver a exportar las tres raíces actuales mediante SerializationService/MCP o guardarlas como modelos nativos.
2. Guardar primero otra copia externa y verificar archivos/hashes.
3. Actualizar los `.rbxm` y manifest.json del proyecto con la versión deseada.
4. Ejecutar builds, comparar jerarquías y hashes con Studio; revisar preview antes de sincronizar recursos.

No aplicar los JSON antiguos ni ejecutar generadores históricos para regenerar el stand/HUDs. El constructor V2 está bloqueado cuando detecta el manifiesto V2.1. SAFE no exporta ni respalda por sí solo cambios artísticos.

## Copias externas verificadas

Antes: H:\repos-github\_backups\SlapDuels-2.0\CrateVisualV21_20261019_155048\*.before.rbxm y manifest.json.

Final: la subcarpeta `final` contiene MainCrateStand.rbxm, CrateOpeningHUD.rbxm, ShopHUD.rbxm y manifest.json. Los nombres, tamaños y SHA-256 están también en src/assets/CrateVisualsV21/manifest.json para el estado final, y tests/assets/backups/CrateVisualV21/export-manifest.json para el anterior.

Comprobar un archivo sin modificarlo:

```powershell
Get-FileHash -LiteralPath 'H:\repos-github\_backups\SlapDuels-2.0\CrateVisualV21_20261019_155048\MainCrateStand.before.rbxm' -Algorithm SHA256
```

Resultado esperado: c5da650d1a9d71e818e46bc7a63ffd0233326962bc28a03dd466b49800e78ffb.

## Restauración si hiciera falta

1. Desconectar Rojo, volver a Edit y guardar una copia separada del place actual antes de reemplazar nada.
2. Importar el modelo deseado en un **place local de recuperación separado**, sin publicarlo; comparar jerarquía/propiedades allí. No importar Recovery encima del proyecto original: contiene varias raíces, incluido el respaldo interno.
3. Elegir versión `before` para el estado del agente visual anterior, o `final` para esta implementación. Sus destinos son Workspace.CrateStands.MainCrateStand, StarterGui.CrateOpeningHUD y StarterGui.ShopHUD.
4. Comparar antes de cualquier sustitución y conservar una copia adicional del estado que se vaya a reemplazar. No borrar ni sobrescribir ServerStorage._CrateVisualBackup_20261019.
5. Si se restaura otra versión visual, actualizar los snapshots y manifiestos del repositorio antes de volver al proyecto completo. Los scripts se recuperan desde las fuentes/backups correspondientes, no desde modelos visuales.

No se ejecutó ninguna restauración sobre el lugar original durante esta tarea; solo se verificó la deserialización en objetos sin parent. No hay commits/push ni publicación asociados.
