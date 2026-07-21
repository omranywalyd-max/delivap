const { Client } = require('ssh2');
const path = require('path');
const conn = new Client();
conn.on('ready', () => {
  conn.sftp((err, sftp) => {
    if (err) { console.error(err); conn.end(); return; }
    sftp.fastPut('C:/server/check_db_script.js', '/tmp/check_db.js', (err) => {
      if (err) { console.error(err); sftp.end(); conn.end(); return; }
      console.log('uploaded');
      sftp.end();
      conn.exec('cd /root/delivery-server && NODE_PATH=/root/delivery-server/node_modules node /tmp/check_db.js', (err2, stream) => {
        if (err2) { console.error(err2); conn.end(); return; }
        let out = '';
        stream.on('data', d => out += d.toString());
        stream.stderr.on('data', d => out += d.toString());
        stream.on('close', () => { console.log(out); conn.end(); });
      });
    });
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
