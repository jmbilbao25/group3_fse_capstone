// Ported from Zel's admin portal (AdminExecutivePortal.jsx: Customer Accounts & 360° Profile, protective account freeze/unfreeze).
import { useEffect, useMemo, useState } from 'react';
import { ArrowDownLeft, ArrowLeftRight, ArrowUpRight, Lock, LockOpen, Undo2, Wallet } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { ago, dateTime, fullName, money, titleCase } from '../lib/format';
import { BRANCH_ROLES, staffName, useAuth } from '../context/Auth';
import { Badge, Button, Drawer, Empty, ErrorNote, PageHeader, SkeletonRows, cn, useLoad, useToast } from '../components/ui';
import { Lifecycle, REVERSIBLE } from './Reversals';

/** Zel's freeze reasons; the code goes to account-service with the request. */
const FREEZE_REASONS = [
  ['SUSPECTED_PHISHING_COERCION', 'Suspected phishing or coercion'],
  ['LOST_DEVICE_SIM_SWAP', 'Lost device or SIM swap'],
  ['IMPOSSIBLE_TRAVEL_ANOMALY', 'Impossible travel'],
  ['COURT_ORDER_REGULATORY_HOLD', 'Court order or regulatory hold'],
  ['CUSTOMER_VOLUNTARY_REQUEST', 'Customer asked for it'],
];
const KYC_TONE = { VERIFIED: 'mint', APPROVED: 'mint', PENDING: 'ember', PENDING_REVIEW: 'ember', REJECTED: 'danger' };
const TX_TONE = { COMMITTED: 'mint', POSTED: 'mint', SETTLED: 'mint', PENDING_APPROVAL: 'ember', REJECTED: 'danger', FAILED: 'danger' };
const SHOWN = 10;
const FIELD = 'h-10 rounded-xl bg-white px-4 text-sm ring-1 ring-inset ring-ink-100 focus:outline-none focus:ring-2 focus:ring-ink';

const initials = (name) => name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
// account-service serialises LocalDate as [year, month, day].
const day = (v) => (Array.isArray(v) ? new Date(v[0], v[1] - 1, v[2]).toLocaleDateString('en-PH', { day: 'numeric', month: 'short', year: 'numeric' }) : v);

export default function Customers() {
  const accounts = useLoad(() => api.get('/accounts').then((r) => r.data), []);
  const customers = useMemo(() => {
    const byOwner = new Map();
    for (const a of accounts.data || []) {
      if (a.owner_role !== 'CUSTOMER') continue;
      const c = byOwner.get(a.user_id) || { user_id: a.user_id, name: a.owner_name || a.user_id, accounts: [] };
      c.accounts.push(a);
      byOwner.set(a.user_id, c);
    }
    return [...byOwner.values()].sort((x, y) => x.name.localeCompare(y.name));
  }, [accounts.data]);
  const owners = useMemo(() => new Map((accounts.data || []).map((a) => [a.account_id, a.owner_name])), [accounts.data]);
  const [userId, setUserId] = useState(null);

  useEffect(() => {
    if (!userId && customers.length) setUserId(customers[0].user_id);
  }, [customers, userId]);
  const selected = customers.find((c) => c.user_id === userId);

  return (
    <>
      <PageHeader
        title="Customers"
        description="Profile, accounts, balances and recent transfers for each customer. Branch operations can freeze an account or ask for a transfer to be reversed."
      />
      <div className="grid items-start gap-6 lg:grid-cols-[320px_1fr]">
        <div className="panel overflow-hidden animate-rise">
          <p className="label px-5 pt-5">Customers{customers.length ? ` · ${customers.length}` : ''}</p>
          {accounts.loading && !accounts.data ? (
            <SkeletonRows rows={4} />
          ) : accounts.error ? (
            <div className="p-5"><ErrorNote message={errorMessage(accounts.error)} onRetry={accounts.reload} /></div>
          ) : !customers.length ? (
            <p className="px-5 py-6 text-sm text-ink-400">No customer accounts yet.</p>
          ) : (
            <ul className="p-2">
              {customers.map((c, i) => {
                const on = userId === c.user_id;
                const frozen = c.accounts.some((a) => a.status === 'LOCKED');
                return (
                  <li key={c.user_id} className="row-enter" style={{ '--i': i }}>
                    <button
                      onClick={() => setUserId(c.user_id)}
                      aria-pressed={on}
                      className={cn('flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm transition-colors', on ? 'bg-ink text-white' : 'hover:bg-paper')}
                    >
                      <span aria-hidden className={cn('grid size-9 shrink-0 place-items-center rounded-full text-xs font-semibold', on ? 'bg-white/10 text-mint' : 'bg-mint-wash text-mint-deep')}>
                        {initials(c.name)}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-semibold">{c.name}</span>
                        <span className={cn('block truncate font-mono text-xs', on ? 'text-white/60' : 'text-ink-400')}>
                          {c.user_id} · {c.accounts.length} {c.accounts.length === 1 ? 'account' : 'accounts'}
                        </span>
                      </span>
                      {frozen && (
                        <>
                          <Lock aria-hidden className={cn('size-4 shrink-0', on ? 'text-ember' : 'text-danger')} />
                          <span className="sr-only">Has a frozen account</span>
                        </>
                      )}
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        {selected && <Profile key={selected.user_id} customer={selected} owners={owners} onChanged={accounts.reload} />}
      </div>
    </>
  );
}

function Profile({ customer, owners, onChanged }) {
  const { staff } = useAuth();
  const canFreeze = BRANCH_ROLES.includes(staff?.role);
  const [accountId, setAccountId] = useState(customer.accounts[0]?.account_id);
  const [tx, setTx] = useState(null);
  // Each source fails on its own, so a missing balance does not blank the profile.
  const info = useLoad(async () => {
    const [profile, location, ...balances] = await Promise.allSettled([
      api.get(`/kyc/${customer.user_id}`).then((r) => r.data),
      api.get(`/users/${customer.user_id}/location`).then((r) => r.data),
      ...customer.accounts.map((a) => api.get(`/accounts/${a.account_id}/balance`).then((r) => r.data)),
    ]);
    return { profile, location: location.value, balances: new Map(customer.accounts.map((a, i) => [a.account_id, balances[i].value])) };
  }, [customer.user_id]);

  const p = info.data?.profile.value;
  const bal = info.data ? customer.accounts.map((a) => info.data.balances.get(a.account_id)) : [];
  // A total is only shown when every balance was read.
  const total = bal.length && bal.every(Boolean) ? bal.reduce((s, b) => s + Number(b.available_balance || 0), 0) : null;
  const account = customer.accounts.find((a) => a.account_id === accountId) || customer.accounts[0];

  return (
    <div className="min-w-0 space-y-6">
      <section className="panel p-6 animate-rise" style={{ animationDelay: '60ms' }}>
        <div className="flex flex-wrap items-start gap-5">
          <span aria-hidden className="grid size-14 shrink-0 place-items-center rounded-full bg-mint-wash text-lg font-semibold text-mint-deep">{initials(customer.name)}</span>
          <div className="min-w-0 flex-1">
            <h2 className="text-xl font-semibold tracking-[-0.02em]">{p ? fullName(p) : customer.name}</h2>
            <p className="mt-0.5 truncate text-sm text-ink-500">
              {p?.email || 'Email unavailable'} <span className="font-mono text-xs text-ink-400">· {customer.user_id}</span>
            </p>
          </div>
          <div className="text-right">
            <p className="text-sm text-ink-400">Available across {customer.accounts.length} {customer.accounts.length === 1 ? 'account' : 'accounts'}</p>
            {info.loading ? <div className="skeleton ml-auto mt-1.5 h-7 w-36" /> : <p className="mt-0.5 text-2xl font-semibold tabular-nums tracking-[-0.02em]">{total == null ? '-' : money(total)}</p>}
          </div>
        </div>
        {info.data?.profile.status === 'rejected' && (
          <div className="mt-5"><ErrorNote message={`Profile unavailable: ${errorMessage(info.data.profile.reason)}`} onRetry={info.reload} /></div>
        )}
        {info.loading ? (
          <div className="skeleton mt-6 h-20" />
        ) : (
          <dl className="mt-6 grid grid-cols-2 gap-x-6 gap-y-3 border-t border-ink-100 pt-5 text-sm md:grid-cols-3">
            {[
              ['Phone', p?.phone_number],
              ['Government ID', p?.government_id],
              ['Date of birth', day(p?.dob)],
              ['Identity', p?.kyc_status && <Badge tone={KYC_TONE[p.kyc_status] || 'neutral'}>{titleCase(p.kyc_status)}</Badge>],
              ['Last seen', info.data?.location?.location_name],
              ['IP address', info.data?.location?.ip_address],
            ].map(([k, v]) => (
              <div key={k}>
                <dt className="text-ink-400">{k}</dt>
                <dd className="mt-0.5 font-medium break-words">{v || '-'}</dd>
              </div>
            ))}
          </dl>
        )}
      </section>

      <section className="panel overflow-hidden animate-rise" style={{ animationDelay: '120ms' }}>
        <p className="label px-5 pb-3 pt-5">Accounts</p>
        <ul>
          {customer.accounts.map((a) => (
            <AccountRow
              key={a.account_id}
              account={a}
              balance={info.data?.balances.get(a.account_id)}
              loading={info.loading}
              on={a.account_id === account?.account_id}
              onSelect={() => setAccountId(a.account_id)}
              canFreeze={canFreeze}
              onChanged={onChanged}
            />
          ))}
        </ul>
      </section>

      {account && <History account={account} owners={owners} onOpen={setTx} />}
      {tx && <TransferDrawer tx={tx} account={account} owners={owners} onClose={() => setTx(null)} />}
    </div>
  );
}

function AccountRow({ account: a, balance: b, loading, on, onSelect, canFreeze, onChanged }) {
  const { staff } = useAuth();
  const toast = useToast();
  const [confirm, setConfirm] = useState(false);
  const [reason, setReason] = useState(FREEZE_REASONS[0][0]);
  const [memo, setMemo] = useState('');
  const [busy, setBusy] = useState(false);
  const frozen = a.status === 'LOCKED';

  async function apply() {
    setBusy(true);
    try {
      await api.patch(`/accounts/${a.account_id}/status`, {
        status: frozen ? 'ACTIVE' : 'LOCKED',
        reason: frozen ? undefined : reason,
        memo: memo.trim() || undefined,
        actioned_by_user_id: staff.id,
      });
      toast(frozen ? `Account ${a.account_number} unfrozen.` : `Account ${a.account_number} frozen.`);
      setConfirm(false);
      setMemo('');
      onChanged();
    } catch (e) {
      toast(errorMessage(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  return (
    <li className={cn('border-t border-ink-100 transition-colors', on && 'bg-paper')}>
      <div className="flex items-center gap-4 px-5 py-4">
        <button onClick={onSelect} aria-pressed={on} className="flex min-w-0 flex-1 items-center gap-4 rounded-xl text-left">
          <span className={cn('grid size-10 shrink-0 place-items-center rounded-xl transition-colors', on ? 'bg-ink text-mint' : 'bg-mint-wash text-mint-deep')}>
            <Wallet className="size-5" />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block font-semibold">{titleCase(a.account_type)}</span>
            <span className="block truncate font-mono text-xs text-ink-400">{a.account_number}</span>
          </span>
          <span className="text-right">
            {loading ? (
              <span className="skeleton block h-5 w-28" />
            ) : b ? (
              <>
                <span className="block font-semibold tabular-nums">{money(b.available_balance)}</span>
                <span className="block text-xs tabular-nums text-ink-400">Ledger {money(b.current_balance)} · Held {money(b.held_balance)}</span>
              </>
            ) : (
              <span className="text-sm text-ink-400">Balance unavailable</span>
            )}
          </span>
        </button>
        <Badge tone={frozen ? 'danger' : a.status === 'ACTIVE' ? 'mint' : 'ember'} className="min-w-[4rem] justify-center">{frozen ? 'Frozen' : titleCase(a.status)}</Badge>
        {canFreeze && (
          <Button
            size="sm" variant={frozen ? 'outline' : 'danger'} icon={frozen ? LockOpen : Lock} className={cn('w-28', confirm && 'invisible')}
            disabled={!['ACTIVE', 'LOCKED'].includes(a.status)} onClick={() => setConfirm(true)}
          >
            {frozen ? 'Unfreeze' : 'Freeze'}
          </Button>
        )}
      </div>
      {confirm && (
        <div className="flex flex-wrap items-center gap-2 px-5 pb-4 animate-fade">
          {!frozen && (
            <select value={reason} onChange={(e) => setReason(e.target.value)} aria-label="Reason for freezing" className={cn(FIELD, 'pr-8')}>
              {FREEZE_REASONS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}
            </select>
          )}
          <input value={memo} onChange={(e) => setMemo(e.target.value)} placeholder="Note for the audit trail" aria-label="Note" className={cn(FIELD, 'min-w-[12rem] flex-1')} autoFocus />
          <Button size="sm" variant="ghost" onClick={() => setConfirm(false)}>Cancel</Button>
          <Button size="sm" variant={frozen ? 'primary' : 'danger'} loading={busy} onClick={apply}>{frozen ? 'Confirm unfreeze' : 'Confirm freeze'}</Button>
        </div>
      )}
    </li>
  );
}

function History({ account, owners, onOpen }) {
  const { data, error, loading, reload } = useLoad(() => api.get(`/transfers/accounts/${account.account_id}/transactions`).then((r) => r.data), [account.account_id]);
  const rows = (data || []).slice(0, SHOWN);

  return (
    <section className="panel overflow-hidden animate-rise" style={{ animationDelay: '180ms' }}>
      <div className="flex items-baseline justify-between gap-4 px-5 pb-3 pt-5">
        <p className="label">Transfers on {titleCase(account.account_type).toLowerCase()} {account.account_number}</p>
        {data?.length > SHOWN && <p className="text-xs text-ink-400">Latest {SHOWN} of {data.length}</p>}
      </div>
      {loading ? (
        <SkeletonRows rows={3} />
      ) : error ? (
        <div className="px-5 pb-5"><ErrorNote message={errorMessage(error)} onRetry={reload} /></div>
      ) : !rows.length ? (
        <Empty icon={ArrowLeftRight} title="No transfers on this account yet" />
      ) : (
        <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-y border-ink-100 text-left">
              {['When', 'Counterparty', 'Reference', 'Amount', 'Status'].map((h) => (
                <th key={h} className={cn('label px-4 py-3 font-semibold', h === 'Amount' && 'text-right')}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((t, i) => {
              const out = t.source_account_id === account.account_id;
              const other = out ? t.target_account_id : t.source_account_id;
              return (
                <tr
                  key={t.transaction_id}
                  tabIndex={0}
                  onClick={() => onOpen(t)}
                  onKeyDown={(e) => e.key === 'Enter' && onOpen(t)}
                  className="row-enter cursor-pointer border-b border-ink-100 transition-colors last:border-0 hover:bg-paper focus-visible:bg-paper"
                  style={{ '--i': Math.min(i, 12) }}
                >
                  <td className="whitespace-nowrap px-4 py-3.5 text-ink-500">{dateTime(t.created_at)}</td>
                  <td className="max-w-[14rem] px-4 py-3.5">
                    <span className="flex items-center gap-2">
                      {out ? <ArrowUpRight aria-hidden className="size-4 shrink-0 text-ink-400" /> : <ArrowDownLeft aria-hidden className="size-4 shrink-0 text-ok" />}
                      <span className="truncate"><span className="sr-only">{out ? 'Sent to ' : 'Received from '}</span>{owners.get(other) || other}</span>
                    </span>
                  </td>
                  <td className="whitespace-nowrap px-4 py-3.5 font-mono text-xs text-ink-500">{t.transaction_id}</td>
                  <td className={cn('whitespace-nowrap px-4 py-3.5 text-right font-semibold tabular-nums', !out && 'text-ok')}>{out ? '−' : '+'}{money(t.amount)}</td>
                  <td className="px-4 py-3.5"><Badge tone={TX_TONE[t.status] || 'neutral'}>{titleCase(t.status)}</Badge></td>
                </tr>
              );
            })}
          </tbody>
        </table>
        </div>
      )}
    </section>
  );
}

function TransferDrawer({ tx, account, owners, onClose }) {
  const { staff } = useAuth();
  const toast = useToast();
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  // An open ticket for this transfer, so the same reversal is not asked for twice.
  const open = useLoad(
    () => api.get('/reversals', { params: { status: 'PENDING' } }).then((r) => r.data.find((t) => t.originalTransactionId === tx.transaction_id)),
    [tx.transaction_id],
  );
  const name = (id) => (owners.get(id) ? `${owners.get(id)} · ${id}` : id);

  async function request() {
    setBusy(true);
    try {
      await api.post('/reversals/request', { originalTransactionId: tx.transaction_id, reason: reason.trim(), makerId: staff.id });
      toast('Reversal requested. A manager or compliance officer signs it off.');
      setReason('');
      open.reload();
    } catch (e) {
      toast(errorMessage(e), 'error');
    } finally {
      setBusy(false);
    }
  }

  const footer = !REVERSIBLE.includes(tx.status) ? (
    <p className="text-sm text-ink-500">Only settled transfers can be reversed. This one is {titleCase(tx.status).toLowerCase()}.</p>
  ) : open.data ? (
    <p className="text-sm text-ink-500">
      <b className="text-ink">{staffName(open.data.makerId)}</b> asked for a reversal {ago(open.data.createdAt)}. It is waiting for a checker on the Reversals page.
    </p>
  ) : (
    <div className="space-y-3">
      <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Why should this transfer be reversed?" aria-label="Reason for the reversal"
        className="h-11 w-full rounded-xl bg-paper px-4 text-sm ring-1 ring-inset ring-ink-100 focus:outline-none focus:ring-2 focus:ring-ink" />
      <div className="flex items-center justify-between gap-2">
        <p className="text-sm text-ink-500">A different person approves it before any money moves.</p>
        <Button icon={Undo2} loading={busy || open.loading} disabled={!reason.trim()} onClick={request}>Request reversal</Button>
      </div>
    </div>
  );

  return (
    <Drawer
      open onClose={onClose}
      title={money(tx.amount)}
      subtitle={`${tx.source_account_id === account.account_id ? 'Sent' : 'Received'} ${dateTime(tx.created_at)}`}
      footer={footer}
    >
      <div className="space-y-6">
        <dl className="panel grid grid-cols-2 gap-x-6 gap-y-3 p-5 text-sm animate-rise">
          {[
            ['From', name(tx.source_account_id)],
            ['To', name(tx.target_account_id)],
            ['Reference', tx.transaction_id],
            ['Status', titleCase(tx.status)],
            ['Type', titleCase(tx.transaction_type)],
            ['Memo', tx.memo || '-'],
          ].map(([k, v]) => (
            <div key={k}>
              <dt className="text-ink-400">{k}</dt>
              <dd className="font-medium break-words">{v}</dd>
            </div>
          ))}
        </dl>
        <Lifecycle txId={tx.transaction_id} />
      </div>
    </Drawer>
  );
}
