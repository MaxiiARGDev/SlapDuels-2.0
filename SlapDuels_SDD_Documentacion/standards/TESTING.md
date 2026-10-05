# Slap Duels 2.0 — TESTING

> Este documento conserva contenido del `GAME_SDD.md` original suministrado, redistribuido por dominio para reducir el contexto necesario para agentes de IA.

## 11. Protocolo de Pruebas (Testing)

Antes de dar por completado cualquier sistema, se deben ejecutar pruebas exhaustivas:
- **Flujo normal:** Comportamiento esperado de principio a fin.
- **Transición de entrada y salida:** Confirmación de que el efecto se dispara exactamente una vez al cambiar de estado.
- **Permanencia prolongada:** Verificar que no se repiten sonidos ni se acumulan clones mientras el estado se mantiene.
- **Prueba de estrés / entrada y salida rápida:** Entrar y salir velozmente para confirmar que el cleanup previene estados corruptos o clones huérfanos.
- **Concurrencia:** Comprobar que múltiples instancias (ej. `Red` y `Blue`) funcionan simultáneamente de forma 100% independiente.
- **Persistencia en Play / Edit:** Comprobar que iniciar y detener Play en Studio no deja objetos temporales guardados en el archivo del juego.
- **Integridad de Rojo:** Validar con `rojo sourcemap` y `rojo build` para asegurar compatibilidad de compilación.

---


## 12. Definition of Done (DoD)

Una tarea o feature solo se considera **COMPLETA** cuando satisface la siguiente lista de verificación:

- [ ] **Arquitectura verificada:** Responsabilidades delimitadas, sin dependencias circulares y siguiendo el patrón `Init(context)` y `Start(context)`.
- [ ] **Assets en Studio:** No se crearon assets permanentes mediante `Instance.new()`; se usaron templates y assets existentes en el proyecto.
- [ ] **Templates intactos:** Ningún template permanente de Studio fue modificado o destruido.
- [ ] **Feedback audiovisual intencional:** Efectos y sonidos apropiados a la importancia de la interacción.
- [ ] **Transiciones controladas:** Feedback ejecutado en cambios de estado, sin spam por frame.
- [ ] **Cleanup garantizado:** Emisores desactivados, clones destruidos, propiedades restauradas a sus valores originales.
- [ ] **Manejo de casos límite:** Soporte para desconexiones, cancelaciones y ausencias de assets.
- [ ] **Logs claros:** Formato estándar `[Servicio]` sin spam.
- [ ] **Pruebas en Studio:** Probado en Roblox Studio en escenarios unitarios y de integración.
- [ ] **Compatibilidad Rojo:** Compilación limpia sin errores en sourcemap ni build.

---
