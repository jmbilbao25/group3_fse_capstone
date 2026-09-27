import React, { useState, useEffect } from 'react';
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
  Building2,
  Printer,
  X,
  FileText,
  Eye,
  EyeOff,
  Search,
  Receipt,
  ChevronRight
} from 'lucide-react';
import { formatPHP, parseMaskedInput, generateUUID } from '../utils/currency';
import apiClient, { mockState, THRESHOLDS } from '../services/api';
import { useAuth } from '../context/AuthContext';

export default function CustomerPortal({ balance, onTransactionComplete, showToast }) {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState('transfer'); // 'transfer' | 'history'
  const [copied, setCopied] = useState(false);

  // Eye Toggle State (Show / Hide Balance & Account Number)
  const [isBalanceVisible, setIsBalanceVisible] = useState(true);
  const [isAccountVisible, setIsAccountVisible] = useState(true);

  useEffect(() => {
    onTransactionComplete?.();
  }, []);

  // Search & Filter State for Activity
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL'); // 'ALL' | 'SETTLED' | 'PENDING_APPROVAL'

  const formatVisiblePHP = (val) => {
    if (!isBalanceVisible) return '₱ ••••••••';
    return formatPHP(val);
  };

  const formatVisibleAccount = (acctId) => {
    const raw = acctId || '1000-2000-3001';
    if (isAccountVisible) return raw;
    const parts = String(raw).split('-');
    if (parts.length === 3) {
      return `••••-••••-${parts[2]}`;
    }
    return raw.length > 4 ? `••••••••${raw.slice(-4)}` : '••••••••';
  };

  const handleViewReceipt = (tx) => {
    setReceiptData({
      refNumber: tx.id,
      fromAccount: tx.from_account_id || balance?.account_id || '1000-2000-3001',
      senderName: user?.name || 'Juan Dela Cruz',
      toAccount: tx.to_account_id,
      recipientName: tx.recipient_name,
      amount: tx.amount,
      fee: 0,
      memo: tx.memo || 'Fund Transfer',
      isHighValue: tx.status === 'PENDING_APPROVAL',
      timestamp: new Date(tx.created_at || Date.now()),
    });
  };

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

  // Modal States
  const [isConfirmModalOpen, setIsConfirmModalOpen] = useState(false);
  const [receiptData, setReceiptData] = useState(null);
  const [receiptCopied, setReceiptCopied] = useState(false);

  const numericAmount = parseFloat(amountInput) || 0;

  const handleAmountChange = (e) => {
    const masked = parseMaskedInput(e.target.value, 2);
    setAmountInput(masked);
  };

  // Quick Amount Handlers
  const handleAddAmount = (addVal) => {
    const current = parseFloat(amountInput) || 0;
    const nextVal = (current + addVal).toFixed(2);
    setAmountInput(nextVal);
  };

  const handleSetMaxAmount = () => {
    const maxVal = (balance?.available_balance || 0).toFixed(2);
    setAmountInput(maxVal);
  };

  // Step 1: Validate and open the Transfer Confirmation Modal
  const handleInitiateTransfer = (e) => {
    e.preventDefault();
    if (!toAccount.trim() || !recipientName.trim()) {
      showToast({
        type: 'error',
        title: 'Missing Details',
        detail: 'Please provide both the recipient account number and full name.',
      });
      return;
    }

    if (numericAmount < 1.00) {
      showToast({
        type: 'error',
        title: 'Invalid Amount',
        detail: 'Minimum transfer amount is ₱ 1.00.',
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

    setIsConfirmModalOpen(true);
  };

  // Step 2: User confirmed in Modal -> Execute API call & generate Receipt
  const handleExecuteTransfer = async () => {
    setIsSubmitting(true);
    try {
      const generatedRef = 'TRX-' + Math.floor(100000 + Math.random() * 900000);
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
          detail: `Your transfer of ${formatPHP(numericAmount)} to ${recipientName} has been submitted for bank manager approval.`,
        });
      } else {
        showToast({
          type: 'success',
          title: 'Transfer Successful',
          detail: `Successfully sent ${formatPHP(numericAmount)} to ${recipientName}.`,
        });
      }

      // Populate Digital Receipt Slip
      setReceiptData({
        refNumber: res?.data?.transfer_id || generatedRef,
        fromAccount: balance?.account_id || '1000-2000-3001',
        senderName: user?.name || 'Juan Dela Cruz',
        toAccount: toAccount.trim(),
        recipientName: recipientName.trim(),
        amount: numericAmount,
        fee: 0,
        memo: memo.trim() || 'Fund Transfer',
        isHighValue,
        timestamp: new Date(),
      });

      // Close confirmation modal
      setIsConfirmModalOpen(false);

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
      <div className="relative overflow-hidden bg-gradient-to-r from-slate-900 via-slate-900/90 to-indigo-950/40 border border-slate-800/80 rounded-2xl p-5 shadow-xl flex flex-col sm:flex-row sm:items-center justify-between gap-4 group hover:border-slate-700/80 transition-all duration-300">
        <div className="absolute -right-10 -bottom-10 w-44 h-44 bg-indigo-600/10 rounded-full blur-3xl pointer-events-none" />
        <div className="flex items-center gap-4 relative z-10">
          <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-400 shadow-inner group-hover:scale-105 transition-transform duration-300">
            <Building2 className="w-6 h-6" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-base font-bold text-white tracking-tight">
                {user?.name || 'Juan Dela Cruz'}
              </h3>
              <span className="text-[10px] font-semibold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 px-2.5 py-0.5 rounded-full border border-emerald-500/20 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" /> Active Account
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              Primary Savings Account &bull; Philippine Peso (PHP)
            </p>
          </div>
        </div>

        <div className="flex items-center justify-between sm:justify-end gap-2 bg-slate-950/80 border border-slate-800 px-3.5 py-2.5 rounded-xl relative z-10 shadow-inner">
          <div className="mr-1">
            <div className="flex items-center gap-1.5">
              <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400">
                My Account Number
              </span>
              <button
                type="button"
                onClick={() => setIsAccountVisible(!isAccountVisible)}
                title={isAccountVisible ? "Hide Account Number" : "Show Account Number"}
                className="text-slate-400 hover:text-white transition-colors p-0.5 rounded hover:bg-slate-800"
              >
                {isAccountVisible ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5 text-indigo-400" />}
              </button>
            </div>
            <span className="text-sm font-mono font-bold text-indigo-300 tracking-wider">
              {formatVisibleAccount(balance?.account_id)}
            </span>
          </div>
          <button
            type="button"
            onClick={handleCopyAccount}
            title="Copy account number"
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-all text-xs font-medium border border-slate-700/60 active:scale-95"
          >
            {copied ? (
              <>
                <Check className="w-3.5 h-3.5 text-emerald-400" />
                <span className="text-emerald-400 font-semibold text-[11px]">Copied!</span>
              </>
            ) : (
              <>
                <Copy className="w-3.5 h-3.5" />
                <span className="text-[11px]">Copy</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* 3 Clean Customer Balance Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {/* Available Balance */}
        <div className="relative p-6 rounded-2xl bg-gradient-to-br from-slate-900 via-slate-900 to-indigo-950/50 border border-indigo-500/40 shadow-xl overflow-hidden group hover:-translate-y-1 hover:shadow-2xl hover:shadow-indigo-500/15 hover:border-indigo-500/60 transition-all duration-300">
          <div className="absolute -right-8 -top-8 w-36 h-36 bg-indigo-500/20 rounded-full blur-2xl pointer-events-none group-hover:bg-indigo-500/30 transition-all duration-500" />
          <div className="flex items-center justify-between mb-3 relative z-10">
            <span className="text-xs font-semibold uppercase tracking-wider text-indigo-400 flex items-center gap-1.5">
              <Wallet className="w-4 h-4" /> Available Balance
              <button
                type="button"
                onClick={() => setIsBalanceVisible(!isBalanceVisible)}
                title={isBalanceVisible ? "Hide Balance" : "Show Balance"}
                className="text-slate-400 hover:text-white transition-colors ml-1 p-0.5 rounded hover:bg-slate-800"
              >
                {isBalanceVisible ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5 text-indigo-400" />}
              </button>
            </span>
            <span className="text-[11px] font-mono bg-indigo-500/10 text-indigo-300 px-2.5 py-0.5 rounded-full border border-indigo-500/20 font-medium flex items-center gap-1.5">
              <span>Acct: {formatVisibleAccount(balance?.account_id)}</span>
              <button
                type="button"
                onClick={() => setIsAccountVisible(!isAccountVisible)}
                title={isAccountVisible ? "Hide Account Number" : "Show Account Number"}
                className="text-indigo-400 hover:text-white transition-colors p-0.5 rounded hover:bg-indigo-500/20"
              >
                {isAccountVisible ? <Eye className="w-3 h-3" /> : <EyeOff className="w-3 h-3 text-indigo-400" />}
              </button>
            </span>
          </div>
          <div className="text-3xl font-mono font-bold text-white tracking-tight relative z-10">
            {formatVisiblePHP(balance?.available_balance)}
          </div>
          <p className="text-xs text-slate-400 mt-2 relative z-10">
            Funds ready for immediate withdrawal or transfer.
          </p>
        </div>

        {/* Total Account Balance */}
        <div className="relative p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg overflow-hidden group hover:-translate-y-1 hover:border-slate-700 hover:shadow-xl transition-all duration-300">
          <div className="absolute -right-8 -top-8 w-36 h-36 bg-blue-500/10 rounded-full blur-2xl pointer-events-none group-hover:bg-blue-500/20 transition-all duration-500" />
          <div className="flex items-center justify-between mb-3 relative z-10">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
              <CreditCard className="w-4 h-4 text-slate-400" /> Total Balance
            </span>
            <span className="text-[10px] font-medium bg-slate-800 text-slate-300 px-2 py-0.5 rounded">
              Savings
            </span>
          </div>
          <div className="text-2xl font-mono font-bold text-slate-200 relative z-10">
            {formatVisiblePHP(balance?.current_balance)}
          </div>
          <p className="text-xs text-slate-400 mt-2 relative z-10">
            Total balance in your savings account.
          </p>
        </div>

        {/* On Hold Balance */}
        <div className="relative p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 shadow-lg overflow-hidden group hover:-translate-y-1 hover:border-amber-500/30 hover:shadow-xl transition-all duration-300">
          <div className="absolute -right-8 -top-8 w-36 h-36 bg-amber-500/10 rounded-full blur-2xl pointer-events-none group-hover:bg-amber-500/20 transition-all duration-500" />
          <div className="flex items-center justify-between mb-3 relative z-10">
            <span className="text-xs font-semibold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
              <Lock className="w-4 h-4" /> On Hold
            </span>
            {balance?.held_balance > 0 && (
              <span className="text-[10px] font-medium bg-amber-500/10 text-amber-400 px-2 py-0.5 rounded border border-amber-500/20 animate-pulse">
                Processing
              </span>
            )}
          </div>
          <div className="text-2xl font-mono font-bold text-amber-400 relative z-10">
            {formatVisiblePHP(balance?.held_balance)}
          </div>
          <p className="text-xs text-slate-400 mt-2 relative z-10">
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
        <div className="max-w-2xl mx-auto p-6 md:p-8 rounded-3xl bg-slate-900/80 backdrop-blur-xl border border-slate-800 shadow-2xl space-y-6 relative overflow-hidden group">
          <div className="absolute -top-24 -left-24 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none group-hover:bg-indigo-500/15 transition-all duration-500" />
          <div className="border-b border-slate-800/80 pb-4 relative z-10">
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <Send className="w-5 h-5 text-indigo-400" />
              Send Money
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Transfer funds instantly to any registered bank account.
            </p>
          </div>

          <form onSubmit={handleInitiateTransfer} className="space-y-5 relative z-10">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                From Account (Source Account)
              </label>
              <div className="flex items-center justify-between bg-slate-950/80 border border-slate-800 rounded-xl px-4 py-3 shadow-inner hover:border-slate-700/80 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 shadow-inner">
                    <Wallet className="w-4 h-4" />
                  </div>
                  <div>
                    <span className="text-xs font-bold text-white block">
                      {user?.name || 'Juan Dela Cruz'} &bull; Primary Savings
                    </span>
                    <span className="text-xs font-mono font-semibold text-indigo-300">
                      {formatVisibleAccount(balance?.account_id)}
                    </span>
                  </div>
                </div>
                <div className="text-right">
                  <span className="text-[10px] uppercase font-semibold text-slate-400 block">Available</span>
                  <span className="text-xs font-mono font-bold text-emerald-400">
                    {formatVisiblePHP(balance?.available_balance)}
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
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs font-mono text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-500/40 focus:shadow-lg focus:shadow-indigo-500/10 transition-all duration-200"
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
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-500/40 focus:shadow-lg focus:shadow-indigo-500/10 transition-all duration-200"
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
                  placeholder="0.00"
                  className="w-full bg-slate-950 border border-slate-700/80 rounded-xl pl-8 pr-3.5 py-2.5 text-sm font-mono text-white font-bold placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-500/40 focus:shadow-lg focus:shadow-indigo-500/10 transition-all duration-200"
                />
              </div>

              {/* Quick Amount Chips */}
              <div className="flex flex-wrap items-center gap-2 mt-2.5">
                <span className="text-[11px] font-medium text-slate-400 mr-1">Quick Add:</span>
                {[500, 1000, 5000].map((quickVal) => (
                  <button
                    key={quickVal}
                    type="button"
                    onClick={() => handleAddAmount(quickVal)}
                    className="px-3 py-1.5 rounded-xl bg-slate-800/90 hover:bg-indigo-600/30 border border-slate-700/70 hover:border-indigo-500/60 text-xs font-mono text-slate-300 hover:text-white transition-all duration-150 active:scale-95 hover:shadow-md hover:shadow-indigo-500/10"
                  >
                    +₱{quickVal.toLocaleString()}
                  </button>
                ))}
                <button
                  type="button"
                  onClick={handleSetMaxAmount}
                  className="px-3 py-1.5 rounded-xl bg-indigo-500/10 hover:bg-indigo-500/20 border border-indigo-500/30 text-xs font-mono font-semibold text-indigo-300 hover:text-indigo-200 transition-all duration-150 ml-auto active:scale-95 hover:shadow-md hover:shadow-indigo-500/10"
                >
                  Transfer MAX
                </button>
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
                className="w-full bg-slate-950 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-500/40 focus:shadow-lg focus:shadow-indigo-500/10 transition-all duration-200"
              />
            </div>

            <div className="pt-2">
              <button
                type="submit"
                className="w-full py-4 rounded-2xl font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all duration-200 shadow-xl bg-gradient-to-r from-indigo-600 via-indigo-500 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white shadow-indigo-600/30 hover:shadow-indigo-500/50 hover:shadow-2xl active:scale-[0.99]"
              >
                <Send className="w-4 h-4" />
                Review &amp; Send Money
              </button>
            </div>

            <p className="text-center text-[11px] text-slate-500 flex items-center justify-center gap-1.5 pt-1">
              <ShieldCheck className="w-3.5 h-3.5 text-indigo-400/80" />
              Secured with 256-bit bank-grade encryption
            </p>
          </form>
        </div>
      )}

      {/* TAB 2: Clean Customer Activity Table with Search & Filter */}
      {activeTab === 'history' && (
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-xl space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <h3 className="text-base font-bold text-white">Recent Transactions</h3>
              <p className="text-xs text-slate-400 mt-0.5">Click any transaction to view and print its official receipt</p>
            </div>

            {/* Status Filter Pills */}
            <div className="flex items-center gap-1.5 bg-slate-950/80 p-1 rounded-xl border border-slate-800/90 self-start sm:self-auto">
              {[
                { id: 'ALL', label: 'All' },
                { id: 'SETTLED', label: 'Completed' },
                { id: 'PENDING_APPROVAL', label: 'Under Review' },
              ].map((pill) => (
                <button
                  key={pill.id}
                  type="button"
                  onClick={() => setStatusFilter(pill.id)}
                  className={`px-3 py-1 rounded-lg text-[11px] font-semibold transition-all ${
                    statusFilter === pill.id
                      ? 'bg-indigo-600 text-white shadow-sm shadow-indigo-600/30'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  {pill.label}
                </button>
              ))}
            </div>
          </div>

          {/* Search Box */}
          <div className="relative">
            <Search className="w-4 h-4 absolute left-3.5 top-3 text-slate-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search by recipient name, account number, or reference (e.g. Maria, TRX-)..."
              className="w-full bg-slate-950/80 border border-slate-800 rounded-xl pl-10 pr-4 py-2.5 text-xs text-white placeholder:text-slate-600 focus:outline-none focus:border-indigo-400 focus:ring-1 focus:ring-indigo-500/30 transition-all"
            />
          </div>

          {/* Filtered Transactions List */}
          {(() => {
            const filteredTransfers = mockState.transfers.filter((tx) => {
              const query = searchQuery.toLowerCase().trim();
              const matchesSearch =
                !query ||
                tx.recipient_name?.toLowerCase().includes(query) ||
                tx.to_account_id?.toLowerCase().includes(query) ||
                tx.id?.toLowerCase().includes(query);
              const matchesStatus =
                statusFilter === 'ALL' || tx.status === statusFilter;
              return matchesSearch && matchesStatus;
            });

            if (filteredTransfers.length === 0) {
              return (
                <div className="text-center py-10 border border-dashed border-slate-800 rounded-2xl bg-slate-950/30">
                  <p className="text-xs text-slate-400">No transactions match your search or filter.</p>
                </div>
              );
            }

            return (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="border-b border-slate-800 text-slate-400 font-semibold uppercase text-[10px] tracking-wider">
                    <tr>
                      <th className="pb-3">Reference No.</th>
                      <th className="pb-3">Recipient</th>
                      <th className="pb-3">Amount</th>
                      <th className="pb-3">Status</th>
                      <th className="pb-3">Date &amp; Time</th>
                      <th className="pb-3 text-right">Receipt</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60">
                    {filteredTransfers.map((tx) => (
                      <tr
                        key={tx.id}
                        onClick={() => handleViewReceipt(tx)}
                        title="Click to view digital receipt slip"
                        className="hover:bg-slate-800/60 cursor-pointer transition-colors group"
                      >
                        <td className="py-3.5 font-mono text-indigo-400 font-semibold flex items-center gap-1.5">
                          <Receipt className="w-3.5 h-3.5 text-slate-500 group-hover:text-indigo-400 transition-colors" />
                          {tx.id}
                        </td>
                        <td className="py-3.5">
                          <p className="font-semibold text-white group-hover:text-indigo-200 transition-colors">
                            {tx.recipient_name}
                          </p>
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
                        <td className="py-3.5 text-right">
                          <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-indigo-400 group-hover:text-indigo-300">
                            View <ChevronRight className="w-3.5 h-3.5 group-hover:translate-x-0.5 transition-transform" />
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            );
          })()}
        </div>
      )}

      {/* 1. Transfer Review & Confirmation Modal */}
      {isConfirmModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700/80 rounded-3xl max-w-lg w-full p-6 sm:p-7 shadow-2xl space-y-5 relative">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-white tracking-tight">Review Transfer Details</h3>
                  <p className="text-xs text-slate-400">Verify recipient information before confirming</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setIsConfirmModalOpen(false)}
                className="text-slate-400 hover:text-white p-1.5 rounded-xl hover:bg-slate-800 transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Transfer Summary Card */}
            <div className="bg-slate-950/80 border border-slate-800 rounded-2xl p-4 space-y-3 text-xs">
              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">Recipient</span>
                <div className="text-right">
                  <span className="font-bold text-white block">{recipientName}</span>
                  <span className="font-mono text-[11px] text-slate-400">{toAccount}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">From Account</span>
                <div className="text-right">
                  <span className="font-semibold text-slate-200 block">{user?.name || 'Juan Dela Cruz'}</span>
                  <span className="font-mono text-[11px] text-slate-400">{balance?.account_id || '1000-2000-3001'}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">Transfer Amount</span>
                <span className="font-mono font-bold text-white text-sm">{formatPHP(numericAmount)}</span>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">Transfer Fee</span>
                <span className="font-mono font-semibold text-emerald-400">₱ 0.00 (FREE)</span>
              </div>

              <div className="flex justify-between items-center py-1 border-b border-slate-800/60">
                <span className="text-slate-400">Purpose / Note</span>
                <span className="text-slate-200 italic">{memo || 'Fund Transfer'}</span>
              </div>

              <div className="flex justify-between items-center pt-2">
                <span className="font-semibold text-white">Total Amount to Deduct</span>
                <span className="font-mono font-bold text-indigo-400 text-base">{formatPHP(numericAmount)}</span>
              </div>
            </div>

            {/* High Value Warning if > ₱50k */}
            {numericAmount > THRESHOLDS.STP_MAX && (
              <div className="bg-amber-500/10 border border-amber-500/30 rounded-xl p-3.5 flex items-start gap-3">
                <AlertCircle className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                <p className="text-[11px] text-amber-300/90 leading-relaxed">
                  <strong>Notice:</strong> This transfer exceeds ₱50,000.00. It will be routed for bank manager dual-control review, and the funds will be placed <strong>On Hold</strong> until verified.
                </p>
              </div>
            )}

            {/* Modal Actions */}
            <div className="flex items-center gap-3 pt-2">
              <button
                type="button"
                onClick={() => setIsConfirmModalOpen(false)}
                disabled={isSubmitting}
                className="w-1/3 py-3 rounded-xl border border-slate-700 bg-slate-800/60 hover:bg-slate-800 text-xs font-semibold text-slate-300 hover:text-white transition-all"
              >
                Back / Edit
              </button>
              <button
                type="button"
                onClick={handleExecuteTransfer}
                disabled={isSubmitting}
                className={`w-2/3 py-3 rounded-xl font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all shadow-lg ${
                  isSubmitting
                    ? 'bg-slate-800 text-slate-500 cursor-not-allowed'
                    : 'bg-indigo-600 hover:bg-indigo-500 text-white shadow-indigo-600/30'
                }`}
              >
                {isSubmitting ? 'Sending...' : 'Confirm & Send Money 🔒'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 2. On-Screen Digital Receipt / Success Slip Modal */}
      {receiptData && (
        <div 
          onClick={(e) => {
            if (e.target === e.currentTarget) setReceiptData(null);
          }}
          className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4 animate-in fade-in duration-200"
        >
          <div className="bg-slate-900 border border-slate-700/90 rounded-3xl max-w-md w-full p-6 sm:p-8 shadow-2xl relative overflow-hidden animate-in zoom-in-95 duration-200">
            {/* Top decorative gradient bar */}
            <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-emerald-400 via-indigo-500 to-purple-500" />

            {/* Close 'X' Button */}
            <button
              type="button"
              onClick={() => setReceiptData(null)}
              aria-label="Close Receipt Slip"
              className="absolute top-4 right-4 z-10 p-2 rounded-full bg-slate-800/80 hover:bg-slate-700 text-slate-400 hover:text-white border border-slate-700/80 transition-all active:scale-95 shadow-md focus:outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>

            {/* Perforated ticket circular notches */}
            <div className="absolute -left-3 top-[236px] w-6 h-6 rounded-full bg-slate-950 border-r border-slate-700/90 pointer-events-none" />
            <div className="absolute -right-3 top-[236px] w-6 h-6 rounded-full bg-slate-950 border-l border-slate-700/90 pointer-events-none" />

            {/* Header Icon with Animated Ripple */}
            <div className="text-center pt-2 pb-5 border-b border-dashed border-slate-800">
              <div className="relative w-16 h-16 mx-auto mb-3 flex items-center justify-center">
                {!receiptData.isHighValue && (
                  <span className="absolute inset-0 rounded-full bg-emerald-400/20 animate-ping duration-1000 pointer-events-none" />
                )}
                <div className="relative w-16 h-16 rounded-full bg-emerald-500/10 border-2 border-emerald-500/30 flex items-center justify-center text-emerald-400 shadow-xl shadow-emerald-500/20">
                  {receiptData.isHighValue ? (
                    <Clock className="w-8 h-8 text-amber-400 animate-pulse" />
                  ) : (
                    <CheckCircle2 className="w-8 h-8" />
                  )}
                </div>
              </div>

              <h3 className="text-xl font-bold text-white tracking-tight">
                {receiptData.isHighValue ? 'Transfer Submitted' : 'Transfer Successful!'}
              </h3>
              <p className="text-xs text-slate-400 mt-1">
                {receiptData.isHighValue
                  ? 'Under Verification: Awaiting Bank Manager Approval'
                  : 'Funds have been securely transferred'}
              </p>

              <div className="mt-4 font-mono font-black text-3xl text-white tracking-tight">
                -{formatPHP(receiptData.amount)}
              </div>
            </div>

            {/* Receipt Details Body */}
            <div className="py-5 space-y-3 text-xs border-b border-dashed border-slate-800">
              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400">Reference Number</span>
                <div className="flex items-center gap-1.5 font-mono text-indigo-400 font-bold bg-indigo-500/10 px-2 py-0.5 rounded-lg border border-indigo-500/20">
                  <span>{receiptData.refNumber}</span>
                  <button
                    type="button"
                    onClick={() => {
                      if (navigator.clipboard) {
                        navigator.clipboard.writeText(receiptData.refNumber);
                        setReceiptCopied(true);
                        setTimeout(() => setReceiptCopied(false), 2000);
                      }
                    }}
                    title="Copy Reference"
                    className="p-1 hover:bg-slate-800 rounded text-slate-400 hover:text-white transition-colors"
                  >
                    {receiptCopied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400">Date &amp; Time</span>
                <span className="text-slate-300 font-mono">
                  {receiptData.timestamp.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })}{' '}
                  &bull;{' '}
                  {receiptData.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400">Sent To</span>
                <div className="text-right">
                  <span className="font-semibold text-white block">{receiptData.recipientName}</span>
                  <span className="text-[11px] font-mono text-slate-400">{receiptData.toAccount}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400">Sent From</span>
                <div className="text-right">
                  <span className="text-slate-300 block">{receiptData.senderName}</span>
                  <span className="text-[11px] font-mono text-slate-400">{receiptData.fromAccount}</span>
                </div>
              </div>

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400">Transfer Fee</span>
                <span className="font-mono text-emerald-400 font-semibold">₱ 0.00 (Waived)</span>
              </div>

              {receiptData.memo && (
                <div className="flex justify-between items-center py-0.5">
                  <span className="text-slate-400">Note</span>
                  <span className="text-slate-300 italic">{receiptData.memo}</span>
                </div>
              )}

              <div className="flex justify-between items-center py-0.5">
                <span className="text-slate-400">Status</span>
                <span
                  className={`px-2.5 py-0.5 rounded-full text-[10px] font-semibold border ${
                    receiptData.isHighValue
                      ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                      : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                  }`}
                >
                  {receiptData.isHighValue ? 'PENDING VERIFICATION' : 'COMPLETED'}
                </span>
              </div>
            </div>

            {/* Modal Actions */}
            <div className="flex flex-col gap-2.5 pt-5">
              <button
                type="button"
                onClick={() => window.print()}
                className="w-full py-3 rounded-xl border border-slate-700 bg-slate-800/80 hover:bg-slate-700 text-xs font-semibold text-slate-200 hover:text-white flex items-center justify-center gap-2 transition-all active:scale-[0.99] shadow-md hover:shadow-lg"
              >
                <Printer className="w-4 h-4 text-slate-400" />
                Print / Save Receipt Slip
              </button>

              <button
                type="button"
                onClick={() => setReceiptData(null)}
                className="w-full py-3.5 rounded-xl bg-gradient-to-r from-indigo-600 via-indigo-500 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white text-xs font-bold uppercase tracking-wider transition-all duration-200 shadow-xl shadow-indigo-600/30 hover:shadow-indigo-500/50 active:scale-[0.99]"
              >
                Make Another Transfer
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
