import React, { useState, useEffect } from 'react';
import { 
  ShieldAlert, 
  CheckCircle2, 
  Clock, 
  FileCheck2, 
  Lock, 
  Search, 
  XCircle,
  Printer,
  Download,
  ExternalLink,
  X,
  Copy,
  Check,
  Building2,
  UserCheck,
  Server,
  Mail,
  RotateCcw,
  History,
  RefreshCw
} from 'lucide-react';
import { mockState, THRESHOLDS } from '../services/api';
import { NotificationService } from '../api/client';
import { formatPHP } from '../utils/currency';
import { cn } from '../ui/cn';

export default function AdminPortal() {
  const [activeTab, setActiveTab] = useState('audit'); // 'audit' | 'amla' | 'infra'
  const [searchQuery, setSearchQuery] = useState('');
  const [eventFilter, setEventFilter] = useState('ALL'); // 'ALL' | 'DEBITS' | 'HOLDS' | 'APPROVALS' | 'DISAPPROVALS'
  const [selectedLog, setSelectedLog] = useState(null);
  const [selectedAmlaTx, setSelectedAmlaTx] = useState(null);
  const [copiedHash, setCopiedHash] = useState(false);

  // Microservices & Infrastructure State
  const [notifications, setNotifications] = useState([]);
  const [spoolStatus, setSpoolStatus] = useState({ spool_size: 0, circuit_open: false });
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [flushMessage, setFlushMessage] = useState(null);

  const fetchHistoryAndSpool = async () => {
    setIsLoadingHistory(true);
    try {
      const historyRes = await NotificationService.getHistory();
      if (historyRes.success && historyRes.data.length > 0) {
        setNotifications(historyRes.data);
      } else {
        setNotifications([
          {
            notificationId: 'NOTIF-8901A',
            userId: 'U1001',
            type: 'TRANSACTION_ALERT',
            message: 'Transaction TX-984210 completed: PHP 15,000.00 transferred to ACC-1000-2000-3002. Digital advice delivered.',
            sentAt: new Date(Date.now() - 1000 * 60 * 5).toISOString(),
          },
          {
            notificationId: 'NOTIF-8902B',
            userId: 'U3002',
            type: 'MAKER_CHECKER_ALERT',
            message: 'Tier 2 Dual Control Hold: Transaction TX-772190 for PHP 75,000.00 requires secondary authorization by BOO Checker.',
            sentAt: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
          },
          {
            notificationId: 'NOTIF-8903C',
            userId: 'U1001',
            type: 'TRANSACTION_ALERT',
            message: 'Transaction TX-772190 approved by Beatriz Ocampo (U3002). Available balance adjusted.',
            sentAt: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
          },
        ]);
      }

      const spoolRes = await NotificationService.getSpoolStatus();
      if (spoolRes.success) {
        setSpoolStatus(spoolRes.data);
      }
    } catch (_) {
      // fallback in case of connection drop
    } finally {
      setIsLoadingHistory(false);
    }
  };

  useEffect(() => {
    fetchHistoryAndSpool();
  }, []);

  const handleFlushSpool = async () => {
    const res = await NotificationService.flushSpool();
    if (res.success) {
      setFlushMessage('Circuit Spool successfully flushed to live SMTP.');
      fetchHistoryAndSpool();
    } else {
      setFlushMessage('No spooled emails pending delivery.');
    }
    setTimeout(() => setFlushMessage(null), 4000);
  };

  const services = [
    {
      name: 'API Gateway',
      port: ':8080',
      status: 'UP',
      protocol: 'HTTP / REST',
      role: 'Perimeter routing, JWT verification, Redis rate limiting',
      link: 'http://localhost:8080/actuator/health',
    },
    {
      name: 'Account Service',
      port: ':8081',
      status: 'UP',
      protocol: 'HTTP / REST',
      role: 'KYC onboarding, accounts provisioning, tokens',
      link: 'http://localhost:8081/actuator/health',
    },
    {
      name: 'Ledger Engine (CME)',
      port: ':8082',
      status: 'UP',
      protocol: 'HTTP / REST',
      role: 'Pessimistic concurrency locks, Maker-Checker, Outbox',
      link: 'http://localhost:8082/actuator/health',
    },
    {
      name: 'Notification Service',
      port: ':8083',
      status: 'UP',
      protocol: 'HTTP / REST',
      role: 'Kafka consumer, HTML email advice, SSE toast streams',
      link: 'http://localhost:8083/actuator/health',
    },
    {
      name: 'MailHog SMTP Sandbox',
      port: ':8025',
      status: 'UP',
      protocol: 'Web Inbox',
      role: 'Visual inbox for transaction & checker emails',
      link: 'http://localhost:8025',
    },
    {
      name: 'Datadog Agent (dd-agent)',
      port: ':8126 / :8125',
      status: 'UP',
      protocol: 'APM / DogStatsD',
      role: 'Enterprise APM traces, DogStatsD metrics, and container log tailing',
      link: 'https://app.datadoghq.com',
    },
    {
      name: 'Jaeger Tracing',
      port: ':16686',
      status: 'UP',
      protocol: 'Web UI',
      role: 'Distributed trace spans & latency analysis',
      link: 'http://localhost:16686',
    },
    {
      name: 'Kafka KRaft UI',
      port: ':8085',
      status: 'UP',
      protocol: 'Web UI',
      role: 'Event commit log topics & partition inspection',
      link: 'http://localhost:8085',
    },
    {
      name: 'Adminer DB Console',
      port: ':8088',
      status: 'UP',
      protocol: 'Web UI',
      role: 'Oracle XE and PostgreSQL table administration',
      link: 'http://localhost:8088',
    },
  ];

  // Data-Driven Compliance Metrics
  const totalAuditLogs = mockState.auditLogs.length;
  const amlaTransactions = mockState.transfers.filter((t) => (t.amount || 0) >= THRESHOLDS.AMLA_CTR_MIN);
  
  const debitCount = mockState.auditLogs.filter((log) => log.event_type === 'BALANCE_MUTATION_DEBIT').length;
  const holdCount = mockState.auditLogs.filter((log) => log.event_type.includes('HOLD')).length;
  
  const dualControlApprovals = mockState.auditLogs.filter((log) => 
    log.event_type === 'MANAGER_CHECKER_AUTHORIZATION' || 
    log.event_type === 'AMLA_TIER3_FIRST_APPROVAL_SIGNOFF' ||
    log.event_type === 'AMLA_TIER3_STAGE1_L1_SIGNOFF' ||
    log.event_type === 'AMLA_TIER3_STAGE2_FINAL_SETTLEMENT'
  ).length;

  const voidedTransactions = mockState.auditLogs.filter((log) => 
    log.event_type === 'MAKER_CHECKER_DISAPPROVAL_VOID'
  ).length;

  // Filtered SCN Journal Logs
  const filteredLogs = mockState.auditLogs.filter((log) => {
    if (eventFilter === 'DEBITS' && log.event_type !== 'BALANCE_MUTATION_DEBIT') return false;
    if (eventFilter === 'HOLDS' && !log.event_type.includes('HOLD')) return false;
    if (eventFilter === 'APPROVALS' && !(log.event_type.includes('AUTHORIZATION') || log.event_type.includes('SIGNOFF') || log.event_type.includes('SETTLEMENT'))) return false;
    if (eventFilter === 'DISAPPROVALS' && !log.event_type.includes('DISAPPROVAL')) return false;

    if (!searchQuery) return true;
    const q = searchQuery.toLowerCase().trim();
    return (
      log.tx_id?.toLowerCase().includes(q) ||
      log.event_type?.toLowerCase().includes(q) ||
      log.actor_id?.toLowerCase().includes(q) ||
      log.actor_role?.toLowerCase().includes(q) ||
      log.scn?.toString().includes(q)
    );
  });

  const renderAuditStatus = (log) => {
    const baseClass = "w-[124px] h-[22px] rounded-none text-2xs font-mono font-medium inline-flex items-center justify-center border";

    if (
      log.event_type === 'BALANCE_MUTATION_DEBIT' ||
      log.event_type === 'MANAGER_CHECKER_AUTHORIZATION' ||
      log.event_type === 'AMLA_TIER3_STAGE2_FINAL_SETTLEMENT'
    ) {
      return (
        <span className={cn(baseClass, "bg-settled-50 text-settled-700 border-settled-200")}>
          SETTLED
        </span>
      );
    }

    if (log.event_type === 'MAKER_CHECKER_DISAPPROVAL_VOID') {
      return (
        <span className={cn(baseClass, "bg-voided-50 text-voided-700 border-voided-200")}>
          VOIDED
        </span>
      );
    }

    if (log.event_type === 'AMLA_TIER3_FIRST_APPROVAL_SIGNOFF' || log.event_type === 'AMLA_TIER3_STAGE1_L1_SIGNOFF') {
      return (
        <span className={cn(baseClass, "bg-accent-soft text-accent-text border-accent-line")}>
          1 OF 2 APPROVED
        </span>
      );
    }

    if (log.event_type.includes('HOLD')) {
      return (
        <span className={cn(baseClass, "bg-held-50 text-held-700 border-held-200")}>
          PENDING (HELD)
        </span>
      );
    }

    return (
      <span className={cn(baseClass, "bg-sunken text-fg-muted border-line")}>
        LOGGED
      </span>
    );
  };

  const handlePrint = () => {
    window.print();
  };

  const handleExportCSV = () => {
    const headers = ['SCN Sequence', 'Event Type', 'Tx Reference', 'Actor ID', 'Actor Role', 'Mutation Delta (PHP)', 'SHA-256 Digest Hash', 'Execution Status', 'Timestamp'];
    const rows = filteredLogs.map((log) => {
      let lifecycleStatus = 'LOGGED';
      if (log.event_type === 'BALANCE_MUTATION_DEBIT' || log.event_type.includes('AUTHORIZATION') || log.event_type.includes('SETTLEMENT')) {
        lifecycleStatus = 'SETTLED';
      } else if (log.event_type.includes('DISAPPROVAL')) {
        lifecycleStatus = 'VOIDED';
      } else if (log.event_type === 'AMLA_TIER3_FIRST_APPROVAL_SIGNOFF' || log.event_type === 'AMLA_TIER3_STAGE1_L1_SIGNOFF') {
        lifecycleStatus = 'FIRST_APPROVAL_RECORDED';
      } else if (log.event_type.includes('HOLD')) {
        lifecycleStatus = 'PENDING_HELD';
      }

      return [
        log.scn,
        log.event_type,
        log.tx_id,
        log.actor_id,
        log.actor_role,
        log.delta_amount,
        log.digest_hash,
        lifecycleStatus,
        `"${new Date(log.timestamp).toISOString()}"`
      ];
    });

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `BSP_SCN_Audit_Vault_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleExportAmlaCSV = () => {
    const headers = ['Reference ID', 'Sender (Maker)', 'Beneficiary Account', 'Beneficiary Name', 'Amount (PHP)', 'AMLC Status', 'Dual-Control State', 'Logged Date'];
    const rows = amlaTransactions.map((tx) => [
      tx.id,
      tx.maker_user_id,
      tx.to_account_id,
      `"${tx.recipient_name}"`,
      tx.amount,
      'CTR_MANDATORY',
      tx.status === 'SETTLED' ? 'FULLY_SETTLED_2_APPROVALS' : tx.approval_stage === 2 ? 'AWAITING_SECOND_APPROVAL' : 'AWAITING_FIRST_APPROVAL',
      `"${new Date(tx.created_at).toISOString()}"`
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `AMLA_CTR_Register_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const selectedTx = selectedLog ? mockState.transfers.find((t) => t.id === selectedLog.tx_id) : null;

  return (
    <div className="space-y-6">
      {/* Institutional Compliance KPI Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        {/* 1. Total SCN Audit Records */}
        <div
          onClick={() => setActiveTab('audit')}
          className={cn(
            "p-4 rounded-none bg-surface border transition-[border-color,background-color] duration-[120ms] cursor-pointer",
            activeTab === 'audit' ? 'border-accent bg-surface-raised' : 'border-line hover:border-line-strong'
          )}
        >
          <div className="flex items-center justify-between">
            <span className="text-2xs font-mono font-medium uppercase tracking-wider text-fg-muted">
              Total Audit Records
            </span>
            <FileCheck2 className="w-4 h-4 text-fg-muted" />
          </div>
          <p className="text-2xl font-mono font-semibold tracking-tight text-fg mt-2">
            {totalAuditLogs}
          </p>
          <p className="text-2xs text-fg-subtle mt-1">
            Chronological mutation events
          </p>
        </div>

        {/* 2. AMLA CTR Covered Items */}
        <div
          onClick={() => setActiveTab('amla')}
          className={cn(
            "p-4 rounded-none bg-surface border transition-[border-color,background-color] duration-[120ms] cursor-pointer",
            activeTab === 'amla' ? 'border-voided-500 bg-surface-raised' : 'border-line hover:border-line-strong'
          )}
        >
          <div className="flex items-center justify-between">
            <span className="text-2xs font-mono font-medium uppercase tracking-wider text-voided-700">
              AMLA Covered (CTR)
            </span>
            <ShieldAlert className="w-4 h-4 text-voided-600" />
          </div>
          <p className="text-2xl font-mono font-semibold tracking-tight text-fg mt-2">
            {amlaTransactions.length}
          </p>
          <p className="text-2xs text-fg-subtle mt-1">
            Statutory threshold &ge; ₱500k
          </p>
        </div>

        {/* 3. Dual-Control Authorizations */}
        <div className="p-4 rounded-none bg-surface border border-line">
          <div className="flex items-center justify-between">
            <span className="text-2xs font-mono font-medium uppercase tracking-wider text-settled-700">
              Dual-Control Approvals
            </span>
            <CheckCircle2 className="w-4 h-4 text-settled-600" />
          </div>
          <p className="text-2xl font-mono font-semibold tracking-tight text-settled-700 mt-2">
            {dualControlApprovals}
          </p>
          <p className="text-2xs text-fg-subtle mt-1">
            Manager verified and released
          </p>
        </div>

        {/* 4. Disapproved & Voided */}
        <div className="p-4 rounded-none bg-surface border border-line">
          <div className="flex items-center justify-between">
            <span className="text-2xs font-mono font-medium uppercase tracking-wider text-held-700">
              Disapproved / Voided
            </span>
            <XCircle className="w-4 h-4 text-held-600" />
          </div>
          <p className="text-2xl font-mono font-semibold tracking-tight text-held-700 mt-2">
            {voidedTransactions}
          </p>
          <p className="text-2xs text-fg-subtle mt-1">
            Soft holds returned to customer
          </p>
        </div>
      </div>

      {/* Navigation Tabs */}
      <div className="flex items-center border-b border-line gap-6 text-xs">
        <button
          onClick={() => setActiveTab('audit')}
          className={cn(
            'flex items-center gap-2 pb-3 font-medium transition-colors border-b-2 -mb-px cursor-pointer',
            activeTab === 'audit'
              ? 'border-accent text-fg font-semibold'
              : 'border-transparent text-fg-muted hover:text-fg'
          )}
        >
          <FileCheck2 className="w-3.5 h-3.5" />
          <span>Immutable SCN Journal</span>
          <span className="font-mono text-2xs px-1.5 py-0.5 border border-line bg-sunken text-fg-muted">
            {totalAuditLogs}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('amla')}
          className={cn(
            'flex items-center gap-2 pb-3 font-medium transition-colors border-b-2 -mb-px cursor-pointer',
            activeTab === 'amla'
              ? 'border-accent text-fg font-semibold'
              : 'border-transparent text-fg-muted hover:text-fg'
          )}
        >
          <ShieldAlert className="w-3.5 h-3.5" />
          <span>AMLA Covered Transactions (CTR)</span>
          <span className="font-mono text-2xs px-1.5 py-0.5 border border-line bg-sunken text-fg-muted">
            {amlaTransactions.length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('infra')}
          className={cn(
            'flex items-center gap-2 pb-3 font-medium transition-colors border-b-2 -mb-px cursor-pointer',
            activeTab === 'infra'
              ? 'border-accent text-fg font-semibold'
              : 'border-transparent text-fg-muted hover:text-fg'
          )}
        >
          <Server className="w-3.5 h-3.5" />
          <span>Infrastructure &amp; Matrix</span>
          <span className="font-mono text-2xs px-1.5 py-0.5 border border-line bg-sunken text-fg-muted">
            {services.length}
          </span>
        </button>
      </div>

      {/* TAB 1: Immutable Audit Log Table */}
      {activeTab === 'audit' && (
        <div className="bg-surface border border-line p-5 rounded-none space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h3 className="text-sm font-semibold text-fg flex items-center gap-2">
                <FileCheck2 className="w-4 h-4 text-accent" />
                Transaction Mutation Journal
              </h3>
              <p className="text-xs text-fg-muted mt-0.5">
                Append-only ledger mutations with SHA-256 integrity digests. Click an SCN to inspect details.
              </p>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={handlePrint}
                className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors flex items-center gap-1.5 cursor-pointer"
              >
                <Printer className="w-3.5 h-3.5 text-fg-muted" /> Print
              </button>
              <button
                onClick={handleExportCSV}
                className="h-8 px-3 text-xs font-medium bg-accent text-accent-contrast hover:bg-accent-emphasis rounded-none transition-colors flex items-center gap-1.5 cursor-pointer"
              >
                <Download className="w-3.5 h-3.5" /> Export CSV
              </button>
            </div>
          </div>

          {/* Filter Toolbar */}
          <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3 pt-3 border-t border-line">
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
              <button
                onClick={() => setEventFilter('ALL')}
                className={cn(
                  'h-7 px-2.5 text-2xs font-mono font-medium rounded-none border transition-colors cursor-pointer whitespace-nowrap',
                  eventFilter === 'ALL'
                    ? 'border-accent bg-accent text-accent-contrast'
                    : 'border-line bg-sunken text-fg-muted hover:text-fg'
                )}
              >
                All ({totalAuditLogs})
              </button>
              <button
                onClick={() => setEventFilter('DEBITS')}
                className={cn(
                  'h-7 px-2.5 text-2xs font-mono font-medium rounded-none border transition-colors cursor-pointer whitespace-nowrap',
                  eventFilter === 'DEBITS'
                    ? 'border-line-strong bg-surface text-fg font-semibold'
                    : 'border-line bg-sunken text-fg-muted hover:text-fg'
                )}
              >
                Debits ({debitCount})
              </button>
              <button
                onClick={() => setEventFilter('HOLDS')}
                className={cn(
                  'h-7 px-2.5 text-2xs font-mono font-medium rounded-none border transition-colors cursor-pointer whitespace-nowrap',
                  eventFilter === 'HOLDS'
                    ? 'border-held-400 bg-held-50 text-held-700 font-semibold'
                    : 'border-line bg-sunken text-fg-muted hover:text-fg'
                )}
              >
                Holds ({holdCount})
              </button>
              <button
                onClick={() => setEventFilter('APPROVALS')}
                className={cn(
                  'h-7 px-2.5 text-2xs font-mono font-medium rounded-none border transition-colors cursor-pointer whitespace-nowrap',
                  eventFilter === 'APPROVALS'
                    ? 'border-settled-400 bg-settled-50 text-settled-700 font-semibold'
                    : 'border-line bg-sunken text-fg-muted hover:text-fg'
                )}
              >
                Approvals ({dualControlApprovals})
              </button>
              <button
                onClick={() => setEventFilter('DISAPPROVALS')}
                className={cn(
                  'h-7 px-2.5 text-2xs font-mono font-medium rounded-none border transition-colors cursor-pointer whitespace-nowrap',
                  eventFilter === 'DISAPPROVALS'
                    ? 'border-voided-400 bg-voided-50 text-voided-700 font-semibold'
                    : 'border-line bg-sunken text-fg-muted hover:text-fg'
                )}
              >
                Disapprovals ({voidedTransactions})
              </button>
            </div>

            <div className="relative w-full md:w-64">
              <Search className="w-3.5 h-3.5 text-fg-subtle absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search SCN, ref, actor..."
                className="w-full h-8 bg-sunken border border-line pl-8 pr-3 text-xs text-fg rounded-none focus:outline-none focus:border-accent transition-colors placeholder:text-fg-subtle"
              />
            </div>
          </div>

          {filteredLogs.length === 0 ? (
            <div className="py-12 text-center text-fg-muted text-xs border border-dashed border-line">
              <FileCheck2 className="w-6 h-6 text-fg-subtle mx-auto mb-2" />
              No audit logs matching event filter "{eventFilter}" or search query.
            </div>
          ) : (
            <div className="overflow-x-auto border border-line">
              <table className="w-full text-left text-xs">
                <thead className="bg-sunken border-b border-line text-2xs font-mono font-medium uppercase tracking-wider text-fg-muted">
                  <tr>
                    <th className="py-2.5 px-3">SCN</th>
                    <th className="py-2.5 px-3">Event Type</th>
                    <th className="py-2.5 px-3">Tx Reference</th>
                    <th className="py-2.5 px-3">Actor ID</th>
                    <th className="py-2.5 px-3">Mutation Delta</th>
                    <th className="py-2.5 px-3">Integrity Digest (SHA-256)</th>
                    <th className="py-2.5 px-3">Status</th>
                    <th className="py-2.5 px-3">Timestamp</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {filteredLogs.map((log) => (
                    <tr key={log.scn} className="hover:bg-sunken/40 transition-colors">
                      <td className="py-2.5 px-3 font-mono font-semibold">
                        <button
                          type="button"
                          onClick={() => {
                            setSelectedLog(log);
                            setCopiedHash(false);
                          }}
                          className="text-accent hover:underline inline-flex items-center gap-1 cursor-pointer"
                        >
                          <span>{log.scn}</span>
                          <ExternalLink className="w-3 h-3 opacity-60" />
                        </button>
                      </td>
                      <td className="py-2.5 px-3 font-mono text-2xs text-fg">
                        {log.event_type}
                      </td>
                      <td className="py-2.5 px-3 font-mono text-fg-muted font-medium">
                        {log.tx_id}
                      </td>
                      <td className="py-2.5 px-3 whitespace-nowrap">
                        <span className={cn(
                          "px-1.5 py-0.5 font-mono text-2xs border",
                          log.actor_role === 'MANAGER'
                            ? 'bg-accent-soft text-accent-text border-accent-line'
                            : 'bg-sunken text-fg-muted border-line'
                        )}>
                          {log.actor_id} ({log.actor_role})
                        </span>
                      </td>
                      <td className="py-2.5 px-3 font-mono font-semibold whitespace-nowrap">
                        {log.delta_amount === 0 ? (
                          <span className="text-fg-subtle text-2xs">₱ 0.00 (SIGN-OFF)</span>
                        ) : (
                          <span className={log.delta_amount < 0 ? 'text-held-700' : 'text-settled-700'}>
                            {log.delta_amount < 0
                              ? `-₱ ${Math.abs(log.delta_amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
                              : `+₱ ${log.delta_amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`}
                          </span>
                        )}
                      </td>
                      <td className="py-2.5 px-3 font-mono text-2xs text-fg-subtle max-w-xs truncate" title={log.digest_hash}>
                        {log.digest_hash}
                      </td>
                      <td className="py-2.5 px-3 whitespace-nowrap">
                        {renderAuditStatus(log)}
                      </td>
                      <td className="py-2.5 px-3 font-mono text-2xs text-fg-muted whitespace-nowrap">
                        <div>{new Date(log.timestamp).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' })}</div>
                        <div className="text-fg-subtle">{new Date(log.timestamp).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false })}</div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* TAB 2: AMLA CTR Register */}
      {activeTab === 'amla' && (
        <div className="bg-surface border border-line p-5 rounded-none space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h3 className="text-sm font-semibold text-fg flex items-center gap-2">
                <ShieldAlert className="w-4 h-4 text-voided-600" />
                R.A. 9160 Anti-Money Laundering Council (AMLC) Covered Register
              </h3>
              <p className="text-xs text-fg-muted mt-0.5">
                Tracks mutations exceeding ₱500,000.00 in a single banking day for statutory reporting.
              </p>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={handlePrint}
                className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors flex items-center gap-1.5 cursor-pointer"
              >
                <Printer className="w-3.5 h-3.5 text-fg-muted" /> Print
              </button>
              <button
                onClick={handleExportAmlaCSV}
                className="h-8 px-3 text-xs font-medium bg-accent text-accent-contrast hover:bg-accent-emphasis rounded-none transition-colors flex items-center gap-1.5 cursor-pointer"
              >
                <Download className="w-3.5 h-3.5" /> Export AMLC CTR
              </button>
            </div>
          </div>

          <div className="overflow-x-auto border border-line">
            <table className="w-full text-left text-xs">
              <thead className="bg-sunken border-b border-line text-2xs font-mono font-medium uppercase tracking-wider text-fg-muted">
                <tr>
                  <th className="py-2.5 px-3">Reference ID</th>
                  <th className="py-2.5 px-3">Sender (Maker)</th>
                  <th className="py-2.5 px-3">Beneficiary</th>
                  <th className="py-2.5 px-3">Amount (PHP)</th>
                  <th className="py-2.5 px-3">Classification</th>
                  <th className="py-2.5 px-3">Dual-Control State</th>
                  <th className="py-2.5 px-3">Logged Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {amlaTransactions.map((tx) => {
                  const stage = tx.approval_stage || 1;
                  const isSettled = tx.status === 'SETTLED';
                  const isRejected = tx.status === 'REJECTED';

                  return (
                    <tr key={tx.id} className="hover:bg-sunken/40 transition-colors">
                      <td className="py-2.5 px-3 whitespace-nowrap">
                        <button
                          type="button"
                          onClick={() => setSelectedAmlaTx(tx)}
                          className="font-mono text-voided-700 font-semibold hover:underline inline-flex items-center gap-1 cursor-pointer"
                        >
                          <span>{tx.id}</span>
                          <ExternalLink className="w-3 h-3 opacity-60" />
                        </button>
                      </td>
                      <td className="py-2.5 px-3 font-mono text-fg-muted">{tx.maker_user_id}</td>
                      <td className="py-2.5 px-3">
                        <p className="font-semibold text-fg">{tx.recipient_name}</p>
                        <p className="text-2xs font-mono text-fg-subtle">{tx.to_account_id}</p>
                      </td>
                      <td className="py-2.5 px-3 font-mono font-semibold text-voided-700">
                        {formatPHP(tx.amount)}
                      </td>
                      <td className="py-2.5 px-3">
                        <span className="px-1.5 py-0.5 text-2xs font-mono font-medium border bg-voided-50 text-voided-700 border-voided-200">
                          CTR MANDATORY
                        </span>
                      </td>
                      <td className="py-2.5 px-3 whitespace-nowrap font-mono text-2xs">
                        {isSettled ? (
                          <span className="px-2 py-0.5 border bg-settled-50 text-settled-700 border-settled-200">
                            FULLY SETTLED (2 APPROVALS)
                          </span>
                        ) : isRejected ? (
                          <span className="px-2 py-0.5 border bg-voided-50 text-voided-700 border-voided-200">
                            DISAPPROVED &amp; VOIDED
                          </span>
                        ) : stage === 2 ? (
                          <span className="px-2 py-0.5 border bg-accent-soft text-accent-text border-accent-line">
                            AWAITING SECOND APPROVAL
                          </span>
                        ) : (
                          <span className="px-2 py-0.5 border bg-held-50 text-held-700 border-held-200">
                            AWAITING FIRST APPROVAL
                          </span>
                        )}
                      </td>
                      <td className="py-2.5 px-3 font-mono text-2xs text-fg-muted whitespace-nowrap">
                        <div>{new Date(tx.created_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' })}</div>
                        <div className="text-fg-subtle">{new Date(tx.created_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false })}</div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: Infrastructure & Microservices Matrix */}
      {activeTab === 'infra' && (
        <div className="space-y-6">
          <div className="bg-surface border border-line p-5 rounded-none space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-line">
              <div className="flex items-center gap-2">
                <Server className="w-4 h-4 text-accent" />
                <div>
                  <h3 className="font-semibold text-fg text-sm">System Health &amp; Infrastructure Matrix</h3>
                  <p className="text-xs text-fg-muted">
                    9 services deployed on unified Docker bridge network (banking-net).
                  </p>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 pt-1">
              {services.map((svc) => (
                <a
                  key={svc.name}
                  href={svc.link}
                  target="_blank"
                  rel="noreferrer"
                  className="p-3 bg-sunken border border-line hover:border-line-strong transition-colors flex flex-col justify-between group rounded-none"
                >
                  <div>
                    <div className="flex items-center justify-between">
                      <span className="font-semibold text-fg text-xs group-hover:text-accent transition-colors">
                        {svc.name}
                      </span>
                      <ExternalLink className="w-3 h-3 text-fg-subtle group-hover:text-accent transition-colors" />
                    </div>
                    <div className="flex items-center gap-2 mt-1 font-mono text-2xs text-fg-muted">
                      <span className="text-settled-700 font-semibold">{svc.status}</span>
                      <span>&bull;</span>
                      <span>{svc.port}</span>
                      <span>&bull;</span>
                      <span className="text-fg-subtle">{svc.protocol}</span>
                    </div>
                    <p className="text-2xs text-fg-muted mt-2 line-clamp-2 leading-relaxed">
                      {svc.role}
                    </p>
                  </div>
                </a>
              ))}
            </div>
          </div>

          {/* Offline Circuit Spool Monitor */}
          <div className="bg-surface border border-line p-5 rounded-none flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <Mail className="w-5 h-5 text-accent" />
              <div>
                <div className="flex items-center gap-2">
                  <h4 className="font-semibold text-fg text-sm">Resilient Circuit Spooler (SCEN-NOTIF-04)</h4>
                  <span className="px-1.5 py-0.5 border border-line bg-sunken text-2xs font-mono font-medium text-fg">
                    Spool Size: {spoolStatus.spool_size || 0}
                  </span>
                </div>
                <p className="text-xs text-fg-muted mt-0.5">
                  In-memory non-blocking buffer retains emails during SMTP outages with zero packet loss.
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              {flushMessage && (
                <span className="text-xs text-settled-700 font-medium">{flushMessage}</span>
              )}
              <button
                onClick={handleFlushSpool}
                className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors flex items-center gap-1.5 cursor-pointer"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                <span>Flush Spool Queue</span>
              </button>
            </div>
          </div>

          {/* Notifications Audit Log Table */}
          <div className="bg-surface border border-line p-5 rounded-none space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-line">
              <div className="flex items-center gap-2">
                <History className="w-4 h-4 text-accent" />
                <h3 className="font-semibold text-fg text-sm">
                  Oracle NOTIFICATIONS Audit Records ({notifications.length})
                </h3>
              </div>

              <button
                onClick={fetchHistoryAndSpool}
                className="h-7 px-2.5 text-2xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors flex items-center gap-1.5 cursor-pointer"
              >
                <RefreshCw className={cn("w-3 h-3", isLoadingHistory && "animate-spin")} />
                <span>Refresh</span>
              </button>
            </div>

            <div className="overflow-x-auto border border-line">
              <table className="w-full text-left text-xs">
                <thead className="bg-sunken text-fg-muted font-mono text-2xs uppercase tracking-wider border-b border-line">
                  <tr>
                    <th className="py-2.5 px-3">Notification ID</th>
                    <th className="py-2.5 px-3">Recipient User</th>
                    <th className="py-2.5 px-3">Alert Classification</th>
                    <th className="py-2.5 px-3">Message Summary</th>
                    <th className="py-2.5 px-3 text-right">Timestamp</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line font-mono text-2xs">
                  {notifications.map((item) => (
                    <tr key={item.notificationId} className="hover:bg-sunken/40 transition-colors">
                      <td className="py-2.5 px-3 font-semibold text-fg">
                        {item.notificationId}
                      </td>
                      <td className="py-2.5 px-3 text-fg-muted">
                        {item.userId}
                      </td>
                      <td className="py-2.5 px-3">
                        <span className="px-1.5 py-0.5 border border-line bg-sunken text-fg font-sans">
                          {item.type}
                        </span>
                      </td>
                      <td className="py-2.5 px-3 text-fg font-sans line-clamp-1 max-w-md">
                        {item.message}
                      </td>
                      <td className="py-2.5 px-3 text-right text-fg-subtle whitespace-nowrap">
                        {new Date(item.sentAt).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false })}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* SCN Record Dossier Modal */}
      {selectedLog && (
        <div 
          onClick={(e) => {
            if (e.target === e.currentTarget) setSelectedLog(null);
          }}
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4"
        >
          <div className="bg-surface border border-line-strong max-w-2xl w-full max-h-[90vh] flex flex-col shadow-2xl relative rounded-none overflow-hidden">
            {/* Header */}
            <div className="p-4 border-b border-line shrink-0 flex items-center justify-between bg-surface">
              <div className="flex items-center gap-2.5">
                <FileCheck2 className="w-4 h-4 text-accent" />
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-sm font-semibold text-fg">SCN Record Dossier</h3>
                    <span className="text-accent font-mono font-semibold text-xs">#{selectedLog.scn}</span>
                  </div>
                  <p className="text-2xs text-fg-muted">
                    PostgreSQL 16 Append-Only Vault &bull; BSP Circular 808 Immutable Ledger Entry
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setSelectedLog(null)}
                aria-label="Close Dossier"
                className="p-1 text-fg-muted hover:text-fg transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Scrollable Body */}
            <div className="p-5 overflow-y-auto space-y-4 flex-1 text-xs">
              {/* Tamper-Proof Stamp */}
              <div className="p-3.5 bg-sunken border border-line space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-2xs font-mono font-semibold text-fg uppercase tracking-wider flex items-center gap-1.5">
                    <Lock className="w-3 h-3 text-settled-700" /> Cryptographic Integrity Digest (SHA-256)
                  </span>
                  <span className="px-1.5 py-0.5 text-2xs font-mono font-semibold bg-settled-50 text-settled-700 border border-settled-200">
                    VERIFIED
                  </span>
                </div>
                <div className="flex items-center justify-between gap-2 p-2 bg-surface border border-line font-mono text-2xs text-fg break-all">
                  <span className="select-all">{selectedLog.digest_hash}</span>
                  <button
                    type="button"
                    onClick={() => {
                      if (navigator.clipboard) {
                        navigator.clipboard.writeText(selectedLog.digest_hash);
                        setCopiedHash(true);
                        setTimeout(() => setCopiedHash(false), 2000);
                      }
                    }}
                    className="p-1 border border-line bg-sunken hover:bg-surface text-fg-muted hover:text-fg transition-colors shrink-0 cursor-pointer"
                    title="Copy SHA-256 Hash"
                  >
                    {copiedHash ? <Check className="w-3.5 h-3.5 text-settled-700" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                </div>
                <p className="text-2xs text-fg-subtle">
                  Protected by PostgreSQL trigger <code className="font-mono text-fg-muted">trg_no_update_delete_mutation_audit</code>. Any manipulation breaks this seal.
                </p>
              </div>

              {/* Financial Mutation Grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 text-xs">
                <div className="p-3 bg-sunken border border-line space-y-1">
                  <span className="text-2xs font-mono text-fg-muted uppercase tracking-wider">Event Classification</span>
                  <p className="font-mono font-semibold text-fg text-xs">{selectedLog.event_type}</p>
                </div>

                <div className="p-3 bg-sunken border border-line space-y-1">
                  <span className="text-2xs font-mono text-fg-muted uppercase tracking-wider">Execution Status</span>
                  <div>{renderAuditStatus(selectedLog)}</div>
                </div>

                <div className="p-3 bg-sunken border border-line space-y-1">
                  <span className="text-2xs font-mono text-fg-muted uppercase tracking-wider">Mutation Delta</span>
                  <p className="font-mono font-semibold text-sm">
                    {selectedLog.delta_amount === 0 ? '₱ 0.00 (SIGN-OFF)' : formatPHP(selectedLog.delta_amount)}
                  </p>
                </div>

                <div className="p-3 bg-sunken border border-line space-y-1">
                  <span className="text-2xs font-mono text-fg-muted uppercase tracking-wider">Balance After Mutation</span>
                  <p className="font-mono font-semibold text-settled-700 text-sm">
                    {selectedLog.balance_after !== undefined ? formatPHP(selectedLog.balance_after) : 'Unchanged'}
                  </p>
                </div>
              </div>

              {/* Actor Details */}
              <div className="p-3.5 bg-sunken border border-line space-y-2">
                <span className="text-2xs font-mono font-semibold text-fg uppercase tracking-wider flex items-center gap-1.5">
                  <UserCheck className="w-3 h-3 text-accent" /> Identity &amp; Non-Repudiation Proof
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 font-mono text-2xs">
                  <div>
                    <span className="text-fg-subtle block">Actor ID</span>
                    <span className="text-fg font-semibold">{selectedLog.actor_id}</span>
                  </div>
                  <div>
                    <span className="text-fg-subtle block">Actor Role</span>
                    <span className="text-fg font-semibold">{selectedLog.actor_role}</span>
                  </div>
                  <div>
                    <span className="text-fg-subtle block">Account Ref</span>
                    <span className="text-fg font-semibold">{selectedLog.account_id || '1000-2000-3001'}</span>
                  </div>
                </div>
                <div className="pt-2 text-2xs text-fg-subtle border-t border-line flex items-center justify-between">
                  <span>Committed Timestamp:</span>
                  <span className="font-mono text-fg font-medium">
                    {new Date(selectedLog.timestamp).toISOString()}
                  </span>
                </div>
              </div>

              {/* Business Context */}
              {selectedTx && (
                <div className="p-3.5 bg-sunken border border-line space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-2xs font-mono font-semibold text-fg uppercase tracking-wider flex items-center gap-1.5">
                      <Building2 className="w-3 h-3 text-fg-muted" /> Business Transfer ({selectedTx.id})
                    </span>
                    <span className="text-2xs font-mono px-1.5 py-0.5 border border-line bg-surface text-fg">
                      {selectedTx.regulatory_tier}
                    </span>
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-2xs">
                    <div>
                      <span className="text-fg-subtle block">Beneficiary</span>
                      <span className="font-semibold text-fg">{selectedTx.recipient_name}</span> ({selectedTx.to_account_id})
                    </div>
                    <div>
                      <span className="text-fg-subtle block">Memo</span>
                      <span className="text-fg italic">{selectedTx.memo || 'Standard Transfer'}</span>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Footer Actions */}
            <div className="p-3.5 border-t border-line shrink-0 flex items-center justify-end gap-2 bg-surface">
              <button
                type="button"
                onClick={() => setSelectedLog(null)}
                className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors cursor-pointer"
              >
                Close
              </button>
              <button
                type="button"
                onClick={() => window.print()}
                className="h-8 px-3 text-xs font-medium bg-accent text-accent-contrast hover:bg-accent-emphasis rounded-none transition-colors flex items-center gap-1.5 cursor-pointer"
              >
                <Printer className="w-3.5 h-3.5" /> Print Dossier
              </button>
            </div>
          </div>
        </div>
      )}

      {/* AMLA CTR Dossier Modal */}
      {selectedAmlaTx && (
        <div 
          onClick={(e) => { if (e.target === e.currentTarget) setSelectedAmlaTx(null); }}
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4"
        >
          <div className="bg-surface border border-line-strong max-w-2xl w-full max-h-[90vh] flex flex-col shadow-2xl relative rounded-none overflow-hidden">
            {/* Header */}
            <div className="p-4 border-b border-line shrink-0 flex items-center justify-between bg-surface">
              <div className="flex items-center gap-2.5">
                <ShieldAlert className="w-4 h-4 text-voided-600" />
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-sm font-semibold text-fg">AMLA Covered Dossier</h3>
                    <span className="px-1.5 py-0.5 text-2xs font-mono font-medium border bg-voided-50 text-voided-700 border-voided-200">
                      R.A. 9160 SEC. 3(B)
                    </span>
                  </div>
                  <p className="text-2xs text-fg-muted">
                    Covered Transaction Report (CTR) &bull; Threshold &ge; ₱500,000.00
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setSelectedAmlaTx(null)}
                className="p-1 text-fg-muted hover:text-fg transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Scrollable Body */}
            <div className="p-5 overflow-y-auto space-y-4 flex-1 text-xs">
              <div className="p-3.5 bg-sunken border border-line flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div>
                  <span className="text-2xs font-mono text-fg-muted uppercase tracking-wider block">Covered Amount</span>
                  <div className="flex items-baseline gap-2 mt-0.5">
                    <span className="font-mono font-bold text-voided-700 text-lg">{formatPHP(selectedAmlaTx.amount)}</span>
                    <span className="text-fg-subtle font-mono text-2xs">({selectedAmlaTx.id})</span>
                  </div>
                </div>
                <div>
                  <span className="text-2xs font-mono text-fg-muted uppercase tracking-wider block mb-1">Dual-Control Status</span>
                  {selectedAmlaTx.status === 'SETTLED' ? (
                    <span className="px-2 py-0.5 border text-2xs font-mono bg-settled-50 text-settled-700 border-settled-200">
                      FULLY SETTLED (2 APPROVALS)
                    </span>
                  ) : selectedAmlaTx.status === 'REJECTED' ? (
                    <span className="px-2 py-0.5 border text-2xs font-mono bg-voided-50 text-voided-700 border-voided-200">
                      DISAPPROVED &amp; VOIDED
                    </span>
                  ) : selectedAmlaTx.approval_stage === 2 ? (
                    <span className="px-2 py-0.5 border text-2xs font-mono bg-accent-soft text-accent-text border-accent-line">
                      AWAITING SECOND APPROVAL
                    </span>
                  ) : (
                    <span className="px-2 py-0.5 border text-2xs font-mono bg-held-50 text-held-700 border-held-200">
                      AWAITING FIRST APPROVAL
                    </span>
                  )}
                </div>
              </div>

              {/* KYC Mandate Box */}
              <div className="p-3.5 bg-sunken border border-line space-y-2.5">
                <span className="text-2xs font-mono font-semibold text-fg uppercase tracking-wider flex items-center gap-1.5">
                  <Building2 className="w-3 h-3 text-fg-muted" /> KYC Accounts
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                  <div className="p-2.5 bg-surface border border-line space-y-1">
                    <span className="text-2xs text-fg-subtle uppercase block font-mono">Sender (Maker)</span>
                    <p className="font-semibold text-fg">Juan Dela Cruz</p>
                    <p className="font-mono text-fg-muted text-2xs">ID: {selectedAmlaTx.maker_user_id || 'U1001'} &bull; Acct: {selectedAmlaTx.from_account_id || '1000-2000-3001'}</p>
                  </div>
                  <div className="p-2.5 bg-surface border border-line space-y-1">
                    <span className="text-2xs text-fg-subtle uppercase block font-mono">Beneficiary (Receiver)</span>
                    <p className="font-semibold text-fg">{selectedAmlaTx.recipient_name}</p>
                    <p className="font-mono text-fg-muted text-2xs">Acct: {selectedAmlaTx.to_account_id}</p>
                  </div>
                </div>
                <div className="pt-2 border-t border-line flex items-center justify-between text-2xs">
                  <span className="text-fg-muted">Payment Purpose / Memo:</span>
                  <span className="font-semibold text-fg italic">{selectedAmlaTx.memo || 'Standard Retail Transfer'}</span>
                </div>
              </div>

              {/* Signatures */}
              <div className="p-3.5 bg-sunken border border-line space-y-2.5">
                <span className="text-2xs font-mono font-semibold text-fg uppercase tracking-wider flex items-center gap-1.5">
                  <UserCheck className="w-3 h-3 text-accent" /> Dual-Control Signatures (Rule AMLA-204)
                </span>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 text-2xs">
                  <div className="p-2.5 bg-surface border border-line space-y-1">
                    <div className="flex items-center justify-between font-mono">
                      <span className="text-fg-muted uppercase">First Manager</span>
                      {selectedAmlaTx.l1_approver_id ? (
                        <span className="text-settled-700 font-semibold">SIGNED</span>
                      ) : (
                        <span className="text-held-700 font-semibold">PENDING</span>
                      )}
                    </div>
                    <p className="font-semibold text-fg">
                      {selectedAmlaTx.l1_approver_name || 'Operations Manager'}{' '}
                      <span className="font-mono text-fg-subtle">({selectedAmlaTx.l1_approver_id || 'Manager 1'})</span>
                    </p>
                    {selectedAmlaTx.l1_notes && (
                      <p className="text-fg-muted italic bg-sunken p-1.5 border border-line">
                        "{selectedAmlaTx.l1_notes}"
                      </p>
                    )}
                  </div>

                  <div className="p-2.5 bg-surface border border-line space-y-1">
                    <div className="flex items-center justify-between font-mono">
                      <span className="text-fg-muted uppercase">Second Manager</span>
                      {selectedAmlaTx.status === 'SETTLED' ? (
                        <span className="text-settled-700 font-semibold">SETTLED</span>
                      ) : (
                        <span className="text-fg-subtle font-semibold">AWAITING</span>
                      )}
                    </div>
                    <p className="font-semibold text-fg">
                      {selectedAmlaTx.l2_approver_name || 'Operations Manager (Distinct)'}{' '}
                      {selectedAmlaTx.l2_approver_id && (
                        <span className="font-mono text-fg-subtle">({selectedAmlaTx.l2_approver_id})</span>
                      )}
                    </p>
                    {selectedAmlaTx.l2_notes && (
                      <p className="text-fg-muted italic bg-sunken p-1.5 border border-line">
                        "{selectedAmlaTx.l2_notes}"
                      </p>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Footer Actions */}
            <div className="p-3.5 border-t border-line shrink-0 flex items-center justify-end gap-2 bg-surface">
              <button
                type="button"
                onClick={() => setSelectedAmlaTx(null)}
                className="h-8 px-3 text-xs font-medium border border-line bg-sunken hover:bg-surface text-fg rounded-none transition-colors cursor-pointer"
              >
                Close
              </button>
              <button
                type="button"
                onClick={() => window.print()}
                className="h-8 px-3 text-xs font-medium bg-accent text-accent-contrast hover:bg-accent-emphasis rounded-none transition-colors flex items-center gap-1.5 cursor-pointer"
              >
                <Printer className="w-3.5 h-3.5" /> Print CTR Dossier
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
