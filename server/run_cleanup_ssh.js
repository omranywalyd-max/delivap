const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

const conn = new Client();
conn.on('ready', () => {
  // Upload the cleanup script
  conn.sftp((err, sftp) => {
    if (err) { console.error('SFTP error:', err); conn.end(); return; }
    sftp.fastPut(
      path.join(__dirname, 'run_cleanup.js'),
      '/root/delivery-server/run_cleanup.js',
      (err) => {
        if (err) { console.error('Upload error:', err); sftp.end(); conn.end(); return; }
        sftp.end();
        // Run it
        conn.exec('node /root/delivery-server/run_cleanup.js', (err2, stream) => {
          if (err2) { console.error(err2); conn.end(); return; }
          let out = '';
          stream.on('data', d => out += d.toString());
          stream.stderr.on('data', d => out += d.toString());
          stream.on('close', () => {
            console.log(out);
            // Cleanup temp file
            conn.exec('rm /root/delivery-server/run_cleanup.js', () => conn.end());
          });
        });
      }
    );
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
