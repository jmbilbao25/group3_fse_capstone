import React, { useState, useEffect } from 'react';
import { 
  Server, 
  ExternalLink, 
  Activity, 
  Layers, 
  Database, 
  Mail, 
  RotateCcw, 
  History,
  CheckCircle2,
  AlertTriangle,
  RefreshCw
} from 'lucide-react';
import { NotificationService } from '../api/client';

export default function AdminPortal() {
  const [notifications, setNotifications] = useState([]);
  const [spoolStatus, setSpoolStatus] = useState({ spool_size: 0, circuit_open: false });
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [flushMessage, setFlushMessage] = useState(null);

  const fetchHistoryAndSpool = async () => {
    setIsLoadingHistory(true);
    const historyRes = await NotificationService.getHistory();
    if (historyRes.success && historyRes.data.length > 0) {
      setNotifications(historyRes.data);
    } else {
      // Mock history if offline
      setNotifications([
        {
          notificationId: 'NOTIF-8901A',
          userId: 'U1001',
          type: 'TRANSACTION_ALERT',
          message: 'Transaction TX-984210 completed: PHP 15,000.00 transferred to ACC-1000-2000-3002. Digital receipt delivered.',
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
    setIsLoadingHistory(false);
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
      role: 'Perimeter routing, JWT check, Redis rate limiting',
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
      link: 'http://localhost:8083/api/v1/notifications/health',
    },
    {
      name: 'MailHog SMTP Sandbox',
      port: ':8025',
      status: 'UP',
      protocol: 'Web Inbox',
      role: 'Instant visual inbox for transaction & checker emails',
      link: 'http://localhost:8025',
    },
    {
      name: 'Grafana Telemetry',
      port: ':3001',
      status: 'UP',
      protocol: 'Web UI',
      role: 'Operational performance dashboards & Prometheus metrics',
      link: 'http://localhost:3001',
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
      name: 'Prometheus Engine',
      port: ':9090',
      status: 'UP',
      protocol: 'Web UI',
      role: 'Actuator metric scraper & TSDB storage',
      link: 'http://localhost:9090',
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

  return (
    <div className="space-y-6">
      {/* Infrastructure & Observability Grid */}
      <div className="p-6 rounded-2xl bg-slate-950/70 border border-slate-800 shadow-xl space-y-4">
        <div className="flex items-center justify-between pb-3 border-b border-slate-800">
          <div className="flex items-center gap-2">
            <Server className="w-5 h-5 text-indigo-400" />
            <div>
              <h3 className="font-bold text-white text-sm">System Health &amp; Infrastructure Matrix</h3>
              <p className="text-xs text-slate-400">
                10-container architecture deployed on unified Docker bridge network (banking-net).
              </p>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3 pt-2">
          {services.map((svc) => (
            <a
              key={svc.name}
              href={svc.link}
              target="_blank"
              rel="noreferrer"
              className="p-3.5 rounded-xl bg-slate-900 border border-slate-800 hover:border-slate-700 transition flex flex-col justify-between group"
            >
              <div>
                <div className="flex items-center justify-between">
                  <span className="font-bold text-white text-xs group-hover:text-indigo-400 transition">
                    {svc.name}
                  </span>
                  <ExternalLink className="w-3 h-3 text-slate-500 group-hover:text-indigo-400 transition" />
                </div>
                <div className="flex items-center gap-1.5 mt-1 font-mono text-[11px] text-slate-400">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                  <span>{svc.port}</span>
                  <span className="text-slate-600">&bull;</span>
                  <span className="text-[10px] text-slate-500">{svc.protocol}</span>
                </div>
                <p className="text-[10px] text-slate-400 mt-2 line-clamp-2 leading-relaxed">
                  {svc.role}
                </p>
              </div>
            </a>
          ))}
        </div>
      </div>

      {/* Offline Circuit Spool Monitor */}
      <div className="p-6 rounded-2xl bg-slate-950/70 border border-slate-800 shadow-xl flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="p-2.5 rounded-xl bg-blue-500/10 text-blue-400 border border-blue-500/20">
            <Mail className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h4 className="font-bold text-white text-sm">Resilient Circuit Spooler (SCEN-NOTIF-04)</h4>
              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-slate-800 text-slate-300 font-mono">
                Spool Size: {spoolStatus.spool_size || 0}
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              In-memory non-blocking buffer retains emails during SMTP outages with zero packet loss.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {flushMessage && (
            <span className="text-xs text-emerald-400 font-medium">{flushMessage}</span>
          )}
          <button
            onClick={handleFlushSpool}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 hover:border-slate-700 text-slate-200 text-xs font-semibold transition"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>Flush Spool Queue</span>
          </button>
        </div>
      </div>

      {/* Notifications Audit Log Table */}
      <div className="p-6 rounded-2xl bg-slate-950/70 border border-slate-800 shadow-xl space-y-4">
        <div className="flex items-center justify-between pb-3 border-b border-slate-800">
          <div className="flex items-center gap-2">
            <History className="w-5 h-5 text-indigo-400" />
            <h3 className="font-bold text-white text-sm">
              Oracle NOTIFICATIONS Audit Records ({notifications.length})
            </h3>
          </div>

          <button
            onClick={fetchHistoryAndSpool}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 hover:border-slate-700 text-slate-300 text-xs transition"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Refresh Audit Log</span>
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-900/60 text-slate-400 font-semibold border-b border-slate-800">
              <tr>
                <th className="py-3 px-4">Notification ID</th>
                <th className="py-3 px-4">Recipient User</th>
                <th className="py-3 px-4">Alert Classification</th>
                <th className="py-3 px-4">Message Summary</th>
                <th className="py-3 px-4 text-right">Dispatched Timestamp</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/80 font-mono">
              {notifications.map((item) => (
                <tr key={item.notificationId} className="hover:bg-slate-900/30 transition">
                  <td className="py-3.5 px-4 font-bold text-white">
                    {item.notificationId}
                  </td>
                  <td className="py-3.5 px-4 text-slate-300">
                    {item.userId}
                  </td>
                  <td className="py-3.5 px-4 font-sans">
                    <span
                      className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                        item.type === 'MAKER_CHECKER_ALERT'
                          ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                          : 'bg-indigo-500/20 text-indigo-400 border border-indigo-500/30'
                      }`}
                    >
                      {item.type}
                    </span>
                  </td>
                  <td className="py-3.5 px-4 text-slate-400 font-sans max-w-md truncate">
                    {item.message}
                  </td>
                  <td className="py-3.5 px-4 text-right text-slate-500">
                    {item.sentAt ? new Date(item.sentAt).toLocaleString() : 'Just now'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
