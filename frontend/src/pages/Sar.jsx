import { useState } from 'react';
import { FileWarning, Send, Undo2, XCircle } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { ago, dateTime, titleCase } from '../lib/format';
import { staffName, useAuth } from '../context/Auth';
import { Badge, Button, Drawer, Empty, ErrorNote, PageHeader, SkeletonRows, useLoad, useToast } from '../components/ui';

const STATUS_TONE = { DRAFT: 'ember', PENDING_CHECKER: 'sky', FILED: 'ink', DISMISSED: 'neutral' };

export default function Sar() {
  const { data, error, loading, reload } = useLoad(() => api.get('/risk/sar').then((r) => r.data), []);
  const [open, setOpen] = useState(null);

  return (
    <>
      <PageHeader
        title="SAR / STR"
        description="Laya drafts a Suspicious Transaction Report for the AMLC when it blocks or flags a transfer. A maker recommends filing or dismissing, and a different checker signs off."
      />
      <div className="panel overflow-hidden animate-rise" style={{ animationDelay: '60ms' }}>
        {loading ? (
          <SkeletonRows />
        ) : error ? (
          <div className="p-5"><ErrorNote message={errorMessage(error)} onRetry={reload} /></div>
        ) : !data?.length ? (
          <Empty icon={FileWarning} title="No reports drafted" body="Drafts appear here when Laya blocks a transfer or scores it 80 or above." />
        ) : (
          <ul>
            {data.map((r, i) => (
              <li key={r.transaction_id} className="row-enter" style={{ '--i': i }}>
                <button onClick={() => setOpen(r.transaction_id)} className="flex w-full items-center gap-5 border-b border-ink-100 px-5 py-4 text-left transition-colors last:border-0 hover:bg-paper">
                  <div className="grid size-10 shrink-0 place-items-center rounded-xl bg-danger-wash text-danger"><FileWarning className="size-5" /></div>
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold">{r.report_number || r.transaction_id}</p>
                    <p className="truncate text-sm text-ink-500">{titleCase(r.reason_code)} · {r.amount || '-'}</p>
                  </div>
                  <span className="hidden text-sm tabular-nums text-ink-500 md:block">{r.risk_score}</span>
                  <Badge tone={STATUS_TONE[r.review?.status] || 'neutral'}>{titleCase(r.review?.status)}</Badge>
                  <span className="w-20 text-right text-sm text-ink-400">{ago(r.created_at)}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
      {open && <SarDrawer txId={open} onClose={() => setOpen(null)} onChanged={reload} />}
    </>
  );
}

function SarDrawer({ txId, onClose, onChanged }) {
  const { staff } = useAuth();
  const toast = useToast();
  const { data, error, loading, reload } = useLoad(() => api.get(`/risk/sar/${txId}`).then((r) => r.data), [txId]);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(null);
  const state = data?.review;

  async function act(action) {
    setBusy(action);
    try {
      await api.post(`/risk/sar/${txId}/review`, { reviewer_id: staff.id, action, note });
      toast({ RECOMMEND_FILE: 'Recommended for filing.', RECOMMEND_DISMISS: 'Recommended for dismissal.', CONFIRM: 'Signed off.', RETURN: 'Returned to draft.' }[action]);
      setNote('');
      onChanged();
      reload();
    } catch (e) {
      toast(errorMessage(e), 'error');
    } finally {
      setBusy(null);
    }
  }

  const isMaker = state?.maker?.id === staff?.id;
  const footer = state && ['DRAFT', 'PENDING_CHECKER'].includes(state.status) && (
    <div className="space-y-3">
      <input value={note} onChange={(e) => setNote(e.target.value)} placeholder={state.status === 'DRAFT' ? 'Reason (required to dismiss)' : 'Note (optional)'}
        className="h-11 w-full rounded-xl bg-paper px-4 text-sm ring-1 ring-inset ring-ink-100 focus:outline-none focus:ring-2 focus:ring-ink" />
      {state.status === 'DRAFT' ? (
        <div className="flex justify-end gap-2">
          <Button variant="outline" icon={XCircle} loading={busy === 'RECOMMEND_DISMISS'} disabled={!note.trim()} onClick={() => act('RECOMMEND_DISMISS')}>Recommend dismiss</Button>
          <Button icon={Send} loading={busy === 'RECOMMEND_FILE'} onClick={() => act('RECOMMEND_FILE')}>Recommend filing</Button>
        </div>
      ) : isMaker ? (
        <p className="text-sm text-ink-500">You made this recommendation. Another reviewer has to sign off.</p>
      ) : (
        <div className="flex items-center justify-between gap-2">
          <p className="text-sm text-ink-500"><b className="text-ink">{staffName(state.maker.id)}</b> recommends {state.maker.recommendation.toLowerCase()}</p>
          <div className="flex gap-2">
            <Button variant="outline" icon={Undo2} loading={busy === 'RETURN'} onClick={() => act('RETURN')}>Send back</Button>
            <Button loading={busy === 'CONFIRM'} onClick={() => act('CONFIRM')}>Sign off</Button>
          </div>
        </div>
      )}
    </div>
  );

  return (
    <Drawer open onClose={onClose} title={data?.report_number || txId} subtitle={data ? `Intercepted ${dateTime(data.intercepted_at || data.created_at)}` : ''} footer={footer} width="max-w-3xl">
      {loading ? (
        <SkeletonRows rows={4} />
      ) : error ? (
        <ErrorNote message={errorMessage(error)} onRetry={reload} />
      ) : (
        <div className="space-y-6">
          <div className="grid grid-cols-3 gap-3 animate-rise">
            {[['Risk score', data.risk_score], ['Amount', data.amount], ['Velocity', data.velocity]].map(([k, v]) => (
              <div key={k} className="panel p-4">
                <p className="text-sm text-ink-400">{k}</p>
                <p className="mt-1 text-lg font-semibold tabular-nums">{v || '-'}</p>
              </div>
            ))}
          </div>
          {data.narrative && (
            <section>
              <p className="label mb-2">Laya narrative</p>
              <p className="text-[15px] leading-relaxed text-ink-700">{data.narrative}</p>
            </section>
          )}
          {data.red_flags?.length > 0 && (
            <section>
              <p className="label mb-2">Red flags</p>
              <ul className="space-y-1.5 text-sm">{data.red_flags.map((f) => <li key={f} className="flex gap-2"><span className="mt-2 size-1.5 shrink-0 rounded-full bg-danger" />{f}</li>)}</ul>
            </section>
          )}
          <details className="panel p-5">
            <summary className="cursor-pointer font-semibold">Full report</summary>
            <pre className="mt-4 overflow-x-auto whitespace-pre-wrap font-mono text-xs leading-relaxed text-ink-700">{data.document}</pre>
          </details>
          {state?.history?.length > 0 && (
            <section>
              <p className="label mb-2">Sign-off trail</p>
              <ol className="space-y-2 text-sm">
                {state.history.map((h) => <li key={h.at}><b>{staffName(h.by)}</b> {titleCase(h.action).toLowerCase()} <span className="text-ink-400">{dateTime(h.at)}</span>{h.note && <span className="text-ink-500"> "{h.note}"</span>}</li>)}
              </ol>
            </section>
          )}
        </div>
      )}
    </Drawer>
  );
}
