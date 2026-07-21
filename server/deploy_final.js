const { Client } = require('ssh2');
const conn = new Client();
conn.on('ready', () => {
  conn.sftp((err, sftp) => {
    if (err) { console.error(err); conn.end(); return; }
    let pending = 2;
    sftp.fastPut('C:/server/index.js', '/root/delivery-server/index.js', (err) => {
      if (err) console.error('index.js upload error:', err);
      else console.log('✅ index.js');
      if (--pending === 0) { sftp.end(); restart(); }
    });
    sftp.fastPut('C:/server/db.js', '/root/delivery-server/db.js', (err) => {
      if (err) console.error('db.js upload error:', err);
      else console.log('✅ db.js');
      if (--pending === 0) { sftp.end(); restart(); }
    });
    function restart() {
      conn.exec('pm2 restart delivery-api', (err2, stream) => {
        let out = '';
        stream.on('data', d => out += d.toString());
        stream.stderr.on('data', d => out += d.toString());
        stream.on('close', () => { console.log(out); conn.end(); });
      });
    }
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
