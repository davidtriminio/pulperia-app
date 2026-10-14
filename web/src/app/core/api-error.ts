/// El servidor respondió con un error: `code` es el código estable (RNF-5) y `codes` todos los
/// problemas encontrados, el primero es `code`.
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    readonly codes: readonly string[] = [code],
  ) {
    super(code);
    this.name = 'ApiError';
  }
}

/// No se pudo hablar con el servidor (o no hay conexión): la web no escribe sin conexión (RF-61).
export class OfflineError extends Error {
  constructor() {
    super('offline');
    this.name = 'OfflineError';
  }
}

/// La sesión ya no se puede renovar: hay que iniciar sesión de nuevo.
export class SessionExpiredError extends Error {
  constructor() {
    super('session_expired');
    this.name = 'SessionExpiredError';
  }
}

/// El navegador tiene conexión pero la petición no llegó a una respuesta: el servidor está caído,
/// la URL de la API es incorrecta o el origen de la web no está permitido por CORS.
export class ServerUnreachableError extends Error {
  constructor() {
    super('server_unreachable');
    this.name = 'ServerUnreachableError';
  }
}
