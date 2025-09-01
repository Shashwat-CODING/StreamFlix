const { app, BrowserWindow } = require('electron');
const path = require('path');
const config = require('./config');

// Polyfill File for undici if not defined
if (typeof File === "undefined") {
  global.File = class File extends Blob {
    constructor(chunks, name, options = {}) {
      super(chunks, options);
      this.name = name;
      this.lastModified = options.lastModified || Date.now();
    }
  };
}


// Import your existing server module (this will auto-start the server)
require('./server'); 

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      enableRemoteModule: false,
      webSecurity: true
    },
    icon: path.join(__dirname, 'assets/icon.png'),
    show: false
  });

  // Load the HTML file directly instead of localhost
  const htmlPath = path.join(__dirname, 'index.html');
  mainWindow.loadFile(htmlPath);

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    require('electron').shell.openExternal(url);
    return { action: 'deny' };
  });

  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools();
  }
}

// App event handlers
app.whenReady().then(() => {
  console.log('Server loaded into Electron app');
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

// Quit when all windows are closed
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Security: Prevent navigation to external websites
app.on('web-contents-created', (event, contents) => {
  contents.on('will-navigate', (navigationEvent, navigationUrl) => {
    const parsedUrl = new URL(navigationUrl);

    // Allow file protocol and localhost for API calls
    if (
      !parsedUrl.protocol.startsWith('file:') &&
      !parsedUrl.hostname.includes('localhost') &&
      !parsedUrl.hostname.includes('127.0.0.1')
    ) {
      navigationEvent.preventDefault();
    }
  });

  contents.setWindowOpenHandler(({ url }) => {
    require('electron').shell.openExternal(url);
    return { action: 'deny' };
  });
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception in Electron:', error);
  app.quit();
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection in Electron at:', promise, 'reason:', reason);
});
