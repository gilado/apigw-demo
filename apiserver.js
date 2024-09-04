/* Copyright (c) 2024 Gilad Odinak */

const http = require('http');
const os = require('os');

const server = http.createServer((req, res) => {
    const path = req.url;
    const method = req.method;
    
    const interfaces = os.networkInterfaces();
    let instanceIp = 'Unknown';

    for (let interfaceName in interfaces) {
        for (let i = 0; i < interfaces[interfaceName].length; i++) {
            const iface = interfaces[interfaceName][i];
            if (iface.family === 'IPv4' && !iface.internal) {
                instanceIp = iface.address;
                break;
            }
        }
        if (instanceIp !== 'Unknown') 
            break;
    }
    
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(`\nEC2 api server: Method: ${method}, Path: ${path}, Instance IP Address: ${instanceIp}\n\n`);
});

const PORT = 3000;
server.listen(PORT, () => {
    console.log(`EC2 api server is listening on port ${PORT}`);
});
