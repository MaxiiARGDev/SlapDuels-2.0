# Slap Variations V1 — entrega en Edit

Se instalaron 12 perfiles cosméticos y 12 previews seguros. Estado: **implementación y validación estática completadas; aprobación visual y de jugabilidad PENDIENTE**.

Al comenzar Studio estaba en Play. No se detuvo ni se alteró esa sesión. Se preparó el código fuera de las rutas Rojo hasta que el desarrollador confirmó el retorno a Edit; después se auditó el Classic real y se instalaron los recursos.

## Auditoría y estructura original

`ServerStorage.Slaps.Classic` es una Tool con 8 descendientes:

```
Classic
  Swing (Animation, rbxassetid://204062532)
  Configuration
    Power (NumberValue, 20)
    SlapCooldown (NumberValue, 0.6)
  Hand (MeshPart)
    Hit (Sound, rbxassetid://5213679380, Volume=0.5, PlaybackSpeed=1)
  Handle (Part)
    WeldConstraint
```

Hand usa MeshId `http://www.roblox.com/asset/?id=32054761`, sin TextureID, color original RGB 248/248/248, SmoothPlastic, tamaño aproximadamente 2.300506 × 3.145587 × 1.088670. No había Attachments, partículas ni scripts de activación dentro de Classic. La Tool original no fue modificada.

El contrato anterior copiaba Attachments/ParticleEmitters a Hand y aplicaba Tint, pero no Material. El preview anterior solo recoloreaba una base y omitía Attachments. Se añadió un aplicador cosmético compartido y genérico; no se modificó SlapService ni su resolución de combate.

## Perfiles instalados

Rutas exactas: `ReplicatedStorage.SlapVariationEffects.<Id>` y `ReplicatedStorage.SlapVariationPreviews.Classic.<Id>` para cada fila:

| Id / RewardId Classic:Id | Tint RGB | Material | Emisión total por defecto | Identidad visual |
|---|---|---|---:|---|
| Basic | Original 248,248,248 | Original SmoothPlastic | 0/s | Sin efectos extraordinarios; conserva base |
| Common | 202,209,218 | SmoothPlastic | 0/s | Plateado discreto |
| Uncommon | 65,190,100 | SmoothPlastic | 5/s | Pequeñas partículas verdes |
| Rare | 69,138,255 | SmoothPlastic | 7/s | Energía azul y luz tenue |
| Gold | 239,187,62 | Metal | 6/s | Destellos dorados |
| Arcoiris | 245,245,245 | SmoothPlastic | 9/s | Secuencia multicolor de partículas, sin bucle de servidor |
| Emote | 220,93,180 | SmoothPlastic | 4/s | Símbolo ✦ decorativo y energía rosa |
| Wings | 151,218,255 | Glass | 6/s | WingLeft/WingRight, dos plumas de energía celeste |
| Epic | 145,58,225 | Neon | 11/s | Energía violeta y brillo moderado |
| Legendary | 255,156,37 | Neon | 16/s | Aura naranja/dorada con luz más notoria |
| Blood | 125,24,45 | SmoothPlastic | 8/s | Energía roja/negra suave, sin gore |
| Galaxy | 38,31,83 | Neon | 12/s | Estrellas azules, violetas y blancas |

Cada perfil tiene Tint Color3, Material, ApplyTint/ApplyMaterial, Intensity, DesignPending, Attachment(s), ParticleEmitter(s) y slots Sound Hit/Reveal vacíos. Se usan texturas incluidas en Roblox (`sparkles_main.dds`, `smoke_main.dds`), no uploads ni SoundIds inventados. Basic/Common mantienen partículas desactivadas. Rare/Epic/Legendary/Galaxy incluyen PointLight sin sombras y de rango pequeño.

Wings no crea alas físicas ni vuelo; Emote no implementa emotes. No se agregan partes al slap equipado. Los previews usan una sola Part con SpecialMesh derivado de la geometría original, Anchored=true y CanCollide/CanTouch/CanQuery=false, sin Tools ni scripts de combate.

## Aplicación e integración

`Shared.SlapCrates.Appearance.Apply` aplica Tint/Material e intensidad, guarda/restaura la apariencia original y clona únicamente clases cosméticas autorizadas. Elimina solo raíces marcadas SlapVariationManaged al reaplicar. No cambia Size, físicas, Configuration, Swing ni sonidos. Attachments con NormalizedPosition se escalan según Hand.Size, reutilizables en otros SlapIds.

CrateService reutiliza este aplicador sobre la Hand ya existente. Conserva el mecanismo previo de audio aprobado, pero todos los nuevos Hit están vacíos: sigue sonando el Hit original. CrateController selecciona el preview por SlapId+VariationId y reutiliza el mismo aplicador. El burst de revelación respeta RevealBurstCount y no genera partículas extraordinarias para Basic.

SlapDefinitions ya autorizaba las 12 variaciones y no se modificó. Catalog/VariationRegistry/CrateRegistry mantienen los mismos IDs. Se comprobaron los 12 RewardIds Classic:VariationId. No se otorgó propiedad ni se modificaron inventario, Coins, compras, probabilidades, stock o configuración productiva. CrateDefinitions y StockDefinitions conservan sus hashes previos.

## Recursos preservados y archivos

Se conservaron los perfiles anteriores en `ServerStorage.SlapVariationsV1_Backup.SlapVariationEffects`. Es respaldo deliberado para recuperación, no un recurso que se use en juego. ServerStorage conserva objetos desconocidos en el proyecto default para proteger este respaldo y las instancias del propietario. No se borró ni guardó forzosamente el lugar.

Archivos de implementación:

- Nuevo: src/shared/SlapCrates/Appearance.luau.
- Modificados: VariationDefinitions.luau, CrateService.luau y CrateController.luau, exclusivamente presentación.
- Actualizado: src/assets/SlapVariationEffects.project.json.
- Nuevo: src/assets/SlapVariationPreviews.project.json.
- default.project.json: mapea previews y preserva objetos desconocidos de ServerStorage; SAFE no cambia.
- Tests, generadores, payloads, paleta, auditoría, evidencia y guías bajo tests/SlapVariationsV1.* y tests/tools.
- Fixture de pruebas de cajas adaptada para cargar Appearance/Color3.fromRGB; sus reglas comerciales no cambian.

Copias previas en tests/assets/backups/SlapVariationsV1. Integridad SHA-256 confirma 136 archivos originales de src sin cambios, incluidos SlapService, CombatService, RagdollService, RoundService, ScoreService, habilidades, Shop, economía, persistencia y catálogos comerciales.

## Validación

| Comprobación | Resultado |
|---|---|
| Perfiles y previews físicos | PASS: 12+12, sin IDs/nombres duplicados |
| Propiedades físicas frente a assets del repo | PASS: 139 nodos, 919 propiedades; Color de BasePart comparado con precisión RGB8 |
| Aplicación sobre clones aislados de Classic, sin parent, en Edit | PASS: 210 aserciones estáticas, incluidas configuración, Swing/Hit, geometría, físicas e idempotencia |
| Aplicador independiente: Basic, material, intensidad, limpieza, clases inseguras, otra geometría | PASS: 19 aserciones aisladas |
| Cajas / probabilidades / inventario / presentación simulada | PASS: 107 aserciones aisladas |
| Combate e inmunidad de víctima | PASS: 150 aserciones aisladas |
| Habilidades | PASS: 164 aserciones aisladas |
| Registry/seguridad | PASS: 89 aserciones aisladas |
| Shop/economía | PASS: 86 aserciones aisladas |
| Compilación Luau | PASS: todos los scripts de runtime y dos specs relevantes |
| Ambos builds Rojo | PASS |
| git diff --check | PASS; advertencias LF/CRLF preexistentes |
| Fuentes Source/editor frente al repositorio | PASS: 4 módulos por SHA-256 normalizado |
| Partidas, percepción visual, rendimiento real y audio final | NOT RUN; validación humana pendiente |

Total offline: 615 aserciones aisladas. Las 210 comprobaciones cosméticas en Edit se informan por separado y no representan jugabilidad. No se inició Play/Run/Team Test/Start Server, no se controlaron personajes, no hubo cloud/publicaciones/commits/push. La selección de persistencia Studio/InMemory/WritesToCloud=false se preserva; no se inicializó persistencia para estas pruebas.

Instrucciones exactas en SlapVariationsV1.manual.md. Las maquetas quedan editables; cualquier aprobación visual definitiva o concesión de una variación para pruebas requiere la decisión del desarrollador. No se avanza a otra fase.
