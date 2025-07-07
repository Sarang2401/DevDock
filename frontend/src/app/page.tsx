// frontend/src/app/page.tsx
'use client'; // Required for client-side fetches in App Router

import { useState, useEffect } from 'react';

export default function Home() {
  const [message, setMessage] = useState('Loading...');
  const [backendStatus, setBackendStatus] = useState('Checking...');

  useEffect(() => {
    // Check backend health
    fetch('/api/health') // Relative path, Next.js proxy will handle it
      .then(res => res.json())
      .then(data => setBackendStatus(data.status))
      .catch(() => setBackendStatus('Down'));

    // Get message from backend
    fetch('/api/message-from-backend') // Relative path, Next.js proxy will handle it
      .then(res => res.json())
      .then(data => setMessage(data.message))
      .catch(() => setMessage('Failed to load message from backend.'));
  }, []);

  return (
    <div style={{ padding: '20px', textAlign: 'center' }}>
      <h1>Frontend Application</h1>
      <p>Backend Status: <strong>{backendStatus}</strong></p>
      <p>Message from Backend: <strong>{message}</strong></p>
    </div>
  );
}
