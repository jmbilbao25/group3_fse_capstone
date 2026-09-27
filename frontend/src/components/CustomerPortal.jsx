import React, { useState } from 'react';
import { 
  ArrowUpRight, 
  Wallet, 
  Lock, 
  CheckCircle2, 
  Clock, 
  AlertTriangle, 
  Send, 
  ShieldAlert,
  CreditCard,
  Sparkles,
  RefreshCw,
  Copy,
  Info,
  ShieldCheck
} from 'lucide-react';
import { formatPHP, parseMaskedInput, generateUUID } from '../utils/currency';
import apiClient, { mockState, THRESHOLDS } from '../services/api';
import { useAuth } from '../context/AuthContext';

export default function CustomerPortal({ balance, onTransactionComplete, showToast }) {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState('transfer'); // 'transfer' | 'history'

  // Transfer Form State
  const [toAccount, setToAccount] = useState('1000-2000-3002');
  const [recipientName, setRecipientName] = useState('Maria Santos');
  const [amountInput, setAmountInput] = useState('15000.0000');
  const [memo, setMemo] = useState('Payment for consultancy services');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [currentIdempotencyKey, setCurrentIdempotencyKey] = useState(generateUUID());
  const [copiedKey, setCopiedKey] = useState(false);

  const numericAmount = parseFloat(amountInput) || 0;

  // Regulatory Tier Calculation
  const isTier3Amla = numericAmount >= THRESHOLDS.AMLA_CTR_MIN;
  const isTier2DualControl = numericAmount > THRESHOLDS.STP_MAX && numericAmount < THRESHOLDS.AMLA_CTR_MIN;
  const isTier1Stp = numericAmount > 0 && numericAmount <= THRESHOLDS.STP_MAX;

  const handleAmountChange = (e) => {
    const masked = parseMaskedInput(e.target.value);
    setAmountInput(masked);
  };

  const handleCopyIdempotency = () => {
    navigator.clipboard.writeText(currentIdempotencyKey);
    setCopiedKey(true);
    setTimeout(() => setCopiedKey(false), 2000);
  };

  const handleTransferSubmit = async (e) => {
    e.preventDefault();
    if (numericAmount <= 0) {
      showToast({
        type: 'error',
        title: 'Validation Error (JSR-380)',
        detail: 'Transfer amount must be strictly greater than 0.0000 PHP.',
        rfcInstance: '/api/v1/transfers',
      });
      return;
    }

    if (numericAmount > (balance?.available_balance || 0)) {
      showToast({
        type: 'error',
        title: 'Insufficient Available Funds',
        detail: `Requested amount (${formatPHP(numericAmount)}) exceeds your liquid available balance (${formatPHP(balance?.available_balance)}).`,
        rfcInstance: '/api/v1/transfers',
      });
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await apiClient.post(
        '/transfers',
        {
          from_account_id: balance?.account_id || '1000-2000-3001',
          to_account_id: toAccount,
          recipient_name: recipientName,
          amount: numericAmount,
          currency: 'PHP',
          memo,
          maker_user_id: user?.user_id || 'U1001',
        },
        {
          headers: {
            'X-Idempotency-Key': currentIdempotencyKey,
          },
        }
      );

      if (isTier3Amla) {
        showToast({
          type: 'warning',
          title: 'AMLA CTR Hold Applied (HTTP 202)',
          detail: `Transfer ${res.data.transfer_id} exceeds ₱500,000 threshold. Placed on soft hold for AMLC CTR review and Manager authorization.`,
          rfcInstance: `/api/v1/transfers/${res.data.transfer_id}`,
        });
      } else if (isTier2DualControl) {
        showToast({
          type: 'warning',
          title: 'Maker-Checker Hold Applied (HTTP 202)',
          detail: `Transfer ${res.data.transfer_id} exceeds ₱50,000 STP cap. Soft hold active pending Level 1 Operations Manager sign-off.`,
          rfcInstance: `/api/v1/transfers/${res.data.transfer_id}`,
        });
      } else {
        showToast({
          type: 'success',
          title: 'Transfer Settled Instantly (STP)',
          detail: `Transferred ${formatPHP(numericAmount)} to ${recipientName}. Debited via Oracle XE Row-Level Lock.`,
          rfcInstance: `/api/v1/transfers/${res.data.transfer_id}`,
        });
      }

      // Rotate idempotency key
      setCurrentIdempotencyKey(generateUUID());
      onTransactionComplete();
    } catch (err) {
      const problem = err.response?.data;
      showToast({
        type: 'error',
        title: problem?.title || 'Transfer Failed',
        detail: problem?.detail || 'An unexpected error occurred while executing balance mutation.',
        rfcInstance: problem?.instance || '/api/v1/transfers',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Ledger Metric Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {/* Available Balance Card */}
        <div className="relative p-6 rounded-2xl bg-gradient-to-br from-slate-900 via-slate-900 to-indigo-950/40 border border-indigo-500/30 shadow-xl overflow-hidden group">
          <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/10 rounded-full blur-2xl group-hover:bg-indigo-500/20 transition-all pointer-events-none" />
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-indigo-400 flex items-center gap-1.5">
              <Wallet className="w-4 h-4" /> Available Liquid Balance
            </span>
            <span className="text-[11px] font-mono bg-indigo-500/10 text-indigo-300 px-2.5 py-0.5 rounded-full border border-indigo-500/20 font-medium">
              {balance?.account_id || '1000-2000-3001'}
            </span>
          </div>
          <div className="text-3xl font-mono font-bold text-white tracking-tight">
            {formatPHP(balance?.available_balance)}
          </div>
          <div className="flex items-center justify-between text-xs text-slate-400 mt-2">
            <span>Liquid funds ready for instantaneous debit</span>
            <span className="text-emerald-400 font-mono text-[11px] flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" /> STP Enabled
            </span>
          </div>
        </div>

        {/* Current Master Ledger Balance */}
        <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
              <CreditCard className="w-4 h-4 text-slate-400" /> Current Master Balance
            </span>
            <span className="text-[10px] font-mono bg-slate-800 text-slate-300 px-2 py-0.5 rounded border border-slate-700/60">
              Oracle XE 21c
            </span>
          </div>
          <div className="text-2xl font-mono font-bold text-slate-200">
            {formatPHP(balance?.current_balance)}
          </div>
          <p className="text-xs text-slate-400 mt-2">
            Base ledger account balance prior to unsettled hold deductions.
          </p>
        </div>

        {/* Soft Held Balance */}
        <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
              <Lock className="w-4 h-4" /> Active Soft Holds
            </span>
            <span className="text-[10px] font-mono bg-amber-500/10 text-amber-400 px-2 py-0.5 rounded border border-amber-500/20 font-semibold">
              Dual-Control Queue
            </span>
          </div>
          <div className="text-2xl font-mono font-bold text-amber-400">
            {formatPHP(balance?.held_balance)}
          </div>
          <p className="text-xs text-slate-400 mt-2">
            Funds reserved under review by Operations Manager (Beatriz Ocampo).
          </p>
        </div>
      </div>

      {/* Navigation Tabs (Transfer vs History) */}
      <div className="flex items-center gap-3 border-b border-slate-800/80 pb-3">
        <button
          onClick={() => setActiveTab('transfer')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 ${
            activeTab === 'transfer'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <Send className="w-3.5 h-3.5" /> Instant Fund Transfer
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 ${
            activeTab === 'history'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <Clock className="w-3.5 h-3.5" /> Mutation History &amp; Journal
        </button>
      </div>

      {/* TAB 1: Fund Transfer Form */}
      {activeTab === 'transfer' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-5">
            <div>
              <div className="flex items-center justify-between">
                <h3 className="text-base font-bold text-white flex items-center gap-2">
                  <ArrowUpRight className="w-5 h-5 text-indigo-400" />
                  Transfer Retail Funds
                </h3>
                <span className="text-[11px] font-mono text-slate-400 flex items-center gap-1">
                  <Sparkles className="w-3.5 h-3.5 text-indigo-400" /> Sub-50ms Settlement
                </span>
              </div>
              <p className="text-xs text-slate-400 mt-1">
                Executes via Oracle XE Pessimistic Row Lock (<code className="text-indigo-300">SELECT FOR UPDATE</code>) with atomic debit and credit advice dispatch.
              </p>
            </div>

            <form onSubmit={handleTransferSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                    Originating Account (Debit)
                  </label>
                  <input
                    type="text"
                    disabled
                    value={`${balance?.account_id || '1000-2000-3001'} (Juan Dela Cruz)`}
                    className="w-full bg-slate-950/60 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs font-mono text-slate-400 cursor-not-allowed"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                    Destination Account (Credit)
                  </label>
                  <input
                    type="text"
                    required
                    value={toAccount}
                    onChange={(e) => setToAccount(e.target.value)}
                    placeholder="e.g. 1000-2000-3002"
                    className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs font-mono text-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                    Beneficiary Full Name
                  </label>
                  <input
                    type="text"
                    required
                    value={recipientName}
                    onChange={(e) => setRecipientName(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-indigo-500 transition-all"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5 flex items-center justify-between">
                    <span>Transfer Amount (PHP)</span>
                    <span className="text-[10px] font-mono text-indigo-400">4-Decimal Precision</span>
                  </label>
                  <div className="relative">
                    <span className="absolute left-3.5 top-2.5 text-xs font-mono text-slate-400 font-bold">₱</span>
                    <input
                      type="text"
                      required
                      value={amountInput}
                      onChange={handleAmountChange}
                      placeholder="0.0000"
                      className="w-full bg-slate-950 border border-slate-700/80 rounded-xl pl-8 pr-3.5 py-2.5 text-xs font-mono text-emerald-400 font-bold focus:outline-none focus:border-indigo-500 transition-all"
                    />
                  </div>
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Transaction Purpose / Reference Memo
                </label>
                <input
                  type="text"
                  value={memo}
                  onChange={(e) => setMemo(e.target.value)}
                  placeholder="e.g. Payment for invoice #8812"
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-indigo-500 transition-all"
                />
              </div>

              {/* DYNAMIC REGULATORY POLICY FEEDBACK CARD */}
              <div className="pt-1">
                {isTier3Amla ? (
                  <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-200 flex items-start gap-3">
                    <ShieldAlert className="w-5 h-5 text-rose-400 shrink-0 mt-0.5" />
                    <div className="text-xs space-y-1">
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-rose-300 uppercase tracking-wider text-[11px]">
                          Tier 3: AMLA Covered Transaction (CTR) &bull; R.A. 9160
                        </span>
                        <span className="px-2 py-0.5 rounded text-[10px] font-mono bg-rose-500/20 text-rose-300 border border-rose-500/30 font-semibold">
                          ≥ ₱500,000.00
                        </span>
                      </div>
                      <p className="text-slate-300 leading-relaxed text-[11px]">
                        This transfer exceeds the Philippine AMLA statutory threshold. Upon submission, <strong>{formatPHP(numericAmount)}</strong> will be placed on soft hold. It requires mandatory AMLC CTR audit registration and dual-control sign-off from Bank Operations Manager (Beatriz Ocampo).
                      </p>
                    </div>
                  </div>
                ) : isTier2DualControl ? (
                  <div className="p-4 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-200 flex items-start gap-3">
                    <AlertTriangle className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
                    <div className="text-xs space-y-1">
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-amber-300 uppercase tracking-wider text-[11px]">
                          Tier 2: Maker-Checker Dual Control Required
                        </span>
                        <span className="px-2 py-0.5 rounded text-[10px] font-mono bg-amber-500/20 text-amber-300 border border-amber-500/30 font-semibold">
                          &gt; ₱50,000.00
                        </span>
                      </div>
                      <p className="text-slate-300 leading-relaxed text-[11px]">
                        Transfer exceeds standard Straight-Through Processing (STP) limits. <strong>{formatPHP(numericAmount)}</strong> will be reserved under soft hold and routed to Operations Manager (Beatriz Ocampo) for Level 1 verification.
                      </p>
                    </div>
                  </div>
                ) : (
                  <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-200 flex items-start gap-3">
                    <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0 mt-0.5" />
                    <div className="text-xs space-y-1">
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-emerald-300 uppercase tracking-wider text-[11px]">
                          Tier 1: Straight-Through Processing (STP)
                        </span>
                        <span className="px-2 py-0.5 rounded text-[10px] font-mono bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 font-semibold">
                          ≤ ₱50,000.00
                        </span>
                      </div>
                      <p className="text-slate-300 leading-relaxed text-[11px]">
                        Eligible for instantaneous settlement. Debited directly via Oracle XE row-level pessimistic lock with immediate inward credit advice notification dispatch.
                      </p>
                    </div>
                  </div>
                )}
              </div>

              {/* Idempotency Footer & Submit Action */}
              <div className="pt-3 border-t border-slate-800/80 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-[11px] text-slate-400">
                <div className="flex items-center gap-2 max-w-sm truncate">
                  <span className="text-indigo-400 font-semibold">Idempotency Key:</span>
                  <span className="font-mono text-slate-300 text-[10px] truncate">{currentIdempotencyKey}</span>
                  <button
                    type="button"
                    onClick={handleCopyIdempotency}
                    title="Copy Key"
                    className="p-1 text-slate-400 hover:text-white transition-colors"
                  >
                    <Copy className="w-3.5 h-3.5" />
                  </button>
                  {copiedKey && <span className="text-[10px] text-emerald-400 font-semibold">Copied!</span>}
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting}
                  className={`w-full sm:w-auto px-6 py-2.5 rounded-xl font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all ${
                    isSubmitting
                      ? 'bg-slate-800 text-slate-500 cursor-not-allowed'
                      : isTier3Amla
                      ? 'bg-rose-600 hover:bg-rose-500 text-white shadow-lg shadow-rose-600/30'
                      : isTier2DualControl
                      ? 'bg-amber-600 hover:bg-amber-500 text-white shadow-lg shadow-amber-600/30'
                      : 'bg-indigo-600 hover:bg-indigo-500 text-white shadow-lg shadow-indigo-600/30'
                  }`}
                >
                  {isSubmitting ? (
                    'Executing Ledger Mutation...'
                  ) : isTier3Amla ? (
                    'Submit for Manager & AMLA Review'
                  ) : isTier2DualControl ? (
                    'Submit for Manager Approval'
                  ) : (
                    'Execute Instant Transfer'
                  )}
                </button>
              </div>
            </form>
          </div>

          {/* Official Bank Limits & Settlement Policy Sidebar */}
          <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-slate-300 flex items-center gap-1.5">
                <ShieldCheck className="w-4 h-4 text-emerald-400" />
                Transfer Limits &amp; Settlement Policy
              </h4>
              <p className="text-[11px] text-slate-400 mt-1">
                Bangko Sentral ng Pilipinas (BSP) core clearing guidelines and daily thresholds.
              </p>
            </div>

            <div className="space-y-3">
              <div className="p-3.5 rounded-xl bg-slate-950/80 border border-slate-800/80 space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-slate-300 font-semibold">Tier 1: Instant STP</span>
                  <span className="font-mono text-emerald-400 font-bold">≤ ₱50,000.00</span>
                </div>
                <p className="text-[11px] text-slate-400 leading-relaxed">
                  Settles instantly in &lt; 50ms via Oracle XE pessimistic row lock without requiring operational sign-off.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-950/80 border border-slate-800/80 space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-slate-300 font-semibold">Tier 2: Dual Control</span>
                  <span className="font-mono text-amber-400 font-bold">&gt; ₱50,000.00</span>
                </div>
                <p className="text-[11px] text-slate-400 leading-relaxed">
                  Amounts over ₱50,000 are placed on soft hold and routed to Operations Manager for Maker-Checker review.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-950/80 border border-slate-800/80 space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-slate-300 font-semibold">Tier 3: AMLA CTR</span>
                  <span className="font-mono text-rose-400 font-bold">≥ ₱500,000.00</span>
                </div>
                <p className="text-[11px] text-slate-400 leading-relaxed">
                  High-value transactions meeting the R.A. 9160 threshold are logged for mandatory AMLC regulatory filing.
                </p>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-indigo-500/5 border border-indigo-500/10 flex items-start gap-2.5 text-[11px] text-slate-400">
              <Lock className="w-4 h-4 text-indigo-400 shrink-0 mt-0.5" />
              <p className="leading-relaxed">
                Protected by PostgreSQL immutable audit sink and end-to-end cryptographic hashing.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* TAB 2: Mutation History Table */}
      {activeTab === 'history' && (
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-base font-bold text-white">Recent Ledger Mutations</h3>
              <p className="text-xs text-slate-400 mt-0.5">Chronological journal entries synchronized with PostgreSQL audit trail.</p>
            </div>
            <span className="text-xs font-mono text-slate-400">
              {mockState.transfers.length} Recorded Mutations
            </span>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 font-semibold uppercase text-[10px] tracking-wider">
                <tr>
                  <th className="pb-3">Reference ID</th>
                  <th className="pb-3">Beneficiary Account</th>
                  <th className="pb-3">Transfer Amount</th>
                  <th className="pb-3">Regulatory Classification</th>
                  <th className="pb-3">Status</th>
                  <th className="pb-3">Timestamp</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {mockState.transfers.map((tx) => (
                  <tr key={tx.id} className="hover:bg-slate-900/40 transition-colors">
                    <td className="py-3.5 font-mono font-semibold text-indigo-400">{tx.id}</td>
                    <td className="py-3.5">
                      <p className="font-semibold text-white">{tx.recipient_name}</p>
                      <p className="text-[10px] font-mono text-slate-400">{tx.to_account_id}</p>
                    </td>
                    <td className="py-3.5 font-mono font-bold text-slate-200">
                      {formatPHP(tx.amount)}
                    </td>
                    <td className="py-3.5">
                      <span className="text-[11px] text-slate-300">
                        {tx.regulatory_tier === 'TIER_3_AMLA_CTR' ? (
                          <span className="text-rose-400 font-semibold flex items-center gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-rose-400" /> Tier 3 (AMLA CTR)
                          </span>
                        ) : tx.regulatory_tier === 'TIER_2_DUAL_CONTROL' ? (
                          <span className="text-amber-400 font-semibold flex items-center gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-amber-400" /> Tier 2 (Dual Control)
                          </span>
                        ) : (
                          <span className="text-emerald-400 font-semibold flex items-center gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" /> Tier 1 (STP)
                          </span>
                        )}
                      </span>
                    </td>
                    <td className="py-3.5">
                      <span
                        className={`px-2.5 py-0.5 rounded-full text-[10px] font-semibold border ${
                          tx.status === 'SETTLED'
                            ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                            : tx.status === 'PENDING_APPROVAL'
                            ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                            : 'bg-rose-500/10 text-rose-400 border-rose-500/20'
                        }`}
                      >
                        {tx.status === 'SETTLED' ? 'SETTLED' : tx.status === 'PENDING_APPROVAL' ? 'PENDING CHECKER' : 'REJECTED'}
                      </span>
                    </td>
                    <td className="py-3.5 text-slate-400 text-[11px] font-mono">
                      {new Date(tx.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
