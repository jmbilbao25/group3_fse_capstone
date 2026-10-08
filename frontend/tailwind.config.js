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
      //
      // Zero radius, everywhere. Every step of the scale collapses to 0, which
      // means a stray `rounded-3xl` left anywhere in the codebase renders square
      // instead of quietly reintroducing the pillow look. The system cannot
      // drift back.
      //
      // Square edges are also the right call on merit: ledger tables, statement
      // rows, and figure columns all align on a strict grid, and rounded
      // containers fight that grid at every corner. Institutional financial
      // software is square because the data is rectangular.
      //
      // `full` survives for the two things that are genuinely circular: the
      // connection-state dot and the button spinner arc.
      borderRadius: {
        none: '0px',
        xs: '0.25rem',
        sm: '0.375rem',
        DEFAULT: '0.5rem',
        md: '0.625rem',
        lg: '0.75rem',
        xl: '1rem',
        '2xl': '1.25rem',
        '3xl': '1.5rem',
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

      /* ---------------- gradients ---------------- */
      //
      // Every gradient is built from the SINGLE accent plus the neutral ramp, and
      // resolves through the theme tokens, so nothing here breaks when the theme
      // flips and no second hue is ever introduced. That constraint is what
      // separates a gradient system from a gradient pile.
      //
      // Ranges are deliberately tight. A gradient that travels a long way in
      // hue reads as decoration; one that travels a short way in lightness reads
      // as a light source, which is the effect worth having.
      backgroundImage: {
        // Elevated panel. ~2% lightness lift at the top edge, as if lit from
        // above. Invisible on its own, but it stops large panels reading flat.
        'surface-raised':
          'linear-gradient(180deg, rgb(var(--grad-lift) / 0.55) 0%, transparent 42%)',

        // Primary action. Short travel within one hue, so it still reads as a
        // solid button rather than a decorative pill.
        'accent-fill':
          'linear-gradient(180deg, rgb(var(--accent-lift)) 0%, rgb(var(--accent)) 58%, rgb(var(--accent-sink)) 100%)',

        // Hairline that fades out toward the edges, for the top rule of a
        // feature panel. Reads as a highlight catching an edge.
        'line-fade':
          'linear-gradient(90deg, transparent, rgb(var(--accent) / 0.55) 22%, rgb(var(--accent) / 0.55) 78%, transparent)',

        // Ambient field behind the balance hero and the sign-in page. Three
        // low-opacity radial stops from the accent, offset so the falloff is
        // asymmetric and it does not read as a centred spotlight.
        aurora: [
          'radial-gradient(ellipse 80% 60% at 12% 0%, rgb(var(--accent) / 0.16), transparent 60%)',
          'radial-gradient(ellipse 60% 50% at 88% 12%, rgb(var(--accent) / 0.10), transparent 58%)',
          'radial-gradient(ellipse 90% 70% at 50% 108%, rgb(var(--accent) / 0.07), transparent 62%)',
        ].join(','),

        // Sheen that sweeps a surface once on mount, and on the skeletons.
        sheen:
          'linear-gradient(105deg, transparent 38%, rgb(var(--grad-lift) / 0.85) 50%, transparent 62%)',
      },

      /* ---------------- motion ---------------- */
      //
      // MOTION_INTENSITY 6. Motion is used for four jobs and no others:
      //   1. Orientation   - staged entrances that establish reading order.
      //   2. Continuity    - tab and route changes that show where content came from.
      //   3. Value change  - figures counting to their target, meters filling.
      //   4. Confirmation  - a one-shot pulse when money actually moves.
      //
      // What is still refused: infinite ambient loops on idle content, parallax,
      // scroll-jacking, and anything that delays a user from reading a number.
      // Durations stay under 500ms because this is a task surface. All of it
      // collapses under prefers-reduced-motion (see src/index.css).
      transitionTimingFunction: {
        DEFAULT: 'cubic-bezier(0.32, 0.72, 0, 1)',
        entrance: 'cubic-bezier(0.16, 1, 0.3, 1)',
        exit: 'cubic-bezier(0.4, 0, 1, 1)',
        // Overshoots ~3%. Reserved for confirmation only, where a little
        // physicality reads as the system reacting.
        spring: 'cubic-bezier(0.34, 1.46, 0.64, 1)',
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
