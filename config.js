// Configuration file for StreamFlix app
// This replaces environment variables that don't work in packaged Electron apps

module.exports = {
  // Server configuration
  PORT: 3000,
  
  // Rate limiting
  RATE_LIMIT: false, // Set to true to enable rate limiting
  
  // Base URL for the streaming service
  BASE_URL: 'https://allmovieland.link/player.js?v=60%20128', // Replace with your actual base URL
  
  // Development mode flag
  NODE_ENV: process.env.NODE_ENV || 'production'
};
