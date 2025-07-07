/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async rewrites() {
    // Use an environment variable for the backend URL
    const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || 'http://localhost:5000'; // Fallback for local
    return [
      {
        source: '/api/health',
        destination: `${backendUrl}/health`,
      },
      {
        source: '/api/message-from-backend',
        destination: `${backendUrl}/api/message`,
      },
    ];
  },
};

module.exports = nextConfig;