import React, { useState, useEffect } from 'react';
import { 
  ShieldCheck, 
  CheckCircle, 
  XCircle, 
  BadgeAlert,
  ShieldAlert, 
  CheckCircle2,
  Lock, 
  UserCheck, 
  User, 
  Search, 
  Clock, 
  FileText, 
  X, 
  ExternalLink, 
  Building2, 
  Printer 
} from 'lucide-react';
import { formatPHP } from '../utils/currency';
import apiClient, { mockState, THRESHOLDS } from '../services/api';
import { useAuth } from '../context/AuthContext';
import { cn } from '../ui/cn';

export default function ManagerPortal({ onActionComplete, showToast }) {
  const { user, switchManager } = useAuth();
  const [pendingTransfers, setPendingTransfers] = useState([]);
  const [selectedTx, setSelectedTx] = useState(null);
  const [approvalNotes, setApprovalNotes] = useState('');
  const [rejectionReason, setRejectionReason] = useState('Disapproved: Inadequate documentation or regulatory mismatch.');
  const [isProcessing, setIsProcessing] = useState(false);
  const [activeModal, setActiveModal] = useState(null); // 'approve' | 'sign-first' | 'reject' | 'details' | null
  const [filterTier, setFilterTier] = useState('ALL'); // 'ALL' | 'TIER_2' | 'TIER_3'
  const [searchQuery, setSearchQuery] = useState('');

  const fetchPending = async () => {
    try {
      const res = await apiClient.get('/transfers/pending');
      const mapped = (res.data || []).map((tx) => {
        const id = tx.id || tx.transactionId;
        const makerUserId = tx.maker_user_id || tx.makerUserId || 'U1001';
        const amount = Number(tx.amount || 0);
        const isTier3 = amount >= THRESHOLDS.AMLA_CTR_MIN;
        const approvedBy = tx.approved_by_user_id || tx.approvedByUserId;
        const firstApproverId = tx.first_approver_id || tx.l1_approver_id || (approvedBy ? approvedBy.split(',')[0].trim() : null);
        const firstApproverName = tx.first_approver_name || tx.l1_approver_name || (firstApproverId === 'U3003' ? 'Carlos Mendoza' : firstApproverId === 'U3002' ? 'Beatriz Ocampo' : firstApproverId);
        const stage = isTier3 ? (firstApproverId ? 2 : 1) : 1;

        return {
          ...tx,
          id,
          maker_user_id: makerUserId,
          maker_name: tx.maker_name || (makerUserId === 'U1001' ? 'Juan Dela Cruz' : makerUserId),
          from_account_id: tx.from_account_id || tx.fromAccountId,
          to_account_id: tx.to_account_id || tx.toAccountId,
          recipient_name: tx.recipient_name || tx.recipientName || ('Beneficiary Account (' + (tx.toAccountId || tx.to_account_id) + ')'),
          amount,
          memo: tx.memo || 'High-value fund transfer',
          status: tx.status || 'PENDING_APPROVAL',
          approval_stage: stage,
          first_approver_id: firstApproverId,
          first_approver_name: firstApproverName,
          first_notes: tx.first_notes || tx.l1_notes,
          first_approved_at: tx.first_approved_at || tx.l1_approved_at,
          created_at: tx.created_at || tx.createdAt || new Date().toISOString(),
        };
      });
      setPendingTransfers(mapped);
    } catch (_) {
      const mockMapped = (mockState.transfers || [])
        .filter((t) => t.status === 'PENDING_APPROVAL')
        .map((tx) => ({
          ...tx,
          first_approver_id: tx.first_approver_id || tx.l1_approver_id,
          first_approver_name: tx.first_approver_name || tx.l1_approver_name,
          first_notes: tx.first_notes || tx.l1_notes,
        }));
      setPendingTransfers(mockMapped);
    }
  };

  useEffect(() => {
    fetchPending();
  }, []);

  const totalHeldAmount = pendingTransfers.reduce((acc, curr) => acc + (curr.amount || 0), 0);
  const amlaCount = pendingTransfers.filter((t) => (t.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN).length;

  const filteredTransfers = pendingTransfers.filter((tx) => {
    if (filterTier === 'TIER_2') {
      const isTier2 = (tx.amount || 0) > THRESHOLDS.STP_MAX && (tx.amount || 0) < THRESHOLDS.AMLA_CTR_MIN;
      if (!isTier2) return false;
    }
    if (filterTier === 'TIER_3') {
      const isTier3 = (tx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN;
      if (!isTier3) return false;
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const matchId = tx.id?.toLowerCase().includes(q);
      const matchMaker = tx.maker_user_id?.toLowerCase().includes(q);
      const matchRecipient = tx.recipient_name?.toLowerCase().includes(q);
      const matchAccount = tx.to_account_id?.toLowerCase().includes(q);
      const matchMemo = tx.memo?.toLowerCase().includes(q);
      if (!matchId && !matchMaker && !matchRecipient && !matchAccount && !matchMemo) {
        return false;
      }
    }
    return true;
  });

  const handleFirstApproval = async () => {
    if (!selectedTx) return;

    if (user?.user_id === selectedTx.maker_user_id) {
      showToast?.({
        type: 'error',
        title: 'Segregation of Duties Violation',
        detail: 'System policy strictly blocks self-approval. A distinct operations manager must authorize this mutation.',
        rfcInstance: `/api/v1/transfers/${selectedTx.id}/sign-l1`,
      });
      return;
    }

    setIsProcessing(true);
    try {
      const res = await apiClient.post(`/transfers/${selectedTx.id}/sign-l1`, {
        notes: approvalNotes || 'AMLA CTR First Approval: Verified customer identity, source of funds, and statutory mandate.',
        checker_user_id: user?.user_id || 'U3002',
        checker_name: user?.name || 'Operations Manager',
      });

      showToast?.({
        type: 'success',
        title: 'First Approval Recorded',
        detail: res.data?.message || `First approval recorded by ${user?.name || 'Operations Manager'}. Awaiting second manager approval for final release.`,
        rfcInstance: `/api/v1/transfers/${selectedTx.id}`,
      });

      setActiveModal(null);
      setSelectedTx(null);
      await fetchPending();
      onActionComplete?.();
    } catch (err) {
      showToast?.({
        type: 'error',
        title: 'First Approval Failed',
        detail: err.response?.data?.detail || err.response?.data?.message || 'Could not record first manager approval.',
      });
    } finally {
      setIsProcessing(false);
    }
  };

  const handleApprove = async () => {
    if (!selectedTx) return;

    if (user?.user_id === selectedTx.maker_user_id) {
      showToast?.({
        type: 'error',
        title: 'Segregation of Duties Violation',
        detail: 'System policy strictly blocks self-approval. A distinct operations manager must authorize this mutation.',
        rfcInstance: `/api/v1/transfers/${selectedTx.id}/approve`,
      });
      return;
    }

    const isAmla = (selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN;
    if (isAmla && selectedTx.first_approver_id && user?.user_id === selectedTx.first_approver_id) {
      showToast?.({
        type: 'error',
        title: 'Dual-Control Segregation Violation',
        detail: `Rule AMLA-204: The second approval must be performed by a different manager. You already recorded the first approval.`,
        rfcInstance: `/api/v1/transfers/${selectedTx.id}/approve`,
      });
      return;
    }

    setIsProcessing(true);
    try {
      const res = await apiClient.post(`/transfers/${selectedTx.id}/approve`, {
        notes: approvalNotes || (isAmla ? 'AMLA CTR Second Approval: Dual manager clearance authorized. Releasing soft hold.' : 'Authorized following KYC mandate and dual-control operational review.'),
        checker_user_id: user?.user_id || 'U3002',
        checker_name: user?.name || 'Operations Manager',
      });

      showToast?.({
        type: 'success',
        title: isAmla ? 'Transfer Fully Authorized (2 of 2)' : 'Transfer Authorized & Released',
        detail: res.data?.message || `Transfer ${selectedTx.id} authorized. Soft hold released and funds settled.`,
        rfcInstance: `/api/v1/transfers/${selectedTx.id}`,
      });

      setActiveModal(null);
      setSelectedTx(null);
      await fetchPending();
      onActionComplete?.();
    } catch (err) {
      showToast?.({
        type: 'error',
        title: 'Approval Failed',
        detail: err.response?.data?.detail || err.response?.data?.message || 'Could not authorize transfer.',
      });
    } finally {
      setIsProcessing(false);
    }
  };

  const handleReject = async () => {
    if (!selectedTx) return;

    setIsProcessing(true);
    try {
      const res = await apiClient.post(`/transfers/${selectedTx.id}/reject`, {
        reason: rejectionReason,
        checker_user_id: user?.user_id || 'U3002',
        checker_name: user?.name || 'Operations Manager',
      });

      showToast?.({
        type: 'warning',
        title: 'Transfer Disapproved & Voided',
        detail: res.data?.message || `Transfer ${selectedTx.id} voided. Soft hold released back to sender.`,
        rfcInstance: `/api/v1/transfers/${selectedTx.id}`,
      });

      setActiveModal(null);
      setSelectedTx(null);
      await fetchPending();
      onActionComplete?.();
    } catch (err) {
      showToast?.({
        type: 'error',
        title: 'Disapproval Failed',
        detail: err.response?.data?.detail || err.response?.data?.message || 'Could not reject transfer.',
      });
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* 1. Dual-Control Manager Persona Switcher */}
      <div className="bg-surface border border-line p-3 px-4 rounded-none flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <UserCheck className="w-4 h-4 text-accent shrink-0" />
          <div className="flex items-center gap-2 flex-wrap text-xs">
            <span className="text-fg-muted font-medium">Session:</span>
            <span className="font-semibold text-fg">{user?.name || 'Beatriz Ocampo'}</span>
            <span className="font-mono text-2xs px-1.5 py-0.5 border border-line bg-sunken text-fg-muted font-medium">
              {user?.user_id || 'U3002'}
            </span>
            <span className="text-fg-subtle hidden md:inline">&bull; {user?.title || 'Operations Manager'}</span>
          </div>
        </div>

        <div className="flex items-center gap-1.5 shrink-0">
          <span className="text-2xs font-mono text-fg-muted uppercase tracking-wider mr-1">Switch Persona:</span>
          <button
            onClick={() => switchManager('U3002')}
            className={cn(
              "h-7 px-2.5 text-2xs font-medium rounded-none border transition-colors flex items-center gap-1.5 cursor-pointer",
              user?.user_id === 'U3002'
                ? "border-accent bg-accent text-accent-contrast font-semibold"
                : "border-line bg-sunken text-fg-muted hover:text-fg"
            )}
          >
            <User className="w-3 h-3" /> Beatriz Ocampo
          </button>
          <button
            onClick={() => switchManager('U3003')}
            className={cn(
              "h-7 px-2.5 text-2xs font-medium rounded-none border transition-colors flex items-center gap-1.5 cursor-pointer",
              user?.user_id === 'U3003'
                ? "border-accent bg-accent text-accent-contrast font-semibold"
                : "border-line bg-sunken text-fg-muted hover:text-fg"
            )}
          >
            <ShieldCheck className="w-3 h-3" /> Carlos Mendoza
          </button>
        </div>
      </div>

      {/* 2. Operational KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {/* Pending Queue */}
        <div className="bg-surface border border-line p-4 rounded-none">
          <div className="flex items-center justify-between">
            <span className="text-2xs font-mono font-medium uppercase tracking-wider text-held-700">
              Pending Queue
            </span>
            <BadgeAlert className="w-4 h-4 text-held-600" />
          </div>
          <p className="text-2xl font-mono font-semibold tracking-tight text-held-700 mt-2">
            {pendingTransfers.length} {pendingTransfers.length === 1 ? 'Transfer' : 'Transfers'}
          </p>
          <p className="text-2xs text-fg-subtle mt-1">
            Awaiting dual-control operational sign-off
          </p>
        </div>

        {/* Total Soft Hold Volume */}
        <div className="bg-surface border border-line p-4 rounded-none">
          <div className="flex items-center justify-between">
            <span className="text-2xs font-mono font-medium uppercase tracking-wider text-fg-muted">
              Total Soft-Hold Volume
            </span>
            <Lock className="w-4 h-4 text-fg-muted" />
          </div>
          <p className="text-2xl font-mono font-semibold tracking-tight text-fg mt-2">
            {formatPHP(totalHeldAmount)}
          </p>
          <p className="text-2xs text-fg-subtle mt-1">
            Funds reserved in ledger until authorized or voided
          </p>
        </div>

        {/* AMLA High-Value Items */}
        <div className="bg-surface border border-line p-4 rounded-none">
          <div className="flex items-center justify-between">
            <span className="text-2xs font-mono font-medium uppercase tracking-wider text-voided-700">
              AMLA High-Value Items
            </span>
            <ShieldAlert className="w-4 h-4 text-voided-600" />
          </div>
          <p className="text-2xl font-mono font-semibold tracking-tight text-voided-700 mt-2">
            {amlaCount} {amlaCount === 1 ? 'Transfer' : 'Transfers'}
          </p>
          <p className="text-2xs text-fg-subtle mt-1">
            Mandatory RA 9160 two-manager sign-off (2 Approvals)
          </p>
        </div>
      </div>

      {/* 3. Review Queue Table */}
      <div className="bg-surface border border-line p-5 rounded-none space-y-4">
        <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4">
          <div>
            <h3 className="text-sm font-semibold text-fg flex items-center gap-2">
              <ShieldCheck className="w-4 h-4 text-accent" />
              Transactions Awaiting Authorization
            </h3>
            <p className="text-xs text-fg-muted mt-0.5">
              Review originating maker and regulatory classification before committing balance mutation.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2.5 w-full lg:w-auto">
            {/* Search Input */}
            <div className="relative">
              <Search className="w-3.5 h-3.5 text-fg-subtle absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search ref, maker, memo..."
                className="w-full sm:w-56 h-8 bg-sunken border border-line pl-8 pr-3 text-xs text-fg rounded-none focus:outline-none focus:border-accent transition-colors placeholder:text-fg-subtle"
              />
            </div>

            {/* Filter buttons */}
            <div className="flex items-center gap-1">
              <button
                onClick={() => setFilterTier('ALL')}
                className={cn(
                  "h-8 px-2.5 text-2xs font-mono font-medium rounded-none border transition-colors cursor-pointer",
                  filterTier === 'ALL'
                    ? "border-accent bg-accent text-accent-contrast"
                    : "border-line bg-sunken text-fg-muted hover:text-fg"
                )}
              >
                All ({pendingTransfers.length})
              </button>
              <button
                onClick={() => setFilterTier('TIER_2')}
                className={cn(
                  "h-8 px-2.5 text-2xs font-mono font-medium rounded-none border transition-colors cursor-pointer",
                  filterTier === 'TIER_2'
                    ? "border-held-400 bg-held-50 text-held-700 font-semibold"
                    : "border-line bg-sunken text-fg-muted hover:text-fg"
                )}
              >
                Tier 2 (&gt; ₱50k)
              </button>
              <button
                onClick={() => setFilterTier('TIER_3')}
                className={cn(
                  "h-8 px-2.5 text-2xs font-mono font-medium rounded-none border transition-colors cursor-pointer",
                  filterTier === 'TIER_3'
                    ? "border-voided-400 bg-voided-50 text-voided-700 font-semibold"
                    : "border-line bg-sunken text-fg-muted hover:text-fg"
                )}
              >
                Tier 3 AMLA (&ge; ₱500k)
              </button>
            </div>

            <button
              onClick={fetchPending}
              className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors cursor-pointer"
            >
              Refresh
            </button>
          </div>
        </div>

        {filteredTransfers.length === 0 ? (
          <div className="py-12 text-center text-fg-muted text-xs border border-dashed border-line">
            <CheckCircle className="w-6 h-6 text-settled-600 mx-auto mb-2" />
            No pending transfers matching filter or search query. All transactions authorized or queue is clear.
          </div>
        ) : (
          <div className="overflow-x-auto border border-line">
            <table className="w-full text-left text-xs">
              <thead className="bg-sunken border-b border-line text-2xs font-mono font-medium uppercase tracking-wider text-fg-muted">
                <tr>
                  <th className="py-2.5 px-3 w-[140px]">Transfer Ref</th>
                  <th className="py-2.5 px-3 w-[160px]">Sender (Maker)</th>
                  <th className="py-2.5 px-3 w-[190px]">Beneficiary Entity</th>
                  <th className="py-2.5 px-3 w-[160px]">Amount (PHP)</th>
                  <th className="py-2.5 px-3 w-[220px]">Regulatory Status</th>
                  <th className="py-2.5 px-3 min-w-[160px]">Memo / Purpose</th>
                  <th className="py-2.5 px-3 text-right w-[240px]">Review Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {filteredTransfers.map((tx) => {
                  const isSelfMaker = user?.user_id === tx.maker_user_id;
                  const isAmla = (tx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN;
                  const hasFirstApproval = Boolean(tx.first_approver_id);
                  const isCurrentUserFirstApprover = tx.first_approver_id === user?.user_id;

                  return (
                    <tr key={tx.id} className="hover:bg-sunken/40 transition-colors">
                      <td className="py-3 px-3 whitespace-nowrap align-middle">
                        <button
                          type="button"
                          onClick={() => {
                            setSelectedTx(tx);
                            setActiveModal('details');
                          }}
                          className="font-mono text-xs font-semibold text-accent hover:underline inline-flex items-center gap-1 cursor-pointer"
                        >
                          <span>{tx.id}</span>
                          <ExternalLink className="w-3 h-3 opacity-60" />
                        </button>
                      </td>

                      <td className="py-3 px-3 align-middle font-mono">
                        <p className="font-semibold text-fg">{tx.maker_name || tx.maker_user_id}</p>
                        <p className="text-2xs text-fg-subtle">ID: {tx.maker_user_id}</p>
                      </td>

                      <td className="py-3 px-3 align-middle">
                        <p className="font-semibold text-fg">{tx.recipient_name}</p>
                        <p className="font-mono text-2xs text-fg-subtle">{tx.to_account_id}</p>
                      </td>

                      <td className="py-3 px-3 align-middle font-mono font-semibold whitespace-nowrap">
                        <span className={isAmla ? "text-voided-700" : "text-fg"}>
                          {formatPHP(tx.amount)}
                        </span>
                      </td>

                      <td className="py-3 px-3 align-middle">
                        {isAmla ? (
                          <div className="space-y-1">
                            <span className="px-1.5 py-0.5 border text-2xs font-mono font-medium bg-voided-50 text-voided-700 border-voided-200 block w-fit">
                              Tier 3 AMLA CTR
                            </span>
                            {hasFirstApproval ? (
                              <p className="text-2xs font-mono text-settled-700 flex items-center gap-1">
                                <CheckCircle2 className="w-3 h-3" /> Signed: {tx.first_approver_id} (1/2)
                              </p>
                            ) : (
                              <p className="text-2xs font-mono text-held-700 flex items-center gap-1">
                                <Clock className="w-3 h-3" /> Awaiting 1st Approval
                              </p>
                            )}
                          </div>
                        ) : (
                          <div className="space-y-1">
                            <span className="px-1.5 py-0.5 border text-2xs font-mono font-medium bg-held-50 text-held-700 border-held-200 block w-fit">
                              Tier 2 Dual Control
                            </span>
                            <p className="text-2xs font-mono text-fg-muted flex items-center gap-1">
                              <Clock className="w-3 h-3 text-fg-subtle" /> 1 Manager Approval
                            </p>
                          </div>
                        )}
                      </td>

                      <td className="py-3 px-3 align-middle">
                        <p className="text-fg-muted text-xs italic line-clamp-2 max-w-[220px]" title={tx.memo}>
                          "{tx.memo || 'Standard Retail Transfer'}"
                        </p>
                      </td>

                      <td className="py-3 px-3 text-right whitespace-nowrap align-middle">
                        <div className="inline-flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => {
                              setSelectedTx(tx);
                              setActiveModal('reject');
                            }}
                            className="h-7 px-2.5 text-2xs font-medium border border-line bg-sunken hover:border-voided-400 hover:bg-voided-50 hover:text-voided-700 text-fg rounded-none transition-colors cursor-pointer"
                          >
                            Disapprove
                          </button>

                          {isSelfMaker ? (
                            <button
                              disabled
                              title="Segregation of Duties: Initiating maker cannot authorize own balance mutation."
                              className="h-7 px-2.5 text-2xs font-medium border border-line bg-sunken text-fg-subtle cursor-not-allowed inline-flex items-center gap-1 rounded-none"
                            >
                              <Lock className="w-3 h-3" /> Self-Approval Blocked
                            </button>
                          ) : !isAmla ? (
                            <button
                              onClick={() => {
                                setSelectedTx(tx);
                                setApprovalNotes('Authorized following KYC mandate and dual-control operational review.');
                                setActiveModal('approve');
                              }}
                              className="h-7 px-3 text-2xs font-medium bg-accent text-accent-contrast hover:bg-accent-emphasis rounded-none transition-colors inline-flex items-center gap-1 cursor-pointer"
                            >
                              <CheckCircle className="w-3 h-3" /> Authorize
                            </button>
                          ) : !hasFirstApproval ? (
                            <button
                              onClick={() => {
                                setSelectedTx(tx);
                                setApprovalNotes('AMLA CTR First Approval: Verified customer identity, source of funds, and statutory mandate.');
                                setActiveModal('sign-first');
                              }}
                              className="h-7 px-3 text-2xs font-medium border border-held-400 bg-held-50 text-held-700 hover:bg-held-100 rounded-none transition-colors inline-flex items-center gap-1 cursor-pointer"
                            >
                              <ShieldAlert className="w-3 h-3" />
                              <span>First Approval (1/2)</span>
                            </button>
                          ) : isCurrentUserFirstApprover ? (
                            <div 
                              className="h-7 px-2.5 text-2xs font-medium border border-line bg-sunken text-held-700 cursor-not-allowed inline-flex items-center gap-1 rounded-none"
                              title="Dual-Control Segregation: The second approval must be signed by a distinct manager."
                            >
                              <CheckCircle2 className="w-3 h-3 text-settled-700" />
                              <span>Approved (1/2) &bull; Awaiting 2nd Mgr</span>
                            </div>
                          ) : (
                            <button
                              onClick={() => {
                                setSelectedTx(tx);
                                setApprovalNotes('AMLA CTR Second Approval: Dual manager clearance authorized. Releasing soft hold.');
                                setActiveModal('approve');
                              }}
                              className="h-7 px-3 text-2xs font-medium bg-accent text-accent-contrast hover:bg-accent-emphasis rounded-none transition-colors inline-flex items-center gap-1 cursor-pointer"
                            >
                              <ShieldCheck className="w-3 h-3" />
                              <span>Second Approval (2/2)</span>
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* MODAL 0: Detailed Transaction Dossier Modal */}
      {activeModal === 'details' && selectedTx && (
        <div 
          onClick={(e) => { if (e.target === e.currentTarget) setActiveModal(null); }}
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4"
        >
          <div className="bg-surface border border-line-strong max-w-2xl w-full max-h-[90vh] flex flex-col shadow-2xl relative rounded-none overflow-hidden">
            <div className="p-4 border-b border-line shrink-0 flex items-center justify-between bg-surface">
              <div className="flex items-center gap-2.5">
                <FileText className="w-4 h-4 text-accent" />
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-sm font-semibold text-fg">
                      Transfer Authorization Dossier
                    </h3>
                    <span className="text-accent font-mono font-semibold text-xs">
                      {selectedTx.id}
                    </span>
                  </div>
                  <p className="text-2xs text-fg-muted">
                    Dual-Control Workstation &bull; Soft-Hold Verification &amp; KYC Ledger Record
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                aria-label="Exit Dossier"
                className="p-1 text-fg-muted hover:text-fg transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Scrollable Body */}
            <div className="p-5 overflow-y-auto space-y-4 flex-1 text-xs">
              <div className="p-3.5 bg-sunken border border-line flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div>
                  <span className="text-2xs font-mono text-fg-muted uppercase tracking-wider block">
                    Pending Transfer Amount
                  </span>
                  <div className="flex items-baseline gap-2 mt-0.5">
                    <span className="font-mono font-bold text-fg text-lg">
                      {formatPHP(selectedTx.amount)}
                    </span>
                    <span className="text-fg-subtle font-mono text-2xs">
                      (PHP Soft-Hold Locked)
                    </span>
                  </div>
                </div>

                <div>
                  <span className="text-2xs font-mono text-fg-muted uppercase tracking-wider block mb-1">
                    Regulatory Classification
                  </span>
                  {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN ? (
                    <span className="px-2 py-0.5 text-2xs font-mono border bg-voided-50 text-voided-700 border-voided-200">
                      TIER 3: AMLA CTR (&ge; ₱500k)
                    </span>
                  ) : (
                    <span className="px-2 py-0.5 text-2xs font-mono border bg-held-50 text-held-700 border-held-200">
                      TIER 2: DUAL-CONTROL (&gt; ₱50k)
                    </span>
                  )}
                </div>
              </div>

              {/* KYC Records */}
              <div className="p-3.5 bg-sunken border border-line space-y-2.5">
                <span className="text-2xs font-mono font-semibold text-fg uppercase tracking-wider flex items-center gap-1.5">
                  <Building2 className="w-3 h-3 text-fg-muted" /> KYC Account Records
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 text-2xs">
                  <div className="p-2.5 bg-surface border border-line space-y-1">
                    <span className="text-2xs text-fg-subtle uppercase block font-mono">Originating Sender (Maker)</span>
                    <p className="font-semibold text-fg">
                      {selectedTx.maker_name || (selectedTx.maker_user_id === 'U1001' ? 'Juan Dela Cruz' : selectedTx.maker_user_id)}
                    </p>
                    <p className="font-mono text-fg-muted text-2xs">
                      ID: {selectedTx.maker_user_id || 'U1001'} &bull; Acct: {selectedTx.from_account_id || '1000-2000-3001'}
                    </p>
                  </div>
                  <div className="p-2.5 bg-surface border border-line space-y-1">
                    <span className="text-2xs text-fg-subtle uppercase block font-mono">Beneficiary Entity (Receiver)</span>
                    <p className="font-semibold text-fg">{selectedTx.recipient_name}</p>
                    <p className="font-mono text-fg-muted text-2xs">Acct: {selectedTx.to_account_id}</p>
                  </div>
                </div>
                <div className="pt-2 border-t border-line flex items-center justify-between text-2xs">
                  <span className="text-fg-muted">Payment Purpose / Memo:</span>
                  <span className="font-semibold text-fg italic">{selectedTx.memo || 'Standard Retail Transfer'}</span>
                </div>
              </div>

              {/* Dual-Control Status */}
              <div className="p-3.5 bg-sunken border border-line space-y-2.5">
                <span className="text-2xs font-mono font-semibold text-fg uppercase tracking-wider flex items-center gap-1.5">
                  <UserCheck className="w-3 h-3 text-accent" /> Dual-Control Authorization Progress
                </span>

                {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN ? (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 text-2xs">
                    <div className="p-2.5 bg-surface border border-line space-y-1">
                      <div className="flex items-center justify-between font-mono">
                        <span className="text-fg-muted uppercase">First Manager</span>
                        {selectedTx.first_approver_id ? (
                          <span className="text-settled-700 font-semibold">SIGNED</span>
                        ) : (
                          <span className="text-held-700 font-semibold">PENDING</span>
                        )}
                      </div>
                      <p className="font-semibold text-fg">
                        {selectedTx.first_approver_name || 'Operations Manager'}{' '}
                        {selectedTx.first_approver_id && (
                          <span className="font-mono text-fg-subtle">({selectedTx.first_approver_id})</span>
                        )}
                      </p>
                      {selectedTx.first_notes && (
                        <p className="text-fg-muted italic bg-sunken p-1.5 border border-line">
                          "{selectedTx.first_notes}"
                        </p>
                      )}
                    </div>

                    <div className="p-2.5 bg-surface border border-line space-y-1">
                      <div className="flex items-center justify-between font-mono">
                        <span className="text-fg-muted uppercase">Second Manager</span>
                        <span className="text-fg-subtle font-semibold">AWAITING RELEASE</span>
                      </div>
                      <p className="font-semibold text-fg">
                        {selectedTx.second_approver_name || 'Operations Manager (Distinct)'}
                      </p>
                    </div>
                  </div>
                ) : (
                  <div className="p-2.5 bg-surface border border-line space-y-1 text-2xs">
                    <span className="font-mono text-fg-muted uppercase">Required Sign-Off</span>
                    <p className="text-fg font-medium">
                      Single Operations Manager authorization required (Beatriz Ocampo or Carlos Mendoza).
                    </p>
                  </div>
                )}
              </div>

              {/* Ledger Status */}
              <div className="p-3 bg-sunken border border-line flex items-center justify-between text-2xs font-mono">
                <span className="text-fg-muted flex items-center gap-1.5">
                  <Lock className="w-3 h-3 text-settled-700" /> Core Vault Status:
                </span>
                <span className="text-settled-700 font-semibold">
                  Soft-Hold Reserved (Awaiting Mutation Commit)
                </span>
              </div>
            </div>

            {/* Actions */}
            <div className="p-3.5 border-t border-line shrink-0 flex items-center justify-between bg-surface">
              <span className="text-2xs text-fg-subtle font-mono">
                BSP Cir. 808 &bull; Segregation of Duties Verified
              </span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setActiveModal(null)}
                  className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors cursor-pointer"
                >
                  Exit
                </button>
                <button
                  type="button"
                  onClick={() => window.print()}
                  className="h-8 px-3 text-xs font-medium bg-accent text-accent-contrast hover:bg-accent-emphasis rounded-none transition-colors flex items-center gap-1.5 cursor-pointer"
                >
                  <Printer className="w-3.5 h-3.5" /> Print Review Slip
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 1: First Manager AMLA Sign-Off Modal */}
      {activeModal === 'sign-first' && selectedTx && (
        <div 
          onClick={(e) => { if (e.target === e.currentTarget) setActiveModal(null); }}
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4"
        >
          <div className="bg-surface border border-line-strong max-w-lg w-full p-5 space-y-4 shadow-2xl relative rounded-none">
            <div className="flex items-center justify-between border-b border-line pb-3">
              <div className="flex items-center gap-2">
                <ShieldAlert className="w-4 h-4 text-held-600" />
                <h4 className="text-sm font-semibold text-fg">
                  AMLA Tier 3 Sign-Off &bull; First Approval (1 of 2)
                </h4>
              </div>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                className="p-1 text-fg-muted hover:text-fg transition-colors cursor-pointer"
                title="Close modal"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-3 bg-sunken border border-line text-2xs space-y-2 font-mono">
              <div className="flex justify-between">
                <span className="text-fg-muted">Transfer Ref:</span>
                <span className="font-semibold text-fg">{selectedTx.id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-muted">Amount:</span>
                <span className="font-semibold text-voided-700">{formatPHP(selectedTx.amount)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-muted">Beneficiary:</span>
                <span className="text-fg">{selectedTx.recipient_name} ({selectedTx.to_account_id})</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-muted">Originating Maker:</span>
                <span className="text-fg">{selectedTx.maker_user_id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-muted">Current Approver:</span>
                <span className="text-accent font-semibold">{user?.name} ({user?.user_id})</span>
              </div>
            </div>

            <div className="p-3 border border-held-200 bg-held-50 text-2xs space-y-1 text-held-700">
              <div className="flex items-center gap-1.5 font-semibold">
                <ShieldCheck className="w-3.5 h-3.5" /> RA 9160 (AMLA) Statutory Review Mandate
              </div>
              <p className="text-fg-muted leading-relaxed">
                Confirming the first approval verifies KYC legitimacy. <strong>Soft hold remains locked in Oracle XE</strong> until a second distinct manager performs final settlement release.
              </p>
            </div>

            <div>
              <label className="block text-2xs font-mono font-semibold text-fg mb-1 uppercase tracking-wider">
                First Manager Verification Notes
              </label>
              <textarea
                rows={3}
                value={approvalNotes}
                onChange={(e) => setApprovalNotes(e.target.value)}
                className="w-full bg-sunken border border-line rounded-none p-2.5 text-xs text-fg focus:outline-none focus:border-accent"
              />
            </div>

            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                onClick={() => setActiveModal(null)}
                className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleFirstApproval}
                disabled={isProcessing}
                className="h-8 px-3 text-xs font-medium bg-accent text-accent-contrast hover:bg-accent-emphasis rounded-none transition-colors cursor-pointer"
              >
                {isProcessing ? 'Recording...' : 'Confirm First Approval (Advance to Stage 2)'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 2: Final Release & Settlement Modal */}
      {activeModal === 'approve' && selectedTx && (
        <div 
          onClick={(e) => { if (e.target === e.currentTarget) setActiveModal(null); }}
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4"
        >
          <div className="bg-surface border border-line-strong max-w-lg w-full p-5 space-y-4 shadow-2xl relative rounded-none">
            <div className="flex items-center justify-between border-b border-line pb-3">
              <div className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-settled-600" />
                <h4 className="text-sm font-semibold text-fg">
                  {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN 
                    ? 'AMLA Tier 3 Final Settlement • Second Approval (2 of 2)'
                    : `Authorize Balance Mutation (${selectedTx.id})`}
                </h4>
              </div>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                className="p-1 text-fg-muted hover:text-fg transition-colors cursor-pointer"
                title="Close modal"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-3 bg-sunken border border-line text-2xs space-y-2 font-mono">
              <div className="flex justify-between">
                <span className="text-fg-muted">Transfer Amount:</span>
                <span className="font-semibold text-fg">{formatPHP(selectedTx.amount)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-muted">Beneficiary:</span>
                <span className="text-fg">{selectedTx.recipient_name} ({selectedTx.to_account_id})</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-muted">Originating Maker:</span>
                <span className="text-fg">{selectedTx.maker_user_id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-muted">Authorizing Manager:</span>
                <span className="text-accent font-semibold">{user?.name} ({user?.user_id})</span>
              </div>
            </div>

            {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN && (
              <div className="p-2.5 border border-settled-200 bg-settled-50 text-2xs space-y-1 text-settled-700">
                <div className="flex items-center gap-1 font-semibold">
                  <CheckCircle2 className="w-3.5 h-3.5" />
                  First Manager Approval Verified
                </div>
                <p className="text-fg-muted">
                  Manager: <span className="font-semibold text-fg">{selectedTx.first_approver_name || 'Operations Manager'}</span> ({selectedTx.first_approver_id || 'Manager 1'})
                </p>
                {selectedTx.first_notes && (
                  <p className="text-fg-subtle italic">
                    "{selectedTx.first_notes}"
                  </p>
                )}
              </div>
            )}

            <div className="p-2.5 bg-sunken border border-line text-2xs space-y-1 text-fg-muted">
              <div className="flex items-center gap-1.5 text-settled-700 font-semibold">
                <CheckCircle2 className="w-3.5 h-3.5" /> Dual-Control Verification Passed
              </div>
              <p className="leading-relaxed">
                Confirming authorization will release the soft hold, execute permanent debit in the Oracle XE core ledger, and dispatch receipt notification.
              </p>
            </div>

            <div>
              <label className="block text-2xs font-mono font-semibold text-fg mb-1 uppercase tracking-wider">
                Manager Authorization Notes
              </label>
              <textarea
                rows={3}
                value={approvalNotes}
                onChange={(e) => setApprovalNotes(e.target.value)}
                className="w-full bg-sunken border border-line rounded-none p-2.5 text-xs text-fg focus:outline-none focus:border-accent"
              />
            </div>

            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                onClick={() => setActiveModal(null)}
                className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleApprove}
                disabled={isProcessing}
                className="h-8 px-3 text-xs font-medium bg-accent text-accent-contrast hover:bg-accent-emphasis rounded-none transition-colors cursor-pointer"
              >
                {isProcessing ? 'Executing Settlement...' : 'Confirm Authorization & Settlement'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 3: Disapproval & Void Modal */}
      {activeModal === 'reject' && selectedTx && (
        <div 
          onClick={(e) => { if (e.target === e.currentTarget) setActiveModal(null); }}
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4"
        >
          <div className="bg-surface border border-line-strong max-w-lg w-full p-5 space-y-4 shadow-2xl relative rounded-none">
            <div className="flex items-center justify-between border-b border-line pb-3">
              <div className="flex items-center gap-2">
                <XCircle className="w-4 h-4 text-voided-600" />
                <h4 className="text-sm font-semibold text-fg">Disapprove &amp; Void Balance Mutation</h4>
              </div>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                className="p-1 text-fg-muted hover:text-fg transition-colors cursor-pointer"
                title="Close modal"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-3 bg-sunken border border-line text-2xs space-y-2 font-mono">
              <div className="flex justify-between">
                <span className="text-fg-muted">Transfer Ref:</span>
                <span className="font-semibold text-voided-700">{selectedTx.id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-muted">Voided Amount:</span>
                <span className="font-semibold text-fg">{formatPHP(selectedTx.amount)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-fg-muted">Reviewing Manager:</span>
                <span className="text-accent font-semibold">{user?.name} ({user?.user_id})</span>
              </div>
            </div>

            <div>
              <label className="block text-2xs font-mono font-semibold text-fg mb-1 uppercase tracking-wider">
                Disapproval Reason (Mandatory Audit Notation)
              </label>
              <textarea
                rows={3}
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                className="w-full bg-sunken border border-line rounded-none p-2.5 text-xs text-fg focus:outline-none focus:border-voided-400"
              />
            </div>

            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                onClick={() => setActiveModal(null)}
                className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleReject}
                disabled={isProcessing}
                className="h-8 px-3 text-xs font-medium bg-voided-600 hover:bg-voided-700 text-white rounded-none transition-colors cursor-pointer"
              >
                {isProcessing ? 'Voiding...' : 'Confirm Disapproval & Release Hold'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
