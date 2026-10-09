import { useState } from 'react';
import { ArrowLeftRight, MapPin, ShieldAlert } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { ago, money, titleCase } from '../lib/format';
import { useAuth, staffName } from '../context/Auth';
import { Badge, Button, Drawer, Empty, ErrorNote, PageHeader, SkeletonRows, useLoad, useToast } from '../components/ui';

/** Why a transfer is on hold, in plain words. */
export function holdReason(t) {
  const r = t.riskReason || '';
  if (r.startsWith('IMPOSSIBLE_TRAVEL')) return { tone: 'danger', label: 'Impossible travel', detail: r.replace('IMPOSSIBLE_TRAVEL: ', '') };
  if (t.requires2FaOtp === 1) return { tone: 'sky', label: 'Waiting for customer OTP', detail: 'Above PHP 50,000. The customer confirms with an emailed code.' };
  if (r) return { tone: 'ember', label: titleCase(r), detail: 'Flagged by Laya.' };
  return { tone: 'ember', label: 'Needs approval', detail: 'Held for a checker.' };
}

export default function Transfers() {
  const { data, error, loading, reload } = useLoad(() => api.get('/transfers/pending').then((r) => r.data), []);
  const [open, setOpen] = useState(null);
  const rows = (data || []).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  return (
    <>
      <PageHeader title="Held transfers" description="Funds are reserved on the sender's account and nothing has moved. Release or reject each one." />
      <div className="panel overflow-hidden animate-rise" style={{ animationDelay: '60ms' }}>
        {loading ? (
          <SkeletonRows />
        ) : error ? (
          <div className="p-5"><ErrorNote message={errorMessage(error)} onRetry={reload} /></div>
        ) : rows.length === 0 ? (
          <Empty icon={ArrowLeftRight} title="No transfers on hold" body="Transfers flagged by Laya, above the OTP threshold, or from an impossible location appear here." />
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-ink-100 text-left">
                {['Transfer', 'From', 'To', 'Amount', 'Reason', 'Held'].map((h) => <th key={h} className="label px-5 py-3 font-semibold">{h}</th>)}
              </tr>
            </thead>
            <tbody>
              {rows.map((t, i) => {
                const why = holdReason(t);
                return (
                  <tr key={t.transactionId} onClick={() => setOpen(t)} className="row-enter cursor-pointer border-b border-ink-100 last:border-0 transition-colors hover:bg-paper" style={{ '--i': i }}>
                    <td className="px-5 py-4 font-mono text-xs">{t.transactionId}</td>
                    <td className="px-5 py-4">{t.fromAccountId}</td>
                    <td className="px-5 py-4">{t.toAccountId}</td>
                    <td className="px-5 py-4 font-semibold tabular-nums">{money(t.amount)}</td>
                    <td className="px-5 py-4"><Badge tone={why.tone}>{why.label}</Badge></td>
                    <td className="px-5 py-4 text-ink-400">{ago(t.createdAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
      {open && <TransferDrawer tx={open} onClose={() => setOpen(null)} onDone={() => { setOpen(null); reload(); }} />}
    </>
  );
}

function TransferDrawer({ tx, onClose, onDone }) {
  const { staff } = useAuth();
  const toast = useToast();
  const [remarks, setRemarks] = useState('');
  const [busy, setBusy] = useState(null);
  const why = holdReason(tx);
  const needsSecond = Number(tx.amount) >= 500000 && !tx.approvedByUserId;

  async function decide(kind) {
    setBusy(kind);
    try {
      const { data } = await api.post(`/transfers/${tx.transactionId}/${kind}`, { transactionId: tx.transactionId, checkerUserId: staff.id, remarks });
      toast(kind === 'reject' ? 'Transfer rejected and the hold released.' : data?.status === 'PENDING_APPROVAL' ? 'First approval recorded. A second approver is needed.' : 'Transfer released and settled.');
      onDone();
    } catch (e) {
      toast(errorMessage(e), 'error');
    } finally {
      setBusy(null);
    }
  }

  return (
    <Drawer
      open onClose={onClose} title={money(tx.amount)} subtitle={`${tx.fromAccountId} to ${tx.toAccountId}`}
      footer={
        <div className="space-y-3">
          <input value={remarks} onChange={(e) => setRemarks(e.target.value)} placeholder="Remarks for the audit trail"
            className="h-11 w-full rounded-xl bg-paper px-4 text-sm ring-1 ring-inset ring-ink-100 focus:outline-none focus:ring-2 focus:ring-ink" />
          <div className="flex justify-end gap-2">
            <Button variant="danger" loading={busy === 'reject'} onClick={() => decide('reject')}>Reject</Button>
            <Button loading={busy === 'approve'} onClick={() => decide('approve')}>{needsSecond ? 'Approve (1 of 2)' : 'Release transfer'}</Button>
          </div>
        </div>
      }
    >
      <div className="space-y-5">
        <div className={`rounded-2xl p-5 animate-rise ${why.tone === 'danger' ? 'bg-danger-wash' : 'bg-ember-wash'}`}>
          <div className="flex items-center gap-2 font-semibold">
            {why.tone === 'danger' ? <MapPin className="size-4 text-danger" /> : <ShieldAlert className="size-4 text-ember-deep" />}
            {why.label}
          </div>
          <p className="mt-1.5 text-[15px] text-ink-700">{why.detail}</p>
        </div>
        <dl className="panel grid grid-cols-2 gap-x-6 gap-y-3 p-5 text-sm">
          {[
            ['Reference', tx.transactionId],
            ['Risk score', tx.riskScore != null ? `${Number(tx.riskScore).toFixed(0)} / 100` : '-'],
            ['Location', tx.locationName || (tx.latitude != null ? `${Number(tx.latitude).toFixed(3)}, ${Number(tx.longitude).toFixed(3)}` : '-')],
            ['IP address', tx.ipAddress || '-'],
            ['First approver', tx.approvedByUserId ? staffName(tx.approvedByUserId) : '-'],
            ['Placed', ago(tx.createdAt)],
          ].map(([k, v]) => (
            <div key={k}>
              <dt className="text-ink-400">{k}</dt>
              <dd className="font-medium break-words">{v}</dd>
            </div>
          ))}
        </dl>
        {needsSecond && <p className="text-sm text-ink-500">PHP 500,000 and above needs two different approvers.</p>}
      </div>
    </Drawer>
  );
}
