const { Client } = require('ssh2');

const conn = new Client();
conn.on('ready', () => {
  conn.exec("curl -s -X POST http://localhost:3000/api/admin/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"ddeelliivv\"}'", (err, stream) => {
    if (err) { console.error(err); conn.end(); return; }
    let out = '';
    stream.on('data', d => out += d.toString());
    stream.stderr.on('data', d => out += d.toString());
    stream.on('close', () => { console.log(out); conn.end(); });
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
