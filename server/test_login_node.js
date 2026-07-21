const { Client } = require('ssh2');

const conn = new Client();
conn.on('ready', () => {
  // Check what the server actually receives
  conn.exec("node -e \"const http = require('http'); const data = JSON.stringify({username:'admin',password:'ddeelliivv'}); const req = http.request({hostname:'localhost',port:3000,path:'/api/admin/login',method:'POST',headers:{'Content-Type':'application/json','Content-Length':data.length}}, res => { let body=''; res.on('data',c=>body+=c); res.on('end',()=>console.log(res.statusCode, body)); }); req.write(data); req.end();\"", { cwd: '/root/delivery-server' }, (err, stream) => {
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
