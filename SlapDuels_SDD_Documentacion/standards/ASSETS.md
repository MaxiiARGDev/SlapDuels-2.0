# Slap Duels 2.0 — ASSETS

> Especificación vigente. Define el comportamiento requerido; no certifica que la implementación ni los assets actuales hayan sido verificados en Studio.

## Regla Fundamental de Assets

**Los assets permanentes de presentación DEBEN crearse y editarse directamente en Roblox Studio.**

Esto incluye de forma obligatoria:
- `Sound` (efectos de sonido, música, locuciones)
- `ParticleEmitter` (chispas, ondas, auras, fuegos, explosiones)
- `Attachment` (puntos de anclaje de efectos)
- `Part` y `MeshPart` utilizados como VFX o proyectiles
- `Trail` y `Beam`
- Elementos de Interfaz de Usuario (`ScreenGui`, `Frame`, `TextLabel`, `ImageLabel`, etc.)
- Modelos visuales y mapas de juego

> [!CAUTION]
> **PROHIBIDO:** Crear permanentemente estos assets mediante código utilizando `Instance.new()` cuando puedan existir como recursos editables dentro del proyecto. El código Luau tiene como único rol **controlar, clonar, posicionar, activar y destruir instancias temporales de los assets existentes**. La apariencia visual, texturas, colores, curvas de tamaño y tasas de emisión deben permanecer editables en Studio por diseñadores y artistas.

---

## Distinción: Template vs Instance

Para cualquier efecto o recurso audiovisual, se debe mantener una separación estricta:

- **ASSET TEMPLATE:** Recurso visual permanente almacenado en Studio (ej. dentro de `Folder` de efectos o `ReplicatedStorage`). Diseñado manualmente. **NUNCA debe modificarse en tiempo de ejecución ni destruirse.**
- **INSTANCE (Clon Temporal):** Copia generada en tiempo de ejecución mediante `:Clone()` para ser utilizada durante una interacción específica.

### Ciclo de Vida de una Instancia de Efecto
```mermaid
stateDiagram-v2
    direction LR
    Template: Template en Studio (Intacto)
    Clone: Clone() temporal
    Active: Posicionado y Activado
    Cleanup: Desactivación de Emitters
    Destroy: Destroy()

    Template --> Clone: Interacción (ej. Jugador entra a Pad)
    Clone --> Active: Anchor, PivotTo, Enable
    Active --> Cleanup: Fin de Interacción (Jugador sale)
    Cleanup --> Destroy: Limpieza total de memoria
```

---

## Alcance de la regla

La prohibición aplica a assets permanentes de presentación. No impide crear infraestructura temporal de gameplay como VoidBoundaryPart, conexiones, remotes o restricciones físicas de ragdoll. Estos recursos tienen propietario y cleanup; esta distinción no permite construir UI, sonidos o VFX permanentes por código. Los cambios deliberados de diseño en modo edición son distintos de mutar templates en runtime.
