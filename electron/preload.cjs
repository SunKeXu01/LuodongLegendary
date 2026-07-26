const { contextBridge } = require('electron');

contextBridge.exposeInMainWorld('luodongDesktop', {
  platform: process.platform,
  version: '0.1.0',
});
