# Retail banking SPA frontend

> Stack: React 18, Vite, Tailwind CSS, Lucide Icons, Nginx Alpine

This single-page application provides dedicated web portals for Customer and Admin roles, featuring real-time Server-Sent Events (SSE) telemetry and email-based two-factor authentication.

## Roles and capabilities

### Customer portal
- Real-time balance monitoring and account details
- Instant funds transfer initiation with automated regulatory tier calculation
- Two-factor authentication (2FA) verification via email OTP
- Live Server-Sent Events (SSE) transaction status alerts

### Admin portal
- Maker-Checker transaction queue for transfers exceeding PHP 50,000.00
- Segregation of duties enforcement (makers cannot authorize their own transactions)
- Dual Admin authorization for AMLA covered transfers exceeding PHP 500,000.00
- System health grid, circuit spool buffer controls, and notification audit logs

## Local development

### 1. Install dependencies
```bash
npm install
```

### 2. Start development server
```bash
npm run dev
```
The application runs on `http://localhost:3000` with API proxying directed to the API Gateway at `http://localhost:8080`.

### 3. Build for production
```bash
npm run build
```
Static production bundles are generated in the `dist/` directory.

## Docker deployment

The frontend is packaged into an Nginx Alpine container that serves static assets and reverse-proxies `/api/` traffic to `gateway-service:8080`:

```powershell
# Build and run standalone container
docker build -t banking-frontend .
docker run -d -p 3000:80 --name banking-frontend --network banking-net banking-frontend
```
