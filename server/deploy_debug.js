const { Client } = require('ssh2');
const conn = new Client();
conn.on('ready', () => {
  conn.exec('node -e "const app=require(\"express\")();app.use(\"/api\",(q,r,n)=>{console.log(\"PATH:\",q.path,\"METHOD:\",q.method);n();});app.get(\"/api/promotions\",(q,r)=>r.json({ok:1}));app.listen(3999,()=>{const h=require(\"http\");h.get(\"http://localhost:3999/api/promotions\",res=>{let d=\"\";res.on(\"data\",c=>d+=c);res.on(\"end\",()=>{console.log(res.statusCode,d);process.exit(0)});});});" 2>&1', (err, stream) => {
    let out = '';
    stream.on('data', d => out += d.toString());
    stream.stderr.on('data', d => out += d.toString());
    stream.on('close', () => { console.log(out); conn.end(); });
  });
});
conn.connect({host:'89.167.84.221',port:22,username:'root',password:'ddeelliivv'});
