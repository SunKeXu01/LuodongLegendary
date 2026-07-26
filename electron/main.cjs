const { app, BrowserWindow, shell } = require('electron');
const path = require('node:path');

const developmentUrl = process.env.VITE_DEV_SERVER_URL;

function createWindow() {
  const window = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 860,
    minHeight: 620,
    backgroundColor: '#dfc8a4',
    title: '泺栋传奇',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  window.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('https://')) void shell.openExternal(url);
    return { action: 'deny' };
  });
  window.webContents.on('will-navigate', (event, url) => {
    const allowedUrl =
      developmentUrl ?? new URL(`file://${path.join(__dirname, '../dist/index.html')}`).href;
    if (url !== allowedUrl) event.preventDefault();
  });

  if (developmentUrl) {
    void window.loadURL(developmentUrl);
  } else {
    void window.loadFile(path.join(__dirname, '../dist/index.html'));
  }
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
