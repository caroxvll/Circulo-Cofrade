export type PaymentStatus = 'pending' | 'paid' | 'unpaid';

export type ExpenseCategory =
  | 'infra'
  | 'ads'
  | 'tools'
  | 'legal'
  | 'other'
  | 'general';

export interface SponsorPayment {
  id: string;
  sponsorName: string;
  concept: string;
  amount: number;
  currency: string;
  status: PaymentStatus;
  periodMonth: string; // YYYY-MM-01
  dueDate: string | null;
  paidAt: string | null;
  notes: string;
  createdAt: string;
}

export interface FinanceExpense {
  id: string;
  category: ExpenseCategory;
  concept: string;
  amount: number;
  currency: string;
  expenseDate: string;
  notes: string;
  createdAt: string;
}

export interface FinanceSummary {
  paid: number;
  pending: number;
  unpaid: number;
  overdue: number;
  expenses: number;
  net: number;
}

export interface CompanyPaymentRollup {
  key: string;
  name: string;
  paid: number;
  pending: number;
  unpaid: number;
  overdue: number;
  /** Estado dominante del periodo para lectura rápida. */
  headline: 'paid' | 'pending' | 'unpaid' | 'mixed' | 'none';
  payments: SponsorPayment[];
}

export function paymentStatusLabel(status: PaymentStatus): string {
  switch (status) {
    case 'paid':
      return 'Pagado';
    case 'pending':
      return 'Pendiente';
    case 'unpaid':
      return 'Impagado';
  }
}

export function expenseCategoryLabel(category: ExpenseCategory): string {
  switch (category) {
    case 'infra':
      return 'Infra / hosting';
    case 'ads':
      return 'Publicidad';
    case 'tools':
      return 'Herramientas';
    case 'legal':
      return 'Legal / admin';
    case 'other':
      return 'Otros';
    case 'general':
      return 'General';
  }
}

export function monthStartIso(date = new Date()): string {
  const d = new Date(date.getFullYear(), date.getMonth(), 1);
  return toDateOnly(d);
}

export function toDateOnly(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function formatEur(amount: number): string {
  return new Intl.NumberFormat('es-ES', {
    style: 'currency',
    currency: 'EUR',
  }).format(amount);
}

export function monthLabelFromIso(iso: string): string {
  const date = new Date(`${iso}T12:00:00`);
  const label = date.toLocaleDateString('es-ES', {
    month: 'long',
    year: 'numeric',
  });
  return label.charAt(0).toUpperCase() + label.slice(1);
}

export function isPaymentOverdue(payment: SponsorPayment, today = new Date()): boolean {
  if (payment.status !== 'pending' || !payment.dueDate) return false;
  const due = new Date(`${payment.dueDate}T23:59:59`);
  return due.getTime() < today.getTime();
}

export function rollupPaymentsByCompany(
  payments: SponsorPayment[],
  knownNames: string[] = [],
): CompanyPaymentRollup[] {
  const map = new Map<string, CompanyPaymentRollup>();

  const ensure = (name: string): CompanyPaymentRollup => {
    const key = name.trim().toLowerCase();
    let row = map.get(key);
    if (!row) {
      row = {
        key,
        name: name.trim(),
        paid: 0,
        pending: 0,
        unpaid: 0,
        overdue: 0,
        headline: 'none',
        payments: [],
      };
      map.set(key, row);
    }
    return row;
  };

  for (const name of knownNames) {
    if (name.trim()) ensure(name);
  }

  for (const payment of payments) {
    const row = ensure(payment.sponsorName);
    row.payments.push(payment);
    if (payment.status === 'paid') row.paid += payment.amount;
    if (payment.status === 'pending') {
      row.pending += payment.amount;
      if (isPaymentOverdue(payment)) row.overdue += payment.amount;
    }
    if (payment.status === 'unpaid') row.unpaid += payment.amount;
  }

  for (const row of map.values()) {
    const flags = [
      row.paid > 0,
      row.pending > 0,
      row.unpaid > 0,
    ].filter(Boolean).length;
    if (flags === 0) row.headline = 'none';
    else if (flags > 1) row.headline = 'mixed';
    else if (row.unpaid > 0) row.headline = 'unpaid';
    else if (row.pending > 0) row.headline = 'pending';
    else row.headline = 'paid';
  }

  return [...map.values()].sort((a, b) => a.name.localeCompare(b.name, 'es'));
}

export function companyHeadlineLabel(headline: CompanyPaymentRollup['headline']): string {
  switch (headline) {
    case 'paid':
      return 'Al día';
    case 'pending':
      return 'Pendiente';
    case 'unpaid':
      return 'Impagado';
    case 'mixed':
      return 'Mixto';
    case 'none':
      return 'Sin cobro';
  }
}
