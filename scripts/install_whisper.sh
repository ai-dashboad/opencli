#!/bin/bash
# 安装 OpenAI Whisper 用于本地语音识别

echo "🎤 安装 OpenAI Whisper..."

# 安装 Whisper
pip3 install -U openai-whisper

# 安装 ffmpeg (音频处理依赖)
if ! command -v ffmpeg &> /dev/null; then
    echo "📦 安装 ffmpeg..."
    brew install ffmpeg
fi

# 测试安装
echo ""
echo "✅ 测试 Whisper 安装:"
whisper --help | head -5

echo ""
echo "📊 可用模型:"
echo "  • tiny    - 最快，39M，适合实时"
echo "  • base    - 快速，74M，推荐"
echo "  • small   - 平衡，244M"
echo "  • medium  - 高质量，769M"
echo "  • large   - 最佳，1550M"

echo ""
echo "🎉 安装完成！"
echo ""
echo "使用示例:"
echo "  whisper audio.m4a --model base --language Chinese"
