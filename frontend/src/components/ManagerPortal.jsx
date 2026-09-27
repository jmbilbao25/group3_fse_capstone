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
  const [activeModal, setActiveModal] = useState(null); // 'approve' | 'sign-l1' | 'reject' | null
  const [filterTier, setFilterTier] = useState('ALL'); // 'ALL' | 'TIER_2' | 'TIER_3'
  const [searchQuery, setSearchQuery] = useState('');

  const fetchPending = async () => {
    try {
      const res = await apiClient.get('/transfers/pending');
      setPendingTransfers(res.data);
    } catch (_) {
      setPendingTransfers(mockState.transfers.filter((t) => t.status === 'PENDING_APPROVAL'));
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

  // Stage 1 Sign-Off (L1 Operations Manager: Beatriz Ocampo)
  const handleSignL1 = async () => {
    if (!selectedTx) return;

    if (user?.user_id === selectedTx.maker_user_id) {
      showToast({
        type: 'error',
        title: 'Segregation of Duties Violation',
        detail: 'System policy strictly blocks self-approval. A distinct operations checker must authorize this mutation.',
        rfcInstance: `/api/v1/transfers/${selectedTx.id}/sign-l1`,
      });
      return;
    }

    setIsProcessing(true);
    try {
      const res = await apiClient.post(`/transfers/${selectedTx.id}/sign-l1`, {
        notes: approvalNotes || 'AMLA CTR Level 1: Verified customer identity, source of funds, and compliance mandate.',
        checker_user_id: user?.user_id || 'U3002',
        checker_name: user?.name || 'Beatriz Ocampo',
      });

      showToast({
        type: 'success',
        title: 'Stage 1 Sign-Off Recorded',
        detail: res.data.message || `Level 1 signed by ${user?.name || 'Beatriz Ocampo'}. Forwarded to Level 2 (Carlos Mendoza) for final release.`,
        rfcInstance: `/api/v1/transfers/${selectedTx.id}`,
      });

      setActiveModal(null);
      setSelectedTx(null);
      await fetchPending();
      onActionComplete();
    } catch (err) {
      showToast({
        type: 'error',
        title: 'Level 1 Sign-Off Failed',
        detail: err.response?.data?.detail || 'Could not record Level 1 sign-off.',
      });
    } finally {
      setIsProcessing(false);
    }
  };

  // Final Approval / Settlement (Tier 2 Single Approver OR Tier 3 L2 Senior Manager)
  const handleApprove = async () => {
    if (!selectedTx) return;

    // Segregation of Duties: Maker cannot approve
    if (user?.user_id === selectedTx.maker_user_id) {
      showToast({
        type: 'error',
        title: 'Segregation of Duties Violation',
        detail: 'System policy strictly blocks self-approval. A distinct operations checker must authorize this mutation.',
        rfcInstance: `/api/v1/transfers/${selectedTx.id}/approve`,
      });
      return;
    }

    // Dual-Control Enforcement: L2 Approver must be distinct from L1 Checker
    const isAmla = (selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN;
    if (isAmla && selectedTx.l1_approver_id && user?.user_id === selectedTx.l1_approver_id) {
      showToast({
        type: 'error',
        title: 'Dual-Control Segregation Violation',
        detail: 'Rule AMLA-204: Level 2 final release must be approved by a distinct Senior Manager (Carlos Mendoza U3003). You already signed Level 1.',
        rfcInstance: `/api/v1/transfers/${selectedTx.id}/approve`,
      });
      return;
    }

    setIsProcessing(true);
    try {
      const res = await apiClient.post(`/transfers/${selectedTx.id}/approve`, {
        notes: approvalNotes || (isAmla ? 'AMLA CTR Level 2: Senior Manager final clearance authorized. Releasing soft hold.' : 'Authorized following KYC mandate and dual-control operational review.'),
        checker_user_id: user?.user_id || (isAmla ? 'U3003' : 'U3002'),
        checker_name: user?.name || (isAmla ? 'Carlos Mendoza' : 'Beatriz Ocampo'),
      });

      showToast({
        type: 'success',
        title: isAmla ? 'AMLA Transfer Fully Settled' : 'Transfer Authorized & Released',
        detail: res.data.message || `Transfer ${selectedTx.id} authorized. Soft hold released and funds settled.`,
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
        detail: err.response?.data?.detail || 'Could not authorize transfer.',
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
        checker_name: user?.name || 'Beatriz Ocampo',
      });

      showToast({
        type: 'warning',
        title: 'Transfer Disapproved & Voided',
        detail: res.data.message || `Transfer ${selectedTx.id} voided. Soft hold released back to sender.`,
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
        detail: err.response?.data?.detail || 'Could not reject transfer.',
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
            <span className="text-xs text-slate-400 hidden md:inline">&bull; {user?.title || (user?.user_id === 'U3003' ? 'Senior Manager (L2)' : 'Operations Manager (L1)')}</span>
          </div>
        </div>

        <div className="flex items-center gap-1.5 bg-slate-950 p-1 rounded-xl border border-slate-800/80 shrink-0">
          <span className="text-[11px] text-slate-500 font-semibold px-2">Switch Approver:</span>
          <button
            onClick={() => switchManager('U3002')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 cursor-pointer ${
              user?.user_id === 'U3002'
                ? 'bg-amber-600 text-white shadow-sm font-bold'
                : 'text-slate-400 hover:text-white hover:bg-slate-900'
            }`}
          >
            <User className="w-3.5 h-3.5" /> Beatriz Ocampo (L1)
          </button>
          <button
            onClick={() => switchManager('U3003')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 cursor-pointer ${
              user?.user_id === 'U3003'
                ? 'bg-emerald-600 text-white shadow-sm font-bold'
                : 'text-slate-400 hover:text-white hover:bg-slate-900'
            }`}
          >
            <ShieldCheck className="w-3.5 h-3.5" /> Carlos Mendoza (L2)
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
            Mandatory RA 9160 dual manager sign-off (L1 + L2)
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
            <div className="flex items-center bg-slate-950 p-1 rounded-xl border border-slate-800 text-xs">
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
                  const stage = tx.approval_stage || 1;
                  const isL1Signed = isAmla && stage === 2;
                  const isCurrentUserL1 = tx.l1_approver_id === user?.user_id || (user?.user_id === 'U3002' && isL1Signed);

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

                      {/* Amount: Clean token badge with whitespace-nowrap */}
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
                            {stage === 1 ? (
                              <p className="text-[10px] text-amber-300 flex items-center gap-1 font-mono">
                                <Clock className="w-3 h-3 text-amber-400 shrink-0" /> Stage 1: Awaiting L1
                              </p>
                            ) : (
                              <p className="text-[10px] text-emerald-400 flex items-center gap-1 font-mono">
                                <CheckCircle2 className="w-3 h-3 text-emerald-400 shrink-0" /> L1 Signed &bull; Awaiting L2
                              </p>
                            )}
                          </div>
                        ) : (
                          <div className="space-y-1">
                            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/25 inline-flex items-center gap-1.5 font-mono shadow-sm">
                              <span className="w-1.5 h-1.5 rounded-full bg-amber-400 shrink-0" /> Tier 2 Dual Control
                            </span>
                            <p className="text-[10px] text-slate-400 flex items-center gap-1 font-mono">
                              <Clock className="w-3 h-3 text-slate-500 shrink-0" /> 1 Approver Required
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
                          ) : stage === 1 ? (
                            /* Tier 3 AMLA: Stage 1 Sign-Off (L1 Operations Checker) */
                            user?.user_id === 'U3003' ? (
                              /* Carlos Mendoza (L2 Approver) view: Awaiting Beatriz Ocampo */
                              <div 
                                className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-800/90 text-amber-300 border border-amber-500/30 shadow-inner"
                                title="Rule AMLA-204: Beatriz Ocampo (U3002) must perform Level 1 Operations review before Level 2 final sign-off."
                              >
                                <Clock className="w-3.5 h-3.5 text-amber-400 shrink-0" />
                                <span>Awaiting L1 Review</span>
                              </div>
                            ) : (
                              /* Beatriz Ocampo (L1 Checker) view: Active Sign L1 button */
                              <button
                                onClick={() => {
                                  setSelectedTx(tx);
                                  setApprovalNotes('AMLA CTR Level 1: Verified customer identity, source of funds, and compliance mandate.');
                                  setActiveModal('sign-l1');
                                }}
                                className="px-4 py-1.5 rounded-xl font-semibold text-xs bg-amber-600 hover:bg-amber-500 text-white shadow-md shadow-amber-600/20 transition-all inline-flex items-center gap-1.5 cursor-pointer"
                              >
                                <ShieldAlert className="w-3.5 h-3.5" />
                                <span>Sign L1</span>
                                <span className="text-[10px] bg-black/30 px-1.5 py-0.5 rounded font-mono font-bold">1/2</span>
                              </button>
                            )
                          ) : isCurrentUserL1 ? (
                            /* Tier 3 AMLA: Stage 2 - Current user already signed L1 */
                            <div 
                              className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 text-amber-300 border border-amber-500/30 cursor-not-allowed shadow-inner"
                              title="Dual-Control Segregation: A distinct Senior Manager (Carlos Mendoza U3003) must execute Stage 2 final release."
                            >
                              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                              <span>Signed L1 &bull; Awaiting L2</span>
                            </div>
                          ) : (
                            /* Tier 3 AMLA: Stage 2 Final Release (L2 Senior Manager: Carlos Mendoza) */
                            <button
                              onClick={() => {
                                setSelectedTx(tx);
                                setApprovalNotes('AMLA CTR Level 2: Senior Manager final clearance authorized. Releasing soft hold.');
                                setActiveModal('approve');
                              }}
                              className="px-4 py-1.5 rounded-xl font-semibold text-xs bg-emerald-600 hover:bg-emerald-500 text-white shadow-lg shadow-emerald-600/30 transition-all inline-flex items-center gap-1.5 cursor-pointer"
                            >
                              <ShieldCheck className="w-3.5 h-3.5" />
                              <span>Final Release (L2)</span>
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

            {/* Header (Fixed Top with Exit Button) */}
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
              {/* Exit Button */}
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                aria-label="Exit Dossier"
                className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer shrink-0"
                title="Exit dossier"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Scrollable Body (Strictly Necessary Banking Details) */}
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
                    {/* Stage 1 */}
                    <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-1.5">
                      <div className="flex items-center justify-between">
                        <span className="text-[10px] font-semibold text-slate-400 uppercase">Stage 1: Operations Checker</span>
                        {selectedTx.l1_approver_id || (selectedTx.approval_stage || 1) === 2 ? (
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
                        {selectedTx.l1_approver_name || 'Beatriz Ocampo'}{' '}
                        <span className="font-mono text-slate-400 text-[10px]">({selectedTx.l1_approver_id || 'U3002'})</span>
                      </p>
                      {selectedTx.l1_notes && (
                        <p className="text-[10px] text-slate-400 italic bg-slate-950 p-2 rounded-lg border border-slate-800/60">
                          "{selectedTx.l1_notes}"
                        </p>
                      )}
                    </div>

                    {/* Stage 2 */}
                    <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-1.5">
                      <div className="flex items-center justify-between">
                        <span className="text-[10px] font-semibold text-slate-400 uppercase">Stage 2: Senior Manager</span>
                        <span className="text-[10px] font-mono text-slate-400 font-bold flex items-center gap-1">
                          <Clock className="w-3 h-3" /> AWAITING RELEASE
                        </span>
                      </div>
                      <p className="font-semibold text-white text-xs">
                        {selectedTx.l2_approver_name || 'Carlos Mendoza'}{' '}
                        <span className="font-mono text-slate-400 text-[10px]">({selectedTx.l2_approver_id || 'U3003'})</span>
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

              {/* 4. Ledger Hold Status (PostgreSQL 15 Append-Only Vault) */}
              <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800/80 flex items-center justify-between text-[11px] font-mono">
                <span className="text-slate-400 flex items-center gap-1.5">
                  <Lock className="w-3.5 h-3.5 text-emerald-400" /> Core Vault Status:
                </span>
                <span className="text-emerald-400 font-bold">
                  Soft-Hold Reserved (Awaiting Mutation Commit)
                </span>
              </div>
            </div>

            {/* Actions (Fixed Bottom with Exit Button) */}
            <div className="p-4 border-t border-slate-800 shrink-0 flex items-center justify-between bg-slate-900/95 backdrop-blur-md">
              <span className="text-[11px] text-slate-500 font-mono">
                BSP Cir. 808 &bull; Segregation of Duties Verified
              </span>
              <div className="flex items-center gap-2">
                {/* Exit Button */}
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

      {/* MODAL 1: Level 1 AMLA Sign-Off Modal */}
      {activeModal === 'sign-l1' && selectedTx && (
        <div 
          onClick={(e) => { if (e.target === e.currentTarget) setActiveModal(null); }}
          className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4"
        >
          <div className="bg-slate-900 border border-amber-500/30 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl relative">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <ShieldAlert className="w-5 h-5 text-amber-400" />
                <h4 className="text-base font-bold text-white">
                  AMLA Tier 3 Sign-Off &bull; Stage 1 of 2
                </h4>
                <span className="text-xs font-mono font-bold px-2 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30">
                  Operations Checker
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
                Confirming Level 1 verifies KYC legitimacy and covered transaction profiling. <strong>Soft hold remains locked in Oracle XE</strong> until Level 2 Senior Manager (Carlos Mendoza) performs final settlement release.
              </p>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Level 1 Verification Notes (Immutable Audit Entry)
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
                onClick={handleSignL1}
                disabled={isProcessing}
                className="px-5 py-2 rounded-xl text-xs font-bold bg-amber-600 hover:bg-amber-500 text-white shadow-lg shadow-amber-600/30 flex items-center gap-1.5"
              >
                {isProcessing ? 'Recording Sign-Off...' : 'Confirm Level 1 Sign-Off (Advance to Stage 2)'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 2: Final Release & Settlement Modal (Tier 2 OR Tier 3 Stage 2) */}
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
                    ? 'AMLA Tier 3 Final Settlement • Stage 2 of 2'
                    : `Authorize Balance Mutation (${selectedTx.id})`}
                </h4>
                <span className="text-xs font-mono font-bold px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                  {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN ? 'Senior Manager L2' : 'Operations Checker'}
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

            {/* If Tier 3 Stage 2: Highlight Level 1 Sign-Off verification */}
            {(selectedTx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN && (
              <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-xs space-y-1 text-emerald-300">
                <div className="flex items-center gap-1.5 font-bold">
                  <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                  Level 1 Audit Sign-Off Verified
                </div>
                <p className="text-[11px] text-slate-300">
                  Operations Checker: <span className="font-semibold text-white">{selectedTx.l1_approver_name || 'Beatriz Ocampo'}</span> ({selectedTx.l1_approver_id || 'U3002'})
                </p>
                {selectedTx.l1_notes && (
                  <p className="text-[11px] text-slate-400 italic">
                    "{selectedTx.l1_notes}"
                  </p>
                )}
              </div>
            )}

            <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 text-xs space-y-1 text-slate-300">
              <div className="flex items-center gap-2 text-emerald-400 text-[11px] font-semibold">
                <CheckCircle2 className="w-3.5 h-3.5" /> Dual-Control Verification Passed
              </div>
              <p className="text-[11px] text-slate-400 leading-relaxed">
                Confirming final authorization will release the soft hold, execute permanent debit in the Oracle XE core ledger, and dispatch receipt notification.
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
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl relative">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h4 className="text-base font-bold text-white flex items-center gap-2">
                <XCircle className="w-5 h-5 text-rose-400" />
                Disapprove &amp; Void Transfer ({selectedTx.id})
              </h4>
              <button
                type="button"
                onClick={() => setActiveModal(null)}
                className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
                title="Close modal"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <p className="text-xs text-slate-400">
              Disapproving this transfer will release the soft hold ({formatPHP(selectedTx.amount)}) back to the customer's liquid available balance.
            </p>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Mandatory Disapproval Reason (Audit Trail Log)
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
                {isProcessing ? 'Voiding Transaction...' : 'Confirm Disapproval'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
