// Ported from Zel's admin portal (AdminExecutivePortal.jsx: Transactions & Reversals, maker-checker rollback), now on his dual-control /reversals API.
import { useState } from 'react';
import { Undo2, XCircle } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { ago, dateTime, money, titleCase } from '../lib/format';
import { BRANCH_ROLES, REVERSAL_CHECKERS, staffName, useAuth } from '../context/Auth';
import { Badge, Button, Drawer, Empty, ErrorNote, PageHeader, SkeletonRows, cn, useLoad, useToast } from '../components/ui';
import { Step } from './Kyc';

/** Ledger statuses a reversal can undo (same rule as executeT24Reversal). */
export const REVERSIBLE = ['COMMITTED', 'POSTED', 'SETTLED'];

const TABS = [
  { key: 'PENDING', label: 'Needs sign-off' },
  { key: 'DONE', label: 'Decided' },
];
const TONE = { PENDING: 'sky', APPROVED: 'ink', REJECTED: 'neutral' };
const LABEL = { PENDING: 'Waiting for checker', APPROVED: 'Reversed', REJECTED: 'Rejected' };

export default function Reversals() {
  const { staff } = useAuth();
  const [tab, setTab] = useState('PENDING');
  const [openId, setOpenId] = useState(null);
  const { data, error, loading, reload } = useLoad(async () => {
    // shortcut: reads the whole journal to show each ticket's amount; ask for amount on ReversalTicketDto when volumes grow.
    const [tickets, journal] = await Promise.all([
      api.get('/reversals').then((r) => r.data),
      api.get('/transfers/transactions').then((r) => r.data).catch(() => []),
    ]);
    const byId = new Map(journal.map((t) => [t.transaction_id, t]));
    return tickets.map((t) => ({ ...t, tx: byId.get(t.originalTransactionId) }));
  }, []);

  const pending = (data || []).filter((t) => t.status === 'PENDING');
  const rows = tab === 'PENDING' ? pending : (data || []).filter((t) => t.status !== 'PENDING');
  const counts = { PENDING: pending.length, DONE: (data?.length || 0) - pending.length };
  const open = data?.find((t) => t.ticketId === openId);

  return (
    <>
      <PageHeader
        title="Reversals"
        description="A maker asks to reverse a settled transfer, and a different checker approves or rejects it. Approving posts a compensating entry; the original stays in the ledger."
      />

      <div className="panel overflow-hidden animate-rise" style={{ animationDelay: '60ms' }}>
        <div className="flex gap-1 border-b border-ink-100 p-2">
          {TABS.map((s) => (
            <button
              key={s.key}
              onClick={() => setTab(s.key)}
              className={cn('flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-semibold transition-colors', tab === s.key ? 'bg-ink text-white' : 'text-ink-500 hover:bg-ink-100')}
            >
              {s.label}
              {data && <span className={cn('rounded-full px-1.5 text-xs tabular-nums', tab === s.key ? 'bg-white/15' : 'bg-ink-100')}>{counts[s.key]}</span>}
            </button>
          ))}
        </div>

        {loading && !data ? (
          <SkeletonRows />
        ) : error ? (
          <div className="p-5"><ErrorNote message={errorMessage(error)} onRetry={reload} /></div>
        ) : rows.length === 0 ? (
          <Empty
            icon={Undo2}
            title={tab === 'PENDING' ? 'No reversals waiting' : 'Nothing decided yet'}
            body={BRANCH_ROLES.includes(staff?.role) ? "Open a settled transfer in a customer's history to request one." : 'Requests from branch operations appear here for a second person to sign off.'}
          />
        ) : (
          <ul>
            {rows.map((t, i) => (
              <li key={t.ticketId} className="row-enter border-b border-ink-100 last:border-0" style={{ '--i': i }}>
                <button onClick={() => setOpenId(t.ticketId)} className="flex w-full items-center gap-5 px-5 py-4 text-left transition-colors hover:bg-paper">
                  <div className="grid size-10 shrink-0 place-items-center rounded-xl bg-ember-wash text-ember-deep"><Undo2 className="size-5" /></div>
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold tabular-nums">{t.tx ? money(t.tx.amount) : t.originalTransactionId}</p>
                    <p className="truncate text-sm text-ink-500">{t.disputeReason}</p>
                  </div>
                  <div className="hidden text-right text-sm md:block">
                    <p className="font-mono text-xs text-ink-500">{t.originalTransactionId}</p>
                    <p className="text-ink-400">{staffName(t.makerId)} · {ago(t.createdAt)}</p>
                  </div>
                  <Badge tone={TONE[t.status] || 'neutral'}>{LABEL[t.status] || titleCase(t.status)}</Badge>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      {open && <ReversalDrawer ticket={open} onClose={() => setOpenId(null)} onChanged={reload} />}
    </>
  );
}

function ReversalDrawer({ ticket: t, onClose, onChanged }) {
  const { staff } = useAuth();
  const toast = useToast();
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(null);
  const isMaker = t.makerId === staff?.id;

  async function decide(kind) {
    setBusy(kind);
    try {
      // The ledger fills in a stock note when none is sent, so always send what the checker wrote.
      await api.post(`/reversals/${kind}`, { reversalRequestId: t.ticketId, checkerId: staff.id, ...(kind === 'approve' ? { checkerNotes: note } : { rejectionReason: note }) });
      toast(kind === 'approve' ? 'Reversal approved. The compensating entry is posted.' : 'Reversal rejected. The transfer stands.');
      setNote('');
      onChanged();
    } catch (e) {
      toast(errorMessage(e), 'error');
    } finally {
      setBusy(null);
    }
  }

  const footer =
    t.status !== 'PENDING' ? null : isMaker ? (
      <p className="text-sm text-ink-500">You requested this reversal. Another reviewer has to sign off.</p>
    ) : !REVERSAL_CHECKERS.includes(staff?.role) ? (
      <p className="text-sm text-ink-500">A manager or compliance officer signs off reversals.</p>
    ) : (
      <div className="space-y-3">
        <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="Note (required to reject)" aria-label="Checker note"
          className="h-11 w-full rounded-xl bg-paper px-4 text-sm ring-1 ring-inset ring-ink-100 focus:outline-none focus:ring-2 focus:ring-ink" />
        <div className="flex items-center justify-between gap-2">
          <p className="text-sm text-ink-500"><b className="text-ink">{staffName(t.makerId)}</b> asks to reverse this transfer</p>
          <div className="flex gap-2">
            <Button variant="danger" icon={XCircle} loading={busy === 'reject'} disabled={!note.trim() || !!busy} onClick={() => decide('reject')}>Reject</Button>
            <Button icon={Undo2} loading={busy === 'approve'} disabled={!!busy} onClick={() => decide('approve')}>Approve reversal</Button>
          </div>
        </div>
      </div>
    );

  return (
    <Drawer
      open onClose={onClose}
      title={t.tx ? money(t.tx.amount) : t.originalTransactionId}
      subtitle={t.tx ? `${t.tx.source_account_id} to ${t.tx.target_account_id}` : 'Transfer not found in the journal'}
      footer={footer}
    >
      <div className="space-y-6">
        <div className="rounded-2xl bg-ember-wash p-5 animate-rise">
          <div className="flex items-center gap-2 font-semibold"><Undo2 className="size-4 text-ember-deep" />{t.disputeReason}</div>
          <p className="mt-1.5 text-[15px] text-ink-700">
            {t.status === 'APPROVED'
              ? `Reversed. Compensating entry ${t.reversalTransactionId || '-'} returned the funds.`
              : t.status === 'REJECTED'
                ? 'Rejected. The transfer stands as posted.'
                : 'Approving moves the amount back from the receiving account to the sender with a compensating entry.'}
          </p>
        </div>

        <dl className="panel grid grid-cols-2 gap-x-6 gap-y-3 p-5 text-sm">
          {[
            ['Original transfer', t.originalTransactionId],
            ['Transfer status', t.tx ? titleCase(t.tx.status) : '-'],
            ['Placed', t.tx ? dateTime(t.tx.created_at) : '-'],
            ['Ticket', t.ticketId],
          ].map(([k, v]) => (
            <div key={k}>
              <dt className="text-ink-400">{k}</dt>
              <dd className="font-medium break-words">{v}</dd>
            </div>
          ))}
        </dl>

        <section>
          <p className="label mb-3">Sign-off trail</p>
          <ol className="space-y-3 text-sm">
            <Step who={staffName(t.makerId)} when={t.createdAt} text="Requested the reversal." />
            {t.checkerId && <Step who={staffName(t.checkerId)} when={t.resolvedAt} text={`${t.status === 'APPROVED' ? 'Approved' : 'Rejected'}.${t.checkerNotes ? ` "${t.checkerNotes}"` : ''}`} />}
          </ol>
        </section>

        <Lifecycle txId={t.originalTransactionId} />
      </div>
    </Drawer>
  );
}

const actor = (h) => (['SERVICE', 'SYSTEM'].includes(h.actorType) ? titleCase(h.actorId) : staffName(h.actorId));

/** The transfer's recorded status changes, oldest first (Zel's lifecycle inspector, on real history). */
export function Lifecycle({ txId }) {
  const { data, error, loading, reload } = useLoad(() => api.get(`/transfers/${txId}/status-history`).then((r) => r.data), [txId]);
  return (
    <section>
      <p className="label mb-3">Lifecycle</p>
      {loading ? (
        <div className="skeleton h-16" />
      ) : error ? (
        <ErrorNote message={errorMessage(error)} onRetry={reload} />
      ) : !data.length ? (
        <p className="text-sm text-ink-400">No status changes recorded.</p>
      ) : (
        <ol className="space-y-3 text-sm">
          {data.map((h) => (
            <Step key={h.historyId} who={titleCase(h.toStatus)} when={h.changedAt} text={[h.reasonDetails || titleCase(h.changeReason), actor(h)].join(' · ')} />
          ))}
        </ol>
      )}
    </section>
  );
}
