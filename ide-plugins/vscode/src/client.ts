import * as net from 'net';
import * as msgpack from 'msgpack-lite';

interface IpcRequest {
    method: string;
    params: string[];
    context?: Record<string, unknown>;
    request_id?: string;
    timeout_ms?: number;
}

interface IpcResponse {
    success: boolean;
    result: string;
    duration_us: number;
    cached: boolean;
    request_id?: string;
    error?: string;
}

export class OpenCliClient {
    private socketPath: string;

    constructor(socketPath: string = '/tmp/opencli.sock') {
        this.socketPath = socketPath;
    }

    async execute(method: string, params: string[] = []): Promise<IpcResponse> {
        return new Promise((resolve, reject) => {
            const socket = net.createConnection(this.socketPath, () => {
                const request: IpcRequest = {
                    method,
                    params,
                    context: {},
                    request_id: this.generateUuid(),
                    timeout_ms: 30000,
                };

                // Serialize with MessagePack
                const payload = msgpack.encode(request);
                const length = Buffer.allocUnsafe(4);
                length.writeUInt32LE(payload.length, 0);

                // Send length + payload
                socket.write(length);
                socket.write(payload);
            });

            let responseBuffer = Buffer.alloc(0);

            socket.on('data', (data) => {
                responseBuffer = Buffer.concat([responseBuffer, data]);

                // Check if we have length prefix (4 bytes)
                if (responseBuffer.length < 4) {
                    return;
                }

                const responseLength = responseBuffer.readUInt32LE(0);

                // Check if we have full response
                if (responseBuffer.length < 4 + responseLength) {
                    return;
                }

                // Deserialize response
                const responsePayload = responseBuffer.slice(4, 4 + responseLength);
                const response = msgpack.decode(responsePayload) as IpcResponse;

                socket.end();

                if (response.success) {
                    resolve(response);
                } else {
                    reject(new Error(response.error || 'Unknown error'));
                }
            });

            socket.on('error', (error) => {
                reject(error);
            });
        });
    }

    async ensureDaemonRunning(): Promise<void> {
        try {
            await this.execute('system.health');
        } catch (error) {
            // Daemon not running, try to start it
            const { spawn } = require('child_process');
            const daemonPath = `${process.env.HOME}/.opencli/bin/opencli-daemon`;
            spawn(daemonPath, [], { detached: true, stdio: 'ignore' }).unref();
        }
    }

    private generateUuid(): string {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
            const r = (Math.random() * 16) | 0;
            const v = c === 'x' ? r : (r & 0x3) | 0x8;
            return v.toString(16);
        });
    }
}
