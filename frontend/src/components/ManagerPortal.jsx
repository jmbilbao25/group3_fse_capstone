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
  ArrowRight,
  Clock,
  Layers,
  FileText,
  X,
  ExternalLink,
  Building2,
  Printer
} from 'lucide-react';
import { formatPHP } from '../utils/currency';
import apiClient, { mockState, THRESHOLDS } from '../services/api';
import { useAuth } from '../context/AuthContext';

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
    // 1. Tier Filter
    if (filterTier === 'TIER_2') {
      const isTier2 = (tx.amount || 0) > THRESHOLDS.STP_MAX && (tx.amount || 0) < THRESHOLDS.AMLA_CTR_MIN;
      if (!isTier2) return false;
    }
    if (filterTier === 'TIER_3') {
      const isTier3 = (tx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN;
      if (!isTier3) return false;
    }

    // 2. Search Query Filter
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

  // First Approval Sign-Off (Any manager can execute for transfers >= 500k)
  const handleFirstApproval = async () => {
    if (!selectedTx) return;

    if (user?.user_id === selectedTx.maker_user_id) {
      showToast({
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

      showToast({
        type: 'success',
        title: 'First Approval Recorded',
        detail: res.data?.message || `First approval recorded by ${user?.name || 'Operations Manager'}. Awaiting second manager approval for final release.`,
        rfcInstance: `/api/v1/transfers/${selectedTx.id}`,
      });

      setActiveModal(null);
      setSelectedTx(null);
      await fetchPending();
      onActionComplete();
    } catch (err) {
      showToast({
        type: 'error',
        title: 'First Approval Failed',
        detail: err.response?.data?.detail || err.response?.data?.message || 'Could not record first manager approval.',
      });
    } finally {
      setIsProcessing(false);
    }
  };

  // Final Approval / Settlement (Tier 2 Single Approver OR Tier 3 Second Manager)
  const handleApprove = async () => {
    if (!selectedTx) return;

    // Segregation of Duties: Maker cannot approve
    if (user?.user_id === selectedTx.maker_user_id) {
      showToast({
        type: 'error',
        title: 'Segregation of Duties Violation',
        detail: 'System policy strictly blocks self-approval. A distinct operations manager must authorize this mutation.',
        rfcInstance: `/api/v1/transfers/${selectedTx.id}/approve`,
      });
      return;
    }

    // Dual-Control Enforcement: Second Approver must be distinct from First Approver
    const isAmla = (selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN;
    if (isAmla && selectedTx.first_approver_id && user?.user_id === selectedTx.first_approver_id) {
      showToast({
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

      showToast({
        type: 'success',
        title: isAmla ? 'Transfer Fully Authorized (2 of 2)' : 'Transfer Authorized & Released',
        detail: res.data?.message || `Transfer ${selectedTx.id} authorized. Soft hold released and funds settled.`,
        rfcInstance: `/api/v1/transfers/${selectedTx.id}`,
      });

      setActiveModal(null);
      setSelectedTx(null);
      await fetchPending();
      onActionComplete();
    } catch (err) {
      showToast({
        type: 'error',
        title: 'Approval Failed',
        detail: err.response?.data?.detail || err.response?.data?.message || 'Could not authorize transfer.',
      });
    } finally {
      setIsProcessing(false);
    }
  };

  // Disapprove & Void Transfer (Unlocks soft hold back to customer)
  const handleReject = async () => {
    if (!selectedTx) return;

    setIsProcessing(true);
    try {
      const res = await apiClient.post(`/transfers/${selectedTx.id}/reject`, {
        reason: rejectionReason,
        checker_user_id: user?.user_id || 'U3002',
        checker_name: user?.name || 'Operations Manager',
      });

      showToast({
        type: 'warning',
        title: 'Transfer Disapproved & Voided',
        detail: res.data?.message || `Transfer ${selectedTx.id} voided. Soft hold released back to sender.`,
        rfcInstance: `/api/v1/transfers/${selectedTx.id}`,
      });

      setActiveModal(null);
      setSelectedTx(null);
      await fetchPending();
      onActionComplete();
    } catch (err) {
      showToast({
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
      {/* 1. Sleek Dual-Control Manager Persona Switcher */}
      <div className="p-3.5 px-4 rounded-2xl bg-slate-900/80 border border-slate-800/90 shadow-md flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 shrink-0">
            <UserCheck className="w-4 h-4" />
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <span className="text-xs text-slate-400 font-medium">Session:</span>
            <span className="text-xs font-bold text-white">{user?.name || 'Beatriz Ocampo'}</span>
            <span className="text-[11px] font-mono px-1.5 py-0.5 rounded bg-slate-800 text-indigo-300 border border-slate-700 font-semibold">
              {user?.user_id || 'U3002'}
            </span>
            <span className="text-xs text-slate-400 hidden md:inline">&bull; {user?.title || 'Operations Manager'}</span>
          </div>
        </div>

        <div className="flex items-center gap-1.5 bg-slate-950 p-1 rounded-xl border border-slate-800/80 shrink-0">
          <span className="text-[11px] text-slate-500 font-semibold px-2">Switch Manager:</span>
          <button
            onClick={() => switchManager('U3002')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 cursor-pointer ${
              user?.user_id === 'U3002'
                ? 'bg-amber-600 text-white shadow-sm font-bold'
                : 'text-slate-400 hover:text-white hover:bg-slate-900'
            }`}
          >
            <User className="w-3.5 h-3.5" /> Beatriz Ocampo
          </button>
          <button
            onClick={() => switchManager('U3003')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 cursor-pointer ${
              user?.user_id === 'U3003'
                ? 'bg-emerald-600 text-white shadow-sm font-bold'
                : 'text-slate-400 hover:text-white hover:bg-slate-900'
            }`}
          >
            <ShieldCheck className="w-3.5 h-3.5" /> Carlos Mendoza
          </button>
        </div>
      </div>

      {/* 2. Dynamic Operational KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {/* Pending Queue */}
        <div className="p-5 rounded-2xl bg-gradient-to-br from-amber-950/40 via-slate-900/90 to-slate-900 border border-slate-800/90 hover:border-amber-500/50 shadow-xl relative overflow-hidden group transition-all duration-300">
          <div className="flex items-center justify-between mb-3">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-amber-400">
              Pending Queue
            </span>
            <div className="w-8 h-8 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400 shadow-inner group-hover:scale-105 transition-transform duration-300">
              <BadgeAlert className="w-4 h-4" />
            </div>
          </div>
          <p className="text-2xl font-mono font-bold text-white tracking-tight">
            {pendingTransfers.length} {pendingTransfers.length === 1 ? 'Transfer' : 'Transfers'}
          </p>
          <p className="text-[11px] text-slate-400 mt-1">
            Awaiting dual-control operational sign-off
          </p>
        </div>

        {/* Total Soft Hold Volume */}
        <div className="p-5 rounded-2xl bg-gradient-to-br from-indigo-950/40 via-slate-900/90 to-slate-900 border border-slate-800/90 hover:border-indigo-500/50 shadow-xl relative overflow-hidden group transition-all duration-300">
          <div className="flex items-center justify-between mb-3">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-indigo-400">
              Total Soft-Hold Volume
            </span>
            <div className="w-8 h-8 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 shadow-inner group-hover:scale-105 transition-transform duration-300">
              <Lock className="w-4 h-4" />
            </div>
          </div>
          <p className="text-2xl font-mono font-bold text-white tracking-tight">
            {formatPHP(totalHeldAmount)}
          </p>
          <p className="text-[11px] text-slate-400 mt-1">
            Funds reserved in ledger until authorized or voided
          </p>
        </div>

        {/* AMLA High-Value Items */}
        <div className="p-5 rounded-2xl bg-gradient-to-br from-rose-950/40 via-slate-900/90 to-slate-900 border border-slate-800/90 hover:border-rose-500/50 shadow-xl relative overflow-hidden group transition-all duration-300">
          <div className="flex items-center justify-between mb-3">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-rose-400">
              AMLA High-Value Items
            </span>
            <div className="w-8 h-8 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-400 shadow-inner group-hover:scale-105 transition-transform duration-300">
              <ShieldAlert className="w-4 h-4" />
            </div>
          </div>
          <p className="text-2xl font-mono font-bold text-white tracking-tight">
            {amlaCount} {amlaCount === 1 ? 'Transfer' : 'Transfers'}
          </p>
          <p className="text-[11px] text-slate-400 mt-1">
            Mandatory RA 9160 two-manager sign-off (2 Approvals Required)
          </p>
        </div>
      </div>

      {/* 3. Review Queue Table */}
      <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
        <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4">
          <div>
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-amber-400" />
              Transactions Awaiting Authorization
            </h3>
            <p className="text-xs text-slate-400 mt-0.5">
              Review originating maker and regulatory classification before committing balance mutation.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2.5 w-full lg:w-auto">
            {/* Search Input */}
            <div className="relative">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-3" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search ref, maker, memo..."
                className="w-full sm:w-56 bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-3 py-1.5 text-xs text-white focus:outline-none focus:border-indigo-500"
              />
            </div>

            {/* Filter buttons */}
            <div className="flex items-center gap-1 bg-slate-950 p-1 rounded-xl border border-slate-800 text-xs">
              <button
                onClick={() => setFilterTier('ALL')}
                className={`px-3 py-1 rounded-lg transition-all ${
                  filterTier === 'ALL' ? 'bg-indigo-600 text-white font-semibold' : 'text-slate-400 hover:text-white'
                }`}
              >
                All ({pendingTransfers.length})
              </button>
              <button
                onClick={() => setFilterTier('TIER_2')}
                className={`px-3 py-1 rounded-lg transition-all ${
                  filterTier === 'TIER_2' ? 'bg-amber-600 text-white font-semibold' : 'text-slate-400 hover:text-white'
                }`}
              >
                Tier 2 (&gt; ₱50k)
              </button>
              <button
                onClick={() => setFilterTier('TIER_3')}
                className={`px-3 py-1 rounded-lg transition-all ${
                  filterTier === 'TIER_3' ? 'bg-rose-600 text-white font-semibold' : 'text-slate-400 hover:text-white'
                }`}
              >
                Tier 3 AMLA (≥ ₱500k)
              </button>
            </div>

            <button
              onClick={fetchPending}
              className="text-xs text-indigo-400 hover:text-indigo-300 font-semibold px-3 py-1.5 rounded-lg bg-slate-950 border border-slate-800 hover:border-slate-700 transition-all text-center"
            >
              Refresh
            </button>
          </div>
        </div>

        {filteredTransfers.length === 0 ? (
          <div className="py-12 text-center text-slate-500 text-xs">
            <CheckCircle className="w-8 h-8 text-emerald-500/40 mx-auto mb-2" />
            No pending transfers matching filter or search query. All transactions authorized or queue is clear.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800/80 text-slate-400 font-semibold uppercase text-[10px] tracking-wider bg-slate-950/40">
                <tr>
                  <th className="py-3.5 px-4 first:pl-5 w-[140px]">Transfer Ref</th>
                  <th className="py-3.5 px-4 w-[160px]">Sender (Maker)</th>
                  <th className="py-3.5 px-4 w-[190px]">Beneficiary Entity</th>
                  <th className="py-3.5 px-4 w-[160px]">Amount (PHP)</th>
                  <th className="py-3.5 px-4 w-[230px]">Regulatory Tier &amp; Status</th>
                  <th className="py-3.5 px-4 min-w-[180px]">Memo / Purpose</th>
                  <th className="py-3.5 px-4 last:pr-5 text-right w-[240px]">Review Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredTransfers.map((tx) => {
                  const isSelfMaker = user?.user_id === tx.maker_user_id;
                  const isAmla = (tx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN;
                  const hasFirstApproval = Boolean(tx.first_approver_id);
                  const isCurrentUserFirstApprover = tx.first_approver_id === user?.user_id;

                  return (
                    <tr key={tx.id} className="hover:bg-slate-800/40 transition-colors">
                      {/* Ref: Clickable & Uniform Pill */}
                      <td className="py-4 px-4 first:pl-5 whitespace-nowrap align-middle">
                        <button
                          type="button"
                          onClick={() => {
                            setSelectedTx(tx);
                            setActiveModal('details');
                          }}
                          className="px-2.5 py-1 rounded-lg bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 hover:text-amber-300 border border-amber-500/25 transition-all cursor-pointer inline-flex items-center gap-1.5 font-mono font-bold text-xs group"
                          title="Click to view complete transfer authorization dossier"
                        >
                          <span>{tx.id}</span>
                          <ExternalLink className="w-3 h-3 opacity-60 group-hover:opacity-100 transition-opacity" />
                        </button>
                      </td>

                      {/* Sender (Maker): Name + ID */}
                      <td className="py-4 px-4 align-middle">
                        <p className="font-semibold text-white text-xs leading-snug">
                          {tx.maker_name || (tx.maker_user_id === 'U1001' ? 'Juan Dela Cruz' : tx.maker_user_id)}
                        </p>
                        <div className="flex items-center gap-1.5 mt-0.5">
                          <span className="font-mono text-slate-400 text-[10px]">{tx.maker_user_id}</span>
                          {isSelfMaker && (
                            <span className="text-[9px] px-1.5 py-0.2 rounded bg-rose-500/20 text-rose-300 border border-rose-500/30 font-semibold">
                              You are Maker
                            </span>
                          )}
                        </div>
                      </td>

                      {/* Beneficiary Entity */}
                      <td className="py-4 px-4 align-middle">
                        <p className="font-semibold text-white text-xs leading-snug">{tx.recipient_name}</p>
                        <p className="text-[10px] font-mono text-slate-400 mt-0.5">{tx.to_account_id}</p>
                      </td>

                      {/* Amount */}
                      <td className="py-4 px-4 whitespace-nowrap align-middle">
                        <span className="px-2.5 py-1 rounded-lg font-mono font-bold text-white text-xs bg-slate-950 border border-slate-800 shadow-inner inline-block">
                          {formatPHP(tx.amount)}
                        </span>
                      </td>

                      {/* Regulatory Classification & Dual-Control Status */}
                      <td className="py-4 px-4 align-middle">
                        {isAmla ? (
                          <div className="space-y-1">
                            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/25 inline-flex items-center gap-1.5 font-mono shadow-sm">
                              <span className="w-1.5 h-1.5 rounded-full bg-rose-400 shrink-0" /> Tier 3 AMLA CTR
                            </span>
                            {!hasFirstApproval ? (
                              <p className="text-[10px] text-amber-300 flex items-center gap-1 font-mono">
                                <Clock className="w-3 h-3 text-amber-400 shrink-0" /> Stage 1: Awaiting 1st Approval
                              </p>
                            ) : (
                              <p className="text-[10px] text-emerald-400 flex items-center gap-1 font-mono">
                                <CheckCircle2 className="w-3 h-3 text-emerald-400 shrink-0" /> 1 of 2 Approved &bull; Awaiting 2nd Approval
                              </p>
                            )}
                          </div>
                        ) : (
                          <div className="space-y-1">
                            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/25 inline-flex items-center gap-1.5 font-mono shadow-sm">
                              <span className="w-1.5 h-1.5 rounded-full bg-amber-400 shrink-0" /> Tier 2 Dual Control
                            </span>
                            <p className="text-[10px] text-slate-400 flex items-center gap-1 font-mono">
                              <Clock className="w-3 h-3 text-slate-500 shrink-0" /> 1 Manager Approval Required
                            </p>
                          </div>
                        )}
                      </td>

                      {/* Memo */}
                      <td className="py-4 px-4 align-middle">
                        <p className="text-slate-300 text-xs italic line-clamp-2 max-w-[240px]" title={tx.memo}>
                          "{tx.memo || 'Standard Retail Transfer'}"
                        </p>
                      </td>

                      {/* Action Buttons */}
                      <td className="py-4 px-4 last:pr-5 text-right whitespace-nowrap align-middle">
                        <div className="inline-flex items-center justify-end gap-2.5">
                          {/* Disapprove */}
                          <button
                            onClick={() => {
                              setSelectedTx(tx);
                              setActiveModal('reject');
                            }}
                            className="px-3 py-1.5 rounded-xl bg-rose-600/20 hover:bg-rose-600/30 text-rose-300 font-semibold border border-rose-500/30 text-xs transition-all cursor-pointer"
                          >
                            Disapprove
                          </button>

                          {/* Smart Authorization Action */}
                          {isSelfMaker ? (
                            <button
                              disabled
                              title="Segregation of Duties: Initiating maker cannot authorize own balance mutation."
                              className="px-3.5 py-1.5 rounded-xl font-semibold text-xs bg-slate-800 text-slate-500 border border-slate-700 cursor-not-allowed inline-flex items-center gap-1"
                            >
                              <Lock className="w-3.5 h-3.5" /> Self-Approval Blocked
                            </button>
                          ) : !isAmla ? (
                            /* Tier 2: Single Manager Authorization */
                            <button
                              onClick={() => {
                                setSelectedTx(tx);
                                setApprovalNotes('Authorized following KYC mandate and dual-control operational review.');
                                setActiveModal('approve');
                              }}
                              className="px-4 py-1.5 rounded-xl font-semibold text-xs bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-600/20 transition-all inline-flex items-center gap-1.5 cursor-pointer"
                            >
                              <CheckCircle className="w-3.5 h-3.5" /> Authorize
                            </button>
                          ) : !hasFirstApproval ? (
                            /* Tier 3 AMLA: First Manager Approval (any manager can sign) */
                            <button
                              onClick={() => {
                                setSelectedTx(tx);
                                setApprovalNotes('AMLA CTR First Approval: Verified customer identity, source of funds, and statutory mandate.');
                                setActiveModal('sign-first');
                              }}
                              className="px-4 py-1.5 rounded-xl font-semibold text-xs bg-amber-600 hover:bg-amber-500 text-white shadow-md shadow-amber-600/20 transition-all inline-flex items-center gap-1.5 cursor-pointer"
                            >
                              <ShieldAlert className="w-3.5 h-3.5" />
                              <span>First Approval</span>
                              <span className="text-[10px] bg-black/30 px-1.5 py-0.5 rounded font-mono font-bold">1/2</span>
                            </button>
                          ) : isCurrentUserFirstApprover ? (
                            /* Tier 3 AMLA: Current user already signed the first approval */
                            <div 
                              className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 text-amber-300 border border-amber-500/30 cursor-not-allowed shadow-inner"
                              title="Dual-Control Segregation: The second approval must be signed by a distinct manager."
                            >
                              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                              <span>Approved (1/2) &bull; Awaiting 2nd Manager</span>
                            </div>
                          ) : (
                            /* Tier 3 AMLA: Second Manager Final Approval (any distinct manager) */
                            <button
                              onClick={() => {
                                setSelectedTx(tx);
                                setApprovalNotes('AMLA CTR Second Approval: Dual manager clearance authorized. Releasing soft hold.');
                                setActiveModal('approve');
                              }}
                              className="px-4 py-1.5 rounded-xl font-semibold text-xs bg-emerald-600 hover:bg-emerald-500 text-white shadow-lg shadow-emerald-600/30 transition-all inline-flex items-center gap-1.5 cursor-pointer"
                            >
                              <ShieldCheck className="w-3.5 h-3.5" />
                              <span>Second Approval</span>
                              <span className="text-[10px] bg-black/30 px-1.5 py-0.5 rounded font-mono font-bold">2/2</span>
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

      {/* MODAL 0: Detailed Transaction Dossier Modal (View Details) */}
      {activeModal === 'details' && selectedTx && (
        <div 
          onClick={(e) => { if (e.target === e.currentTarget) setActiveModal(null); }}
          className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex items-center justify-center p-4 sm:p-6 animate-in fade-in duration-200"
        >
          <div className="bg-slate-900 border border-amber-500/30 rounded-3xl max-w-2xl w-full max-h-[88vh] flex flex-col shadow-2xl relative overflow-hidden animate-in zoom-in-95 duration-200">
            {/* Top decorative gradient bar */}
            <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-amber-500 via-indigo-500 to-emerald-500 z-10" />

            {/* Header */}
            <div className="p-5 border-b border-slate-800 shrink-0 flex items-start justify-between bg-slate-900/95 backdrop-blur-md pt-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-amber-500/10 border border-amber-500/25 flex items-center justify-center text-amber-400 shadow-inner shrink-0">
                  <FileText className="w-5 h-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-base sm:text-lg font-bold text-white tracking-tight">
                      Transfer Authorization Dossier
                    </h3>
                    <span className="text-amber-400 font-mono font-bold text-xs px-2 py-0.5 rounded-full bg-amber-500/10 border border-amber-500/20">
                      {selectedTx.id}
                    </span>
                  </div>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Dual-Control Workstation &bull; Soft-Hold Verification &amp; KYC Ledger Record
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                aria-label="Exit Dossier"
                className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer shrink-0"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Scrollable Body */}
            <div className="p-5 overflow-y-auto space-y-4 flex-1 text-xs">
              {/* 1. Core Financial Banner */}
              <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div>
                  <span className="text-[10px] font-semibold text-slate-400 uppercase tracking-wider block">
                    Pending Transfer Amount
                  </span>
                  <div className="flex items-baseline gap-2 mt-0.5">
                    <span className="font-mono font-bold text-amber-400 text-xl">
                      {formatPHP(selectedTx.amount)}
                    </span>
                    <span className="text-slate-500 font-mono text-[11px]">
                      (PHP Soft-Hold Locked)
                    </span>
                  </div>
                </div>

                <div>
                  <span className="text-[10px] font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                    Regulatory Classification
                  </span>
                  {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN ? (
                    <span className="px-3 py-1 rounded-full text-[11px] font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/25 inline-flex items-center gap-1.5 font-mono shadow-sm">
                      <ShieldAlert className="w-3.5 h-3.5" /> TIER 3: AMLA CTR (&ge; ₱500k)
                    </span>
                  ) : (
                    <span className="px-3 py-1 rounded-full text-[11px] font-semibold bg-amber-500/10 text-amber-300 border border-amber-500/25 inline-flex items-center gap-1.5 font-mono shadow-sm">
                      <ShieldCheck className="w-3.5 h-3.5" /> TIER 2: DUAL-CONTROL (&gt; ₱50k)
                    </span>
                  )}
                </div>
              </div>

              {/* 2. KYC Originating Maker & Beneficiary Entity Records */}
              <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 space-y-3">
                <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
                  <Building2 className="w-3.5 h-3.5 text-slate-400" /> Originating &amp; Beneficiary Account Records (KYC)
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div className="p-3 rounded-xl bg-slate-900/60 border border-slate-800/80 space-y-1">
                    <span className="text-[10px] text-slate-500 uppercase font-semibold block">Originating Sender (Maker)</span>
                    <p className="font-semibold text-white">
                      {selectedTx.maker_name || (selectedTx.maker_user_id === 'U1001' ? 'Juan Dela Cruz' : selectedTx.maker_user_id)}
                    </p>
                    <p className="font-mono text-slate-400 text-[11px]">
                      ID: {selectedTx.maker_user_id || 'U1001'} &bull; Acct: {selectedTx.from_account_id || '1000-2000-3001'}
                    </p>
                  </div>
                  <div className="p-3 rounded-xl bg-slate-900/60 border border-slate-800/80 space-y-1">
                    <span className="text-[10px] text-slate-500 uppercase font-semibold block">Beneficiary Entity (Receiver)</span>
                    <p className="font-semibold text-white">{selectedTx.recipient_name}</p>
                    <p className="font-mono text-slate-400 text-[11px]">Acct: {selectedTx.to_account_id}</p>
                  </div>
                </div>
                <div className="pt-2 border-t border-slate-800/60 flex items-center justify-between text-[11px]">
                  <span className="text-slate-400">Payment Purpose / Memo:</span>
                  <span className="font-semibold text-slate-200 italic">{selectedTx.memo || 'Standard Retail Transfer'}</span>
                </div>
              </div>

              {/* 3. Dual-Control Approval Mandate & Sign-Off Status */}
              <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 space-y-3">
                <span className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
                  <UserCheck className="w-3.5 h-3.5 text-indigo-400" /> Dual-Control Authorization Progress
                </span>

                {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN ? (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {/* First Approval */}
                    <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-1.5">
                      <div className="flex items-center justify-between">
                        <span className="text-[10px] font-semibold text-slate-400 uppercase">First Manager Approval</span>
                        {selectedTx.first_approver_id ? (
                          <span className="text-[10px] font-mono text-emerald-400 font-bold flex items-center gap-1">
                            <CheckCircle2 className="w-3 h-3" /> SIGNED
                          </span>
                        ) : (
                          <span className="text-[10px] font-mono text-amber-400 font-bold flex items-center gap-1">
                            <Clock className="w-3 h-3" /> PENDING
                          </span>
                        )}
                      </div>
                      <p className="font-semibold text-white text-xs">
                        {selectedTx.first_approver_name || 'Operations Manager'}{' '}
                        {selectedTx.first_approver_id && (
                          <span className="font-mono text-slate-400 text-[10px]">({selectedTx.first_approver_id})</span>
                        )}
                      </p>
                      {selectedTx.first_notes && (
                        <p className="text-[10px] text-slate-400 italic bg-slate-950 p-2 rounded-lg border border-slate-800/60">
                          "{selectedTx.first_notes}"
                        </p>
                      )}
                    </div>

                    {/* Second Approval */}
                    <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-1.5">
                      <div className="flex items-center justify-between">
                        <span className="text-[10px] font-semibold text-slate-400 uppercase">Second Manager Approval</span>
                        <span className="text-[10px] font-mono text-slate-400 font-bold flex items-center gap-1">
                          <Clock className="w-3 h-3" /> AWAITING RELEASE
                        </span>
                      </div>
                      <p className="font-semibold text-white text-xs">
                        {selectedTx.second_approver_name || 'Operations Manager (Distinct)'}
                      </p>
                    </div>
                  </div>
                ) : (
                  <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-1">
                    <span className="text-[10px] font-semibold text-slate-400 uppercase">Required Sign-Off</span>
                    <p className="text-slate-200 text-xs font-semibold">
                      Single Operations Manager authorization required (Beatriz Ocampo or Carlos Mendoza).
                    </p>
                  </div>
                )}
              </div>

              {/* 4. Ledger Hold Status */}
              <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between text-[11px] font-mono">
                <span className="text-slate-400 flex items-center gap-1.5">
                  <Lock className="w-3.5 h-3.5 text-emerald-400" /> Core Vault Status:
                </span>
                <span className="text-emerald-400 font-bold">
                  Soft-Hold Reserved (Awaiting Mutation Commit)
                </span>
              </div>
            </div>

            {/* Actions */}
            <div className="p-4 border-t border-slate-800 shrink-0 flex items-center justify-between bg-slate-900/95 backdrop-blur-md">
              <span className="text-[11px] text-slate-500 font-mono">
                BSP Cir. 808 &bull; Segregation of Duties Verified
              </span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setActiveModal(null)}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition-all cursor-pointer"
                >
                  Exit
                </button>
                <button
                  type="button"
                  onClick={() => window.print()}
                  className="px-5 py-2 rounded-xl text-xs font-bold bg-amber-600 hover:bg-amber-500 text-white shadow-md shadow-amber-600/30 transition-all flex items-center gap-1.5 cursor-pointer"
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
          className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4"
        >
          <div className="bg-slate-900 border border-amber-500/30 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl relative">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <ShieldAlert className="w-5 h-5 text-amber-400" />
                <h4 className="text-base font-bold text-white">
                  AMLA Tier 3 Sign-Off &bull; First Approval (1 of 2)
                </h4>
                <span className="text-xs font-mono font-bold px-2 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30">
                  Operations Manager
                </span>
              </div>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
                title="Close modal"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs space-y-2 font-mono">
              <div className="flex justify-between">
                <span className="text-slate-400">Transfer Reference:</span>
                <span className="font-bold text-amber-400">{selectedTx.id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Transaction Amount:</span>
                <span className="font-bold text-emerald-400">{formatPHP(selectedTx.amount)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Beneficiary:</span>
                <span className="text-slate-200">{selectedTx.recipient_name} ({selectedTx.to_account_id})</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Originating Maker:</span>
                <span className="text-slate-200">{selectedTx.maker_user_id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Current Approver:</span>
                <span className="text-indigo-400 font-semibold">{user?.name} ({user?.user_id})</span>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-xs space-y-1.5 text-amber-200">
              <div className="flex items-center gap-2 font-semibold">
                <ShieldCheck className="w-4 h-4 text-amber-400" /> RA 9160 (AMLA) Statutory Review Mandate
              </div>
              <p className="text-[11px] text-slate-300 leading-relaxed">
                Confirming the first approval verifies KYC legitimacy and covered transaction profiling. <strong>Soft hold remains locked in Oracle XE</strong> until a second distinct manager performs final settlement release.
              </p>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                First Manager Verification Notes (Immutable Audit Entry)
              </label>
              <textarea
                rows={3}
                value={approvalNotes}
                onChange={(e) => setApprovalNotes(e.target.value)}
                className="w-full bg-slate-950 border border-slate-700/80 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-amber-500"
              />
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                onClick={() => setActiveModal(null)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white"
              >
                Cancel
              </button>
              <button
                onClick={handleFirstApproval}
                disabled={isProcessing}
                className="px-5 py-2 rounded-xl text-xs font-bold bg-amber-600 hover:bg-amber-500 text-white shadow-lg shadow-amber-600/30 flex items-center gap-1.5"
              >
                {isProcessing ? 'Recording First Approval...' : 'Confirm First Approval (Advance to Stage 2)'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 2: Final Release & Settlement Modal (Tier 2 OR Tier 3 Second Manager) */}
      {activeModal === 'approve' && selectedTx && (
        <div 
          onClick={(e) => { if (e.target === e.currentTarget) setActiveModal(null); }}
          className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4"
        >
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl relative">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <CheckCircle className="w-5 h-5 text-emerald-400" />
                <h4 className="text-base font-bold text-white">
                  {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN 
                    ? 'AMLA Tier 3 Final Settlement • Second Approval (2 of 2)'
                    : `Authorize Balance Mutation (${selectedTx.id})`}
                </h4>
                <span className="text-xs font-mono font-bold px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                  Operations Manager
                </span>
              </div>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
                title="Close modal"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs space-y-2 font-mono">
              <div className="flex justify-between">
                <span className="text-slate-400">Transfer Amount:</span>
                <span className="font-bold text-emerald-400">{formatPHP(selectedTx.amount)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Beneficiary:</span>
                <span className="text-slate-200">{selectedTx.recipient_name} ({selectedTx.to_account_id})</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Originating Maker:</span>
                <span className="text-slate-200">{selectedTx.maker_user_id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Authorizing Manager:</span>
                <span className="text-indigo-400 font-semibold">{user?.name} ({user?.user_id})</span>
              </div>
            </div>

            {/* If Tier 3: Highlight First Manager Sign-Off verification */}
            {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN && (
              <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-xs space-y-1 text-emerald-300">
                <div className="flex items-center gap-1.5 font-bold">
                  <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                  First Manager Approval Verified
                </div>
                <p className="text-[11px] text-slate-300">
                  Operations Manager: <span className="font-semibold text-white">{selectedTx.first_approver_name || 'Operations Manager'}</span> ({selectedTx.first_approver_id || 'Manager 1'})
                </p>
                {selectedTx.first_notes && (
                  <p className="text-[11px] text-slate-400 italic">
                    "{selectedTx.first_notes}"
                  </p>
                )}
              </div>
            )}

            <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 text-xs space-y-1 text-slate-300">
              <div className="flex items-center gap-2 text-emerald-400 text-[11px] font-semibold">
                <CheckCircle2 className="w-3.5 h-3.5" /> Dual-Control Verification Passed
              </div>
              <p className="text-[11px] text-slate-400 leading-relaxed">
                Confirming authorization will release the soft hold, execute permanent debit in the Oracle XE core ledger, and dispatch receipt notification.
              </p>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Manager Authorization Notes (Immutable PostgreSQL Audit Sink)
              </label>
              <textarea
                rows={3}
                value={approvalNotes}
                onChange={(e) => setApprovalNotes(e.target.value)}
                className="w-full bg-slate-950 border border-slate-700/80 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                onClick={() => setActiveModal(null)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white"
              >
                Cancel
              </button>
              <button
                onClick={handleApprove}
                disabled={isProcessing}
                className="px-5 py-2 rounded-xl text-xs font-bold bg-emerald-600 hover:bg-emerald-500 text-white shadow-lg shadow-emerald-600/30"
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
          className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4"
        >
          <div className="bg-slate-900 border border-rose-500/30 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl relative">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <XCircle className="w-5 h-5 text-rose-400" />
                <h4 className="text-base font-bold text-white">Disapprove &amp; Void Balance Mutation</h4>
              </div>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
                title="Close modal"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-3.5 rounded-xl bg-slate-950 border border-slate-800 text-xs space-y-2 font-mono">
              <div className="flex justify-between">
                <span className="text-slate-400">Transfer Ref:</span>
                <span className="font-bold text-rose-400">{selectedTx.id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Voided Amount:</span>
                <span className="font-bold text-white">{formatPHP(selectedTx.amount)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-400">Reviewing Manager:</span>
                <span className="text-indigo-400 font-semibold">{user?.name} ({user?.user_id})</span>
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Disapproval Reason (Mandatory BSP Audit Notation)
              </label>
              <textarea
                rows={3}
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                className="w-full bg-slate-950 border border-slate-700/80 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-rose-500"
              />
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                onClick={() => setActiveModal(null)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white"
              >
                Cancel
              </button>
              <button
                onClick={handleReject}
                disabled={isProcessing}
                className="px-5 py-2 rounded-xl text-xs font-bold bg-rose-600 hover:bg-rose-500 text-white shadow-lg shadow-rose-600/30"
              >
                {isProcessing ? 'Voiding Transfer...' : 'Confirm Disapproval & Release Hold'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
