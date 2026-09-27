import React, { useState, useEffect } from 'react';
import { 
  ShieldCheck, 
  CheckCircle, 
  XCircle, 
  AlertOctagon, 
  Eye, 
  FileText, 
  UserX,
  BadgeAlert,
  ArrowRight,
  ShieldAlert,
  Filter,
  CheckCircle2,
  AlertTriangle
} from 'lucide-react';
import { formatPHP } from '../utils/currency';
import apiClient, { mockState, THRESHOLDS } from '../services/api';
import { useAuth } from '../context/AuthContext';

export default function ManagerPortal({ onActionComplete, showToast }) {
  const { user } = useAuth();
  const [pendingTransfers, setPendingTransfers] = useState([]);
  const [selectedTx, setSelectedTx] = useState(null);
  const [approvalNotes, setApprovalNotes] = useState('Authorized following KYC mandate and dual-control operational review.');
  const [rejectionReason, setRejectionReason] = useState('Disapproved: Inadequate documentation or regulatory mismatch.');
  const [isProcessing, setIsProcessing] = useState(false);
  const [activeModal, setActiveModal] = useState(null); // 'approve' | 'reject' | null
  const [filterTier, setFilterTier] = useState('ALL'); // 'ALL' | 'TIER_2' | 'TIER_3'

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
    if (filterTier === 'TIER_2') return tx.amount > THRESHOLDS.STP_MAX && tx.amount < THRESHOLDS.AMLA_CTR_MIN;
    if (filterTier === 'TIER_3') return tx.amount >= THRESHOLDS.AMLA_CTR_MIN;
    return true;
  });

  const handleApprove = async () => {
    if (!selectedTx) return;

    // Segregation of Duties perimeter check
    if (user?.user_id === selectedTx.maker_user_id) {
      showToast({
        type: 'error',
        title: 'Segregation of Duties Violation',
        detail: 'System policy strictly blocks self-approval. A distinct operations checker must authorize this mutation.',
        rfcInstance: `/api/v1/transfers/${selectedTx.id}/approve`,
      });
      return;
    }

    setIsProcessing(true);
    try {
      const res = await apiClient.post(`/transfers/${selectedTx.id}/approve`, {
        notes: approvalNotes,
        checker_user_id: user?.user_id || 'U3002',
      });

      showToast({
        type: 'success',
        title: 'Transfer Authorized & Released',
        detail: res.data.message || `Transfer ${selectedTx.id} authorized. Oracle master balance debited.`,
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

  const handleReject = async () => {
    if (!selectedTx) return;

    setIsProcessing(true);
    try {
      const res = await apiClient.post(`/transfers/${selectedTx.id}/reject`, {
        reason: rejectionReason,
        checker_user_id: user?.user_id || 'U3002',
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
      {/* Manager Console Header KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        <div className="p-6 rounded-2xl bg-gradient-to-br from-slate-900 to-amber-950/30 border border-amber-500/30 shadow-xl relative overflow-hidden">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-semibold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
              <BadgeAlert className="w-4 h-4" /> Pending Maker-Checker Queue
            </span>
            <span className="px-2.5 py-0.5 rounded-full text-xs font-mono font-bold bg-amber-500/20 text-amber-300 border border-amber-500/30">
              {pendingTransfers.length} PENDING
            </span>
          </div>
          <p className="text-2xl font-mono font-bold text-white tracking-tight">
            {formatPHP(totalHeldAmount)}
          </p>
          <div className="flex items-center justify-between text-xs text-slate-400 mt-2">
            <span>Total volume reserved under soft hold</span>
            {amlaCount > 0 && (
              <span className="text-rose-400 font-semibold text-[11px] flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-rose-400 animate-pulse" /> {amlaCount} AMLA CTR
              </span>
            )}
          </div>
        </div>

        <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1.5 mb-2">
            <ShieldCheck className="w-4 h-4 text-emerald-400" /> Active Checker Session
          </span>
          <p className="text-lg font-bold text-white">{user?.name || 'Beatriz Ocampo'}</p>
          <p className="text-xs font-mono text-emerald-400 mt-1">ID: {user?.user_id} &bull; Operations Manager (Level 1)</p>
          <p className="text-[11px] text-slate-400 mt-2">
            Authorized to sign off on Tier 2 Dual Control and Tier 3 AMLA transactions.
          </p>
        </div>

        <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1.5 mb-2">
            <AlertOctagon className="w-4 h-4 text-indigo-400" /> Regulatory Enforcement
          </span>
          <p className="text-sm font-semibold text-slate-200">Segregation of Duties (Dual-Control)</p>
          <p className="text-xs text-slate-400 mt-1.5 leading-relaxed">
            Rule FSE-204 enforces that the initiating user (maker) cannot authorize their own mutation. Self-approval attempts are blocked at the API gateway.
          </p>
        </div>
      </div>

      {/* Review Queue Table */}
      <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-amber-400" />
              Transactions Awaiting Manager Dual-Control Authorization
            </h3>
            <p className="text-xs text-slate-400 mt-0.5">
              Verify originating maker, beneficiary account, memo, and compliance tier before committing ledger mutation.
            </p>
          </div>

          <div className="flex items-center gap-2">
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
              className="text-xs text-indigo-400 hover:text-indigo-300 font-semibold px-3 py-1.5 rounded-lg bg-slate-950 border border-slate-800 hover:border-slate-700 transition-all"
            >
              Refresh
            </button>
          </div>
        </div>

        {filteredTransfers.length === 0 ? (
          <div className="py-12 text-center text-slate-500 text-xs">
            <CheckCircle className="w-8 h-8 text-emerald-500/40 mx-auto mb-2" />
            No pending transfers matching filter. All transactions authorized or queue is clear.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 font-semibold uppercase text-[10px] tracking-wider">
                <tr>
                  <th className="pb-3">Transfer Ref</th>
                  <th className="pb-3">Sender (Maker)</th>
                  <th className="pb-3">Beneficiary Account</th>
                  <th className="pb-3">Amount (PHP)</th>
                  <th className="pb-3">Regulatory Classification</th>
                  <th className="pb-3">Memo</th>
                  <th className="pb-3 text-right">Review Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filteredTransfers.map((tx) => {
                  const isSelfMaker = user?.user_id === tx.maker_user_id;
                  const isAmla = (tx.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN;

                  return (
                    <tr key={tx.id} className="hover:bg-slate-900/40 transition-colors">
                      <td className="py-3.5 font-mono text-amber-400 font-bold">{tx.id}</td>
                      <td className="py-3.5">
                        <div className="flex items-center gap-1.5">
                          <span className="font-mono text-slate-300 font-semibold">{tx.maker_user_id}</span>
                          {isSelfMaker && (
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-rose-500/20 text-rose-300 border border-rose-500/30 font-semibold">
                              You are Maker
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="py-3.5">
                        <p className="font-semibold text-white">{tx.recipient_name}</p>
                        <p className="text-[10px] font-mono text-slate-400">{tx.to_account_id}</p>
                      </td>
                      <td className="py-3.5 font-mono font-bold text-slate-200">
                        {formatPHP(tx.amount)}
                      </td>
                      <td className="py-3.5">
                        {isAmla ? (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/20 inline-flex items-center gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-rose-400" /> Tier 3 AMLA CTR
                          </span>
                        ) : (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/20 inline-flex items-center gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-amber-400" /> Tier 2 Dual Control
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 text-slate-400 max-w-xs truncate">{tx.memo}</td>
                      <td className="py-3.5 text-right space-x-2">
                        <button
                          onClick={() => {
                            setSelectedTx(tx);
                            setActiveModal('reject');
                          }}
                          className="px-3 py-1.5 rounded-lg bg-rose-600/20 hover:bg-rose-600/30 text-rose-300 font-semibold border border-rose-500/30 text-xs transition-all"
                        >
                          Disapprove
                        </button>
                        <button
                          onClick={() => {
                            setSelectedTx(tx);
                            setActiveModal('approve');
                          }}
                          disabled={isSelfMaker}
                          title={isSelfMaker ? 'Segregation of Duties: Cannot self-approve' : 'Authorize transfer'}
                          className={`px-3 py-1.5 rounded-lg font-semibold text-xs transition-all ${
                            isSelfMaker
                              ? 'bg-slate-800 text-slate-500 border border-slate-700 cursor-not-allowed'
                              : 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-600/20'
                          }`}
                        >
                          Authorize
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Approval Modal */}
      {activeModal === 'approve' && selectedTx && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl">
            <h4 className="text-base font-bold text-white flex items-center gap-2">
              <CheckCircle className="w-5 h-5 text-emerald-400" />
              Authorize Balance Mutation ({selectedTx.id})
            </h4>

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
                <span className="text-slate-400">Classification:</span>
                <span className="text-amber-400 font-semibold">{selectedTx.regulatory_tier || 'TIER_2_DUAL_CONTROL'}</span>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 text-xs space-y-1.5 text-slate-300">
              <div className="flex items-center gap-2 text-emerald-400 text-[11px] font-semibold">
                <CheckCircle2 className="w-3.5 h-3.5" /> Compliance Verification Checklist Passed
              </div>
              <p className="text-[11px] text-slate-400 leading-relaxed">
                Dual-control sign-off confirms identity, sufficient master ledger balance, and releases the soft hold directly into Oracle XE.
              </p>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Manager Verification Notes (Immutable PostgreSQL Audit Sink)
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
                {isProcessing ? 'Executing Settlement...' : 'Confirm Authorization'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Disapproval Modal */}
      {activeModal === 'reject' && selectedTx && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl">
            <h4 className="text-base font-bold text-white flex items-center gap-2">
              <XCircle className="w-5 h-5 text-rose-400" />
              Disapprove &amp; Void Transfer ({selectedTx.id})
            </h4>
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
