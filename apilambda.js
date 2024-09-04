/* Copyright (c) 2024 Gilad Odinak */

const os = require('os');

exports.handler = async (event) => {
    const path = event.rawPath + (event.rawQueryString ? "?" + event.rawQueryString : "");
    const method = event.requestContext.http.method;

    const interfaces = os.networkInterfaces();
    let containerIp = 'Unknown';

    for (let interfaceName in interfaces) {
        for (let i = 0; i < interfaces[interfaceName].length; i++) {
            const iface = interfaces[interfaceName][i];
            if (iface.family === 'IPv4' && !iface.internal) {
                containerIp = iface.address;
                break;
            }
        }
        if (containerIp !== 'Unknown') 
            break;
    }
    
        
    let statusCode = 200;
    let responseMessage = `\nLambda API server: Method: ${method}, Path: ${path}, Container IP Address: ${containerIp}\n\n`;
    return {
        statusCode: statusCode,
        headers: { 'Content-Type': 'text/plain' },
        body: responseMessage,
    };
};

