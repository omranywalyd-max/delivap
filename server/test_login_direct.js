const { Client } = require('ssh2');

const conn = new Client();
conn.on('ready', () => {
  conn.exec("node -e \"const http = require('http'); const data = JSON.stringify({username:'admin',password:'ddeelliivv'}); const req = http.request({hostname:'localhost',port:3000,path:'/api/admin/login',method:'POST',headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(data)}}, res => { let body=''; res.on('data',c=>body+=c); res.on('end',()=>console.log(res.statusCode, body)); }); req.write(data); req.end();\"", { cwd: '/root/delivery-server' }, (err, stream) => {
    let out = '';
    stream.on('data', d => out += d.toString());
    stream.stderr.on('data', d => out += d.toString());
    stream.on('close', () => { console.log(out); conn.end(); });
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
