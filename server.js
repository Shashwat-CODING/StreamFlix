const http = require('http');
const url = require('url');
const querystring = require('querystring');
// Import routes
const router = require('./routes/route');
const config = require('./config');

// Simple rate limiting store
const rateLimitStore = new Map();
const RATE_LIMIT_WINDOW = 5 * 60 * 1000; // 5 minutes
const RATE_LIMIT_MAX = 10; // 10 requests per window

// Rate limiting function
function rateLimit(req, res) {
  if (config.RATE_LIMIT !== true) {
    return false; // Rate limiting disabled
  }

  const clientIP = req.connection.remoteAddress || req.socket.remoteAddress;
  const now = Date.now();
  const clientData = rateLimitStore.get(clientIP) || { count: 0, resetTime: now + RATE_LIMIT_WINDOW };

  // Reset count if window has expired
  if (now > clientData.resetTime) {
    clientData.count = 0;
    clientData.resetTime = now + RATE_LIMIT_WINDOW;
  }

  // Check if limit exceeded
  if (clientData.count >= RATE_LIMIT_MAX) {
    res.writeHead(429, { 
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Allow-Credentials': 'true'
    });
    res.end(JSON.stringify({ error: 'Too many requests, please try again later.' }));
    return true; // Rate limited
  }

  // Increment count
  clientData.count++;
  rateLimitStore.set(clientIP, clientData);
  
  return false; // Not rate limited
}

// CORS headers function
function setCORSHeaders(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
}

// Parse JSON body
function parseJSONBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (error) {
        reject(error);
      }
    });
  });
}

// Create HTTP server
const server = http.createServer(async (req, res) => {
  console.log(`${req.method} ${req.url} - ${new Date().toISOString()}`);
  
  // Set CORS headers
  setCORSHeaders(res);

  // Handle OPTIONS preflight requests
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Apply rate limiting
  if (rateLimit(req, res)) {
    return; // Request was rate limited
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const query = parsedUrl.query;

  try {
    // Root endpoint - serve the HTML file
    if (pathname === '/' && req.method === 'GET') {
      const fs = require('fs');
      const path = require('path');
      
      try {
        const htmlPath = path.join(__dirname, 'index.html');
        const htmlContent = fs.readFileSync(htmlPath, 'utf8');
        
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(htmlContent);
        return;
      } catch (error) {
        console.error('Error reading HTML file:', error);
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Error loading application');
        return;
      }
    }

    // API routes
    if (pathname.startsWith('/api/v1/')) {
      const apiPath = pathname.replace('/api/v1', '');
      console.log(`API request: ${apiPath}`);
      
      // Parse request body for POST requests
      let body = {};
      if (req.method === 'POST') {
        try {
          body = await parseJSONBody(req);
        } catch (error) {
          console.error('JSON parsing error:', error);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Invalid JSON' }));
          return;
        }
      }

      // Create request object similar to Express
      const request = {
        method: req.method,
        url: req.url,
        query: query,
        body: body,
        headers: req.headers
      };

      // Create response object similar to Express
      const response = {
        json: (data) => {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(data));
        },
        send: (data) => {
          res.writeHead(200, { 'Content-Type': 'text/plain' });
          res.end(data);
        },
        status: (code) => {
          res.statusCode = code;
          return response;
        }
      };

      // Route to appropriate handler
      await router.handleRequest(apiPath, request, response);
      return;
    }

    // 404 for other routes
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));

  } catch (error) {
    console.error('Server error:', error);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Internal server error' }));
  }
});

// Allow connections from all hosts
const Port = config.PORT || 3000;
server.listen(Port, '0.0.0.0', () => {
  console.log(`Server running on port ${Port} and accepting connections from all hosts`);
});




