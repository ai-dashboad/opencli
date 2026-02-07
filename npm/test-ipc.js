const net = require('net');
const msgpack = require('@msgpack/msgpack');

const socket = net.createConnection('/tmp/opencli.sock');

socket.on('connect', () => {
  console.log('[Connected to socket]');

  const request = {
    method: 'system.health',
    params: [],
    context: {},
    request_id: Date.now().toString(16),
    timeout_ms: 30000,
  };

  console.log('[Request]', JSON.stringify(request, null, 2));

  // Encode to MessagePack
  const payload = msgpack.encode(request);
  console.log('[Payload length]', payload.length, 'bytes');
  console.log('[Payload hex]', Buffer.from(payload).toString('hex').slice(0, 100) + '...');

  // Write length prefix (4-byte LE)
  const lengthBuf = Buffer.allocUnsafe(4);
  lengthBuf.writeUInt32LE(payload.length, 0);
  console.log('[Length prefix hex]', lengthBuf.toString('hex'));

  // Send
  socket.write(lengthBuf);
  socket.write(Buffer.from(payload));
  console.log('[Sent request]');
});

let responseBuffer = Buffer.alloc(0);

socket.on('data', (chunk) => {
  console.log('[Received chunk]', chunk.length, 'bytes');
  responseBuffer = Buffer.concat([responseBuffer, chunk]);
  console.log('[Total buffer]', responseBuffer.length, 'bytes');

  if (responseBuffer.length >= 4) {
    const length = responseBuffer.readUInt32LE(0);
    console.log('[Expected payload length]', length, 'bytes');

    if (responseBuffer.length >= 4 + length) {
      console.log('[Got complete response]');
      const payload = responseBuffer.subarray(4, 4 + length);
      console.log('[Payload hex]', payload.toString('hex').slice(0, 100) + '...');

      try {
        const response = msgpack.decode(payload);
        console.log('[Response]', JSON.stringify(response, null, 2));
        socket.end();
        process.exit(0);
      } catch (err) {
        console.error('[Decode error]', err.message);
        socket.destroy();
        process.exit(1);
      }
    } else {
      console.log('[Waiting for', 4 + length - responseBuffer.length, 'more bytes]');
    }
  }
});

socket.on('error', (err) => {
  console.error('[Socket error]', err.message);
  process.exit(1);
});

socket.on('timeout', () => {
  console.error('[Timeout]');
  socket.destroy();
  process.exit(1);
});

socket.setTimeout(5000);
