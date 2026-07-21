const { Client } = require('ssh2');
const path = require('path');

const conn = new Client();
const files = {
  'C:/server/routes/projectDeliveries.js': '/root/delivery-server/routes/projectDeliveries.js',
  'C:/server/routes/misc.js': '/root/delivery-server/routes/misc.js',
  'C:/server/fcm.js': '/root/delivery-server/fcm.js',
};

conn.on('ready', () => {
  conn.sftp((err, sftp) => {
    if (err) { console.error('SFTP error:', err); conn.end(); return; }
    const entries = Object.entries(files);
    let i = 0;
    function uploadNext() {
      if (i >= entries.length) {
        sftp.end();
        console.log('All files uploaded. Restarting...');
        conn.exec('pm2 restart delivery-api', (err2, stream) => {
          let out = '';
          stream.on('data', d => out += d.toString());
          stream.stderr.on('data', d => out += d.toString());
          stream.on('close', () => { console.log(out); conn.end(); });
        });
        return;
      }
      const [local, remote] = entries[i++];
      sftp.fastPut(local, remote, (err) => {
        if (err) console.error(`Upload error ${local}:`, err);
        else console.log(`\u2705 ${path.basename(local)}`);
        uploadNext();
      });
    }
    uploadNext();
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
