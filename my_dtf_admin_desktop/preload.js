// Pont minimal et en lecture seule entre le collecteur PrintExp (processus principal) et la page My DTF.
// La page reçoit les relevés, les enregistre avec la session de l'utilisateur connecté, puis accuse réception.
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('mydtfCollector', {
  onReport: cb => { const h = (_e, d) => cb(d); ipcRenderer.on('collector:report', h); ipcRenderer.send('collector:ready'); return () => ipcRenderer.removeListener('collector:report', h); },
  ack: keys => ipcRenderer.send('collector:ack', Array.isArray(keys) ? keys.map(String).slice(0, 500) : []),
  status: () => ipcRenderer.invoke('collector:status'),
});
