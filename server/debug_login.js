const { Client } = require('ssh2');

const conn = new Client();
// Add debug log to login route via sed
const cmd = "sed -i '41a\\\\    console.log(\"LOGIN HIT\", req.path, req.method);' /root/delivery-server/routes/admin.js";
conn.on('ready', () => {
  conn.exec(cmd, (err, stream) => {
    let out = '';
    stream.on('data', d => out += d.toString());
    stream.stderr.on('data', d => out += d.toString());
    stream.on('close', () => {
      console.log('sed result:', out);
      conn.exec('pm2 restart delivery-api', (err2, stream2) => {
        let out2 = '';
        stream2.on('data', d => out2 += d.toString());
        stream2.stderr.on('data', d => out2 += d.toString());
        stream2.on('close', () => { console.log(out2); conn.end(); });
      });
    });
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
