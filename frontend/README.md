# Retail banking SPA frontend

> Stack: React 18, Vite, Tailwind CSS, Lucide Icons, Nginx Alpine

This single-page application provides dedicated web portals for Customer and Admin roles, featuring real-time Server-Sent Events (SSE) telemetry and customer email-based two-factor authentication.

## Roles and capabilities

### Customer portal
- Real-time balance monitoring and account details
- Instant funds transfer initiation with automated regulatory tier calculation
- Bound hardware biometric authentication (Primary Device) or Out-of-Band push notification (Secondary Device) with step-up MPIN for high-value transfers (Zero SMS OTP under BSP Circular 1213)
- Live Server-Sent Events (SSE) transaction status alerts

### Admin portal
- System health grid and telemetry monitoring across all 16 services
- Circuit spool buffer recovery and notification retry controls
- Database connection status and compliance audit log inspection

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
