const { Client } = require('ssh2');

const conn = new Client();
conn.on('ready', () => {
  conn.exec('head -70 /root/delivery-server/routes/admin.js', (err, stream) => {
    if (err) { console.error('Exec error:', err); conn.end(); return; }
    let out = '';
    stream.on('data', d => out += d.toString());
    stream.stderr.on('data', d => out += d.toString());
    stream.on('close', () => { console.log(out); conn.end(); });
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
