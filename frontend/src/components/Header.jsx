import React from 'react';
import { 
  Building2, 
  ShieldCheck, 
  ExternalLink, 
  Radio, 
  Layers, 
  Activity,
  Mail,
  SlidersHorizontal,
  Server
} from 'lucide-react';
import { ROLES } from '../api/client';

export default function Header({ activeRole, setActiveRole, isLiveConnected }) {
  const currentRoleInfo = ROLES[activeRole];

  return (
    <header className="border-b border-slate-800 bg-slate-950/80 backdrop-blur sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        {/* Brand & Platform Identity */}
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-gradient-to-br from-indigo-500 to-indigo-700 rounded-xl shadow-lg shadow-indigo-500/20 text-white flex items-center justify-center">
            <Building2 className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="font-bold text-base sm:text-lg text-white tracking-tight">
                EastWest Retail Core Ledger
              </h1>
              <span className="hidden sm:inline-flex items-center px-2 py-0.5 rounded text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                v1.0.0 KRaft
              </span>
            </div>
            <p className="text-xs text-slate-400">
              High-Throughput Mutation Engine &bull; Dual-Write Audit &bull; Maker-Checker
            </p>
          </div>
        </div>

        {/* Center: Live Connection & Observability Links */}
        <div className="flex items-center gap-3">
          {/* SSE Stream Status Indicator */}
          <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-slate-900 border border-slate-800 text-xs">
            <span className={`w-2 h-2 rounded-full ${isLiveConnected ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'}`} />
            <span className="text-slate-300 font-medium text-[11px]">
              {isLiveConnected ? 'SSE Live Stream Active' : 'Connecting Stream...'}
            </span>
          </div>

          {/* Quick Links Menu */}
          <div className="hidden lg:flex items-center gap-2 text-xs">
            <a
              href="http://localhost:8025"
              target="_blank"
              rel="noreferrer"
              title="MailHog Mock Email Inbox"
              className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-900 border border-slate-800 text-slate-300 hover:text-white hover:border-slate-700 transition"
            >
              <Mail className="w-3.5 h-3.5 text-blue-400" />
              <span>MailHog :8025</span>
              <ExternalLink className="w-3 h-3 text-slate-500" />
            </a>

            <a
              href="http://localhost:3001"
              target="_blank"
              rel="noreferrer"
              title="Grafana Observability Dashboard"
              className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-900 border border-slate-800 text-slate-300 hover:text-white hover:border-slate-700 transition"
            >
              <Activity className="w-3.5 h-3.5 text-amber-400" />
              <span>Grafana :3001</span>
              <ExternalLink className="w-3 h-3 text-slate-500" />
            </a>

            <a
              href="http://localhost:8085"
              target="_blank"
              rel="noreferrer"
              title="Apache Kafka KRaft UI"
              className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-900 border border-slate-800 text-slate-300 hover:text-white hover:border-slate-700 transition"
            >
              <Layers className="w-3.5 h-3.5 text-emerald-400" />
              <span>Kafka UI :8085</span>
              <ExternalLink className="w-3 h-3 text-slate-500" />
            </a>
          </div>
        </div>

        {/* Role Switcher */}
        <div className="flex items-center p-1 bg-slate-900/90 border border-slate-800 rounded-xl">
          {Object.keys(ROLES).map((roleKey) => {
            const role = ROLES[roleKey];
            const isActive = activeRole === roleKey;
            return (
              <button
                key={roleKey}
                onClick={() => setActiveRole(roleKey)}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                  isActive
                    ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
                    : 'text-slate-400 hover:text-slate-200'
                }`}
              >
                {roleKey === 'TELLER' ? 'TELLER / CHECKER' : roleKey}
              </button>
            );
          })}
        </div>
      </div>
    </header>
  );
}
