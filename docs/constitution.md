# Constitución — pulperia-app (APROBADA el 2026-10-02)

Principios innegociables. Toda spec, plan y tarea debe cumplirlos.

1. **La spec manda**: no se implementa comportamiento que no esté en la spec activa. Si falta una decisión, se detiene el trabajo y se pregunta.
2. **Offline-first en el móvil**: una vez iniciada la sesión, el móvil funciona 100 % sin conexión. La escritura va primero a SQLite local y a una cola de cambios; la red nunca bloquea al usuario. Solo crear la cuenta y el primer inicio de sesión en un dispositivo requieren conexión. La web exige conexión y guarda directo en el servidor.
3. **Sync simple y determinista**: sincronización por lote (push de la cola, pull de cambios desde la última marca). Los registros distintos se conservan todos; si dos dispositivos modifican el mismo registro, el servidor gana. Las operaciones de sync son idempotentes.
4. **Precio histórico inmutable**: cada ítem fiado guarda su precio y cantidad al momento de la compra. Cambiar el precio del producto jamás altera deudas ya registradas.
5. **Dinero exacto**: nunca `double`/`float` para montos.
6. **Aislamiento por negocio**: todo dato pertenece a un negocio; ninguna consulta ni sync cruza datos entre negocios. La administración de la plataforma (super administrador) solo ve metadatos y cifras agregadas de cada negocio, jamás sus datos.
7. **Lógica separada de interfaz**: reglas de negocio testeables sin UI ni red (dominio en .NET, repositorios/casos de uso en Flutter, servicios en Angular).
8. **Tests como puerta**: cada tarea termina con sus tests en verde. Prohibido avanzar en rojo.
9. **Ligero y optimizado**: pensado para móviles modestos y datos limitados; sync incremental, payloads pequeños, sin dependencias innecesarias.
10. **Idioma**: código en inglés; mensajes al usuario y documentación en español.
11. **Trazabilidad**: los fiados y abonos no se editan ni se eliminan. Se anulan, y queda registrado quién lo hizo y cuándo. Todo movimiento guarda qué usuario lo creó.
