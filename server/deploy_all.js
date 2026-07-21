const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

const conn = new Client();
const files = {
  'C:/server/index.js': '/root/delivery-server/index.js',
  'C:/server/routes/config.js': '/root/delivery-server/routes/config.js',
  'C:/server/routes/misc.js': '/root/delivery-server/routes/misc.js',
  'C:/server/routes/admin.js': '/root/delivery-server/routes/admin.js',
  'C:/server/routes/users.js': '/root/delivery-server/routes/users.js',
  'C:/server/routes/orders.js': '/root/delivery-server/routes/orders.js',
  'C:/server/routes/products.js': '/root/delivery-server/routes/products.js',
  'C:/server/routes/drivers.js': '/root/delivery-server/routes/drivers.js',
  'C:/server/models/Order.js': '/root/delivery-server/models/Order.js',
  'C:/server/models/User.js': '/root/delivery-server/models/User.js',
  'C:/server/models/Product.js': '/root/delivery-server/models/Product.js',
};

conn.on('ready', () => {
  conn.sftp((err, sftp) => {
    if (err) { console.error('SFTP error:', err); conn.end(); return; }
    const entries = Object.entries(files);
    let i = 0;
    function uploadNext() {
      if (i >= entries.length) {
        sftp.end();
        console.log('All files uploaded. Restarting...');
        conn.exec('pm2 restart delivery-api', (err2, stream) => {
          let out = '';
          stream.on('data', d => out += d.toString());
          stream.stderr.on('data', d => out += d.toString());
          stream.on('close', () => { console.log(out); conn.end(); });
        });
        return;
      }
      const [local, remote] = entries[i++];
      sftp.fastPut(local, remote, (err) => {
        if (err) console.error(`Upload error ${local}:`, err);
        else console.log(`✅ ${path.basename(local)}`);
        uploadNext();
      });
    }
    uploadNext();
  });
});
conn.connect({
  host: '89.167.84.221', port: 22, username: 'root', password: 'ddeelliivv',
});
