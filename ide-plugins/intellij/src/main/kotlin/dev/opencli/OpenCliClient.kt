package dev.opencli

import org.msgpack.core.MessagePack
import java.io.InputStream
import java.io.OutputStream
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.*

data class IpcRequest(
    val method: String,
    val params: List<String> = emptyList(),
    val context: Map<String, Any> = emptyMap(),
    val requestId: String = UUID.randomUUID().toString(),
    val timeoutMs: Int = 30000
)

data class IpcResponse(
    val success: Boolean,
    val result: String,
    val durationUs: Long,
    val cached: Boolean,
    val requestId: String?,
    val error: String?
)

class OpenCliClient(private val socketPath: String = "/tmp/opencli.sock") {

    fun execute(method: String, params: List<String> = emptyList()): IpcResponse {
        val socket = Socket()
        socket.connect(java.net.UnixDomainSocketAddress.of(socketPath))

        val request = IpcRequest(method, params)

        // Serialize request
        val packer = MessagePack.newDefaultBufferPacker()
        packer.packMapHeader(5)
        packer.packString("method").packString(request.method)
        packer.packString("params").packArrayHeader(request.params.size)
        request.params.forEach { packer.packString(it) }
        packer.packString("context").packMapHeader(0)
        packer.packString("request_id").packString(request.requestId)
        packer.packString("timeout_ms").packInt(request.timeoutMs)

        val payload = packer.toByteArray()

        // Send length prefix + payload
        val length = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(payload.size).array()
        socket.getOutputStream().write(length)
        socket.getOutputStream().write(payload)
        socket.getOutputStream().flush()

        // Read response
        val responseLength = readInt32LE(socket.getInputStream())
        val responsePayload = ByteArray(responseLength)
        socket.getInputStream().read(responsePayload)

        // Deserialize response
        val unpacker = MessagePack.newDefaultUnpacker(responsePayload)
        val mapSize = unpacker.unpackMapHeader()

        var success = false
        var result = ""
        var durationUs = 0L
        var cached = false
        var requestId: String? = null
        var error: String? = null

        repeat(mapSize) {
            when (unpacker.unpackString()) {
                "success" -> success = unpacker.unpackBoolean()
                "result" -> result = unpacker.unpackString()
                "duration_us" -> durationUs = unpacker.unpackLong()
                "cached" -> cached = unpacker.unpackBoolean()
                "request_id" -> requestId = unpacker.unpackString()
                "error" -> error = if (unpacker.tryUnpackNil()) null else unpacker.unpackString()
            }
        }

        socket.close()

        return IpcResponse(success, result, durationUs, cached, requestId, error)
    }

    private fun readInt32LE(input: InputStream): Int {
        val bytes = ByteArray(4)
        input.read(bytes)
        return ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).int
    }

    fun ensureDaemonRunning() {
        try {
            execute("system.health")
        } catch (e: Exception) {
            // Start daemon
            val daemonPath = "${System.getProperty("user.home")}/.opencli/bin/opencli-daemon"
            ProcessBuilder(daemonPath).start()
        }
    }
}
