const { Client } = require('ssh2');
const conn = new Client();
conn.on('ready', () => {
  conn.sftp((err, sftp) => {
    if (err) { console.error('SFTP error:', err); conn.end(); return; }
    sftp.fastPut('C:/server/routes/drivers.js', '/root/delivery-server/routes/drivers.js', (err) => {
      if (err) console.error('Upload error:', err);
      else console.log('✅ drivers.js');
      sftp.end();
      conn.exec('pm2 restart delivery-api', (err2, stream) => {
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
