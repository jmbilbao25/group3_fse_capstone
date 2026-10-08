import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Check, ChevronDown, LogOut, Users } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import Brand from './Brand';
import ThemeToggle from './ThemeToggle';
import Button from '../ui/Button';
import { cn } from '../ui';

const ADMIN_PERSONAS = [
  {
    role: 'ROLE_ADMIN',
    email: 'alex.rivera@bank.com',
    name: 'Alex Rivera',
    title: 'Fraud Ops Analyst',
    id: 'usr-1007-sec-003',
  },
  {
    role: 'ROLE_ADMIN',
    email: 'carlos.mendoza@bank.com',
    name: 'Carlos Mendoza',
    title: 'Branch Operations Officer',
    id: 'usr-1006-mgr-002',
  },
  {
    role: 'ROLE_ADMIN',
    email: 'diana.admin@bank.com',
    name: 'Diana Vance',
    title: 'Compliance Lead (Checker)',
    id: 'usr-1004-adm-001',
  },
];

export default function Navbar() {
  const navigate = useNavigate();
  const { user, login, logout } = useAuth();
  const [menuOpen, setMenuOpen] = React.useState(false);
  const menuRef = React.useRef(null);

  React.useEffect(() => {
    if (!menuOpen) return;

    const onPointerDown = (event) => {
      if (!menuRef.current?.contains(event.target)) setMenuOpen(false);
    };
    const onKeyDown = (event) => {
      if (event.key === 'Escape') setMenuOpen(false);
    };

    document.addEventListener('mousedown', onPointerDown);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('mousedown', onPointerDown);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [menuOpen]);

  const handleSelectAdmin = async (persona) => {
    setMenuOpen(false);
    await login(persona.email, 'password123');
    navigate('/admin');
  };

  const initials = user?.name
    ? user.name.split(' ').filter(Boolean).slice(0, 2).map((p) => p[0]).join('')
    : 'CM';

  return (
    <header className="sticky top-0 z-40 border-b border-line bg-surface/80 backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-shell items-center justify-between gap-4 px-6 lg:px-10">
        <div className="flex items-center gap-3">
          <Brand />
          <span className="hidden sm:inline-block rounded-md bg-sunken border border-line px-2 py-0.5 text-[11px] font-medium text-fg-muted">
            Operations
          </span>
        </div>

        <div className="flex items-center gap-3">
          <ThemeToggle className="hidden sm:inline-flex" />

          {/* Active Admin Persona Dropdown */}
          <div className="relative" ref={menuRef}>
            <button
              type="button"
              onClick={() => setMenuOpen((open) => !open)}
              aria-expanded={menuOpen}
              className={cn(
                'flex items-center gap-2.5 rounded-xl border border-line py-1.5 pl-2 pr-3 text-left bg-surface',
                'transition hover:bg-sunken hover:border-line-strong',
                menuOpen && 'bg-sunken'
              )}
            >
              <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-accent text-xs font-semibold text-fg-inverse shadow-xs">
                {initials}
              </span>
              <span className="hidden min-w-0 leading-tight md:block">
                <span className="block truncate text-xs font-semibold text-fg">
                  {user?.name || 'Alex Rivera'}
                </span>
                <span className="block text-[10px] text-fg-subtle">
                  {user?.title || 'Fraud Ops Analyst'}
                </span>
              </span>
              <ChevronDown className="h-3.5 w-3.5 shrink-0 text-fg-subtle" aria-hidden="true" />
            </button>

            {menuOpen && (
              <div
                role="menu"
                className="absolute right-0 top-full z-50 mt-2 w-72 rounded-2xl border border-line bg-surface shadow-xl p-1.5 animate-in fade-in"
              >
                <div className="flex items-center gap-2 border-b border-line px-3 py-2 text-fg-subtle">
                  <Users className="h-3.5 w-3.5" aria-hidden="true" />
                  <p className="text-[10px] font-bold uppercase tracking-wider">
                    Switch Active Operator
                  </p>
                </div>

                <div className="p-1 space-y-1">
                  {ADMIN_PERSONAS.map((admin) => {
                    const active = user?.email === admin.email;

                    return (
                      <button
                        key={admin.email}
                        type="button"
                        role="menuitem"
                        onClick={() => handleSelectAdmin(admin)}
                        className={cn(
                          'flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-left transition',
                          'hover:bg-sunken',
                          active && 'bg-accent/10 border border-accent/30'
                        )}
                      >
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-xs font-bold text-fg">{admin.name}</span>
                          <span className="block text-[11px] text-fg-muted mt-0.5">
                            {admin.title}
                          </span>
                        </span>
                        {active && (
                          <Check className="h-4 w-4 shrink-0 text-accent" aria-hidden="true" />
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          </div>

          <Button variant="ghost" size="md" icon={LogOut} onClick={logout} className="shrink-0 rounded-xl">
            <span className="hidden sm:inline text-xs">Sign out</span>
          </Button>
        </div>
      </div>
    </header>
  );
}
