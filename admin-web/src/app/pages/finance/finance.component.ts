import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AdsService } from '../../core/ads/ads.service';
import { FinanceService } from '../../core/finance/finance.service';
import {
  CompanyPaymentRollup,
  ExpenseCategory,
  FinanceExpense,
  FinanceSummary,
  PaymentStatus,
  SponsorPayment,
  companyHeadlineLabel,
  expenseCategoryLabel,
  formatEur,
  isPaymentOverdue,
  monthLabelFromIso,
  monthStartIso,
  paymentStatusLabel,
  rollupPaymentsByCompany,
  toDateOnly,
} from '../../core/finance/finance.models';

type FinanceTab = 'income' | 'expenses';
type IncomeView = 'companies' | 'detail';

@Component({
  selector: 'app-finance-page',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './finance.component.html',
  styleUrl: './finance.component.scss',
})
export class FinancePageComponent implements OnInit {
  private readonly finance = inject(FinanceService);
  private readonly ads = inject(AdsService);

  readonly tab = signal<FinanceTab>('income');
  readonly incomeView = signal<IncomeView>('companies');
  readonly periodMonth = signal(this.finance.defaultPeriod());
  readonly allMonths = signal(false);

  readonly payments = signal<SponsorPayment[]>([]);
  readonly expenses = signal<FinanceExpense[]>([]);
  readonly companyNames = signal<string[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);
  readonly saving = signal(false);

  readonly showPaymentForm = signal(false);
  readonly editingPayment = signal<SponsorPayment | null>(null);
  paySponsor = '';
  payConcept = '';
  payAmount: number | null = null;
  payStatus: PaymentStatus = 'pending';
  payPeriod = this.finance.defaultPeriod();
  payDue = '';
  payPaidAt = '';
  payNotes = '';

  readonly showExpenseForm = signal(false);
  readonly editingExpense = signal<FinanceExpense | null>(null);
  expCategory: ExpenseCategory = 'general';
  expConcept = '';
  expAmount: number | null = null;
  expDate = toDateOnly(new Date());
  expNotes = '';

  readonly eur = formatEur;
  readonly statusLabel = paymentStatusLabel;
  readonly categoryLabel = expenseCategoryLabel;
  readonly monthLabel = monthLabelFromIso;
  readonly overdue = isPaymentOverdue;
  readonly headlineLabel = companyHeadlineLabel;

  readonly summary = computed<FinanceSummary>(() =>
    this.finance.summarize(this.payments(), this.expenses()),
  );

  readonly byCompany = computed<CompanyPaymentRollup[]>(() =>
    rollupPaymentsByCompany(this.payments(), this.companyNames()),
  );

  readonly periodOptions = computed(() => {
    const options: string[] = [];
    const now = new Date();
    for (let i = 0; i < 12; i++) {
      options.push(monthStartIso(new Date(now.getFullYear(), now.getMonth() - i, 1)));
    }
    return options;
  });

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const period = this.allMonths() ? null : this.periodMonth();
      const [payments, expenses, ads] = await Promise.all([
        this.finance.fetchPayments(period),
        this.finance.fetchExpenses(period),
        this.ads.fetchAdminAds().catch(() => []),
      ]);
      this.payments.set(payments);
      this.expenses.set(expenses);
      const names = this.ads
        .listCompanies(ads)
        .map((c) => c.name)
        .sort((a, b) => a.localeCompare(b, 'es'));
      this.companyNames.set(names);
    } catch (err) {
      this.error.set(
        err instanceof Error
          ? `${err.message} ¿Ejecutaste finance_sponsor_payments.sql?`
          : 'No se pudo cargar finanzas',
      );
    } finally {
      this.loading.set(false);
    }
  }

  setTab(tab: FinanceTab): void {
    this.tab.set(tab);
  }

  setIncomeView(view: IncomeView): void {
    this.incomeView.set(view);
  }

  openNewPaymentFor(companyName: string): void {
    this.openNewPayment();
    this.paySponsor = companyName;
  }

  onPeriodChange(value: string): void {
    this.periodMonth.set(value);
    this.allMonths.set(false);
    void this.reload();
  }

  toggleAllMonths(checked: boolean): void {
    this.allMonths.set(checked);
    void this.reload();
  }

  openNewPayment(): void {
    this.editingPayment.set(null);
    this.paySponsor = this.companyNames()[0] ?? '';
    this.payConcept = `Patrocinio ${monthLabelFromIso(this.periodMonth())}`;
    this.payAmount = null;
    this.payStatus = 'pending';
    this.payPeriod = this.periodMonth();
    this.payDue = '';
    this.payPaidAt = '';
    this.payNotes = '';
    this.showPaymentForm.set(true);
  }

  openEditPayment(payment: SponsorPayment): void {
    this.editingPayment.set(payment);
    this.paySponsor = payment.sponsorName;
    this.payConcept = payment.concept;
    this.payAmount = payment.amount;
    this.payStatus = payment.status;
    this.payPeriod = payment.periodMonth;
    this.payDue = payment.dueDate ?? '';
    this.payPaidAt = payment.paidAt ?? '';
    this.payNotes = payment.notes;
    this.showPaymentForm.set(true);
  }

  closePaymentForm(): void {
    this.showPaymentForm.set(false);
    this.editingPayment.set(null);
  }

  async savePayment(): Promise<void> {
    if (this.paySponsor.trim().length < 2) {
      this.error.set('Indica la empresa.');
      return;
    }
    if (this.payAmount == null || this.payAmount < 0) {
      this.error.set('Indica un importe válido.');
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      const period = this.normalizeMonth(this.payPeriod);
      await this.finance.savePayment({
        id: this.editingPayment()?.id,
        sponsorName: this.paySponsor,
        concept: this.payConcept,
        amount: this.payAmount,
        status: this.payStatus,
        periodMonth: period,
        dueDate: this.payDue || null,
        paidAt: this.payPaidAt || null,
        notes: this.payNotes,
      });
      this.closePaymentForm();
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar el cobro');
    } finally {
      this.saving.set(false);
    }
  }

  private normalizeMonth(value: string): string {
    const raw = value?.trim();
    if (!raw) return this.finance.defaultPeriod();
    const date = new Date(`${raw}T12:00:00`);
    if (Number.isNaN(date.getTime())) return this.finance.defaultPeriod();
    return monthStartIso(date);
  }

  async markPaid(payment: SponsorPayment): Promise<void> {
    this.saving.set(true);
    try {
      await this.finance.savePayment({
        id: payment.id,
        sponsorName: payment.sponsorName,
        concept: payment.concept,
        amount: payment.amount,
        status: 'paid',
        periodMonth: payment.periodMonth,
        dueDate: payment.dueDate,
        paidAt: toDateOnly(new Date()),
        notes: payment.notes,
      });
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo marcar como pagado');
    } finally {
      this.saving.set(false);
    }
  }

  async removePayment(payment: SponsorPayment): Promise<void> {
    if (!confirm(`¿Borrar cobro de ${payment.sponsorName}?`)) return;
    try {
      await this.finance.deletePayment(payment.id);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo borrar');
    }
  }

  openNewExpense(): void {
    this.editingExpense.set(null);
    this.expCategory = 'general';
    this.expConcept = '';
    this.expAmount = null;
    this.expDate = toDateOnly(new Date());
    this.expNotes = '';
    this.showExpenseForm.set(true);
  }

  openEditExpense(expense: FinanceExpense): void {
    this.editingExpense.set(expense);
    this.expCategory = expense.category;
    this.expConcept = expense.concept;
    this.expAmount = expense.amount;
    this.expDate = expense.expenseDate;
    this.expNotes = expense.notes;
    this.showExpenseForm.set(true);
  }

  closeExpenseForm(): void {
    this.showExpenseForm.set(false);
    this.editingExpense.set(null);
  }

  async saveExpense(): Promise<void> {
    if (this.expConcept.trim().length < 2) {
      this.error.set('Indica el concepto del gasto.');
      return;
    }
    if (this.expAmount == null || this.expAmount < 0) {
      this.error.set('Indica un importe válido.');
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.finance.saveExpense({
        id: this.editingExpense()?.id,
        category: this.expCategory,
        concept: this.expConcept,
        amount: this.expAmount,
        expenseDate: this.expDate,
        notes: this.expNotes,
      });
      this.closeExpenseForm();
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo guardar el gasto');
    } finally {
      this.saving.set(false);
    }
  }

  async removeExpense(expense: FinanceExpense): Promise<void> {
    if (!confirm(`¿Borrar gasto «${expense.concept}»?`)) return;
    try {
      await this.finance.deleteExpense(expense.id);
      await this.reload();
    } catch (err) {
      this.error.set(err instanceof Error ? err.message : 'No se pudo borrar');
    }
  }
}
