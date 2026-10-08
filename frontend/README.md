# Retail Banking Web Client

Single-page web application providing Customer Banking and Administrative Operations portals for the retail banking platform.

## 1. Overview and purpose

The frontend application provides an omnichannel web interface built with React 18 and Vite. It connects to the backend through the perimeter API Gateway on port 8080 and provides two primary operational modes:

1. **Customer portal:** Account overview, real-time balance queries, funds transfer wizard with friction modal handling, and cryptographic device authorization.
2. **Admin portal:** Operations dashboard, multi-service health inspection, circuit spool buffer monitoring, and compliance audit trail inspection.

## 2. Tech stack

* Core: React 18, TypeScript / JavaScript ES2022
* Build tool: Vite 5
* Styling: Tailwind CSS 3, PostCSS, Autoprefixer
* Icons: Lucide React
* Real-time events: Server-Sent Events (SSE) and native WebSockets
* Production runtime: Nginx 1.25 Alpine reverse proxy container

## 3. Scope and boundaries

### In scope
* Authentication workflows: Customer login, registration, token refresh, and session logout.
* Account management: Balance cards, cleared funds vs available funds display.
* Transfer flow with risk engine friction handling:
  * Standard allowed transfers with local biometric simulation.
  * Advisory warning modals (rendering Laya scam explanations with Cancel, 10-Minute Hold, or Proceed buttons and a 3-second mandatory read delay).
  * Step-up authentication modals for biometric plus transaction MPIN.
  * Immediate rejection notices for blocked transfers (zero bypass allowed).
* Live SSE transaction status updates.
* Admin telemetry dashboard for service monitoring and audit verification.

### Out of scope
* Core business validations: Delegated to backend microservices.
* Financial ledger state: Maintained exclusively by `ledger-mutation-engine`.
* Fraud heuristics: Evaluated by `risk-service`.

## 4. Regulatory compliance: Zero SMS OTP

In compliance with Bangko Sentral ng Pilipinas (BSP) Circular 1213:
* The web client never displays or prompts for an SMS one-time password (OTP).
* Primary devices authenticate via bound hardware biometrics.
* Secondary devices or browser sessions use out-of-band push confirmation or step-up MPIN.
* High-value or anomalous transactions require step-up authentication using biometric confirmation plus an MPIN.

## 5. Local development

### Install dependencies
```bash
cd frontend
npm install
```

### Run development server
```bash
npm run dev
```
The development server launches at `http://localhost:3000`. API requests to `/api/` proxy automatically to the API Gateway at `http://localhost:8080`.

### Production build
```bash
npm run build
```
Static production bundles compile into the `dist/` directory.

## 6. Docker deployment

The frontend is containerized using multi-stage Nginx Alpine builds:

```bash
docker build -t banking-frontend .
docker run -d -p 3000:80 --name banking-frontend --network banking-net banking-frontend
```

Nginx serves compiled static assets and proxies `/api/` traffic directly to `gateway-service:8080`.
