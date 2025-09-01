const mediaInfo = require('../controllers/mediaInfo');
const getStream = require('../controllers/getStream');
const getSeasonList = require('../controllers/getSeasonList');

// Route handler function
async function handleRequest(path, req, res) {
  try {
    switch (path) {
      case '/mediaInfo':
        if (req.method === 'GET') {
          await mediaInfo(req, res);
        } else {
          res.status(405).json({ error: 'Method not allowed' });
        }
        break;
        
      case '/getStream':
        if (req.method === 'POST') {
          await getStream(req, res);
        } else {
          res.status(405).json({ error: 'Method not allowed' });
        }
        break;
        
      case '/getSeasonList':
        if (req.method === 'GET') {
          await getSeasonList(req, res);
        } else {
          res.status(405).json({ error: 'Method not allowed' });
        }
        break;
        
      default:
        res.status(404).json({ error: 'Route not found' });
        break;
    }
  } catch (error) {
    console.error('Route handler error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

module.exports = {
  handleRequest
};
