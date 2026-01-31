package dev.opencli

import com.intellij.openapi.project.Project
import com.intellij.openapi.wm.ToolWindow
import com.intellij.ui.components.JBScrollPane
import com.intellij.ui.components.JBTextArea
import java.awt.BorderLayout
import javax.swing.*

class ChatToolWindow(private val project: Project) {
    private val client = OpenCliClient()
    private val chatArea = JBTextArea()
    private val inputField = JTextField()

    fun createToolWindowContent(toolWindow: ToolWindow): JComponent {
        val panel = JPanel(BorderLayout())

        // Chat history area
        chatArea.isEditable = false
        chatArea.lineWrap = true
        chatArea.wrapStyleWord = true
        val scrollPane = JBScrollPane(chatArea)

        // Input area
        val inputPanel = JPanel(BorderLayout())
        inputPanel.add(inputField, BorderLayout.CENTER)

        val sendButton = JButton("Send")
        sendButton.addActionListener { sendMessage() }
        inputPanel.add(sendButton, BorderLayout.EAST)

        // Enter key sends message
        inputField.addActionListener { sendMessage() }

        panel.add(scrollPane, BorderLayout.CENTER)
        panel.add(inputPanel, BorderLayout.SOUTH)

        return panel
    }

    private fun sendMessage() {
        val message = inputField.text.trim()
        if (message.isEmpty()) return

        chatArea.append("You: $message\n")
        inputField.text = ""

        SwingUtilities.invokeLater {
            try {
                val response = client.execute("chat", listOf(message))
                chatArea.append("OpenCLI: ${response.result}\n\n")
            } catch (e: Exception) {
                chatArea.append("Error: ${e.message}\n\n")
            }
            chatArea.caretPosition = chatArea.document.length
        }
    }
}
