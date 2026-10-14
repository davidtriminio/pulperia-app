/// Tipos del contrato de la API (`shared/openapi.json`). El dinero es siempre un entero en la
/// unidad menor (centavos); las fechas llegan como texto ISO en UTC.

export type Role = 'owner' | 'employee';
export type AmountMode = 'integer' | 'two_decimals';
export type QuantityMode = 'integer' | 'fractional';
export type BusinessStatus = 'pending' | 'active' | 'suspended';

export interface Tokens {
  userId: string;
  accessToken: string;
  accessExpiresAt: string;
  refreshToken: string;
  refreshExpiresAt: string;
}

export interface Registered {
  userId: string;
  businessId: string;
}

/// Las dos formas del registro (D-32): con negocio propio, o con un código de invitación.
export type RegisterRequest =
  | {
      email: string;
      password: string;
      businessName: string;
      amountMode: AmountMode;
      quantityMode: QuantityMode;
    }
  | { email: string; password: string; invitationCode: string };

export interface BusinessSummary {
  id: string;
  name: string;
  role: Role;
  amountMode: AmountMode;
  quantityMode: QuantityMode;
  status: BusinessStatus;
}

export interface CreateBusinessRequest {
  name: string;
  amountMode: AmountMode;
  quantityMode: QuantityMode;
}

export type BalanceLabel = 'debt' | 'credit' | 'settled';

export interface Client {
  id: string;
  name: string;
  characterId: string;
  skinId: string;
  backgroundId: string;
  phone: string | null;
  address: string | null;
  note: string | null;
  archived: boolean;
  version: number;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

/// Positivo es deuda y negativo es saldo a favor (RF-42).
export interface ClientWithBalance extends Client {
  balance: number;
  balanceLabel: BalanceLabel;
}

export interface FiadoItem {
  id: string;
  productId: string | null;
  description: string;
  quantity: number;
  unit: string;
  unitPrice: number;
  subtotal: number;
}

export interface Movement {
  kind: 'fiado' | 'payment';
  id: string;
  amount: number;
  occurredAt: string;
  serverSeq: number;
  createdBy: string;
  annulledAt: string | null;
  annulledBy: string | null;
  items?: FiadoItem[];
}

export interface ClientDetail extends ClientWithBalance {
  movements: Movement[];
}

export interface Product {
  id: string;
  name: string;
  price: number;
  unit: string;
  previousPrice: number | null;
  priceChangedAt: string | null;
  archived: boolean;
  version: number;
  createdBy: string;
  createdAt: string;
}

export interface Summary {
  debtTotal: number;
  creditTotal: number;
  debtors: { clientId: string; name: string; debt: number }[];
}

export type OperationType =
  | 'client.create'
  | 'client.update'
  | 'client.archive'
  | 'client.restore'
  | 'product.create'
  | 'product.update'
  | 'product.archive'
  | 'fiado.create'
  | 'fiado.annul'
  | 'payment.create'
  | 'payment.annul';

export interface OperationResult {
  opId: string;
  status: 'applied' | 'duplicate' | 'rejected';
  code?: string;
  codes?: string[];
}
