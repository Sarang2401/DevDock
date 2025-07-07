/** @type {import('next').NextConfig} */
const nextConfig = {
  async rewrites() {
    return [
      {
        source: '/api/health',
        destination: 'http://localhost:5000/health', // This will be the backend service name in Docker/ECS
      },
      {
        source: '/api/message-from-backend',
        destination: 'http://localhost:5000/api/message', // This will be the backend service name in Docker/ECS
      },
    ];
  },
};

module.exports = nextConfig;
