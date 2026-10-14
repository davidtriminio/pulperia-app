import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { environment } from '../../environments/environment';
import { ApiError } from './api-error';
import { IdGenerator } from './id-generator';
import { OperationResult, OperationType } from './models';

/// El servidor aceptó la petición pero rechazó la operación por una regla del dominio. `code` es
/// el código estable que `errorMessage` traduce.
export class OperationRejectedError extends ApiError {
  constructor(code: string, codes: readonly string[]) {
    super(200, code, codes);
    this.name = 'OperationRejectedError';
  }
}

/// La única vía de escritura de la web (D-4, RF-59, RF-60): una operación a la vez, directo al
/// servidor y sin cola. Mismas reglas e idempotencia que el lote del móvil.
@Injectable({ providedIn: 'root' })
export class OperationsService {
  private readonly http = inject(HttpClient);
  private readonly ids = inject(IdGenerator);

  /// Envía la operación y devuelve su resultado (`applied` o `duplicate`). Si el servidor la
  /// rechaza lanza [OperationRejectedError]; un error de red o de sesión lo lanza el interceptor.
  async send(
    type: OperationType,
    entityId: string,
    payload: Record<string, unknown>,
    options: { baseVersion?: number } = {},
  ): Promise<OperationResult> {
    const body: Record<string, unknown> = {
      opId: this.ids.next(),
      type,
      entityId,
      payload,
    };
    if (options.baseVersion !== undefined) body['baseVersion'] = options.baseVersion;

    const result = await firstValueFrom(
      this.http.post<OperationResult>(`${environment.apiUrl}/api/operations`, body),
    );
    if (result.status === 'rejected') {
      const code = result.code ?? 'invalid_request';
      throw new OperationRejectedError(code, result.codes ?? [code]);
    }
    return result;
  }

  /// Un identificador nuevo para el registro que crea una operación.
  newId(): string {
    return this.ids.next();
  }
}
