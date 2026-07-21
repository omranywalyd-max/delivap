const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

const conn = new Client();
const files = {
  'C:/server/models/Category.js': '/root/delivery-server/models/Category.js',
  'C:/server/migrate_cats.js': '/root/delivery-server/migrate_cats.js',
};

conn.on('ready', () => {
  conn.sftp((err, sftp) => {
    if (err) { console.error('SFTP error:', err); conn.end(); return; }
    const entries = Object.entries(files);
    let i = 0;
    function uploadNext() {
      if (i >= entries.length) {
        sftp.end();
        console.log('Files uploaded. Running migration...');
        conn.exec('cd /root/delivery-server && node migrate_cats.js', (err2, stream) => {
          let out = '';
          stream.on('data', d => out += d.toString());
          stream.stderr.on('data', d => out += d.toString());
          stream.on('close', () => {
            console.log('Migration output:', out);
            console.log('Restarting server...');
            conn.exec('pm2 restart delivery-api', (err3, stream2) => {
              let out2 = '';
              stream2.on('data', d => out2 += d.toString());
              stream2.stderr.on('data', d => out2 += d.toString());
              stream2.on('close', () => { console.log(out2); conn.end(); });
            });
          });
        });
        return;
      }
      const [local, remote] = entries[i++];
      sftp.fastPut(local, remote, (err) => {
        if (err) console.error(`Upload error ${local}:`, err);
        else console.log(`OK ${path.basename(local)}`);
        uploadNext();
      });
    }
    uploadNext();
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
