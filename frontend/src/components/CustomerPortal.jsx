import React, { useState, useEffect, useMemo } from 'react';
import { 
  ArrowUpRight, 
  ArrowDownLeft,
  Wallet, 
  Send, 
  CheckCircle2, 
  AlertCircle, 
  ShieldCheck, 
  ShieldAlert, 
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
  ChevronRight, 
  User,
  Download,
  Calendar,
  Filter,
  RotateCcw,
  PhoneCall,
  QrCode,
  PieChart,
  HelpCircle,
  Layers,
  ArrowRight,
  ExternalLink,
  Clock,
  Landmark
} from 'lucide-react';
import { formatPHP, parseMaskedInput, generateUUID } from '../utils/currency';
import apiClient, { mockState, THRESHOLDS } from '../services/api';
import { useAuth } from '../context/AuthContext';
import CustomerProfile from './CustomerProfile';
import { cn } from '../ui';
import Button from '../ui/Button';
import Badge from '../ui/Badge';
import Money from '../ui/Money';

export default function CustomerPortal({ balance, onTransactionComplete, onSwitchAccount, showToast }) {
  const { user } = useAuth();
  
  // Navigation tabs: 'accounts' (Bento Dashboard) | 'transfer' (Send Money) | 'history' (Statement) | 'profile' (KYC)
  const [activeTab, setActiveTab] = useState('accounts');
  const [copied, setCopied] = useState(false);
  const [qrModalOpen, setQrModalOpen] = useState(false);

  // Active Deposit Account (1000-2000-3001)
  const activeAccountId = balance?.account_id || '1000-2000-3001';

  // Eye Toggle State (Show / Hide Balance & Account Number)
  const [isBalanceVisible, setIsBalanceVisible] = useState(true);
  const [isAccountVisible, setIsAccountVisible] = useState(true);

  // Clock
  const [currentTime, setCurrentTime] = useState(new Date());
  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    onTransactionComplete?.();
  }, []);

  // Search & Filter State for Activity Tab
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL'); // 'ALL' | 'SETTLED'
  const [dateFilter, setDateFilter] = useState('ALL');     // 'ALL' | 'TODAY' | 'MONTH'

  // Bento Donut Chart State Filter
  const [donutMonth, setDonutMonth] = useState('SEP_2026');

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

  const handleCopyAccount = (acctNumber = '1000-2000-3001') => {
    navigator.clipboard?.writeText(acctNumber);
    setCopied(true);
    showToast?.({
      type: 'info',
      title: 'Account Number Copied',
      detail: `Copied ${acctNumber} to clipboard.`,
    });
    setTimeout(() => setCopied(false), 2000);
  };

  // Transfer Form State
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
  
  // Customer Email OTP Verification Modal State
  const [isOtpModalOpen, setIsOtpModalOpen] = useState(false);
  const [otpInput, setOtpInput] = useState('');
  const [activePendingTx, setActivePendingTx] = useState(null);
  const [dispatchedOtpCode, setDispatchedOtpCode] = useState('');
  const [isVerifyingOtp, setIsVerifyingOtp] = useState(false);
  const [fraudAlertData, setFraudAlertData] = useState(null);

  const numericAmount = parseFloat(amountInput) || 0;
  const sourceAvailable = mockState.account?.available_balance ?? balance?.available_balance ?? 15000000;
  const sourceCurrent = mockState.account?.current_balance ?? balance?.current_balance ?? 15000000;
  const sourceHeld = mockState.account?.held_balance ?? balance?.held_balance ?? 0;

  const handleAmountChange = (e) => {
    const masked = parseMaskedInput(e.target.value, 2);
    setAmountInput(masked);
  };

  const handleAddAmount = (addVal) => {
    const current = parseFloat(amountInput) || 0;
    const nextVal = (current + addVal).toFixed(2);
    setAmountInput(nextVal);
  };

  const handleSetMaxAmount = () => {
    const maxVal = sourceAvailable.toFixed(2);
    setAmountInput(maxVal);
  };

  const handleInitiateTransfer = (e) => {
    e.preventDefault();
    if (!toAccount.trim() || !recipientName.trim()) {
      showToast?.({
        type: 'error',
        title: 'Missing Details',
        detail: 'Please provide both recipient account number and full name.',
      });
      return;
    }

    const myAccountClean = (balance?.account_id || '1000-2000-3001').replace(/[\s-]/g, '').toUpperCase();
    const enteredAccountClean = toAccount.trim().replace(/[\s-]/g, '').toUpperCase();
    if (myAccountClean === enteredAccountClean) {
      showToast?.({
        type: 'error',
        title: 'Invalid Destination Account',
        detail: 'You cannot transfer funds to your own source account.',
      });
      return;
    }

    const registeredList = mockState?.registeredAccounts || [];
    if (registeredList.length > 0) {
      const match = registeredList.find((acc) => {
        const accNumClean = (acc.account_number || '').replace(/[\s-]/g, '').toUpperCase();
        const accIdClean = (acc.account_id || '').replace(/[\s-]/g, '').toUpperCase();
        return accNumClean === enteredAccountClean || accIdClean === enteredAccountClean;
      });
      if (!match) {
        showToast?.({
          type: 'error',
          title: 'Account Not Found',
          detail: `Destination account "${toAccount}" does not exist in the bank directory. Please enter a valid account number (e.g. 1000-2000-3002).`,
        });
        return;
      }
    }

    if (numericAmount < 1.00) {
      showToast?.({
        type: 'error',
        title: 'Invalid Amount',
        detail: 'Minimum transfer amount is ₱ 1.00.',
      });
      return;
    }

    if (numericAmount > sourceAvailable) {
      showToast?.({
        type: 'error',
        title: 'Insufficient Balance',
        detail: `You have ${formatPHP(sourceAvailable)} available in source account.`,
      });
      return;
    }

    setIsConfirmModalOpen(true);
  };

  const handleExecuteTransfer = async () => {
    setIsSubmitting(true);
    try {
      const generatedRef = 'TX-' + Math.floor(100000 + Math.random() * 900000);
      const fromAcc = balance?.account_id || '1000-2000-3001';
      const toAcc = toAccount.trim();
      const res = await apiClient.post(
        '/transfers',
        {
          account_id: fromAcc,
          accountId: fromAcc,
          source_account_id: fromAcc,
          from_account_id: fromAcc,
          target_account_id: toAcc,
          targetAccountId: toAcc,
          destination_account_id: toAcc,
          to_account_id: toAcc,
          amount: numericAmount,
          mutation_amount: numericAmount,
          currency: 'PHP',
          recipient_name: recipientName.trim(),
          memo: memo.trim() || 'Fund Transfer',
        },
        {
          headers: {
            'X-Idempotency-Key': generateUUID(),
          },
        }
      );

      const isHighValue = numericAmount > THRESHOLDS.STP_MAX;

      if (isHighValue) {
        setIsConfirmModalOpen(false);
        const transferId = res?.data?.transfer_id || res?.data?.transaction_id || generatedRef;
        setActivePendingTx({
          transferId: transferId,
          amount: numericAmount,
          recipientName: recipientName.trim(),
          toAccount: toAcc,
          fromAccount: fromAcc,
          memo: memo.trim() || 'Fund Transfer',
        });
        setOtpInput('');
        setIsOtpModalOpen(true);

        // Guarantee OTP email delivery to MailHog (:8025)
        apiClient.post('/notifications/send-otp', {
          transfer_id: transferId,
          amount: numericAmount,
          from_account_id: fromAcc,
          to_account_id: toAcc,
          recipient_name: recipientName.trim(),
          recipient_email: user?.email || 'juan.dc@email.com',
        }).catch(() => {
          axios.post('http://localhost:8083/api/v1/notifications/send-otp', {
            transfer_id: transferId,
            amount: numericAmount,
            from_account_id: fromAcc,
            to_account_id: toAcc,
            recipient_name: recipientName.trim(),
            recipient_email: user?.email || 'juan.dc@email.com',
          }).catch(() => {});
        });

        showToast?.({
          type: 'info',
          title: 'Verification Code Dispatched',
          detail: `Transfer exceeds ₱50k threshold. 6-digit OTP dispatched to registered email in MailHog (:8025).`,
        });
        return;
      }

      showToast?.({
        type: 'success',
        title: 'Transfer Successful',
        detail: `Successfully sent ${formatPHP(numericAmount)} to ${recipientName}.`,
      });

      setReceiptData({
        refNumber: res?.data?.transfer_id || res?.data?.transaction_id || generatedRef,
        fromAccount: balance?.account_id || '1000-2000-3001',
        senderName: user?.name || 'Juan Dela Cruz',
        toAccount: toAccount.trim(),
        recipientName: recipientName.trim(),
        amount: numericAmount,
        fee: 0,
        memo: memo.trim() || 'Fund Transfer',
        isHighValue: false,
        isEmailVerified: false,
        timestamp: new Date(),
      });

      setIsConfirmModalOpen(false);
      setToAccount('');
      setRecipientName('');
      setAmountInput('');
      setMemo('');
      setCurrentIdempotencyKey(generateUUID());
      onTransactionComplete?.();
    } catch (err) {
      const problem = err.response?.data;
      if (err.response?.status === 422 && (problem?.error_code === 'RISK_THRESHOLD_EXCEEDED' || problem?.status === 'REJECTED_FRAUD')) {
        setFraudAlertData({
          title: 'Security Notice: Transaction Temporarily Held',
          location: problem?.location || 'New Location',
          timestamp: new Date().toLocaleTimeString()
        });
        setIsConfirmModalOpen(false);
        return;
      }

      showToast?.({
        type: 'error',
        title: problem?.title || problem?.error || 'Transfer Failed',
        detail: problem?.detail || problem?.message || 'Unable to complete transfer. Please verify recipient details and try again.',
      });
      setIsConfirmModalOpen(false);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleVerifyOtp = async (codeToVerify) => {
    const code = (codeToVerify || otpInput || '').toString().trim();
    if (!code || code.length !== 6) {
      showToast?.({
        type: 'error',
        title: 'Invalid Code',
        detail: 'Please enter a valid 6-digit verification code.',
      });
      return;
    }

    setIsVerifyingOtp(true);
    try {
      await apiClient.post('/transfers/verify-otp', {
        transfer_id: activePendingTx?.transferId,
        otp: code,
      });

      showToast?.({
        type: 'success',
        title: 'Transfer Verified & Settled',
        detail: `Transfer of ${formatPHP(activePendingTx?.amount || 0)} verified and settled successfully.`,
      });

      setReceiptData({
        refNumber: activePendingTx?.transferId,
        fromAccount: activePendingTx?.fromAccount || balance?.account_id || '1000-2000-3001',
        senderName: user?.name || 'Juan Dela Cruz',
        toAccount: activePendingTx?.toAccount,
        recipientName: activePendingTx?.recipientName,
        amount: activePendingTx?.amount,
        fee: 0,
        memo: activePendingTx?.memo,
        isHighValue: true,
        isEmailVerified: true,
        timestamp: new Date(),
      });

      setIsOtpModalOpen(false);
      setActivePendingTx(null);
      setOtpInput('');
      setToAccount('');
      setRecipientName('');
      setAmountInput('');
      setMemo('');
      setCurrentIdempotencyKey(generateUUID());
      onTransactionComplete?.();
    } catch (err) {
      const problem = err.response?.data;
      showToast?.({
        type: 'error',
        title: problem?.error_code || problem?.title || 'Verification Failed',
        detail: problem?.message || problem?.detail || 'Incorrect verification code. Please check MailHog (:8025) and try again.',
      });
    } finally {
      setIsVerifyingOtp(false);
    }
  };

  // Filtered transactions for History tab
  const transactionsList = useMemo(() => {
    let list = mockState.transfers || [];
    
    // Status filter
    if (statusFilter === 'SETTLED') {
      list = list.filter((t) => t.status === 'SETTLED');
    }

    // Date filter
    if (dateFilter === 'TODAY') {
      const today = new Date().toDateString();
      list = list.filter((t) => new Date(t.created_at).toDateString() === today);
    } else if (dateFilter === 'MONTH') {
      const currentMonth = new Date().getMonth();
      const currentYear = new Date().getFullYear();
      list = list.filter((t) => {
        const d = new Date(t.created_at);
        return d.getMonth() === currentMonth && d.getFullYear() === currentYear;
      });
    }

    // Search query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      list = list.filter(
        (t) =>
          (t.id || '').toLowerCase().includes(q) ||
          (t.recipient_name || '').toLowerCase().includes(q) ||
          (t.memo || '').toLowerCase().includes(q) ||
          String(t.amount || '').includes(q)
      );
    }

    return list;
  }, [statusFilter, dateFilter, searchQuery]);

  const handleExportCSV = () => {
    const headers = ['Transaction Reference', 'Timestamp', 'From Account', 'To Account', 'Recipient', 'Amount (PHP)', 'Status', 'Memo'];
    const rows = transactionsList.map((tx) => [
      `"${tx.id || ''}"`,
      `"${new Date(tx.created_at).toISOString()}"`,
      `"${tx.from_account_id || ''}"`,
      `"${tx.to_account_id || ''}"`,
      `"${(tx.recipient_name || '').replace(/"/g, '""')}"`,
      tx.amount || 0,
      `"${tx.status || ''}"`,
      `"${(tx.memo || '').replace(/"/g, '""')}"`,
    ]);

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `AuraBank_Statement_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    showToast?.({
      type: 'success',
      title: 'Statement Exported',
      detail: `Exported ${transactionsList.length} transaction records as CSV.`,
    });
  };

  const handleViewReceipt = (tx) => {
    const isIncoming = tx.to_account_id === '1000-2000-3001' && tx.from_account_id !== '1000-2000-3001';
    setReceiptData({
      refNumber: tx.id,
      fromAccount: tx.from_account_id || '1000-2000-3001',
      senderName: isIncoming ? tx.recipient_name : (user?.name || 'Juan Dela Cruz'),
      toAccount: tx.to_account_id || '1000-2000-3002',
      recipientName: isIncoming ? (user?.name || 'Juan Dela Cruz') : (tx.recipient_name || 'Beneficiary'),
      amount: tx.amount,
      fee: 0,
      memo: tx.memo || (isIncoming ? 'Direct Credit' : 'Fund Transfer'),
      isHighValue: tx.amount > THRESHOLDS.STP_MAX,
      isEmailVerified: tx.status === 'SETTLED' && tx.amount > THRESHOLDS.STP_MAX,
      timestamp: new Date(tx.created_at),
    });
  };

  return (
    <div className="space-y-5 animate-enter">
      {/* ========================================================
          1. INSTITUTIONAL PORTFOLIO HEADER RIBBON
         ======================================================== */}
      <div className="bg-surface border border-line card-highlight p-5 text-fg">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-5">
          {/* Left: Date, Time & Calendar */}
          <div className="flex items-center gap-3.5">
            <div className="w-10 h-10 bg-sunken border border-line text-accent flex items-center justify-center shrink-0">
              <Calendar className="w-5 h-5 text-accent" />
            </div>
            <div>
              <p className="text-2xs font-mono uppercase tracking-wider text-fg-subtle font-medium">
                {currentTime.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' })}
              </p>
              <p className="text-sm font-semibold font-mono text-fg flex items-center gap-2 mt-0.5">
                <Clock className="w-3.5 h-3.5 text-fg-subtle" />
                <span>{currentTime.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' })} PHT</span>
              </p>
            </div>
          </div>

          {/* Right: Focused Balance Metrics (Deposit Portfolio Only) */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 lg:gap-8 divide-y sm:divide-y-0 sm:divide-x divide-line pt-2 lg:pt-0">
            {/* Metric 1: Available Liquid Balance */}
            <div className="sm:px-4 first:pl-0 pt-2 sm:pt-0">
              <span className="text-2xs font-medium uppercase tracking-wider text-fg-subtle flex items-center gap-1.5">
                <Wallet className="w-3.5 h-3.5 text-accent" /> Primary Savings
              </span>
              <p className="text-base font-semibold font-mono text-fg mt-1">
                {formatVisiblePHP(sourceAvailable)}
              </p>
              <span className="text-2xs text-fg-subtle font-mono">...3001 &bull; 1.25% p.a.</span>
            </div>

            {/* Metric 2: Total Ledger Balance */}
            <div className="sm:px-4 pt-2 sm:pt-0">
              <span className="text-2xs font-medium uppercase tracking-wider text-fg-subtle flex items-center gap-1.5">
                <Landmark className="w-3.5 h-3.5 text-fg-subtle" /> Total Ledger Balance
              </span>
              <p className="text-base font-semibold font-mono text-fg mt-1">
                {formatVisiblePHP(sourceCurrent)}
              </p>
              <span className="text-2xs text-fg-subtle font-mono">Gross deposit position</span>
            </div>
          </div>
        </div>
      </div>

      {/* ========================================================
          2. HORIZONTAL NAVIGATION TABS
         ======================================================== */}
      <div className="bg-surface border border-line p-1.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-1 overflow-x-auto pb-1 sm:pb-0">
          <button
            type="button"
            onClick={() => setActiveTab('accounts')}
            className={cn(
              'px-4 py-2 text-xs font-medium transition-colors flex items-center gap-2 cursor-pointer shrink-0',
              activeTab === 'accounts'
                ? 'bg-accent text-fg-inverse font-semibold'
                : 'text-fg-muted hover:text-fg hover:bg-sunken'
            )}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>Accounts &amp; Overview</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('transfer')}
            className={cn(
              'px-4 py-2 text-xs font-medium transition-colors flex items-center gap-2 cursor-pointer shrink-0',
              activeTab === 'transfer'
                ? 'bg-accent text-fg-inverse font-semibold'
                : 'text-fg-muted hover:text-fg hover:bg-sunken'
            )}
          >
            <Send className="w-3.5 h-3.5" />
            <span>Transfers &amp; Payments</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('history')}
            className={cn(
              'px-4 py-2 text-xs font-medium transition-colors flex items-center gap-2 cursor-pointer shrink-0',
              activeTab === 'history'
                ? 'bg-accent text-fg-inverse font-semibold'
                : 'text-fg-muted hover:text-fg hover:bg-sunken'
            )}
          >
            <FileText className="w-3.5 h-3.5" />
            <span>Statement &amp; Activity</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('profile')}
            className={cn(
              'px-4 py-2 text-xs font-medium transition-colors flex items-center gap-2 cursor-pointer shrink-0',
              activeTab === 'profile'
                ? 'bg-accent text-fg-inverse font-semibold'
                : 'text-fg-muted hover:text-fg hover:bg-sunken'
            )}
          >
            <User className="w-3.5 h-3.5" />
            <span>Profile &amp; Security</span>
          </button>
        </div>

        {/* Global Privacy Toggle */}
        <div className="flex items-center gap-2 self-end sm:self-auto text-xs text-fg-muted px-2">
          <button
            type="button"
            onClick={() => setIsBalanceVisible(!isBalanceVisible)}
            className="flex items-center gap-1.5 px-3 py-1.5 border border-line hover:bg-sunken text-fg-muted hover:text-fg transition-colors cursor-pointer text-xs"
            title={isBalanceVisible ? 'Mask financial figures' : 'Reveal financial figures'}
          >
            {isBalanceVisible ? <Eye className="w-3.5 h-3.5 text-accent" /> : <EyeOff className="w-3.5 h-3.5 text-fg-subtle" />}
            <span className="font-mono text-2xs font-medium">{isBalanceVisible ? 'Hide Figures' : 'Show Figures'}</span>
          </button>
        </div>
      </div>

      {/* ========================================================
          3. MAIN TAB CONTENT
         ======================================================== */}
      {activeTab === 'accounts' && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-start">
          {/* Left Column: Quick Actions & Desk Support */}
          <div className="lg:col-span-4 space-y-5">
            {/* Quick Actions Card */}
            <div className="bg-surface border border-line card-highlight p-5 space-y-4">
              <h3 className="text-2xs font-medium uppercase tracking-wider text-fg-subtle">
                Frequent Operations
              </h3>

              <div className="space-y-1">
                <button
                  type="button"
                  onClick={() => setActiveTab('transfer')}
                  className="w-full flex items-center justify-between p-3 border border-line bg-sunken hover:bg-surface hover:border-accent-line text-left transition-colors cursor-pointer group"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-surface border border-line flex items-center justify-center text-accent">
                      <Send className="w-4 h-4" />
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-fg group-hover:text-accent transition-colors">Send Money</p>
                      <p className="text-2xs text-fg-subtle">Transfer funds to domestic accounts</p>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-fg-subtle group-hover:text-accent transition-colors" />
                </button>

                <button
                  type="button"
                  onClick={() => setActiveTab('history')}
                  className="w-full flex items-center justify-between p-3 border border-line bg-sunken hover:bg-surface hover:border-accent-line text-left transition-colors cursor-pointer group"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-surface border border-line flex items-center justify-center text-accent">
                      <FileText className="w-4 h-4" />
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-fg group-hover:text-accent transition-colors">Statement Ledger</p>
                      <p className="text-2xs text-fg-subtle">Audit history and export statements</p>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-fg-subtle group-hover:text-accent transition-colors" />
                </button>

                <button
                  type="button"
                  onClick={() => setQrModalOpen(true)}
                  className="w-full flex items-center justify-between p-3 border border-line bg-sunken hover:bg-surface hover:border-accent-line text-left transition-colors cursor-pointer group"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-surface border border-line flex items-center justify-center text-accent">
                      <QrCode className="w-4 h-4" />
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-fg group-hover:text-accent transition-colors">Receive via QR</p>
                      <p className="text-2xs text-fg-subtle">Instant deposit barcode</p>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-fg-subtle group-hover:text-accent transition-colors" />
                </button>

                <button
                  type="button"
                  onClick={() => setActiveTab('profile')}
                  className="w-full flex items-center justify-between p-3 border border-line bg-sunken hover:bg-surface hover:border-accent-line text-left transition-colors cursor-pointer group"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-surface border border-line flex items-center justify-center text-accent">
                      <User className="w-4 h-4" />
                    </div>
                    <div>
                      <p className="text-xs font-semibold text-fg group-hover:text-accent transition-colors">Profile Particulars</p>
                      <p className="text-2xs text-fg-subtle">Identity KYC &amp; transaction PIN</p>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-fg-subtle group-hover:text-accent transition-colors" />
                </button>
              </div>
            </div>

              {/* Verified Institutional Desk Support Card */}
            <div className="bg-sunken border border-line p-5 space-y-3">
              <div className="flex items-center gap-2">
                <Building2 className="w-4 h-4 text-accent" />
                <h4 className="text-xs font-semibold text-fg">Direct Commercial Routing</h4>
              </div>
              <p className="text-2xs text-fg-muted leading-relaxed">
                Direct branch clearing via Makati Financial Center. Inquiries and transaction exceptions are routed to your designated relationship desk.
              </p>
              <div className="pt-2 border-t border-line space-y-1.5 text-2xs text-fg-subtle font-mono">
                <div className="flex justify-between">
                  <span>Routing Transit:</span>
                  <span className="text-fg font-medium">0100-8492</span>
                </div>
                <div className="flex justify-between">
                  <span>Priority Line:</span>
                  <span className="text-fg font-medium">+63 (2) 8888-AURA</span>
                </div>
              </div>
            </div>
          </div>

          {/* Right Column: Donut Breakdown + Accounts + Recent Activity */}
          <div className="lg:col-span-8 space-y-5">
            {/* Cash Flow by Category Card */}
            <div className="bg-surface border border-line card-highlight p-5 space-y-5">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-line">
                <div>
                  <h3 className="text-sm font-semibold text-fg flex items-center gap-2">
                    <PieChart className="w-4 h-4 text-accent" />
                    Outflow &amp; Disbursements by Category
                  </h3>
                  <p className="text-2xs text-fg-muted mt-0.5">
                    Operational outflow allocation across verified domestic counterparty disbursements
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <span className="text-2xs font-mono px-2.5 py-1 border border-line bg-sunken text-fg-subtle">
                    September 2026
                  </span>
                </div>
              </div>

              {/* Chart & Legend Layout */}
              <div className="grid grid-cols-1 md:grid-cols-12 gap-6 items-center">
                {/* Donut Chart SVG */}
                <div className="md:col-span-5 flex flex-col items-center justify-center py-2">
                  <div className="relative w-44 h-44">
                    <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
                      {/* Segment 1: Commercial Real Estate (89.4%) -> circumference 251.2, strokeDasharray 224.5 251.2 */}
                      <circle
                        cx="50"
                        cy="50"
                        r="40"
                        fill="transparent"
                        stroke="rgb(var(--accent))"
                        strokeWidth="12"
                        strokeDasharray="224.5 251.2"
                        strokeDashoffset="0"
                      />
                      {/* Segment 2: Vendor Invoices (10.3%) -> strokeDasharray 25.9 251.2, offset -224.5 */}
                      <circle
                        cx="50"
                        cy="50"
                        r="40"
                        fill="transparent"
                        stroke="rgb(var(--accent-hover))"
                        strokeWidth="12"
                        strokeDasharray="25.9 251.2"
                        strokeDashoffset="-224.5"
                      />
                      {/* Segment 3: Executive Payroll (0.3%) -> strokeDasharray 0.8 251.2, offset -250.4 */}
                      <circle
                        cx="50"
                        cy="50"
                        r="40"
                        fill="transparent"
                        stroke="rgb(var(--settled-600))"
                        strokeWidth="12"
                        strokeDasharray="1.5 251.2"
                        strokeDashoffset="-250.4"
                      />
                    </svg>
                    <div className="absolute inset-0 flex flex-col items-center justify-center text-center p-2">
                      <span className="text-[10px] uppercase font-mono tracking-wider text-fg-subtle">Total Outflow</span>
                      <span className="text-sm font-semibold font-mono text-fg mt-0.5">{formatVisiblePHP(727000)}</span>
                    </div>
                  </div>
                </div>

                {/* Categorical Breakdown List */}
                <div className="md:col-span-7 space-y-2.5">
                  <div className="p-3 bg-sunken border border-line flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2.5">
                      <div className="w-2.5 h-2.5 bg-accent shrink-0" />
                      <span className="font-medium text-fg">Commercial Real Estate Acquisition</span>
                    </div>
                    <div className="text-right">
                      <span className="font-mono font-medium text-fg">{formatVisiblePHP(650000)}</span>
                      <span className="text-2xs text-fg-subtle ml-2 font-mono">89.4%</span>
                    </div>
                  </div>

                  <div className="p-3 bg-sunken border border-line flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2.5">
                      <div className="w-2.5 h-2.5 bg-accent-hover shrink-0" />
                      <span className="font-medium text-fg">Vendor &amp; Supplier Invoices</span>
                    </div>
                    <div className="text-right">
                      <span className="font-mono font-medium text-fg">{formatVisiblePHP(75000)}</span>
                      <span className="text-2xs text-fg-subtle ml-2 font-mono">10.3%</span>
                    </div>
                  </div>

                  <div className="p-3 bg-sunken border border-line flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2.5">
                      <div className="w-2.5 h-2.5 bg-settled-600 shrink-0" />
                      <span className="font-medium text-fg">Executive Payroll &amp; Fund Transfers</span>
                    </div>
                    <div className="text-right">
                      <span className="font-mono font-medium text-fg">{formatVisiblePHP(2000)}</span>
                      <span className="text-2xs text-fg-subtle ml-2 font-mono">0.3%</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Primary Deposit Account Card */}
            <div className="bg-surface border border-line card-highlight p-5 space-y-4">
              <div className="flex items-center justify-between pb-3 border-b border-line">
                <div>
                  <h3 className="text-sm font-semibold text-fg flex items-center gap-2">
                    <Landmark className="w-4 h-4 text-accent" />
                    Primary Commercial Deposit Account
                  </h3>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="text-xs font-mono font-medium text-fg">{formatVisibleAccount('1000-2000-3001')}</span>
                    <button
                      type="button"
                      onClick={() => handleCopyAccount('1000-2000-3001')}
                      className="text-fg-subtle hover:text-fg transition-colors"
                      title="Copy account number"
                    >
                      {copied ? <Check className="w-3.5 h-3.5 text-settled-600" /> : <Copy className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                </div>

                <Badge tone="settled" size="sm">
                  Active &bull; Prime Regular
                </Badge>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="p-4 bg-sunken border border-line">
                  <span className="text-2xs uppercase font-mono tracking-wider text-fg-subtle">Available Liquid Balance</span>
                  <p className="text-2xl font-semibold font-mono text-fg mt-1">
                    {formatVisiblePHP(sourceAvailable)}
                  </p>
                  <p className="text-2xs text-fg-subtle mt-1 font-mono">Unencumbered withdrawal limit</p>
                </div>

                <div className="p-4 bg-sunken border border-line">
                  <span className="text-2xs uppercase font-mono tracking-wider text-fg-subtle">Total Gross Ledger Balance</span>
                  <p className="text-2xl font-semibold font-mono text-fg mt-1">
                    {formatVisiblePHP(sourceCurrent)}
                  </p>
                  <p className="text-2xs text-fg-subtle mt-1 font-mono">
                    Direct on-demand book balance
                  </p>
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <Button
                  variant="secondary"
                  size="sm"
                  icon={QrCode}
                  onClick={() => setQrModalOpen(true)}
                >
                  Deposit QR
                </Button>
                <Button
                  variant="primary"
                  size="sm"
                  icon={Send}
                  onClick={() => setActiveTab('transfer')}
                >
                  Transfer Out
                </Button>
              </div>
            </div>

            {/* Recent Transactions Snippet */}
            <div className="bg-surface border border-line card-highlight p-5 space-y-4">
              <div className="flex items-center justify-between pb-3 border-b border-line">
                <h3 className="text-sm font-semibold text-fg flex items-center gap-2">
                  <Receipt className="w-4 h-4 text-accent" />
                  Recent Ledger Transactions
                </h3>
                <button
                  type="button"
                  onClick={() => setActiveTab('history')}
                  className="text-xs font-medium text-accent hover:underline flex items-center gap-1 cursor-pointer"
                >
                  <span>View Statement</span>
                  <ChevronRight className="w-3.5 h-3.5" />
                </button>
              </div>

              <div className="space-y-1">
                {(mockState.transfers || []).slice(0, 4).map((tx) => {
                  const isIncoming = tx.to_account_id === '1000-2000-3001' && tx.from_account_id !== '1000-2000-3001';
                  const isSettled = tx.status === 'SETTLED';

                  return (
                    <div
                      key={tx.id}
                      onClick={() => handleViewReceipt(tx)}
                      className="p-3 border border-line bg-sunken hover:bg-surface hover:border-accent-line flex items-center justify-between text-xs cursor-pointer transition-colors"
                    >
                      <div className="flex items-center gap-3">
                        <div className={cn(
                          'w-7 h-7 flex items-center justify-center border',
                          isIncoming ? 'bg-settled-50 dark:bg-settled-900/30 border-settled-200 dark:border-settled-800 text-settled-600' : 'bg-surface border-line text-fg-subtle'
                        )}>
                          {isIncoming ? <ArrowDownLeft className="w-3.5 h-3.5" /> : <ArrowUpRight className="w-3.5 h-3.5" />}
                        </div>
                        <div>
                          <p className="font-semibold text-fg">{tx.recipient_name || 'Counterparty'}</p>
                          <p className="text-2xs font-mono text-fg-subtle">
                            {tx.id} &bull; {new Date(tx.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                          </p>
                        </div>
                      </div>

                      <div className="text-right">
                        <p className={cn(
                          'font-mono font-semibold',
                          isIncoming ? 'text-settled-600 dark:text-settled-400' : 'text-fg'
                        )}>
                          {isIncoming ? '+' : '-'}{formatVisiblePHP(tx.amount)}
                        </p>
                        <span className={cn(
                          'text-[10px] font-mono uppercase px-1.5 py-0.2 border',
                          isSettled 
                            ? 'bg-settled-50 dark:bg-settled-900/30 text-settled-700 dark:text-settled-400 border-settled-200 dark:border-settled-800'
                            : 'bg-sunken text-fg-subtle border-line'
                        )}>
                          {isSettled ? 'Settled' : (tx.status || 'Settled')}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          TAB 2: TRANSFERS & PAYMENTS
         ======================================================== */}
      {activeTab === 'transfer' && (
        <div className="max-w-2xl mx-auto space-y-5">
          <div className="bg-surface border border-line card-highlight p-6 space-y-6">
            <div className="border-b border-line pb-4">
              <h2 className="text-base font-semibold text-fg">Direct Fund Transfer</h2>
              <p className="text-xs text-fg-muted mt-1">
                Disburse funds immediately to verified domestic counterparty bank accounts.
              </p>
            </div>

            <form onSubmit={handleInitiateTransfer} className="space-y-4">
              {/* Source Account Info */}
              <div>
                <label className="block text-xs font-medium text-fg mb-1">Source Deposit Account</label>
                <div className="p-3 bg-sunken border border-line text-xs font-mono flex items-center justify-between text-fg">
                  <div>
                    <span className="font-semibold">Primary Savings (1000-2000-3001)</span>
                    <p className="text-2xs text-fg-subtle font-sans mt-0.5">Available for disbursement: {formatVisiblePHP(sourceAvailable)}</p>
                  </div>
                  <span className="text-2xs font-mono text-settled-600 dark:text-settled-400 border border-settled-200 dark:border-settled-800 px-2 py-0.5 bg-settled-50 dark:bg-settled-900/30">
                    Active
                  </span>
                </div>
              </div>

              {/* Destination Account */}
              <div>
                <label className="block text-xs font-medium text-fg mb-1">Destination Account Number</label>
                <input
                  type="text"
                  value={toAccount}
                  onChange={(e) => setToAccount(e.target.value)}
                  placeholder="e.g. 1000-2000-3002"
                  className="w-full bg-surface border border-line px-3.5 py-2 text-xs text-fg focus:outline-none focus:border-accent font-mono"
                  required
                />
                <div className="flex items-center gap-2 mt-2">
                  <span className="text-2xs text-fg-subtle">Quick Directory:</span>
                  <button
                    type="button"
                    onClick={() => {
                      setToAccount('1000-2000-3002');
                      setRecipientName('Maria Santos');
                    }}
                    className="text-2xs font-mono text-accent hover:underline border border-line px-1.5 py-0.5 bg-sunken"
                  >
                    Maria Santos (...3002)
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setToAccount('1000-2000-3004');
                      setRecipientName('Apex Commercial Supplies');
                    }}
                    className="text-2xs font-mono text-accent hover:underline border border-line px-1.5 py-0.5 bg-sunken"
                  >
                    Apex Supplies (...3004)
                  </button>
                </div>
              </div>

              {/* Recipient Full Name */}
              <div>
                <label className="block text-xs font-medium text-fg mb-1">Beneficiary Full Name</label>
                <input
                  type="text"
                  value={recipientName}
                  onChange={(e) => setRecipientName(e.target.value)}
                  placeholder="Official recipient name"
                  className="w-full bg-surface border border-line px-3.5 py-2 text-xs text-fg focus:outline-none focus:border-accent"
                  required
                />
              </div>

              {/* Transfer Amount */}
              <div>
                <div className="flex justify-between items-center mb-1">
                  <label className="block text-xs font-medium text-fg">Transfer Amount (PHP)</label>
                  <span className="text-2xs text-fg-subtle font-mono">Fee: ₱0.00</span>
                </div>
                <div className="relative">
                  <span className="absolute left-3.5 top-2.5 text-xs font-mono font-medium text-fg-subtle">₱</span>
                  <input
                    type="text"
                    value={amountInput}
                    onChange={handleAmountChange}
                    placeholder="0.00"
                    className="w-full bg-surface border border-line pl-8 pr-3.5 py-2 text-sm text-fg font-mono font-semibold focus:outline-none focus:border-accent"
                    required
                  />
                </div>
                
                {/* Quick Add Buttons */}
                <div className="flex items-center gap-1.5 mt-2">
                  <button
                    type="button"
                    onClick={() => handleAddAmount(1000)}
                    className="text-2xs font-mono border border-line px-2 py-1 bg-sunken hover:bg-surface text-fg"
                  >
                    + ₱1,000
                  </button>
                  <button
                    type="button"
                    onClick={() => handleAddAmount(10000)}
                    className="text-2xs font-mono border border-line px-2 py-1 bg-sunken hover:bg-surface text-fg"
                  >
                    + ₱10,000
                  </button>
                  <button
                    type="button"
                    onClick={() => handleAddAmount(50000)}
                    className="text-2xs font-mono border border-line px-2 py-1 bg-sunken hover:bg-surface text-fg"
                  >
                    + ₱50,000
                  </button>
                  <button
                    type="button"
                    onClick={handleSetMaxAmount}
                    className="text-2xs font-mono border border-line px-2 py-1 bg-sunken hover:bg-surface text-accent font-semibold ml-auto"
                  >
                    Max Available
                  </button>
                </div>
              </div>

              {/* Memo */}
              <div>
                <label className="block text-xs font-medium text-fg mb-1">Disbursement Purpose / Memo</label>
                <input
                  type="text"
                  value={memo}
                  onChange={(e) => setMemo(e.target.value)}
                  placeholder="e.g. Commercial invoice settlement #849"
                  className="w-full bg-surface border border-line px-3.5 py-2 text-xs text-fg focus:outline-none focus:border-accent"
                />
              </div>

              {numericAmount > THRESHOLDS.STP_MAX && (
                <div className="p-3 bg-accent-soft/30 border border-accent-line text-2xs text-fg flex items-start gap-2">
                  <ShieldCheck className="w-4 h-4 text-accent shrink-0 mt-0.5" />
                  <span>
                    High-value disbursement (exceeding ₱50,000.00). An OTP security challenge will be dispatched to your registered email via MailHog (:8025) before settlement.
                  </span>
                </div>
              )}

              <div className="pt-3 border-t border-line flex items-center justify-end gap-2">
                <Button
                  variant="ghost"
                  size="md"
                  type="button"
                  onClick={() => {
                    setToAccount('');
                    setRecipientName('');
                    setAmountInput('');
                    setMemo('');
                  }}
                >
                  Clear
                </Button>
                <Button
                  variant="primary"
                  size="md"
                  type="submit"
                  icon={ArrowRight}
                  disabled={isSubmitting || numericAmount <= 0}
                >
                  Review Details &rarr;
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================
          TAB 3: STATEMENT & ACTIVITY
         ======================================================== */}
      {activeTab === 'history' && (
        <div className="space-y-4">
          <div className="bg-surface border border-line card-highlight p-5 space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-line">
              <div>
                <h2 className="text-sm font-semibold text-fg">Account Statement &amp; Activity Ledger</h2>
                <p className="text-2xs text-fg-muted mt-0.5">
                  Complete audit ledger of verified debit and credit transactions.
                </p>
              </div>

              <Button
                variant="secondary"
                size="sm"
                icon={Download}
                onClick={handleExportCSV}
              >
                Export CSV Statement
              </Button>
            </div>

            {/* Filter Controls */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="relative">
                <Search className="w-3.5 h-3.5 absolute left-3 top-2.5 text-fg-subtle" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search reference, recipient, memo..."
                  className="w-full bg-surface border border-line pl-8 pr-3 py-1.5 text-xs text-fg focus:outline-none focus:border-accent"
                />
              </div>

              <div className="flex items-center gap-2">
                <label className="text-2xs text-fg-subtle uppercase font-mono">Status:</label>
                <select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  className="flex-1 bg-surface border border-line px-2.5 py-1.5 text-xs text-fg focus:outline-none focus:border-accent"
                >
                  <option value="ALL">All Statuses</option>
                  <option value="SETTLED">Settled Only</option>
                </select>
              </div>

              <div className="flex items-center gap-2">
                <label className="text-2xs text-fg-subtle uppercase font-mono">Period:</label>
                <select
                  value={dateFilter}
                  onChange={(e) => setDateFilter(e.target.value)}
                  className="flex-1 bg-surface border border-line px-2.5 py-1.5 text-xs text-fg focus:outline-none focus:border-accent"
                >
                  <option value="ALL">All Time</option>
                  <option value="TODAY">Today Only</option>
                  <option value="MONTH">This Month</option>
                </select>
              </div>
            </div>
          </div>

          {/* Ledger Table */}
          <div className="bg-surface border border-line overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-sunken border-b border-line text-2xs font-mono uppercase text-fg-subtle">
                <tr>
                  <th className="px-4 py-3 font-medium">Timestamp</th>
                  <th className="px-4 py-3 font-medium">Reference ID</th>
                  <th className="px-4 py-3 font-medium">Counterparty</th>
                  <th className="px-4 py-3 font-medium">Description</th>
                  <th className="px-4 py-3 font-medium text-right">Amount (PHP)</th>
                  <th className="px-4 py-3 font-medium">Status</th>
                  <th className="px-4 py-3 font-medium text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {transactionsList.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-4 py-8 text-center text-fg-subtle text-xs">
                      No transaction records match the selected search and filter criteria.
                    </td>
                  </tr>
                ) : (
                  transactionsList.map((tx) => {
                    const isIncoming = tx.to_account_id === '1000-2000-3001' && tx.from_account_id !== '1000-2000-3001';
                    const isSettled = tx.status === 'SETTLED';

                    return (
                      <tr key={tx.id} className="hover:bg-sunken/60 transition-colors">
                        <td className="px-4 py-3 font-mono text-fg-muted whitespace-nowrap">
                          {new Date(tx.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                        </td>
                        <td className="px-4 py-3 font-mono text-fg font-medium whitespace-nowrap">
                          {tx.id}
                        </td>
                        <td className="px-4 py-3 text-fg font-medium">
                          {tx.recipient_name || 'Counterparty'}
                        </td>
                        <td className="px-4 py-3 text-fg-muted truncate max-w-xs">
                          {tx.memo || 'Fund Transfer'}
                        </td>
                        <td className={cn(
                          'px-4 py-3 font-mono font-semibold text-right whitespace-nowrap',
                          isIncoming ? 'text-settled-600 dark:text-settled-400' : 'text-fg'
                        )}>
                          {isIncoming ? '+' : '-'}{formatVisiblePHP(tx.amount)}
                        </td>
                        <td className="px-4 py-3 whitespace-nowrap">
                          <span className={cn(
                            'text-2xs font-mono uppercase px-2 py-0.5 border',
                            isSettled
                              ? 'bg-settled-50 dark:bg-settled-900/30 text-settled-700 dark:text-settled-400 border-settled-200 dark:border-settled-800'
                              : 'bg-sunken text-fg-subtle border-line'
                          )}>
                            {isSettled ? 'Settled' : (tx.status || 'Settled')}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-right whitespace-nowrap">
                          <button
                            type="button"
                            onClick={() => handleViewReceipt(tx)}
                            className="text-2xs font-medium text-accent hover:underline cursor-pointer"
                          >
                            Receipt
                          </button>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ========================================================
          TAB 4: PROFILE & SECURITY
         ======================================================== */}
      {activeTab === 'profile' && (
        <CustomerProfile showToast={showToast} activeAccountId={activeAccountId} />
      )}

      {/* ========================================================
          MODAL 1: CONFIRM TRANSFER
         ======================================================== */}
      {isConfirmModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink-950/50 backdrop-blur-xs animate-enter">
          <div className="w-full max-w-md bg-surface border border-line card-highlight p-6 space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-line">
              <h3 className="text-sm font-semibold text-fg">Confirm Fund Transfer</h3>
              <button
                type="button"
                onClick={() => setIsConfirmModalOpen(false)}
                className="text-fg-subtle hover:text-fg"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-2.5 text-xs">
              <div className="p-3 bg-sunken border border-line space-y-2">
                <div className="flex justify-between">
                  <span className="text-fg-subtle">Source Account:</span>
                  <span className="font-mono text-fg font-medium">1000-2000-3001 (Savings)</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-fg-subtle">Beneficiary:</span>
                  <span className="text-fg font-medium">{recipientName}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-fg-subtle">Account Number:</span>
                  <span className="font-mono text-fg font-medium">{toAccount}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-fg-subtle">Transfer Fee:</span>
                  <span className="font-mono text-settled-600 dark:text-settled-400 font-medium">₱0.00 (Zero Fee)</span>
                </div>
                <div className="flex justify-between pt-2 border-t border-line text-sm font-semibold">
                  <span>Total Debit:</span>
                  <span className="font-mono text-accent">{formatPHP(numericAmount)}</span>
                </div>
              </div>

              {memo && (
                <div className="p-2.5 bg-sunken border border-line text-2xs text-fg-muted">
                  <span className="font-medium text-fg">Memo:</span> {memo}
                </div>
              )}
            </div>

            <div className="flex items-center justify-end gap-2 pt-2 border-t border-line">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setIsConfirmModalOpen(false)}
                disabled={isSubmitting}
              >
                Cancel
              </Button>
              <Button
                variant="primary"
                size="sm"
                onClick={handleExecuteTransfer}
                disabled={isSubmitting}
              >
                {isSubmitting ? 'Submitting...' : 'Authorize Disbursement'}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL 2: OTP VERIFICATION FOR HIGH-VALUE TRANSFERS
         ======================================================== */}
      {isOtpModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink-950/50 backdrop-blur-xs animate-enter">
          <div className="w-full max-w-md bg-surface border border-line card-highlight p-6 space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-line">
              <h3 className="text-sm font-semibold text-fg flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-accent" />
                Security Verification Code
              </h3>
              <button
                type="button"
                onClick={() => setIsOtpModalOpen(false)}
                className="text-fg-subtle hover:text-fg"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <p className="text-xs text-fg-muted">
              Transfer amount of <strong className="text-fg font-mono">{formatPHP(activePendingTx?.amount || 0)}</strong> requires OTP verification. A 6-digit code has been dispatched to your registered email address.
            </p>

            <div className="p-3 bg-sunken border border-line space-y-2">
              <label className="block text-2xs font-mono uppercase text-fg-subtle">
                6-Digit Verification Code
              </label>
              <input
                type="text"
                maxLength={6}
                value={otpInput}
                onChange={(e) => setOtpInput(e.target.value.replace(/\D/g, ''))}
                placeholder="123456"
                className="w-full bg-surface border border-line px-3.5 py-2.5 text-center text-lg font-mono font-bold tracking-widest text-fg focus:outline-none focus:border-accent"
              />
              <p className="text-2xs text-fg-subtle">
                Local Environment: inspect MailHog UI on port 8025 to view dispatched OTP mail.
              </p>
            </div>

            <div className="flex items-center justify-end gap-2 pt-2 border-t border-line">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setIsOtpModalOpen(false)}
                disabled={isVerifyingOtp}
              >
                Cancel
              </Button>
              <Button
                variant="primary"
                size="sm"
                onClick={() => handleVerifyOtp(otpInput)}
                disabled={isVerifyingOtp || otpInput.length !== 6}
              >
                {isVerifyingOtp ? 'Verifying...' : 'Verify & Disburse'}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL 3: OFFICIAL TRANSACTION RECEIPT
         ======================================================== */}
      {receiptData && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink-950/50 backdrop-blur-xs animate-enter">
          <div className="w-full max-w-md bg-surface border border-line card-highlight p-6 space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-line no-print">
              <h3 className="text-sm font-semibold text-fg">Official Transaction Slip</h3>
              <button
                type="button"
                onClick={() => setReceiptData(null)}
                className="text-fg-subtle hover:text-fg cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div id="printable-receipt" className="space-y-4 text-xs">
              <div className="text-center pb-3 border-b border-line">
                <h4 className="text-base font-bold text-fg">AURABANK PHILIPPINES</h4>
                <p className="text-2xs text-fg-subtle font-mono mt-0.5">CORE TRANSACTION SETTLEMENT ADVICE</p>
                <p className="text-2xs text-fg-subtle font-mono">
                  {new Date(receiptData.timestamp).toLocaleString('en-US')}
                </p>
              </div>

              <div className="space-y-2 font-mono">
                <div className="flex justify-between">
                  <span className="text-fg-subtle">Reference ID:</span>
                  <span className="text-fg font-semibold">{receiptData.refNumber}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-fg-subtle">Sender:</span>
                  <span className="text-fg">{receiptData.senderName}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-fg-subtle">From Account:</span>
                  <span className="text-fg">{receiptData.fromAccount}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-fg-subtle">Beneficiary:</span>
                  <span className="text-fg">{receiptData.recipientName}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-fg-subtle">To Account:</span>
                  <span className="text-fg">{receiptData.toAccount}</span>
                </div>
                <div className="flex justify-between pt-2 border-t border-line text-sm font-bold">
                  <span>Amount Settled:</span>
                  <span className="text-accent">{formatPHP(receiptData.amount)}</span>
                </div>
                <div className="flex justify-between text-2xs text-settled-600 dark:text-settled-400">
                  <span>Status:</span>
                  <span>COMPLETED &bull; LEDGER COMMITTED</span>
                </div>
              </div>

              {receiptData.memo && (
                <div className="p-2.5 bg-sunken border border-line text-2xs text-fg-muted font-sans">
                  <span className="font-semibold text-fg">Particulars:</span> {receiptData.memo}
                </div>
              )}
            </div>

            <div className="flex items-center justify-end gap-2 pt-3 border-t border-line no-print">
              <Button
                variant="secondary"
                size="sm"
                icon={Printer}
                onClick={() => window.print()}
              >
                Print Receipt
              </Button>
              <Button
                variant="primary"
                size="sm"
                onClick={() => setReceiptData(null)}
              >
                Done
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL 4: RECEIVE VIA QR
         ======================================================== */}
      {qrModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink-950/50 backdrop-blur-xs animate-enter">
          <div className="w-full max-w-sm bg-surface border border-line card-highlight p-6 space-y-4 text-center">
            <div className="flex items-center justify-between pb-3 border-b border-line text-left">
              <h3 className="text-sm font-semibold text-fg">Direct Deposit QR</h3>
              <button
                type="button"
                onClick={() => setQrModalOpen(false)}
                className="text-fg-subtle hover:text-fg cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="p-4 bg-sunken border border-line inline-block mx-auto">
              {/* High contrast SVG QR Representation */}
              <div className="w-44 h-44 bg-surface border border-line p-3 flex flex-col justify-between items-center">
                <div className="grid grid-cols-5 gap-1.5 w-full h-full p-2">
                  <div className="bg-fg col-span-2 row-span-2" />
                  <div className="bg-transparent" />
                  <div className="bg-fg col-span-2 row-span-2" />
                  <div className="bg-fg" />
                  <div className="bg-fg col-span-3" />
                  <div className="bg-fg" />
                  <div className="bg-fg col-span-2 row-span-2" />
                  <div className="bg-transparent" />
                  <div className="bg-fg col-span-2 row-span-2" />
                </div>
              </div>
            </div>

            <div>
              <p className="text-xs font-semibold text-fg">Juan Dela Cruz</p>
              <p className="text-xs font-mono text-accent mt-0.5">1000-2000-3001</p>
              <p className="text-2xs text-fg-subtle mt-1">AuraBank Primary Savings Deposit</p>
            </div>

            <div className="pt-2 border-t border-line flex justify-center gap-2">
              <Button
                variant="secondary"
                size="sm"
                icon={Copy}
                onClick={() => handleCopyAccount('1000-2000-3001')}
              >
                {copied ? 'Copied' : 'Copy Number'}
              </Button>
              <Button
                variant="primary"
                size="sm"
                onClick={() => setQrModalOpen(false)}
              >
                Close
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          MODAL 5: CUSTOMER SECURITY NOTICE (GEOVELOCITY HOLD)
         ======================================================== */}
      {fraudAlertData && (
        <div 
          onClick={(e) => {
            if (e.target === e.currentTarget) setFraudAlertData(null);
          }}
          className="fixed inset-0 z-50 bg-black/80 backdrop-blur-xs flex items-center justify-center p-4 animate-in fade-in"
        >
          <div className="bg-surface border-2 border-amber-500 max-w-lg w-full p-6 shadow-2xl relative space-y-5">
            <div className="flex items-start gap-3.5">
              <div className="w-11 h-11 rounded-full bg-amber-500/15 border border-amber-500 flex items-center justify-center shrink-0">
                <ShieldAlert className="w-6 h-6 text-amber-500 animate-pulse" />
              </div>
              <div className="space-y-1">
                <h3 className="text-base font-bold text-fg font-sans">
                  Security Notice: Transaction Temporarily Held
                </h3>
                <p className="text-2xs text-fg-subtle">
                  AuraBank Account Safeguard &bull; Real-Time Fraud &amp; Identity Protection
                </p>
              </div>
            </div>

            <div className="p-4 bg-amber-500/10 border border-amber-500/25 space-y-3">
              <p className="text-xs text-fg leading-relaxed">
                We detected unusual activity from a new location. To protect your funds, this transfer was stopped and your account has been placed on a temporary security hold.
              </p>
              <p className="text-xs text-fg-muted leading-relaxed">
                If this was you, please verify your identity via Face/2FA or contact Customer Support.
              </p>
              <div className="pt-2 border-t border-amber-500/20 flex flex-wrap items-center justify-between gap-2 text-2xs text-fg-subtle">
                <span className="flex items-center gap-1.5 font-medium text-emerald-600 dark:text-emerald-400">
                  <CheckCircle2 className="w-3.5 h-3.5" />
                  ₱0.00 Deducted &bull; Funds Fully Protected
                </span>
                <span className="font-mono text-fg-subtle">
                  Time: {fraudAlertData.timestamp || 'Just now'}
                </span>
              </div>
            </div>

            <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => {
                  showToast?.({
                    type: 'info',
                    title: 'Customer Support Hotline',
                    detail: 'Priority 24/7 Security Assistance: 1-800-888-AURA (Domestic toll-free)',
                  });
                }}
                className="px-3.5 py-2 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg cursor-pointer transition-colors text-center"
              >
                Contact Support
              </button>
              <button
                type="button"
                onClick={() => {
                  showToast?.({
                    type: 'info',
                    title: 'Identity Verification Initiated',
                    detail: 'A secure 2FA identity challenge code has been dispatched to your registered contact channel.',
                  });
                  setFraudAlertData(null);
                }}
                className="px-4 py-2 text-xs font-semibold bg-accent text-fg-inverse hover:opacity-90 cursor-pointer transition-opacity text-center"
              >
                Verify Identity via 2FA
              </button>
              <button
                type="button"
                onClick={() => setFraudAlertData(null)}
                className="px-3 py-2 text-xs text-fg-subtle hover:text-fg cursor-pointer transition-colors text-center"
              >
                Dismiss
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
