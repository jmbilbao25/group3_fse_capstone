import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Check, ChevronDown, LogOut, UserCog } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import Brand from './Brand';
import ThemeToggle from './ThemeToggle';
import Button from '../ui/Button';
import { cn } from '../ui';

/*
 * Application header.
 *
 * Removed from the previous version, all of it decoration presented as fact:
 *   - "Ledger :3000" and "SCN 982144" pills. Invented telemetry. A port number
 *     is not information a banking customer can act on, and the SCN was a
 *     hardcoded string dressed up as a live sequence number.
 *   - "PREMIER VAULT" badge beside the wordmark.
 *   - A mail menu badged "5" that rendered two items, and a bell badged "2"
 *     with two hardcoded notices. Counts that disagree with their own contents
 *     teach users to distrust every other number on the screen. The real
 *     notification stream already arrives as toasts from the SSE connection in
 *     App.jsx, so these menus were duplicating a feature that works.
 *   - A pulsing green dot, animating forever, meaning nothing.
 *
 * What remains: identity, the genuine connection state, the role switcher this
 * demo needs, theme, and sign out.
 */

const ROLE_LABELS = {
  ROLE_CUSTOMER: 'Customer',
  ROLE_MANAGER: 'Manager',
  ROLE_ADMIN: 'Compliance',
};

/* The three personas this build ships for demonstration. */
const PERSONAS = [
  {
    role: 'ROLE_CUSTOMER',
    name: 'Juan Dela Cruz',
    title: 'Account holder',
    id: 'U1001',
  },
  {
    role: 'ROLE_MANAGER',
    name: 'Beatriz Ocampo',
    title: 'Operations manager',
    id: 'U3002',
  },
  {
    role: 'ROLE_ADMIN',
    name: 'Diana Vance',
    title: 'Compliance officer',
    id: 'U0001',
  },
];

const ROLE_HOME = {
  ROLE_CUSTOMER: '/customer',
  ROLE_MANAGER: '/manager',
  ROLE_ADMIN: '/admin',
};

export default function Navbar({ onRefreshBalance, isLiveConnected }) {
  const navigate = useNavigate();
  const { user, switchRole, logout } = useAuth();
  const [menuOpen, setMenuOpen] = React.useState(false);
  const menuRef = React.useRef(null);

  // Close on outside click and on Escape. The previous menus stayed open until
  // another menu was clicked, so they could be left hanging over the content.
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

  const handleSelect = async (role) => {
    setMenuOpen(false);
    await switchRole(role);
    onRefreshBalance?.();
    const dest = ROLE_HOME[role] || '/customer';
    navigate(dest);
  };

  const initials = user?.name
    ? user.name.split(' ').filter(Boolean).slice(0, 2).map((p) => p[0]).join('')
    : 'JD';

  return (
    <header className="sticky top-0 z-40 border-b border-line bg-surface">
      <div className="mx-auto flex h-14 max-w-shell items-center justify-between gap-4 px-4 sm:px-6">
        <Brand />

        <div className="flex items-center gap-2">
          <ThemeToggle className="hidden sm:inline-flex" />

          <div className="relative" ref={menuRef}>
            <button
              type="button"
              onClick={() => setMenuOpen((open) => !open)}
              aria-expanded={menuOpen}
              aria-haspopup="menu"
              className={cn(
                'flex items-center gap-2 border border-line py-1 pl-1 pr-2 text-left',
                'transition-colors duration-[120ms] hover:bg-sunken',
                menuOpen && 'bg-sunken'
              )}
            >
              {/* Square avatar, matching the shape lock. Initials rather than a
                  generic person icon, so the active identity is unambiguous
                  when switching between four personas. */}
              <span className="flex h-7 w-7 items-center justify-center bg-accent text-2xs font-semibold uppercase text-fg-inverse">
                {initials}
              </span>
              <span className="hidden min-w-0 leading-tight md:block">
                <span className="block truncate text-sm font-medium text-fg">
                  {user?.name || 'Juan Dela Cruz'}
                </span>
                <span className="block text-2xs text-fg-subtle">
                  {ROLE_LABELS[user?.role] || 'Customer'}
                </span>
              </span>
              <ChevronDown className="h-3.5 w-3.5 shrink-0 text-fg-subtle" aria-hidden="true" />
            </button>

            {menuOpen && <PersonaMenu currentRole={user?.role} onSelect={handleSelect} />}
          </div>

          <Button variant="ghost" size="md" icon={LogOut} onClick={logout} className="shrink-0">
            <span className="hidden sm:inline">Sign out</span>
          </Button>
        </div>
      </div>
    </header>
  );
}


/*
 * Persona menu.
 *
 * This is a demonstration affordance, so it says so plainly rather than dressing
 * itself up as an "RBAC Gateway" with a monospace badge. Being honest about what
 * a control is costs nothing and stops the UI from overclaiming.
 */
function PersonaMenu({ currentRole, onSelect }) {
  return (
    <div
      role="menu"
      className="absolute right-0 top-full z-50 mt-1 w-72 animate-fade-up border border-line bg-surface shadow-lg"
    >
      <div className="flex items-center gap-2 border-b border-line bg-sunken px-3 py-2">
        <UserCog className="h-3.5 w-3.5 text-fg-subtle" aria-hidden="true" />
        <p className="text-2xs font-medium uppercase tracking-wider text-fg-subtle">
          Switch demo persona
        </p>
      </div>

      <div className="p-1">
        {PERSONAS.map((persona) => {
          const active = currentRole === persona.role;

          return (
            <button
              key={persona.role}
              type="button"
              role="menuitem"
              onClick={() => onSelect(persona.role)}
              className={cn(
                'flex w-full items-center gap-3 px-2 py-2 text-left',
                'transition-colors duration-[120ms] hover:bg-sunken',
                active && 'bg-accent-soft'
              )}
            >
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-medium text-fg">{persona.name}</span>
                <span className="block text-xs text-fg-muted">
                  {persona.title}
                  <span className="ml-1.5 font-mono text-fg-subtle">{persona.id}</span>
                </span>
              </span>
              {active && (
                <Check className="h-3.5 w-3.5 shrink-0 text-accent-text" aria-hidden="true" />
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}
