import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import { ThemeProvider } from './context/ThemeContext.jsx';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    {/* ThemeProvider sits above the router so the data-theme attribute is set
        before the first paint of any route. */}
    <ThemeProvider>
      <App />
    </ThemeProvider>
  </React.StrictMode>,
);
