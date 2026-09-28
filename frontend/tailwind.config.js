/** @type {import('tailwindcss').Config} */

/*
 * AuraBank design system - token definitions.
 *
 * Two layers:
 *   1. Raw ramps (ink, cobalt, settled, held, voided) are the palette.
 *      Components never reference a raw ramp directly.
 *   2. Semantic tokens (surface, line, fg, accent...) resolve through CSS
 *      custom properties in src/index.css, so one root-level switch repaints
 *      the whole application. Components use these.
 *
 * Locks enforced here:
 *   - ONE accent (cobalt). Status ramps encode real ledger state only.
 *   - ONE radius scale, so a stray rounded-3xl collapses into the system.
 *   - ONE type scale, tuned for dense financial reading with tabular figures.
 */

const token = (name) => `rgb(var(--${name}) / <alpha-value>)`;

export default {
  darkMode: ['class', '[data-theme="dark"]'],
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        /* ---------------- raw ramps ---------------- */

        // Cool-neutral base. Deliberately not `slate`: no blue cast to fight
        // the accent, no warm cast that would read as "artisan".
        ink: {
          0: '#FFFFFF',
          50: '#F8F9FA',
          100: '#F1F2F4',
          200: '#E4E6EA',
          300: '#CDD1D7',
          400: '#9BA1AB',
          500: '#6F7680',
          600: '#545A63',
          700: '#3F444B',
          800: '#2A2E34',
          850: '#1F2227',
          900: '#1A1D21',
          950: '#101215',
        },

        // The single accent. Institutional cobalt: cobalt-600 is 6.4:1 on
        // white, so it carries white label text on a filled button at AA.
        cobalt: {
          50: '#EFF3FF',
          100: '#DEE6FE',
          200: '#C3D0FC',
          300: '#9DB1F8',
          400: '#7189F2',
          500: '#4F66E8',
          600: '#3A4CD6',
          700: '#2F3DB4',
          800: '#29348F',
          900: '#252F72',
          950: '#1A2050',
        },

        // Status ramps encode ledger state, not mood. Three states only,
        // matching the terminal states a balance mutation can hold.
        settled: {
          50: '#EBF7F0',
          100: '#D2EDDE',
          200: '#A6DCBE',
          400: '#3E9E6F',
          600: '#137547',
          700: '#0F5C38',
          900: '#0A3A24',
        },
        held: {
          50: '#FDF4E7',
          100: '#FAE7C6',
          200: '#F0CE93',
          400: '#C4881B',
          600: '#8A5D0C',
          700: '#6E4A09',
          900: '#432D06',
        },
        voided: {
          50: '#FDF0F1',
          100: '#FADCDF',
          200: '#F2B4BB',
          400: '#D64452',
          600: '#AF1F2C',
          700: '#8B1822',
          900: '#551015',
        },

        /* ---------------- semantic tokens ---------------- */

        // Backgrounds, in elevation order.
        canvas: token('canvas'),
        surface: token('surface'),
        raised: token('raised'),
        sunken: token('sunken'),

        // Hairlines. `line` is the workhorse, `line-strong` marks structure.
        line: {
          DEFAULT: token('line'),
          strong: token('line-strong'),
        },

        // Foreground ramp. Four steps is enough, more invites mush.
        fg: {
          DEFAULT: token('fg'),
          muted: token('fg-muted'),
          subtle: token('fg-subtle'),
          inverse: token('fg-inverse'),
        },

        accent: {
          DEFAULT: token('accent'),
          hover: token('accent-hover'),
          soft: token('accent-soft'),
          line: token('accent-line'),
          text: token('accent-text'),
        },
      },

      /* ---------------- shape lock ---------------- */
      // Four steps, crisp rather than pillowy. The oversized pillow radius is
      // the loudest tell in generated UI, so the large steps stay restrained.
      // `full` is reserved for genuinely circular things: avatars, dots.
      borderRadius: {
        none: '0',
        sm: '3px',
        DEFAULT: '5px',
        md: '5px',
        lg: '7px',
        xl: '9px',
        '2xl': '11px',
        '3xl': '11px',
        full: '9999px',
      },

      /* ---------------- type scale ---------------- */
      // Geist for the interface, Geist Mono for anything a reader compares
      // digit by digit. Nothing below 11px carries meaning.
      fontFamily: {
        sans: ['Geist Variable', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['Geist Mono Variable', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      fontSize: {
        '2xs': ['0.6875rem', { lineHeight: '1rem', letterSpacing: '0.03em' }],
        xs: ['0.75rem', { lineHeight: '1.125rem' }],
        sm: ['0.8125rem', { lineHeight: '1.25rem' }],
        base: ['0.875rem', { lineHeight: '1.375rem' }],
        md: ['0.9375rem', { lineHeight: '1.5rem' }],
        lg: ['1.0625rem', { lineHeight: '1.5rem', letterSpacing: '-0.01em' }],
        xl: ['1.25rem', { lineHeight: '1.75rem', letterSpacing: '-0.015em' }],
        '2xl': ['1.5rem', { lineHeight: '1.9375rem', letterSpacing: '-0.02em' }],
        '3xl': ['1.875rem', { lineHeight: '2.25rem', letterSpacing: '-0.022em' }],
        '4xl': ['2.375rem', { lineHeight: '2.625rem', letterSpacing: '-0.025em' }],
        '5xl': ['3rem', { lineHeight: '3.125rem', letterSpacing: '-0.03em' }],
      },

      /* ---------------- elevation ---------------- */
      // Shadows tint to the neutral ramp, never pure black, and stay shallow.
      // Structure comes from hairlines, not from drop shadows.
      boxShadow: {
        xs: '0 1px 2px 0 rgb(var(--shadow) / 0.04)',
        sm: '0 1px 2px 0 rgb(var(--shadow) / 0.05), 0 1px 1px -1px rgb(var(--shadow) / 0.04)',
        DEFAULT: '0 2px 4px -1px rgb(var(--shadow) / 0.06), 0 1px 2px -1px rgb(var(--shadow) / 0.04)',
        md: '0 4px 10px -2px rgb(var(--shadow) / 0.07), 0 2px 4px -2px rgb(var(--shadow) / 0.05)',
        lg: '0 12px 28px -6px rgb(var(--shadow) / 0.10), 0 4px 10px -4px rgb(var(--shadow) / 0.06)',
        xl: '0 24px 56px -12px rgb(var(--shadow) / 0.16), 0 8px 20px -8px rgb(var(--shadow) / 0.08)',
        inner: 'inset 0 1px 2px 0 rgb(var(--shadow) / 0.05)',
        none: 'none',
      },

      /* ---------------- motion ---------------- */
      // MOTION_INTENSITY 3: feedback and state transitions only. No ambient
      // loops, no scroll theatre. Every keyframe answers a user action or
      // announces that data arrived, and all of it collapses under
      // prefers-reduced-motion (see src/index.css).
      transitionTimingFunction: {
        DEFAULT: 'cubic-bezier(0.32, 0.72, 0, 1)',
        entrance: 'cubic-bezier(0.16, 1, 0.3, 1)',
      },
      keyframes: {
        'fade-in': { from: { opacity: '0' }, to: { opacity: '1' } },
        'fade-up': {
          from: { opacity: '0', transform: 'translateY(4px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
        'scale-in': {
          from: { opacity: '0', transform: 'scale(0.98) translateY(6px)' },
          to: { opacity: '1', transform: 'scale(1) translateY(0)' },
        },
        'slide-in-right': {
          from: { opacity: '0', transform: 'translateX(12px)' },
          to: { opacity: '1', transform: 'translateX(0)' },
        },
        // The only repeating animation in the system. It stops the moment
        // real data replaces the placeholder.
        shimmer: { '100%': { transform: 'translateX(100%)' } },
      },
      animation: {
        'fade-in': 'fade-in 160ms cubic-bezier(0.16, 1, 0.3, 1) both',
        'fade-up': 'fade-up 200ms cubic-bezier(0.16, 1, 0.3, 1) both',
        'scale-in': 'scale-in 180ms cubic-bezier(0.16, 1, 0.3, 1) both',
        'slide-in-right': 'slide-in-right 220ms cubic-bezier(0.16, 1, 0.3, 1) both',
        shimmer: 'shimmer 1.6s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
      maxWidth: {
        prose: '68ch',
        shell: '1440px',
      },
    },
  },
  plugins: [],
};
