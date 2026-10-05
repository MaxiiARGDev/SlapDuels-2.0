# Slap Duels 2.0 — DEBUGGING

> Este documento conserva contenido del `GAME_SDD.md` original suministrado, redistribuido por dominio para reducir el contexto necesario para agentes de IA.

## 6. Política de Limpieza (Cleanup)

Todo sistema audiovisual temporal debe garantizar un **cleanup exhaustivo**:
1. **Detener sonidos:** Pausar o silenciar sonidos antes de destruir la instancia si están en reproducción.
2. **Desactivar emisores:** Cambiar `ParticleEmitter.Enabled = false` para permitir que las partículas existentes se disuelvan de forma natural o destruirlas de inmediato según el caso.
3. **Destruir clones temporales:** Invocar `:Destroy()` sobre cualquier objeto generado dinámicamente.
4. **Restaurar propiedades:** Devolver cualquier propiedad modificada a su valor previo exacto.
5. **Desconectar eventos:** Desconectar toda conexión `RBXScriptConnection` al finalizar el ciclo.

**Cero residuos:** Ningún sistema debe dejar `ParticleEmitter`s huérfanos, sonidos sonando indefinidamente, partes invisibles acumulándose en `Workspace`, o referencias colgadas en tablas de Lua.

---


## 7. Modificación de Propiedades Existentes

Cuando un sistema modifique una propiedad de un objeto preexistente (como un pad o un componente del mapa):
- **Guardar el estado original:** Registrar el valor previo en memoria antes de aplicar el cambio.
  ```luau
  -- Correcto:
  self._originalMaterials[pad] = pad.Material
  pad.Material = Enum.Material.Neon
  
  -- Al restaurar:
  pad.Material = self._originalMaterials[pad]
  ```
- **PROHIBIDO asumir valores por defecto:** Nunca asumir `pad.Material = Enum.Material.Plastic` o colores estándar, ya que en el futuro el mapa puede cambiar de diseño y el valor asumido corrompería la apariencia original.

---


## 10. Directrices de Depuración y Logging

- **Prefijo obligatorio:** Todo mensaje de log debe usar la convención:
  `[NombreServicio] Mensaje descriptivo`
- **Sin spam por frame:** Prohibido emitir logs dentro de ciclos de alta frecuencia (`Heartbeat` / `RenderStepped`) en condiciones normales.
- **Detalle en errores:** Ante una falla, el log debe especificar:
  - Qué operación falló.
  - Qué instancia o asset no fue encontrado.
  - Qué estado se esperaba y cuál se recibió.
  - La acción de recuperación o cancelación tomada.

---
