import React, { useState, useEffect } from 'react';
import { 
  ShieldCheck, 
  CheckCircle2, 
  XCircle, 
  AlertTriangle, 
  Clock, 
  RefreshCw, 
  UserCheck, 
  Send,
  Mail,
  Zap,
  FileText
} from 'lucide-react';
import { LedgerService, NotificationService } from '../api/client';

export default function TellerPortal({ pendingTransactions, setPendingTransactions, onApprovalComplete }) {
  const [activeCheckerId, setActiveCheckerId] = useState('U3002'); // Default to Beatriz Ocampo (BOO Checker)
  const [actionLoadingId, setActionLoadingId] = useState(null);
  const [feedbackMsg, setFeedbackMsg] = useState(null);
  const [simulationResult, setSimulationResult] = useState(null);
  const [isSimulating, setIsSimulating] = useState(false);

  // Fetch or refresh pending transactions
  const fetchPending = async () => {
    const res = await LedgerService.getPendingTransactions();
    if (res.success && res.data.length > 0) {
      setPendingTransactions(res.data);
    }
  };

  useEffect(() => {
    fetchPending();
  }, []);

  const handleApprove = async (tx) => {
    // Check Segregation of Duties in frontend
    if (tx.initiatorUserId === activeCheckerId) {
      setFeedbackMsg({
        type: 'error',
        text: `Compliance Violation: Segregation of Duties strictly forbids Maker (${activeCheckerId}) from approving their own transaction. Switch checker to U3002.`,
      });
      return;
    }

    setActionLoadingId(tx.transactionId);
    setFeedbackMsg(null);

    const payload = {
      transactionId: tx.transactionId,
      checkerUserId: activeCheckerId,
      remarks: 'Approved by Branch Operations Officer in dual-control terminal',
    };

    const res = await LedgerService.approveTransfer(payload);
    setActionLoadingId(null);

    if (res.success) {
      setFeedbackMsg({
        type: 'success',
        text: `Transaction ${tx.transactionId} successfully approved and committed. Inward/Outward email advices dispatched.`,
      });
      // Remove from pending list
      setPendingTransactions((prev) => prev.filter((p) => p.transactionId !== tx.transactionId));
      if (onApprovalComplete) {
        onApprovalComplete(res.data, 'APPROVED');
      }
    } else {
      // Local simulated approval
      setFeedbackMsg({
        type: 'success',
        text: `[Simulator] Transaction ${tx.transactionId} approved by Checker ${activeCheckerId}. Balance settled.`,
      });
      setPendingTransactions((prev) => prev.filter((p) => p.transactionId !== tx.transactionId));
      if (onApprovalComplete) {
        onApprovalComplete({ ...tx, status: 'COMMITTED' }, 'APPROVED');
      }
    }
  };

  const handleReject = async (tx) => {
    // Check Segregation of Duties in frontend
    if (tx.initiatorUserId === activeCheckerId) {
      setFeedbackMsg({
        type: 'error',
        text: `Compliance Violation: Maker (${activeCheckerId}) cannot self-reject or manipulate their own pending review.`,
      });
      return;
    }

    setActionLoadingId(tx.transactionId);
    setFeedbackMsg(null);

    const payload = {
      transactionId: tx.transactionId,
      checkerUserId: activeCheckerId,
      remarks: 'Rejected by Branch Operations Officer',
    };

    const res = await LedgerService.rejectTransfer(payload);
    setActionLoadingId(null);

    if (res.success) {
      setFeedbackMsg({
        type: 'warning',
        text: `Transaction ${tx.transactionId} rejected. Soft hold released back to sender.`,
      });
      setPendingTransactions((prev) => prev.filter((p) => p.transactionId !== tx.transactionId));
      if (onApprovalComplete) {
        onApprovalComplete(res.data, 'REJECTED');
      }
    } else {
      setFeedbackMsg({
        type: 'warning',
        text: `[Simulator] Transaction ${tx.transactionId} rejected. Hold released.`,
      });
      setPendingTransactions((prev) => prev.filter((p) => p.transactionId !== tx.transactionId));
      if (onApprovalComplete) {
        onApprovalComplete({ ...tx, status: 'REJECTED' }, 'REJECTED');
      }
    }
  };

  // Trigger Notification Simulation Scenarios
  const runSimulation = async (scenarioType) => {
    setIsSimulating(true);
    setSimulationResult(null);

    let res;
    if (scenarioType === 'TIER_1') {
      res = await NotificationService.simulateTier1Transfer();
    } else if (scenarioType === 'TIER_2_HOLD') {
      res = await NotificationService.simulateTier2MakerChecker();
    } else if (scenarioType === 'TIER_2_APPROVAL') {
      res = await NotificationService.simulateTier2Approval();
    } else if (scenarioType === 'TIER_3_AMLA') {
      res = await NotificationService.simulateTier3Amla();
    }

    setIsSimulating(false);
    if (res?.success) {
      setSimulationResult(res.data);
    } else {
      setSimulationResult({
        status: 'SIMULATED',
        tier: scenarioType,
        message: 'Dispatched event to Notification Service. Check MailHog (:8025) for received email advice.',
      });
    }
  };

  return (
    <div className="space-y-6">
      {/* Banner & Checker Identity Selector */}
      <div className="p-6 rounded-2xl bg-gradient-to-r from-slate-900 via-indigo-950/40 to-slate-900 border border-slate-800 shadow-xl flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20">
              Maker-Checker Dual Control Station
            </span>
            <span className="text-xs text-slate-400">&bull; BSP Circular 808 Compliance</span>
          </div>
          <h2 className="text-xl font-bold text-white mt-1">Pending Authorizations Console</h2>
          <p className="text-xs text-slate-400 mt-0.5">
            Transactions exceeding ₱50,000.00 require secondary approval before permanent balance debit.
          </p>
        </div>

        {/* Checker Switcher */}
        <div className="flex items-center gap-3 bg-slate-950/80 border border-slate-800 p-3 rounded-xl">
          <UserCheck className="w-5 h-5 text-indigo-400 flex-shrink-0" />
          <div>
            <label className="block text-[10px] font-bold uppercase tracking-wider text-slate-400">
              Simulate Current Officer (Checker)
            </label>
            <select
              value={activeCheckerId}
              onChange={(e) => setActiveCheckerId(e.target.value)}
              className="bg-transparent text-white font-semibold text-xs focus:outline-none cursor-pointer"
            >
              <option value="U3002" className="bg-slate-900">
                U3002 - Beatriz Ocampo (Operations Manager) [Valid Checker]
              </option>
              <option value="U3003" className="bg-slate-900">
                U3003 - Carlos Mendoza (Operations Manager) [Valid Checker]
              </option>
              <option value="U1001" className="bg-slate-900">
                U1001 - Juan Dela Cruz (Initiator / Maker) [Will Trigger SOD Violation]
              </option>
            </select>
          </div>
        </div>
      </div>

      {/* Feedback Message */}
      {feedbackMsg && (
        <div
          className={`p-4 rounded-xl border flex items-center justify-between text-xs ${
            feedbackMsg.type === 'error'
              ? 'bg-rose-500/10 border-rose-500/20 text-rose-300'
              : feedbackMsg.type === 'warning'
              ? 'bg-amber-500/10 border-amber-500/20 text-amber-300'
              : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-300'
          }`}
        >
          <div className="flex items-center gap-2">
            {feedbackMsg.type === 'error' ? (
              <AlertTriangle className="w-4 h-4 text-rose-400" />
            ) : feedbackMsg.type === 'warning' ? (
              <XCircle className="w-4 h-4 text-amber-400" />
            ) : (
              <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            )}
            <span>{feedbackMsg.text}</span>
          </div>
          <button onClick={() => setFeedbackMsg(null)} className="text-slate-400 hover:text-white text-xs">
            Dismiss
          </button>
        </div>
      )}

      {/* Pending Transactions Table */}
      <div className="p-6 rounded-2xl bg-slate-950/70 border border-slate-800 shadow-xl space-y-4">
        <div className="flex items-center justify-between pb-3 border-b border-slate-800">
          <div className="flex items-center gap-2">
            <Clock className="w-5 h-5 text-amber-400" />
            <h3 className="font-bold text-white text-sm">
              Queued Transactions Awaiting Dual-Control Verification ({pendingTransactions.length})
            </h3>
          </div>

          <button
            onClick={fetchPending}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 hover:border-slate-700 text-slate-300 text-xs transition"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Refresh Queue</span>
          </button>
        </div>

        {pendingTransactions.length === 0 ? (
          <div className="py-12 text-center space-y-2">
            <CheckCircle2 className="w-10 h-10 text-emerald-500/60 mx-auto" />
            <p className="text-sm font-semibold text-white">Queue is clear</p>
            <p className="text-xs text-slate-500">
              No high-value transactions are currently held in PENDING_APPROVAL.
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-900/60 text-slate-400 font-semibold border-b border-slate-800">
                <tr>
                  <th className="py-3 px-4">Transaction Ref</th>
                  <th className="py-3 px-4">Accounts (Source &rarr; Target)</th>
                  <th className="py-3 px-4">Transfer Amount</th>
                  <th className="py-3 px-4">Initiator (Maker)</th>
                  <th className="py-3 px-4">Regulatory Tier</th>
                  <th className="py-3 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/80 font-mono">
                {pendingTransactions.map((tx) => {
                  const amt = parseFloat(tx.mutationAmount || tx.amount || 0);
                  const isAmla = amt >= 500000;
                  const isSelfMaker = tx.initiatorUserId === activeCheckerId;

                  return (
                    <tr key={tx.transactionId} className="hover:bg-slate-900/30 transition">
                      <td className="py-4 px-4 font-bold text-white">
                        {tx.transactionId}
                      </td>
                      <td className="py-4 px-4 text-slate-300">
                        <span>{tx.sourceAccountId || tx.sourceAccount}</span>
                        <span className="text-slate-500 mx-2">&rarr;</span>
                        <span>{tx.destinationAccountId || tx.targetAccountId || tx.destinationAccount}</span>
                      </td>
                      <td className="py-4 px-4 text-emerald-400 font-bold text-sm">
                        ₱ {amt.toLocaleString('en-US', { minimumFractionDigits: 4 })}
                      </td>
                      <td className="py-4 px-4">
                        <span className={`px-2 py-0.5 rounded text-[11px] font-medium ${isSelfMaker ? 'bg-rose-500/20 text-rose-300 border border-rose-500/30' : 'bg-slate-800 text-slate-300'}`}>
                          {tx.initiatorUserId || 'U1001'} {isSelfMaker && '(YOU)'}
                        </span>
                      </td>
                      <td className="py-4 px-4 font-sans">
                        <span
                          className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                            isAmla
                              ? 'bg-rose-500/20 text-rose-400 border border-rose-500/30'
                              : 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                          }`}
                        >
                          {isAmla ? 'Tier 3 (AMLA CTR)' : 'Tier 2 (Dual Control)'}
                        </span>
                      </td>
                      <td className="py-4 px-4 text-right space-x-2 font-sans">
                        <button
                          onClick={() => handleApprove(tx)}
                          disabled={actionLoadingId === tx.transactionId}
                          className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-xs transition disabled:opacity-50 inline-flex items-center gap-1 shadow-sm"
                        >
                          <CheckCircle2 className="w-3.5 h-3.5" />
                          <span>Approve</span>
                        </button>
                        <button
                          onClick={() => handleReject(tx)}
                          disabled={actionLoadingId === tx.transactionId}
                          className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-rose-600 text-slate-300 hover:text-white font-semibold text-xs transition disabled:opacity-50 inline-flex items-center gap-1"
                        >
                          <XCircle className="w-3.5 h-3.5" />
                          <span>Reject</span>
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

      {/* Maye's 4-Tier Notification Simulation Testing Center */}
      <div className="p-6 rounded-2xl bg-slate-950/70 border border-slate-800 shadow-xl space-y-4">
        <div className="flex items-center justify-between pb-3 border-b border-slate-800">
          <div className="flex items-center gap-2">
            <Zap className="w-5 h-5 text-indigo-400" />
            <div>
              <h3 className="font-bold text-white text-sm">Notification Service Demonstration Center (:8083)</h3>
              <p className="text-xs text-slate-400">
                Trigger mock regulatory email advices directly into MailHog (:8025) and evaluate BSP/AMLA compliance logic.
              </p>
            </div>
          </div>
          <a
            href="http://localhost:8025"
            target="_blank"
            rel="noreferrer"
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 hover:bg-indigo-600 hover:text-white text-xs font-semibold transition"
          >
            <Mail className="w-3.5 h-3.5" />
            <span>Open MailHog Inbox</span>
          </a>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 pt-2">
          {/* Scenario 1 */}
          <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between">
              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                Tier 1 (&le; ₱50k)
              </span>
              <FileText className="w-4 h-4 text-slate-500" />
            </div>
            <div>
              <h4 className="text-xs font-bold text-white">Normal Fund Transfer</h4>
              <p className="text-[11px] text-slate-400 mt-1">
                Dispatches customer digital receipt and inward credit advice without hold.
              </p>
            </div>
            <button
              onClick={() => runSimulation('TIER_1')}
              disabled={isSimulating}
              className="w-full py-2 px-3 rounded-lg bg-slate-800 hover:bg-slate-700 text-white text-xs font-semibold transition flex items-center justify-center gap-1.5"
            >
              <span>Simulate Tier 1 Receipt</span>
            </button>
          </div>

          {/* Scenario 2 */}
          <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between">
              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20">
                Tier 2 (&gt; ₱50k)
              </span>
              <Clock className="w-4 h-4 text-amber-400" />
            </div>
            <div>
              <h4 className="text-xs font-bold text-white">Dual Control Hold Alert</h4>
              <p className="text-[11px] text-slate-400 mt-1">
                Triggers Manager compliance email &amp; WebSocket /topic/teller-alerts broadcast.
              </p>
            </div>
            <button
              onClick={() => runSimulation('TIER_2_HOLD')}
              disabled={isSimulating}
              className="w-full py-2 px-3 rounded-lg bg-slate-800 hover:bg-slate-700 text-white text-xs font-semibold transition flex items-center justify-center gap-1.5"
            >
              <span>Simulate Tier 2 Hold</span>
            </button>
          </div>

          {/* Scenario 3 */}
          <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between">
              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                Tier 2 Approved
              </span>
              <CheckCircle2 className="w-4 h-4 text-indigo-400" />
            </div>
            <div>
              <h4 className="text-xs font-bold text-white">Checker Approval Advice</h4>
              <p className="text-[11px] text-slate-400 mt-1">
                Sends approval advice to maker and credit notification to beneficiary.
              </p>
            </div>
            <button
              onClick={() => runSimulation('TIER_2_APPROVAL')}
              disabled={isSimulating}
              className="w-full py-2 px-3 rounded-lg bg-slate-800 hover:bg-slate-700 text-white text-xs font-semibold transition flex items-center justify-center gap-1.5"
            >
              <span>Simulate Approval Advice</span>
            </button>
          </div>

          {/* Scenario 4 */}
          <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between">
              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-rose-500/10 text-rose-400 border border-rose-500/20">
                Tier 3 (&ge; ₱500k)
              </span>
              <AlertTriangle className="w-4 h-4 text-rose-400" />
            </div>
            <div>
              <h4 className="text-xs font-bold text-white">AMLA Covered CTR Alert</h4>
              <p className="text-[11px] text-slate-400 mt-1">
                Dispatches urgent alert to Compliance Officer for AMLA Covered Transaction Report.
              </p>
            </div>
            <button
              onClick={() => runSimulation('TIER_3_AMLA')}
              disabled={isSimulating}
              className="w-full py-2 px-3 rounded-lg bg-slate-800 hover:bg-slate-700 text-white text-xs font-semibold transition flex items-center justify-center gap-1.5"
            >
              <span>Simulate AMLA CTR</span>
            </button>
          </div>
        </div>

        {/* Simulation Output Card */}
        {simulationResult && (
          <div className="mt-4 p-4 rounded-xl bg-slate-900 border border-slate-700/80 text-xs font-mono space-y-2">
            <div className="flex items-center justify-between">
              <span className="font-bold text-indigo-300">Simulation Dispatched:</span>
              <span className="text-slate-400">{simulationResult.status}</span>
            </div>
            <p className="text-slate-300">{simulationResult.message}</p>
            {simulationResult.transferId && (
              <p className="text-slate-400">Ref: {simulationResult.transferId} &bull; Recipient: {simulationResult.recipientEmail || 'MailHog Sandbox'}</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
