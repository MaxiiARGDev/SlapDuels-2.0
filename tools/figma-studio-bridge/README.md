# Figma → Roblox Studio · UI Bridge V1

Dos plugins propios y un puente **local**, sin licencia comercial ni dependencias npm. No usa código de Framewisp. No modifica los sistemas de SlapDuels: todo está en esta carpeta independiente.

## Instalación

### 1. Puente local

Requiere Node.js 20 o superior. En PowerShell:

```powershell
cd H:\repos-github\SlapDuels-2.0\tools\figma-studio-bridge
node bridge/server.mjs
```

Dejá esa terminal abierta. Aparece un token aleatorio de sesión para pegar en ambos plugins. El puente escucha únicamente en `127.0.0.1:38474`; no publica un servicio en Internet. El token no es una clave de Roblox y no se guarda en los plugins. Reiniciar el puente genera otro token, pero conserva el último diseño y las asociaciones de imágenes en `.local/`, excluido de Git.

### 2. Figma

Usá Figma Design, preferentemente Desktop para el primer montaje:

1. Abrí un archivo de diseño.
2. Plugins → Development → Import plugin from manifest.
3. Elegí `figma/manifest.json` de esta carpeta.
4. Ejecutá **SlapDuels UI Bridge** desde Development.
5. Si tu versión de Figma exige un ID de plugin, creá uno mediante Development → New plugin y conservá el ID que Figma te asigne agregándolo como campo `id` a nuestro manifest. No inventes un ID ni uses el de otro producto.
6. Permití el acceso a red local si Figma o el navegador lo solicita. Solo se declara `http://localhost:38474` para desarrollo.

Seleccioná un único Frame, componente o instancia; pegá el token y pulsá **Exportar selección → Enviar al puente local**. El exportador guarda una identidad del diseño mediante pluginData; no cambia la geometría ni crea capas. Mantené ese Frame para conservar los IDs en las reimportaciones.

### 3. Roblox Studio

El archivo listo para instalar es `SlapDuelsUIBridge.rbxm`. El instalador copia solamente ese plugin a `%LOCALAPPDATA%\Roblox\Plugins`, verifica SHA-256 y respalda cualquier versión anterior diferente:

```powershell
cd H:\repos-github\SlapDuels-2.0\tools\figma-studio-bridge
.\Install-StudioPlugin.ps1
```

Si PowerShell bloquea el archivo por la política local, podés copiar manualmente el `.rbxm` desde Studio → Plugins Folder, sin cambiar la política del equipo. Guardá tus cambios y reiniciá Studio **cuando vos decidas**. Ningún script de instalación cierra ni reinicia el lugar.

En Studio Edit:

1. Abrí el botón **Figma → Studio** de la toolbar **UI Bridge**.
2. Pegá el mismo token de la terminal.
3. Pulsá **Obtener diseño**. Autorizá al plugin únicamente el acceso HTTP a `127.0.0.1:38474` si Studio lo pide. No hace falta habilitar HTTP de los servidores de juego.
4. Pulsá **Preview y revisar cambios**: muestra la interfaz y cantidades de objetos nuevos, actualizados, antiguos e imágenes sin ID.
5. Pulsá **APLICAR** para instalar en un ScreenGui nuevo `StarterGui.Bridge_<nombre>`.
6. Para actualizar: exportá de nuevo el mismo Frame, obtené la nueva revisión, revisá y aplicá.

No se importan automáticamente cambios en segundo plano. Una revisión nueva requiere preview y aplicación explícitas.

## Imágenes, iconos y dibujos

Los dibujos, imágenes, elipses y efectos complejos se exportan como PNG a 2×. El plugin de Studio **no puede usar un archivo PNG local como un asset publicado**. Esta versión no publica imágenes automáticamente ni solicita cookies, contraseñas o claves Open Cloud.

1. Abrí `http://localhost:38474` y pegá el token.
2. Consultá diseño y PNG: verás la carpeta `.local/assets` y el hash/nombre de cada imagen.
3. Importá los PNG con el Asset Manager de Roblox en la cuenta o grupo dueño de la experiencia.
4. Pegá las asociaciones en el dashboard, por ejemplo `{"<hash mostrado>":"123456789"}`. Usá el ID utilizable en `ImageLabel.Image`, no un identificador de otro tipo de asset.
5. Guardá asociaciones y volvé a Obtener → Preview en Studio. Las asociaciones se conservan por contenido; una imagen que cambia necesita otro ID.

Los permisos y moderación de Roblox pueden impedir que una imagen se muestre aunque el importador sea correcto. Una imagen sin ID queda como espacio vacío y figura como pendiente; no se inventan IDs ni se usa la cuenta de un tercero.

## Etiquetas de capas

| Nombre en Figma | Resultado |
|---|---|
| `Comprar [button]` | TextButton; si se rasteriza, ImageButton |
| `Premios [scroll]` | ScrollingFrame con CanvasSize automático XY |
| `Ilustración [raster]` | PNG con sus hijos incluidos |
| `Coins [dynamic]` | Conserva texto editable ante efectos incompatibles; advierte simplificaciones |
| `Título [font=GothamBold]` | Enum.Font indicado; desconocido usa Gotham |
| `Icono [asset=123456789]` | ImageLabel usando un asset existente |
| `Comprar [button] [asset=123456789]` | ImageButton usando un asset existente |

Separá texto dinámico y adornos gráficos en capas diferentes. Un contenedor con fondo de imagen o efectos puede rasterizarse junto a sus hijos: el exportador lo advierte. No uses `[raster]` para un texto que deba mostrar EXP/Coins/nombres cambiantes.

## Actualizaciones y protección del proyecto

- Solo actualiza ScreenGui de este puente con el mismo `UIBridgeSource`; nunca adopta ShopHUD, PlayerProfileHUD u otros HUD existentes.
- Los nodos conservan identidad mediante `UIBridgeId`; nombres visibles pueden cambiar sin romper la identidad del importador. Si tu controlador busca por nombre, deberás conservar sus nombres de contrato.
- Una capa eliminada de Figma se oculta y marca `UIBridgeStale`; **no se destruye**, por lo que sus scripts y objetos añadidos manualmente se conservan.
- Las propiedades visuales administradas se actualizan desde Figma; ajustes manuales de esas mismas propiedades se reemplazarán al reimportar.
- Solo genera GUI y decoraciones de una lista permitida. Nunca importa Source ni genera scripts de juego.
- Clase modificada para un mismo ID: se bloquea para revisión, evitando reemplazos que eliminen hijos o scripts.
- Preview aislada en el widget. Aplicación en Edit con Undo y rollback ante errores. Bloqueado en Play/Run, sin detener sesiones.
- Para conectar la UI de SlapDuels, primero revisar el resultado y después adaptar sus referencias en una tarea independiente; no hay conexión automática a compras, recompensas ni persistencia.

## Alcance real de V1

Nativo: Frames, textos simples, TextButton/ImageButton, ImageLabel, scroll, colores sólidos, opacidad simple, borde, esquinas uniformes, orden visual y geometría relativa. La raíz conserva su relación de aspecto y se centra. El texto se ajusta a su caja con un máximo basado en el tamaño de Figma.

Fallback PNG: vectores, imágenes, elipses, degradados y efectos complejos. Se prioriza aspecto antes que editabilidad para estas capas.

Limitaciones: Auto Layout se captura en su geometría actual, sin trasladar reglas; máscaras, constraints de Figma, texto mixto, tipografías personalizadas, opacidad de grupos, rotaciones/pivotes y sombras requieren revisión. No promete equivalencia píxel a píxel para cualquier archivo ni reflujo responsive automático. No convierte prototipos de Figma en lógica, no crea ViewportFrames 3D ni ofrece sincronización bidireccional. No es una réplica completa de Framewisp Pro.

## Alternativa sin red local

Descargá el JSON desde Figma. Para diseños sin PNG pendientes, pegalo en el cuadro del plugin de Studio → Preview → Aplicar. Para extraer PNG y asociar IDs desde un archivo, abrí el dashboard local y cargá el JSON allí. `examples/demo.bridge.json` permite probar el importador sin Figma ni imágenes.

## Verificación y estado

- `node build.mjs`: genera `figma/code.js` desde el exportador y main.
- `node --test tests/*.test.mjs`: pruebas del exportador, validación, transporte, autorización y persistencia local.
- `rojo build rojo.project.json -o SlapDuelsUIBridge.rbxm`: genera el plugin de Studio.
- `tests/Core.edit.spec.luau`: prueba el importador contra objetos reales de Studio separados del juego.

Resultados de esta entrega: 4 suites Node aprobadas y 16 aserciones del importador aprobadas en Studio Edit. Compilación Luau y build del plugin aprobados. No se ejecutó Play, no se publicaron assets ni se modificaron interfaces del juego.

**Pendiente:** ejecutar el plugin dentro de Figma y el widget instalado dentro de Studio, probar la transferencia con un diseño tuyo y comprobar permisos HTTP/PNG. La prueba del núcleo con objetos reales no sustituye esa validación entre las dos aplicaciones.

## Fuentes técnicas

- Figma manifest y permisos: https://developers.figma.com/docs/plugins/manifest/
- Figma exportAsync: https://developers.figma.com/docs/plugins/api/properties/nodes-exportasync/
- Roblox HttpService: https://create.roblox.com/docs/reference/engine/classes/HttpService
- Roblox Undo: https://create.roblox.com/docs/reference/engine/classes/ChangeHistoryService

Para retirar el sistema: detener la terminal y desactivar/eliminar únicamente este plugin desde Manage Plugins. La UI ya importada permanece nativa y no depende del puente al ejecutar el juego.
