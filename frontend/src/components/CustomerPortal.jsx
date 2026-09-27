import React, { useState } from 'react';
import { 
  ArrowUpRight, 
  Wallet, 
  Lock, 
  Clock, 
  Send, 
  CreditCard,
  CheckCircle2,
  AlertCircle,
  ShieldCheck,
  UserCheck,
  Copy,
  Check,
  Building2
} from 'lucide-react';
import { formatPHP, parseMaskedInput, generateUUID } from '../utils/currency';
import apiClient, { mockState, THRESHOLDS } from '../services/api';
import { useAuth } from '../context/AuthContext';

export default function CustomerPortal({ balance, onTransactionComplete, showToast }) {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState('transfer'); // 'transfer' | 'history'
  const [copied, setCopied] = useState(false);

  const handleCopyAccount = () => {
    const acct = balance?.account_id || '1000-2000-3001';
    if (navigator.clipboard) {
      navigator.clipboard.writeText(acct);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  // Transfer Form State (Empty by default for real customer entry)
  const [toAccount, setToAccount] = useState('');
  const [recipientName, setRecipientName] = useState('');
  const [amountInput, setAmountInput] = useState('');
  const [memo, setMemo] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [currentIdempotencyKey, setCurrentIdempotencyKey] = useState(generateUUID());

  const numericAmount = parseFloat(amountInput) || 0;

  const handleAmountChange = (e) => {
    const masked = parseMaskedInput(e.target.value);
    setAmountInput(masked);
  };

  const handleTransferSubmit = async (e) => {
    e.preventDefault();
    if (!toAccount.trim() || !recipientName.trim()) {
      showToast({
        type: 'error',
        title: 'Missing Details',
        detail: 'Please provide both the recipient account number and full name.',
      });
      return;
    }

    if (numericAmount <= 0) {
      showToast({
        type: 'error',
        title: 'Invalid Amount',
        detail: 'Please enter a valid transfer amount greater than ₱0.00.',
      });
      return;
    }

    if (numericAmount > (balance?.available_balance || 0)) {
      showToast({
        type: 'error',
        title: 'Insufficient Balance',
        detail: `You only have ${formatPHP(balance?.available_balance)} available to transfer.`,
      });
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await apiClient.post(
        '/transfers',
        {
          from_account_id: balance?.account_id || '1000-2000-3001',
          to_account_id: toAccount.trim(),
          recipient_name: recipientName.trim(),
          amount: numericAmount,
          currency: 'PHP',
          memo: memo.trim() || 'Fund Transfer',
          maker_user_id: user?.user_id || 'U1001',
        },
        {
          headers: {
            'X-Idempotency-Key': currentIdempotencyKey,
          },
        }
      );

      const isHighValue = numericAmount > THRESHOLDS.STP_MAX;

      if (isHighValue) {
        showToast({
          type: 'warning',
          title: 'Transfer Submitted for Verification',
          detail: `Your transfer of ${formatPHP(numericAmount)} to ${recipientName} has been submitted and is currently being verified by the bank.`,
        });
      } else {
        showToast({
          type: 'success',
          title: 'Transfer Successful',
          detail: `Successfully sent ${formatPHP(numericAmount)} to ${recipientName}.`,
        });
      }

      // Reset form to empty for the next transfer
      setToAccount('');
      setRecipientName('');
      setAmountInput('');
      setMemo('');

      // Generate a fresh idempotency key for the next transfer
      setCurrentIdempotencyKey(generateUUID());
      onTransactionComplete();
    } catch (err) {
      const problem = err.response?.data;
      showToast({
        type: 'error',
        title: 'Transfer Failed',
        detail: problem?.detail || 'Unable to complete transfer. Please try again.',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Prominent Customer Account Summary Banner */}
      <div className="bg-gradient-to-r from-slate-900 via-slate-900/90 to-indigo-950/40 border border-slate-800/80 rounded-2xl p-5 shadow-xl flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
            <Building2 className="w-6 h-6" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-base font-bold text-white tracking-tight">
                {user?.name || 'Juan Dela Cruz'}
              </h3>
              <span className="text-[10px] font-semibold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 px-2.5 py-0.5 rounded-full border border-emerald-500/20 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" /> Active Account
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              Primary Savings Account &bull; Philippine Peso (PHP)
            </p>
          </div>
        </div>

        <div className="flex items-center justify-between sm:justify-end gap-3 bg-slate-950/80 border border-slate-800 px-4 py-2.5 rounded-xl">
          <div>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400 block">
              My Account Number
            </span>
            <span className="text-sm font-mono font-bold text-indigo-300 tracking-wider">
              {balance?.account_id || '1000-2000-3001'}
            </span>
          </div>
          <button
            type="button"
            onClick={handleCopyAccount}
            title="Copy account number"
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-all text-xs font-medium border border-slate-700/60"
          >
            {copied ? (
              <>
                <Check className="w-3.5 h-3.5 text-emerald-400" />
                <span className="text-emerald-400 font-semibold">Copied!</span>
              </>
            ) : (
              <>
                <Copy className="w-3.5 h-3.5" />
                <span>Copy</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* 3 Clean Customer Balance Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {/* Available Balance */}
        <div className="relative p-6 rounded-2xl bg-gradient-to-br from-slate-900 via-slate-900 to-indigo-950/40 border border-indigo-500/30 shadow-xl overflow-hidden group">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-indigo-400 flex items-center gap-1.5">
              <Wallet className="w-4 h-4" /> Available Balance
            </span>
            <span className="text-[11px] font-mono bg-indigo-500/10 text-indigo-300 px-2.5 py-0.5 rounded-full border border-indigo-500/20 font-medium">
              Acct: {balance?.account_id || '1000-2000-3001'}
            </span>
          </div>
          <div className="text-3xl font-mono font-bold text-white tracking-tight">
            {formatPHP(balance?.available_balance)}
          </div>
          <p className="text-xs text-slate-400 mt-2">
            Funds ready for immediate withdrawal or transfer.
          </p>
        </div>

        {/* Total Account Balance */}
        <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
              <CreditCard className="w-4 h-4 text-slate-400" /> Total Balance
            </span>
            <span className="text-[10px] font-medium bg-slate-800 text-slate-300 px-2 py-0.5 rounded">
              Savings
            </span>
          </div>
          <div className="text-2xl font-mono font-bold text-slate-200">
            {formatPHP(balance?.current_balance)}
          </div>
          <p className="text-xs text-slate-400 mt-2">
            Total balance in your savings account.
          </p>
        </div>

        {/* On Hold Balance */}
        <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
              <Lock className="w-4 h-4" /> On Hold
            </span>
            {balance?.held_balance > 0 && (
              <span className="text-[10px] font-medium bg-amber-500/10 text-amber-400 px-2 py-0.5 rounded border border-amber-500/20">
                Processing
              </span>
            )}
          </div>
          <div className="text-2xl font-mono font-bold text-amber-400">
            {formatPHP(balance?.held_balance)}
          </div>
          <p className="text-xs text-slate-400 mt-2">
            Pending transfers currently undergoing bank verification.
          </p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-3 border-b border-slate-800/80 pb-3">
        <button
          onClick={() => setActiveTab('transfer')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 ${
            activeTab === 'transfer'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <Send className="w-3.5 h-3.5" /> Send Money
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all flex items-center gap-2 ${
            activeTab === 'history'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-900'
          }`}
        >
          <Clock className="w-3.5 h-3.5" /> Recent Activity
        </button>
      </div>

      {/* TAB 1: Clean Customer Fund Transfer Form */}
      {activeTab === 'transfer' && (
        <div className="max-w-2xl mx-auto p-6 md:p-8 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-2xl space-y-6">
          <div className="border-b border-slate-800/80 pb-4">
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <Send className="w-5 h-5 text-indigo-400" />
              Send Money
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Transfer funds instantly to any registered bank account.
            </p>
          </div>

          <form onSubmit={handleTransferSubmit} className="space-y-5">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                From Account (Source Account)
              </label>
              <div className="flex items-center justify-between bg-slate-950/80 border border-slate-800 rounded-xl px-4 py-3">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
                    <Wallet className="w-4 h-4" />
                  </div>
                  <div>
                    <span className="text-xs font-bold text-white block">
                      {user?.name || 'Juan Dela Cruz'} &bull; Primary Savings
                    </span>
                    <span className="text-xs font-mono font-semibold text-indigo-300">
                      {balance?.account_id || '1000-2000-3001'}
                    </span>
                  </div>
                </div>
                <div className="text-right">
                  <span className="text-[10px] uppercase font-semibold text-slate-400 block">Available</span>
                  <span className="text-xs font-mono font-bold text-emerald-400">
                    {formatPHP(balance?.available_balance)}
                  </span>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Recipient Account Number
                </label>
                <input
                  type="text"
                  required
                  value={toAccount}
                  onChange={(e) => setToAccount(e.target.value)}
                  placeholder="Enter account number (e.g. 1000-2000-3002)"
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs font-mono text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Recipient Full Name
                </label>
                <input
                  type="text"
                  required
                  value={recipientName}
                  onChange={(e) => setRecipientName(e.target.value)}
                  placeholder="Enter full name (e.g. Maria Santos)"
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-500 transition-all"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5 flex items-center justify-between">
                <span>Amount (PHP)</span>
                <span className="text-[11px] text-slate-400">
                  Available: <strong className="text-white font-mono">{formatPHP(balance?.available_balance)}</strong>
                </span>
              </label>
              <div className="relative">
                <span className="absolute left-3.5 top-2.5 text-sm font-mono text-slate-400 font-bold">₱</span>
                <input
                  type="text"
                  required
                  value={amountInput}
                  onChange={handleAmountChange}
                  placeholder="0.0000"
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl pl-8 pr-3.5 py-2.5 text-sm font-mono text-white font-bold placeholder:text-slate-600 focus:outline-none focus:border-indigo-500 transition-all"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Note / Purpose <span className="text-slate-500 font-normal">(Optional)</span>
              </label>
              <input
                type="text"
                value={memo}
                onChange={(e) => setMemo(e.target.value)}
                placeholder="What is this transfer for? (e.g. Allowance, Rent, Groceries)"
                className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-500 transition-all"
              />
            </div>

            <div className="pt-2">
              <button
                type="submit"
                disabled={isSubmitting}
                className={`w-full py-3 rounded-xl font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all shadow-lg ${
                  isSubmitting
                    ? 'bg-slate-800 text-slate-500 cursor-not-allowed'
                    : 'bg-indigo-600 hover:bg-indigo-500 text-white shadow-indigo-600/30'
                }`}
              >
                {isSubmitting ? 'Processing Transfer...' : 'Send Money'}
              </button>
            </div>

            <p className="text-center text-[11px] text-slate-500 flex items-center justify-center gap-1.5 pt-1">
              <ShieldCheck className="w-3.5 h-3.5 text-slate-400" />
              Secured with 256-bit bank-grade encryption
            </p>
          </form>
        </div>
      )}

      {/* TAB 2: Clean Customer Activity Table */}
      {activeTab === 'history' && (
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-base font-bold text-white">Recent Transactions</h3>
              <p className="text-xs text-slate-400 mt-0.5">Your recent transfers and payments</p>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 text-slate-400 font-semibold uppercase text-[10px] tracking-wider">
                <tr>
                  <th className="pb-3">Reference No.</th>
                  <th className="pb-3">Recipient</th>
                  <th className="pb-3">Amount</th>
                  <th className="pb-3">Status</th>
                  <th className="pb-3">Date &amp; Time</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {mockState.transfers.map((tx) => (
                  <tr key={tx.id} className="hover:bg-slate-900/40 transition-colors">
                    <td className="py-3.5 font-mono text-indigo-400 font-semibold">{tx.id}</td>
                    <td className="py-3.5">
                      <p className="font-semibold text-white">{tx.recipient_name}</p>
                      <p className="text-[10px] font-mono text-slate-400">{tx.to_account_id}</p>
                    </td>
                    <td className="py-3.5 font-mono font-bold text-slate-100">
                      -{formatPHP(tx.amount)}
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
                        {tx.status === 'SETTLED' ? 'Completed' : tx.status === 'PENDING_APPROVAL' ? 'Pending Verification' : 'Cancelled'}
                      </span>
                    </td>
                    <td className="py-3.5 text-slate-400 text-[11px]">
                      {new Date(tx.created_at).toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })}{' '}
                      {new Date(tx.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
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
