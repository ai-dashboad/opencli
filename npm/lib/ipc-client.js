const net = require('net');
const msgpack = require('@msgpack/msgpack');

/**
 * IPC client for communicating with OpenCLI daemon via Unix socket
 * Uses MessagePack serialization with 4-byte length prefix
 */
class IpcClient {
  constructor(socketPath = '/tmp/opencli.sock') {
    this.socketPath = socketPath;
  }

  /**
   * Send request to daemon via IPC
   * @param {string} method - Method to execute (e.g., "chat", "system.health")
   * @param {string[]} params - Parameters array
   * @param {number} timeout - Timeout in milliseconds
   * @returns {Promise<Object>} IPC response
   */
  async sendRequest(method, params = [], timeout = 30000) {
    return new Promise((resolve, reject) => {
      const socket = net.createConnection(this.socketPath);

      socket.on('connect', () => {
        // Set timeout only after connected
        socket.setTimeout(timeout);

        const request = {
          method,
          params,
          context: {},
          request_id: this._generateRequestId(),
          timeout_ms: timeout,
        };

        try {
          // Encode to MessagePack
          const payload = msgpack.encode(request);

          // Write 4-byte little-endian length prefix
          const lengthBuf = Buffer.allocUnsafe(4);
          lengthBuf.writeUInt32LE(payload.length, 0);

          // Send length + payload
          socket.write(lengthBuf);
          socket.write(Buffer.from(payload));
        } catch (err) {
          socket.destroy();
          reject(new Error(`Failed to encode request: ${err.message}`));
        }
      });

      let responseBuffer = Buffer.alloc(0);

      socket.on('data', (chunk) => {
        responseBuffer = Buffer.concat([responseBuffer, chunk]);

        // Check if we have length prefix (4 bytes)
        if (responseBuffer.length >= 4) {
          const length = responseBuffer.readUInt32LE(0);

          // Check if we have complete payload
          if (responseBuffer.length >= 4 + length) {
            try {
              const payload = responseBuffer.subarray(4, 4 + length);
              const response = msgpack.decode(payload);
              socket.end();

              if (response.success) {
                resolve(response);
              } else {
                reject(new Error(response.error || 'Unknown error'));
              }
            } catch (err) {
              socket.destroy();
              reject(new Error(`Failed to decode response: ${err.message}`));
            }
          }
        }
      });

      socket.on('error', (err) => {
        if (err.code === 'ENOENT' || err.code === 'ECONNREFUSED') {
          reject(new Error(
            'Daemon not running. Start with: opencli daemon start'
          ));
        } else {
          reject(new Error(`Socket error: ${err.message}`));
        }
      });

      socket.on('timeout', () => {
        socket.destroy();
        reject(new Error('Request timeout'));
      });
    });
  }

  /**
   * Generate unique request ID
   * @returns {string} Unique ID
   * @private
   */
  _generateRequestId() {
    return Date.now().toString(16) + Math.random().toString(16).slice(2);
  }
}

module.exports = IpcClient;
