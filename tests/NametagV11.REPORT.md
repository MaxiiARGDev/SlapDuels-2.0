# Nametag V1.1 — inicialización

Causa demostrada en Output de la prueba del desarrollador: Workspace.NametagService tenía Sandboxed=true, mientras ReplicatedStorage.Shared.NametagPresentation tenía Sandboxed=false. Roblox rechazaba el require en la línea 5. El servidor nunca alcanzaba la creación de Remotes.Nametag, provocando la espera indefinida del cliente.

Se corrigió exclusivamente el script propio Workspace.NametagService a Sandboxed=false y RunContext=Server, y se declararon ambas propiedades en default.project.json y studio-safe.project.json para conservarlas al sincronizar. No se modificaron permisos de otros scripts ni del lugar. El módulo compartido sigue igual. Referencia: https://create.roblox.com/docs/scripting/capabilities

El cliente ahora espera recursos con timeout de 10 segundos por nivel y emite un diagnóstico explícito si falta un recurso. El servidor emite `[NametagService] Ready: ReportPlatform y nametags inicializados` después de la inicialización. No se crearon Remotes artificialmente en Edit para ocultar un fallo del servidor.

Verificado en Edit: propiedades corregidas y Source/editor sincronizados. 41 comprobaciones aisladas de presentación PASS, compilación de ambos scripts PASS, ambos builds Rojo PASS, inspección de propiedades dentro de ambos builds PASS y git diff --check PASS. No se ejecutó Play ni se detuvo ninguna sesión. La nueva prueba real sigue pendiente.

Respaldo previo: tests/assets/backups/NametagV11/.

Prueba del desarrollador: iniciar nueva sesión; verificar la línea Ready y la existencia de ReplicatedStorage.Remotes.Nametag.ReportPlatform en el servidor. El nombre/copa/nivel deben aparecer y, tras unos dos segundos, el icono. Si falla, enviar el primer error del servidor anterior al aviso del cliente.
