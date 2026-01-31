export class OpenCliClient {
  private ws: WebSocket | null = null;
  private readonly wsUrl: string;

  constructor(wsUrl: string) {
    this.wsUrl = wsUrl;
  }

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.wsUrl);

      this.ws.onopen = () => {
        console.log('Connected to OpenCLI daemon');
        resolve();
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        reject(error);
      };
    });
  }

  async execute(method: string, params: string[] = []): Promise<any> {
    const response = await fetch('http://localhost:9529/api/v1/execute', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        method,
        params,
        context: {},
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    return response.json();
  }

  async chatStream(
    message: string,
    model: string,
    onChunk: (chunk: string) => void
  ): Promise<void> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      await this.connect();
    }

    return new Promise((resolve, reject) => {
      const messageHandler = (event: MessageEvent) => {
        const data = JSON.parse(event.data);

        switch (data.type) {
          case 'chunk':
            onChunk(data.content);
            break;

          case 'done':
            this.ws?.removeEventListener('message', messageHandler);
            resolve();
            break;

          case 'error':
            this.ws?.removeEventListener('message', messageHandler);
            reject(new Error(data.message));
            break;
        }
      };

      this.ws?.addEventListener('message', messageHandler);

      this.ws?.send(
        JSON.stringify({
          type: 'chat',
          message,
          model,
        })
      );
    });
  }

  disconnect(): void {
    this.ws?.close();
    this.ws = null;
  }
}
