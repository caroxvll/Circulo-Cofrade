import { Injectable, inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { getSupabase } from '../supabase.client';
import {
  ExpenseCategory,
  FinanceExpense,
  FinanceSummary,
  PaymentStatus,
  SponsorPayment,
  isPaymentOverdue,
  monthStartIso,
  toDateOnly,
} from './finance.models';

@Injectable({ providedIn: 'root' })
export class FinanceService {
  private readonly auth = inject(AuthService);

  async fetchPayments(periodMonth: string | null): Promise<SponsorPayment[]> {
    let query = getSupabase()
      .from('sponsor_payments')
      .select('*')
      .order('period_month', { ascending: false })
      .order('created_at', { ascending: false });

    if (periodMonth) {
      query = query.eq('period_month', periodMonth);
    }

    const { data, error } = await query.limit(200);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapPayment(row));
  }

  async savePayment(input: {
    id?: string;
    sponsorName: string;
    concept: string;
    amount: number;
    status: PaymentStatus;
    periodMonth: string;
    dueDate?: string | null;
    paidAt?: string | null;
    notes?: string;
  }): Promise<void> {
    const userId = this.auth.profile()?.id ?? null;
    const payload = {
      sponsor_name: input.sponsorName.trim(),
      concept: (input.concept ?? '').trim(),
      amount: Number(input.amount),
      currency: 'EUR',
      status: input.status,
      period_month: input.periodMonth,
      due_date: input.dueDate || null,
      paid_at:
        input.status === 'paid'
          ? input.paidAt || toDateOnly(new Date())
          : input.paidAt || null,
      notes: (input.notes ?? '').trim(),
      updated_at: new Date().toISOString(),
    };

    if (input.id) {
      const { error } = await getSupabase()
        .from('sponsor_payments')
        .update(payload)
        .eq('id', input.id);
      if (error) throw error;
      return;
    }

    const { error } = await getSupabase().from('sponsor_payments').insert({
      ...payload,
      created_by: userId,
    });
    if (error) throw error;
  }

  async deletePayment(id: string): Promise<void> {
    const { error } = await getSupabase()
      .from('sponsor_payments')
      .delete()
      .eq('id', id);
    if (error) throw error;
  }

  /** Borra todos los cobros de una marca (casos: eliminar empresa). */
  async deletePaymentsBySponsor(sponsorName: string): Promise<number> {
    const name = sponsorName.trim();
    if (!name) return 0;
    const { data, error } = await getSupabase()
      .from('sponsor_payments')
      .select('id, sponsor_name');
    if (error) throw error;
    const key = name.toLowerCase();
    const ids = (data ?? [])
      .filter((row) => String(row['sponsor_name'] ?? '').trim().toLowerCase() === key)
      .map((row) => String(row['id']));
    if (!ids.length) return 0;
    const { error: delError } = await getSupabase()
      .from('sponsor_payments')
      .delete()
      .in('id', ids);
    if (delError) throw delError;
    return ids.length;
  }

  async renameSponsorPayments(fromName: string, toName: string): Promise<void> {
    const from = fromName.trim();
    const to = toName.trim();
    if (!from || !to || from.toLowerCase() === to.toLowerCase()) return;
    const { data, error } = await getSupabase()
      .from('sponsor_payments')
      .select('id, sponsor_name');
    if (error) throw error;
    const key = from.toLowerCase();
    const ids = (data ?? [])
      .filter((row) => String(row['sponsor_name'] ?? '').trim().toLowerCase() === key)
      .map((row) => String(row['id']));
    for (const id of ids) {
      const { error: updError } = await getSupabase()
        .from('sponsor_payments')
        .update({ sponsor_name: to, updated_at: new Date().toISOString() })
        .eq('id', id);
      if (updError) throw updError;
    }
  }

  async fetchExpenses(periodMonth: string | null): Promise<FinanceExpense[]> {
    let query = getSupabase()
      .from('finance_expenses')
      .select('*')
      .order('expense_date', { ascending: false })
      .order('created_at', { ascending: false });

    if (periodMonth) {
      const start = periodMonth;
      const d = new Date(`${periodMonth}T12:00:00`);
      const end = toDateOnly(new Date(d.getFullYear(), d.getMonth() + 1, 1));
      query = query.gte('expense_date', start).lt('expense_date', end);
    }

    const { data, error } = await query.limit(200);
    if (error) throw error;
    return (data ?? []).map((row) => this.mapExpense(row));
  }

  async saveExpense(input: {
    id?: string;
    category: ExpenseCategory;
    concept: string;
    amount: number;
    expenseDate: string;
    notes?: string;
  }): Promise<void> {
    const userId = this.auth.profile()?.id ?? null;
    const payload = {
      category: input.category,
      concept: input.concept.trim(),
      amount: Number(input.amount),
      currency: 'EUR',
      expense_date: input.expenseDate,
      notes: (input.notes ?? '').trim(),
      updated_at: new Date().toISOString(),
    };

    if (input.id) {
      const { error } = await getSupabase()
        .from('finance_expenses')
        .update(payload)
        .eq('id', input.id);
      if (error) throw error;
      return;
    }

    const { error } = await getSupabase().from('finance_expenses').insert({
      ...payload,
      created_by: userId,
    });
    if (error) throw error;
  }

  async deleteExpense(id: string): Promise<void> {
    const { error } = await getSupabase()
      .from('finance_expenses')
      .delete()
      .eq('id', id);
    if (error) throw error;
  }

  summarize(
    payments: SponsorPayment[],
    expenses: FinanceExpense[],
  ): FinanceSummary {
    let paid = 0;
    let pending = 0;
    let unpaid = 0;
    let overdue = 0;
    for (const payment of payments) {
      if (payment.status === 'paid') paid += payment.amount;
      if (payment.status === 'pending') {
        pending += payment.amount;
        if (isPaymentOverdue(payment)) overdue += payment.amount;
      }
      if (payment.status === 'unpaid') unpaid += payment.amount;
    }
    const expenseTotal = expenses.reduce((sum, row) => sum + row.amount, 0);
    return {
      paid,
      pending,
      unpaid,
      overdue,
      expenses: expenseTotal,
      net: paid - expenseTotal,
    };
  }

  defaultPeriod(): string {
    return monthStartIso(new Date());
  }

  private mapPayment(row: Record<string, unknown>): SponsorPayment {
    return {
      id: String(row['id'] ?? ''),
      sponsorName: String(row['sponsor_name'] ?? ''),
      concept: String(row['concept'] ?? ''),
      amount: Number(row['amount'] ?? 0),
      currency: String(row['currency'] ?? 'EUR'),
      status: (row['status'] as PaymentStatus) ?? 'pending',
      periodMonth: String(row['period_month'] ?? this.defaultPeriod()),
      dueDate: (row['due_date'] as string | null) ?? null,
      paidAt: (row['paid_at'] as string | null) ?? null,
      notes: String(row['notes'] ?? ''),
      createdAt: String(row['created_at'] ?? ''),
    };
  }

  private mapExpense(row: Record<string, unknown>): FinanceExpense {
    return {
      id: String(row['id'] ?? ''),
      category: (row['category'] as ExpenseCategory) ?? 'general',
      concept: String(row['concept'] ?? ''),
      amount: Number(row['amount'] ?? 0),
      currency: String(row['currency'] ?? 'EUR'),
      expenseDate: String(row['expense_date'] ?? toDateOnly(new Date())),
      notes: String(row['notes'] ?? ''),
      createdAt: String(row['created_at'] ?? ''),
    };
  }
}
