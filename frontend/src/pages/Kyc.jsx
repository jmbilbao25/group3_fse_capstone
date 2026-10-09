import { useMemo, useState } from 'react';
import { ScanFace, Sparkles, UserCheck, UserX, Undo2, Maximize2, ImageOff } from 'lucide-react';
import { api, errorMessage } from '../lib/api';
import { ago, dateTime, fullName, idTypeLabel, titleCase } from '../lib/format';
import { staffName, useAuth } from '../context/Auth';
import { Badge, Button, ConfidenceRing, Drawer, Empty, ErrorNote, PageHeader, SkeletonRows, cn, useLoad, useToast } from '../components/ui';

const STAGES = [
  { key: 'PENDING_MAKER', label: 'Needs maker' },
  { key: 'PENDING_CHECKER', label: 'Needs checker' },
  { key: 'DONE', label: 'Decided' },
];

const LAYA_TONE = { APPROVED: 'mint', PENDING_REVIEW: 'ember', REJECTED: 'danger' };
const LAYA_LABEL = { APPROVED: 'Recommends approve', PENDING_REVIEW: 'Unsure', REJECTED: 'Recommends reject' };

export default function Kyc() {
  const [stage, setStage] = useState('PENDING_MAKER');
  const [openId, setOpenId] = useState(null);
  const { data, error, loading, reload } = useLoad(() => api.get('/kyc/reviews').then((r) => r.data), []);

  const counts = useMemo(() => {
    const c = { PENDING_MAKER: 0, PENDING_CHECKER: 0, DONE: 0 };
    (data || []).forEach((r) => (c[r.status in c ? r.status : 'DONE'] += 1));
    return c;
  }, [data]);
  const rows = (data || []).filter((r) => (stage === 'DONE' ? !['PENDING_MAKER', 'PENDING_CHECKER'].includes(r.status) : r.status === stage));

  return (
    <>
      <PageHeader
        title="Identity review"
        description="Laya reads each ID and selfie and suggests a decision. A maker recommends, and a different checker confirms before the customer is verified."
      />

      <div className="panel overflow-hidden animate-rise" style={{ animationDelay: '60ms' }}>
        <div className="flex gap-1 border-b border-ink-100 p-2">
          {STAGES.map((s) => (
            <button
              key={s.key}
              onClick={() => setStage(s.key)}
              className={cn(
                'flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-semibold transition-colors',
                stage === s.key ? 'bg-ink text-white' : 'text-ink-500 hover:bg-ink-100',
              )}
            >
              {s.label}
              <span className={cn('rounded-full px-1.5 text-xs tabular-nums', stage === s.key ? 'bg-white/15' : 'bg-ink-100')}>{counts[s.key]}</span>
            </button>
          ))}
        </div>

        {loading ? (
          <SkeletonRows />
        ) : error ? (
          <div className="p-5"><ErrorNote message={errorMessage(error)} onRetry={reload} /></div>
        ) : rows.length === 0 ? (
          <Empty icon={ScanFace} title="Nothing waiting here" body="New applications appear as soon as a customer finishes the ID and selfie steps in the app." />
        ) : (
          <ul>
            {rows.map((r, i) => (
              <li key={r.user_id} className="row-enter" style={{ '--i': i }}>
                <button onClick={() => setOpenId(r.user_id)} className="flex w-full items-center gap-5 border-b border-ink-100 px-5 py-4 text-left transition-colors last:border-0 hover:bg-paper">
                  <ConfidenceRing value={r.confidence_score} size={48} />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <p className="font-semibold">{r.user_id}</p>
                      <Badge tone={LAYA_TONE[r.laya_decision] || 'neutral'}>
                        <Sparkles className="size-3" /> {LAYA_LABEL[r.laya_decision] || 'No result'}
                      </Badge>
                    </div>
                    <p className="mt-0.5 truncate text-sm text-ink-500">{r.laya_summary}</p>
                  </div>
                  <div className="hidden text-right text-sm md:block">
                    <p className="text-ink-500">{idTypeLabel(r.id_type)}</p>
                    <p className="text-ink-400">{ago(r.submitted_at)}</p>
                  </div>
                  {r.status === 'PENDING_CHECKER' && <Badge tone="sky">{staffName(r.maker_id)} recommends {r.maker_decision?.toLowerCase()}</Badge>}
                  {['APPROVED', 'REJECTED'].includes(r.status) && <Badge tone={r.status === 'APPROVED' ? 'mint' : 'danger'}>{titleCase(r.status)}</Badge>}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      {openId && <ReviewDrawer userId={openId} onClose={() => setOpenId(null)} onChanged={reload} />}
    </>
  );
}

function ReviewDrawer({ userId, onClose, onChanged }) {
  const { staff } = useAuth();
  const toast = useToast();
  const { data, error, loading, reload } = useLoad(() => api.get(`/kyc/${userId}/review`).then((r) => r.data), [userId]);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(null);
  const [zoom, setZoom] = useState(null);

  const review = data?.review;
  const profile = data?.profile;
  const isMaker = review?.maker_id === staff?.id;

  async function act(kind, payload) {
    setBusy(kind);
    try {
      await api.post(`/kyc/${userId}/${kind === 'recommend' ? 'recommend' : 'check'}`, payload);
      toast(kind === 'recommend' ? 'Recommendation recorded. A checker will confirm it.' : payload.action === 'CONFIRM' ? 'Decision confirmed. The customer has been notified.' : 'Sent back to the maker.');
      setNote('');
      onChanged();
      reload();
    } catch (e) {
      toast(errorMessage(e), 'error');
    } finally {
      setBusy(null);
    }
  }

  const footer = review && (
    <div className="space-y-3">
      {['PENDING_MAKER', 'PENDING_CHECKER'].includes(review.status) && (
        <textarea
          value={note} onChange={(e) => setNote(e.target.value)} rows={2}
          placeholder={review.status === 'PENDING_MAKER' ? 'Note for the checker (required to reject)' : 'Note (optional)'}
          className="w-full resize-none rounded-xl bg-paper px-4 py-3 text-sm ring-1 ring-inset ring-ink-100 focus:outline-none focus:ring-2 focus:ring-ink"
        />
      )}
      {review.status === 'PENDING_MAKER' && (
        <div className="flex justify-end gap-2">
          <Button variant="danger" icon={UserX} loading={busy === 'reject'} disabled={!note.trim()} onClick={() => act('recommend', { decision: 'REJECT', note })}>Recommend reject</Button>
          <Button icon={UserCheck} loading={busy === 'approve'} onClick={() => act('recommend', { decision: 'APPROVE', note })}>Recommend approve</Button>
        </div>
      )}
      {review.status === 'PENDING_CHECKER' &&
        (isMaker ? (
          <p className="text-sm text-ink-500">You made this recommendation. Another reviewer has to check it.</p>
        ) : (
          <div className="flex items-center justify-between gap-2">
            <p className="text-sm text-ink-500">
              <b className="text-ink">{staffName(review.maker_id)}</b> recommends <b className="text-ink">{review.maker_decision?.toLowerCase()}</b>
            </p>
            <div className="flex gap-2">
              <Button variant="outline" icon={Undo2} loading={busy === 'return'} onClick={() => act('check', { action: 'RETURN', note })}>Send back</Button>
              <Button variant={review.maker_decision === 'REJECT' ? 'danger' : 'primary'} loading={busy === 'confirm'} onClick={() => act('check', { action: 'CONFIRM', note })}>
                Confirm {review.maker_decision?.toLowerCase()}
              </Button>
            </div>
          </div>
        ))}
    </div>
  );

  return (
    <Drawer open onClose={onClose} title={profile ? fullName(profile) : userId} subtitle={profile ? `${profile.email}  ·  ${userId}` : 'Loading'} footer={footer} width="max-w-3xl">
      {loading ? (
        <SkeletonRows rows={4} />
      ) : error ? (
        <ErrorNote message={errorMessage(error)} onRetry={reload} />
      ) : (
        <div className="space-y-6">
          <section className="panel flex gap-5 p-5 animate-rise">
            <ConfidenceRing value={review.confidence_score} size={84} />
            <div className="min-w-0">
              <div className="flex items-center gap-2">
                <Sparkles className="size-4 text-mint-deep" />
                <p className="font-semibold">Laya summary</p>
                <Badge tone={LAYA_TONE[review.laya_decision] || 'neutral'}>{LAYA_LABEL[review.laya_decision]}</Badge>
              </div>
              <p className="mt-2 text-[15px] leading-relaxed text-ink-700">{review.laya_summary}</p>
              <p className="mt-2 text-xs text-ink-400">A suggestion, not a decision. Check the images yourself.</p>
            </div>
          </section>

          <section className="grid grid-cols-3 gap-3">
            {['front', 'back', 'selfie'].map((k, i) => (
              <figure key={k} className="animate-rise" style={{ animationDelay: `${80 + i * 50}ms` }}>
                <button
                  onClick={() => data.images?.[k] && setZoom(k)}
                  className="group relative block aspect-[4/3] w-full overflow-hidden rounded-xl bg-ink-100"
                  aria-label={`Open ${k} image`}
                >
                  {data.images?.[k] ? (
                    <>
                      <img src={data.images[k]} alt={`${k} of submitted ${idTypeLabel(review.id_type)}`} className="size-full object-cover transition-transform duration-500 ease-out group-hover:scale-105" loading="lazy" />
                      <Maximize2 className="absolute right-2 top-2 size-7 rounded-full bg-ink/60 p-1.5 text-white opacity-0 transition-opacity group-hover:opacity-100" />
                    </>
                  ) : (
                    <span className="grid size-full place-items-center text-ink-400"><ImageOff className="size-5" /></span>
                  )}
                </button>
                <figcaption className="mt-1.5 text-xs font-medium text-ink-500">{k === 'selfie' ? 'Selfie' : `ID ${k}`}</figcaption>
              </figure>
            ))}
          </section>

          <section className="panel grid grid-cols-2 gap-x-6 gap-y-3 p-5 text-sm">
            <Fact k="Declared name" v={fullName(profile)} />
            <Fact k="Date of birth" v={profile.dob} />
            <Fact k="Document" v={idTypeLabel(review.id_type)} />
            <Fact k="Government ID" v={profile.government_id} />
            <Fact k="Face match" v={review.face_similarity != null ? `${Math.round(review.face_similarity * 100)}%` : '-'} />
            <Fact k="Liveness" v={review.liveness_score != null ? `${Math.round(review.liveness_score * 100)}%` : '-'} />
          </section>

          {review.laya_flags?.length > 0 && (
            <section>
              <p className="label mb-2">Flags</p>
              <div className="flex flex-wrap gap-1.5">{review.laya_flags.map((f) => <Badge key={f} tone="ember">{titleCase(f)}</Badge>)}</div>
            </section>
          )}

          <section>
            <p className="label mb-3">Trail</p>
            <ol className="space-y-3 text-sm">
              <Step who="Laya" when={review.submitted_at} text={`Scored ${review.confidence_score ?? '-'}% and suggested ${LAYA_LABEL[review.laya_decision]?.toLowerCase()}.`} />
              {review.maker_id && <Step who={staffName(review.maker_id)} when={review.maker_at} text={`Recommended ${review.maker_decision?.toLowerCase()}.${review.maker_note ? ` "${review.maker_note}"` : ''}`} />}
              {review.checker_id && <Step who={staffName(review.checker_id)} when={review.checker_at} text={`${review.status === 'PENDING_MAKER' ? 'Sent back' : 'Confirmed'}.${review.checker_note ? ` "${review.checker_note}"` : ''}`} />}
            </ol>
          </section>
        </div>
      )}

      {zoom && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-ink/80 p-10 animate-fade" onClick={() => setZoom(null)}>
          <img src={data.images[zoom]} alt={`${zoom} enlarged`} className="max-h-full max-w-full rounded-2xl shadow-lift animate-rise" />
        </div>
      )}
    </Drawer>
  );
}

const Fact = ({ k, v }) => (
  <div>
    <p className="text-ink-400">{k}</p>
    <p className="font-medium">{v || '-'}</p>
  </div>
);

export const Step = ({ who, when, text }) => (
  <li className="flex gap-3">
    <span className="mt-1.5 size-2 shrink-0 rounded-full bg-mint-deep" />
    <div>
      <p><b>{who}</b> <span className="text-ink-400">{dateTime(when)}</span></p>
      <p className="text-ink-500">{text}</p>
    </div>
  </li>
);
