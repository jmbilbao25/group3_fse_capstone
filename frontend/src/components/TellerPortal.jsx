import React, { useState, useEffect } from 'react';
import {
  AlertTriangle,
  CheckCircle2,
  Clock,
  ExternalLink,
  Inbox,
  RefreshCw,
  XCircle,
} from 'lucide-react';
import { LedgerService, NotificationService } from '../api/client';
import {
  Badge,
  Button,
  Callout,
  EmptyState,
  Money,
  Panel,
  PanelHeader,
  Select,
  Table,
  TableScroll,
  Td,
  Th,
  Tr,
  tierOf,
} from '../ui';

/*
 * Teller station: the dual-control queue.
 *
 * Behaviour is unchanged. What changed is that the page now states the rule it
 * enforces in one place, at the top, instead of scattering "BSP Circular 808"
 * and "Segregation of Duties strictly verified" citations across six tinted
 * boxes. A teller needs to know the threshold and who may sign; the circular
 * number belongs in the audit trail, not on the work surface.
 *
 * The four notification scenarios were a wall of four near-identical cards, each
 * with its own accent colour, each ending in a button reading "Simulate ...".
 * They are now one labelled group of actions, which is what they are.
 */

const SCENARIOS = [
  {
    key: 'TIER_1',
    tier: 'Tier 1',
    title: 'Straight-through transfer',
    detail: 'Sends the payer receipt and the payee credit advice. No hold.',
  },
  {
    key: 'TIER_2_HOLD',
    tier: 'Tier 2',
    title: 'Manager approval hold',
    detail: 'Raises the manager review alert and holds the funds.',
  },
  {
    key: 'TIER_2_APPROVAL',
    tier: 'Tier 2',
    title: 'Approval confirmation',
    detail: 'Confirms release to the originator and credits the payee.',
  },
  {
    key: 'TIER_3_AMLA',
    tier: 'Tier 3',
    title: 'AMLA covered transaction',
    detail: 'Escalates to the compliance officer for CTR filing.',
  },
];

/* Officers who may act as checker. The maker is listed so the segregation rule
   can be demonstrated, and it says plainly what selecting them will do. */
const CHECKERS = [
  { id: 'U3002', label: 'Beatriz Ocampo, operations officer' },
  { id: 'U3003', label: 'Carlos Mendoza, branch head' },
  { id: 'U1001', label: 'Juan Dela Cruz, originator (blocked as checker)' },
];

export default function TellerPortal({
  pendingTransactions,
  setPendingTransactions,
  onApprovalComplete,
}) {
  const [activeCheckerId, setActiveCheckerId] = useState('U3002');
  const [actionLoadingId, setActionLoadingId] = useState(null);
  const [feedback, setFeedback] = useState(null);
  const [simulation, setSimulation] = useState(null);
  const [isSimulating, setIsSimulating] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const fetchPending = async () => {
    setIsRefreshing(true);
    const res = await LedgerService.getPendingTransactions();
    if (res.success && res.data.length > 0) {
      setPendingTransactions(res.data);
    }
    setIsRefreshing(false);
  };

  useEffect(() => {
    fetchPending();
  }, []);

  const handleApprove = async (tx) => {
    // Segregation of duties. Checked here as well as server-side so the teller
    // gets the answer immediately rather than after a round trip.
    if (tx.initiatorUserId === activeCheckerId) {
      setFeedback({
        tone: 'voided',
        title: 'You cannot approve your own transfer',
        detail:
          'The officer who started a transfer may not approve it. Select a different officer as checker.',
      });
      return;
    }

    setActionLoadingId(tx.transactionId);
    setFeedback(null);

    const res = await LedgerService.approveTransfer({
      transactionId: tx.transactionId,
      checkerUserId: activeCheckerId,
      remarks: 'Approved by Branch Operations Officer in dual-control terminal',
    });

    setActionLoadingId(null);
    setPendingTransactions((prev) => prev.filter((p) => p.transactionId !== tx.transactionId));

    setFeedback({
      tone: 'settled',
      title: `${tx.transactionId} approved`,
      detail: res.success
        ? 'Funds settled. Receipt and credit advice have been sent.'
        : 'Funds settled locally. The ledger service was unreachable, so this was recorded by the simulator.',
    });

    onApprovalComplete?.(res.success ? res.data : { ...tx, status: 'COMMITTED' }, 'APPROVED');
  };

  const handleReject = async (tx) => {
    if (tx.initiatorUserId === activeCheckerId) {
      setFeedback({
        tone: 'voided',
        title: 'You cannot decline your own transfer',
        detail:
          'The officer who started a transfer may not act on it. Select a different officer as checker.',
      });
      return;
    }

    setActionLoadingId(tx.transactionId);
    setFeedback(null);

    const res = await LedgerService.rejectTransfer({
      transactionId: tx.transactionId,
      checkerUserId: activeCheckerId,
      remarks: 'Rejected by Branch Operations Officer',
    });

    setActionLoadingId(null);
    setPendingTransactions((prev) => prev.filter((p) => p.transactionId !== tx.transactionId));

    setFeedback({
      tone: 'held',
      title: `${tx.transactionId} declined`,
      detail: 'The hold has been released and the funds are available to the sender again.',
    });

    onApprovalComplete?.(res.success ? res.data : { ...tx, status: 'REJECTED' }, 'REJECTED');
  };

  const runSimulation = async (key) => {
    setIsSimulating(true);
    setSimulation(null);

    const calls = {
      TIER_1: NotificationService.simulateTier1Transfer,
      TIER_2_HOLD: NotificationService.simulateTier2MakerChecker,
      TIER_2_APPROVAL: NotificationService.simulateTier2Approval,
      TIER_3_AMLA: NotificationService.simulateTier3Amla,
    };

    const res = await calls[key]?.();
    setIsSimulating(false);

    setSimulation(
      res?.success
        ? res.data
        : {
            status: 'SIMULATED',
            tier: key,
            message: 'Event dispatched. Open the mail sandbox to read the advice that was sent.',
          }
    );
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-xl font-semibold tracking-tight text-fg">Approvals</h1>
          <p className="mt-1 max-w-prose text-sm text-fg-muted">
            Transfers above PHP 50,000 are held here until an officer other than the one who
            started them approves the release.
          </p>
        </div>

        {/* Checker identity. A real labelled select rather than a bare
            <select> floating inside a dark pill with no accessible name. */}
        <div className="shrink-0">
          <label
            htmlFor="checker"
            className="mb-1 block text-2xs font-medium uppercase tracking-wider text-fg-subtle"
          >
            Acting as
          </label>
          <Select
            id="checker"
            value={activeCheckerId}
            onChange={(e) => setActiveCheckerId(e.target.value)}
            className="sm:w-80"
          >
            {CHECKERS.map((checker) => (
              <option key={checker.id} value={checker.id}>
                {checker.label}
              </option>
            ))}
          </Select>
        </div>
      </div>

      {feedback && (
        <Callout
          tone={feedback.tone}
          role={feedback.tone === 'voided' ? 'alert' : 'status'}
          icon={
            feedback.tone === 'voided'
              ? AlertTriangle
              : feedback.tone === 'held'
                ? XCircle
                : CheckCircle2
          }
          title={feedback.title}
          action={
            <Button variant="ghost" size="sm" onClick={() => setFeedback(null)}>
              Dismiss
            </Button>
          }
        >
          {feedback.detail}
        </Callout>
      )}

      <Panel flush>
        <div className="flex items-center justify-between gap-4 px-4 py-3">
          <h2 className="text-md font-semibold text-fg">
            Waiting for approval
            {pendingTransactions.length > 0 && (
              <span className="ml-2 font-mono text-sm font-normal text-fg-subtle">
                {pendingTransactions.length}
              </span>
            )}
          </h2>
          <Button
            variant="secondary"
            size="sm"
            icon={RefreshCw}
            onClick={fetchPending}
            loading={isRefreshing}
          >
            Refresh
          </Button>
        </div>

        {pendingTransactions.length === 0 ? (
          <div className="border-t border-line">
            <EmptyState
              icon={Inbox}
              title="Nothing waiting"
              description="Transfers above PHP 50,000 will appear here for approval as customers submit them."
            />
          </div>
        ) : (
          <TableScroll label="Transfers waiting for approval" className="mx-0">
            <Table>
              <thead>
                <tr>
                  <Th>Reference</Th>
                  <Th>From and to</Th>
                  <Th align="right">Amount</Th>
                  <Th>Started by</Th>
                  <Th>Category</Th>
                  <Th align="right">Decision</Th>
                </tr>
              </thead>
              <tbody>
                {pendingTransactions.map((tx) => (
                  <QueueRow
                    key={tx.transactionId}
                    tx={tx}
                    activeCheckerId={activeCheckerId}
                    busy={actionLoadingId === tx.transactionId}
                    onApprove={handleApprove}
                    onReject={handleReject}
                  />
                ))}
              </tbody>
            </Table>
          </TableScroll>
        )}
      </Panel>

      {/* Notification test harness. Grouped and labelled as a test tool, so it
          is not mistaken for part of the approval workflow. */}
      <Panel>
        <PanelHeader
          title="Notification tests"
          description="Send a sample advice through the notification service to check the templates and routing."
          actions={
            <Button
              as="a"
              href="http://localhost:8025"
              target="_blank"
              rel="noreferrer"
              variant="secondary"
              size="sm"
              icon={ExternalLink}
            >
              Mail sandbox
            </Button>
          }
        />

        <div className="mt-4 grid gap-px border border-line bg-line sm:grid-cols-2 lg:grid-cols-4">
          {SCENARIOS.map((scenario) => (
            <div key={scenario.key} className="flex flex-col bg-surface p-3">
              <Badge tone="neutral" size="sm" className="self-start">
                {scenario.tier}
              </Badge>
              <p className="mt-2 text-sm font-medium text-fg">{scenario.title}</p>
              <p className="mt-0.5 flex-1 text-xs leading-snug text-fg-muted">{scenario.detail}</p>
              <Button
                variant="secondary"
                size="sm"
                fullWidth
                className="mt-3"
                disabled={isSimulating}
                onClick={() => runSimulation(scenario.key)}
              >
                Send
              </Button>
            </div>
          ))}
        </div>

        {simulation && (
          <Callout tone="accent" className="mt-3" title="Advice dispatched">
            {simulation.message}
            {simulation.transferId && (
              <span className="mt-1 block font-mono text-xs">
                {simulation.transferId}
                {simulation.recipientEmail ? ` to ${simulation.recipientEmail}` : ''}
              </span>
            )}
          </Callout>
        )}
      </Panel>
    </div>
  );
}

/*
 * One row of the approval queue.
 *
 * The blocked state is the interesting case. Previously the maker's own row
 * still showed live Approve and Reject buttons, and the refusal only arrived
 * after clicking. Now the row disables the decision and says why, so the rule is
 * visible before the teller reaches for it.
 */
function QueueRow({ tx, activeCheckerId, busy, onApprove, onReject }) {
  const amount = parseFloat(tx.mutationAmount || tx.amount || 0);
  const tier = tierOf(amount);
  const isOwnTransfer = tx.initiatorUserId === activeCheckerId;

  return (
    <Tr>
      <Td className="font-mono font-medium">{tx.transactionId}</Td>

      <Td>
        <span className="flex items-center gap-1.5 font-mono text-xs text-fg-muted">
          <span className="text-fg">{tx.sourceAccountId || tx.sourceAccount}</span>
          <span aria-hidden="true">&rarr;</span>
          <span className="text-fg">
            {tx.destinationAccountId || tx.targetAccountId || tx.destinationAccount}
          </span>
        </span>
      </Td>

      <Td align="right">
        <Money value={amount} size="sm" />
      </Td>

      <Td>
        <span className="font-mono text-xs text-fg-muted">{tx.initiatorUserId || 'U1001'}</span>
        {isOwnTransfer && (
          <Badge tone="voided" size="sm" className="ml-1.5">
            You
          </Badge>
        )}
      </Td>

      <Td>
        <Badge tone={tier.tone} size="sm">
          {tier.label}
        </Badge>
      </Td>

      <Td align="right">
        {isOwnTransfer ? (
          <span className="inline-flex items-center gap-1.5 text-xs text-fg-subtle">
            <Clock className="h-3.5 w-3.5" aria-hidden="true" />
            Needs another officer
          </span>
        ) : (
          <span className="inline-flex items-center justify-end gap-2">
            <Button variant="danger" size="sm" disabled={busy} onClick={() => onReject(tx)}>
              Decline
            </Button>
            <Button
              variant="approve"
              size="sm"
              icon={CheckCircle2}
              loading={busy}
              onClick={() => onApprove(tx)}
            >
              Approve
            </Button>
          </span>
        )}
      </Td>
    </Tr>
  );
}
