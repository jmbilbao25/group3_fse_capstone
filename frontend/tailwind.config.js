/** Aura Console tokens. Same four brand colours as the customer app. */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        ink: { DEFAULT: '#10171C', 900: '#0A0F13', 800: '#1A2329', 700: '#26313A', 500: '#47525C', 400: '#7D8892', 300: '#A9B1B8', 200: '#D5DADF', 100: '#EAECEE' },
        paper: '#F7F7F7',
        sky: { DEFAULT: '#97CFF3', deep: '#2F78A8', wash: '#EFF6FB' },
        mint: { DEFAULT: '#A7E8D1', deep: '#1C6E5A', wash: '#E6F6EF' },
        peri: '#BEC6F7',
        ember: { DEFAULT: '#F2A25C', deep: '#9A5A16', wash: '#FDF1E4' },
        danger: { DEFAULT: '#C8423B', wash: '#FBE9E7' },
        ok: { DEFAULT: '#17805F', wash: '#E4F5EE' },
      },
      fontFamily: {
        sans: ['"Onest Variable"', 'system-ui', 'sans-serif'],
        mono: ['"Geist Mono Variable"', 'ui-monospace', 'monospace'],
      },
      fontSize: { '2xs': ['0.6875rem', '1rem'] },
      borderRadius: { xl: '14px', '2xl': '20px', '3xl': '28px' },
      boxShadow: {
        card: '0 1px 2px rgba(16,23,28,.04), 0 6px 20px -8px rgba(16,23,28,.10)',
        lift: '0 2px 4px rgba(16,23,28,.06), 0 24px 48px -16px rgba(16,23,28,.22)',
      },
      transitionTimingFunction: { out: 'cubic-bezier(0.16, 1, 0.3, 1)' },
      keyframes: {
        rise: { from: { opacity: 0, transform: 'translateY(10px)' }, to: { opacity: 1, transform: 'none' } },
        fade: { from: { opacity: 0 }, to: { opacity: 1 } },
        drawer: { from: { transform: 'translateX(32px)', opacity: 0 }, to: { transform: 'none', opacity: 1 } },
        shimmer: { from: { backgroundPosition: '-200% 0' }, to: { backgroundPosition: '200% 0' } },
      },
      animation: {
        rise: 'rise .55s cubic-bezier(0.16,1,0.3,1) both',
        fade: 'fade .3s ease-out both',
        drawer: 'drawer .42s cubic-bezier(0.16,1,0.3,1) both',
        shimmer: 'shimmer 1.6s linear infinite',
      },
    },
  },
  plugins: [],
};
