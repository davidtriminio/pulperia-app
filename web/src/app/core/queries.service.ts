import { HttpClient, HttpParams } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { environment } from '../../environments/environment';
import { ClientDetail, ClientWithBalance, Product, Summary } from './models';

/// Las lecturas de la web (RF-59): vienen del servidor, que calcula los saldos y el resumen.
@Injectable({ providedIn: 'root' })
export class QueriesService {
  private readonly http = inject(HttpClient);

  clients(options: { archived?: boolean } = {}): Promise<ClientWithBalance[]> {
    return firstValueFrom(
      this.http.get<ClientWithBalance[]>(`${environment.apiUrl}/api/clients`, {
        params: archivedParams(options),
      }),
    );
  }

  client(id: string): Promise<ClientDetail> {
    return firstValueFrom(
      this.http.get<ClientDetail>(`${environment.apiUrl}/api/clients/${encodeURIComponent(id)}`),
    );
  }

  products(options: { archived?: boolean } = {}): Promise<Product[]> {
    return firstValueFrom(
      this.http.get<Product[]>(`${environment.apiUrl}/api/products`, {
        params: archivedParams(options),
      }),
    );
  }

  summary(limit?: number): Promise<Summary> {
    let params = new HttpParams();
    if (limit !== undefined) params = params.set('limit', limit);
    return firstValueFrom(
      this.http.get<Summary>(`${environment.apiUrl}/api/summary`, { params }),
    );
  }
}

function archivedParams(options: { archived?: boolean }): HttpParams {
  let params = new HttpParams();
  if (options.archived) params = params.set('archived', 'true');
  return params;
}
