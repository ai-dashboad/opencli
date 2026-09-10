#!/usr/bin/env python3
"""Translate the documentation site's own furniture.

Not the pages — the navbar, the sidebar's category names and the footer. There
are about two dozen of them and they are what makes a site feel like it is in
your language even when a page underneath it is not: Docusaurus falls back to
the English page rather than a 404, so a reader lands in a site whose
navigation they can read and an article they can follow well enough to know
whether they want it translated.

Run after adding a locale or renaming a category:

    node -e 0 && python3 scripts/write-chrome.py

It writes only the keys it has a translation for and leaves the rest as
Docusaurus generated them.
"""

from __future__ import annotations

import json
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent

CHROME: dict[str, dict[str, str]] = {
    "zh-CN": {
        "item.label.Docs": "文档",
        "item.label.Get started": "开始",
        "item.label.FAQ": "常见问题",
        "item.label.Download": "下载",
        "sidebar.docs.category.Getting started": "开始",
        "sidebar.docs.category.Doing work": "用它做事",
        "sidebar.docs.category.Configuration": "配置",
        "sidebar.docs.category.Tutorials": "教程",
        "sidebar.docs.category.Help": "帮助",
        "sidebar.docs.category.Reference": "参考",
        "link.title.Start here": "从这里开始",
        "link.title.Help": "帮助",
        "link.title.Elsewhere": "其他地方",
        "link.item.label.Install": "安装",
        "link.item.label.Point it at a model": "指一个模型给它",
        "link.item.label.FAQ": "常见问题",
        "link.item.label.Troubleshooting": "故障排查",
        "link.item.label.Security": "安全",
        "link.item.label.Issues": "问题反馈",
    },
    "zh-TW": {
        "item.label.Docs": "文件",
        "item.label.Get started": "開始",
        "item.label.FAQ": "常見問題",
        "item.label.Download": "下載",
        "sidebar.docs.category.Getting started": "開始",
        "sidebar.docs.category.Doing work": "用它做事",
        "sidebar.docs.category.Configuration": "設定",
        "sidebar.docs.category.Tutorials": "教學",
        "sidebar.docs.category.Help": "說明",
        "sidebar.docs.category.Reference": "參考",
        "link.title.Start here": "從這裡開始",
        "link.title.Help": "說明",
        "link.title.Elsewhere": "其他地方",
        "link.item.label.Install": "安裝",
        "link.item.label.Point it at a model": "指一個模型給它",
        "link.item.label.FAQ": "常見問題",
        "link.item.label.Troubleshooting": "疑難排解",
        "link.item.label.Security": "安全",
        "link.item.label.Issues": "問題回報",
    },
    "ja": {
        "item.label.Docs": "ドキュメント",
        "item.label.Get started": "はじめに",
        "item.label.FAQ": "よくある質問",
        "item.label.Download": "ダウンロード",
        "sidebar.docs.category.Getting started": "はじめに",
        "sidebar.docs.category.Doing work": "仕事に使う",
        "sidebar.docs.category.Configuration": "設定",
        "sidebar.docs.category.Tutorials": "チュートリアル",
        "sidebar.docs.category.Help": "ヘルプ",
        "sidebar.docs.category.Reference": "リファレンス",
        "link.title.Start here": "ここから",
        "link.title.Help": "ヘルプ",
        "link.title.Elsewhere": "その他",
        "link.item.label.Install": "インストール",
        "link.item.label.Point it at a model": "モデルを指定する",
        "link.item.label.FAQ": "よくある質問",
        "link.item.label.Troubleshooting": "トラブルシューティング",
        "link.item.label.Security": "セキュリティ",
        "link.item.label.Issues": "問題を報告",
    },
    "ko": {
        "item.label.Docs": "문서",
        "item.label.Get started": "시작하기",
        "item.label.FAQ": "자주 묻는 질문",
        "item.label.Download": "다운로드",
        "sidebar.docs.category.Getting started": "시작하기",
        "sidebar.docs.category.Doing work": "일에 쓰기",
        "sidebar.docs.category.Configuration": "설정",
        "sidebar.docs.category.Tutorials": "튜토리얼",
        "sidebar.docs.category.Help": "도움말",
        "sidebar.docs.category.Reference": "참고",
        "link.title.Start here": "여기서 시작",
        "link.title.Help": "도움말",
        "link.title.Elsewhere": "그 밖에",
        "link.item.label.Install": "설치",
        "link.item.label.Point it at a model": "모델 지정하기",
        "link.item.label.FAQ": "자주 묻는 질문",
        "link.item.label.Troubleshooting": "문제 해결",
        "link.item.label.Security": "보안",
        "link.item.label.Issues": "문제 신고",
    },
    "es": {
        "item.label.Docs": "Documentación",
        "item.label.Get started": "Primeros pasos",
        "item.label.FAQ": "Preguntas frecuentes",
        "item.label.Download": "Descargar",
        "sidebar.docs.category.Getting started": "Primeros pasos",
        "sidebar.docs.category.Doing work": "Trabajar con ello",
        "sidebar.docs.category.Configuration": "Configuración",
        "sidebar.docs.category.Tutorials": "Tutoriales",
        "sidebar.docs.category.Help": "Ayuda",
        "sidebar.docs.category.Reference": "Referencia",
        "link.title.Start here": "Empieza aquí",
        "link.title.Help": "Ayuda",
        "link.title.Elsewhere": "En otros sitios",
        "link.item.label.Install": "Instalar",
        "link.item.label.Point it at a model": "Apuntarlo a un modelo",
        "link.item.label.FAQ": "Preguntas frecuentes",
        "link.item.label.Troubleshooting": "Solución de problemas",
        "link.item.label.Security": "Seguridad",
        "link.item.label.Issues": "Incidencias",
    },
    "pt-BR": {
        "item.label.Docs": "Documentação",
        "item.label.Get started": "Primeiros passos",
        "item.label.FAQ": "Perguntas frequentes",
        "item.label.Download": "Baixar",
        "sidebar.docs.category.Getting started": "Primeiros passos",
        "sidebar.docs.category.Doing work": "Trabalhando com ele",
        "sidebar.docs.category.Configuration": "Configuração",
        "sidebar.docs.category.Tutorials": "Tutoriais",
        "sidebar.docs.category.Help": "Ajuda",
        "sidebar.docs.category.Reference": "Referência",
        "link.title.Start here": "Comece aqui",
        "link.title.Help": "Ajuda",
        "link.title.Elsewhere": "Em outros lugares",
        "link.item.label.Install": "Instalar",
        "link.item.label.Point it at a model": "Apontar para um modelo",
        "link.item.label.FAQ": "Perguntas frequentes",
        "link.item.label.Troubleshooting": "Solução de problemas",
        "link.item.label.Security": "Segurança",
        "link.item.label.Issues": "Problemas",
    },
    "fr": {
        "item.label.Docs": "Documentation",
        "item.label.Get started": "Démarrer",
        "item.label.FAQ": "Questions fréquentes",
        "item.label.Download": "Télécharger",
        "sidebar.docs.category.Getting started": "Démarrer",
        "sidebar.docs.category.Doing work": "Travailler avec",
        "sidebar.docs.category.Configuration": "Configuration",
        "sidebar.docs.category.Tutorials": "Tutoriels",
        "sidebar.docs.category.Help": "Aide",
        "sidebar.docs.category.Reference": "Référence",
        "link.title.Start here": "Commencer ici",
        "link.title.Help": "Aide",
        "link.title.Elsewhere": "Ailleurs",
        "link.item.label.Install": "Installer",
        "link.item.label.Point it at a model": "Le pointer vers un modèle",
        "link.item.label.FAQ": "Questions fréquentes",
        "link.item.label.Troubleshooting": "Dépannage",
        "link.item.label.Security": "Sécurité",
        "link.item.label.Issues": "Tickets",
    },
    "de": {
        "item.label.Docs": "Dokumentation",
        "item.label.Get started": "Erste Schritte",
        "item.label.FAQ": "Häufige Fragen",
        "item.label.Download": "Herunterladen",
        "sidebar.docs.category.Getting started": "Erste Schritte",
        "sidebar.docs.category.Doing work": "Damit arbeiten",
        "sidebar.docs.category.Configuration": "Konfiguration",
        "sidebar.docs.category.Tutorials": "Anleitungen",
        "sidebar.docs.category.Help": "Hilfe",
        "sidebar.docs.category.Reference": "Referenz",
        "link.title.Start here": "Hier anfangen",
        "link.title.Help": "Hilfe",
        "link.title.Elsewhere": "Anderswo",
        "link.item.label.Install": "Installieren",
        "link.item.label.Point it at a model": "Auf ein Modell zeigen",
        "link.item.label.FAQ": "Häufige Fragen",
        "link.item.label.Troubleshooting": "Fehlersuche",
        "link.item.label.Security": "Sicherheit",
        "link.item.label.Issues": "Meldungen",
    },
    "ru": {
        "item.label.Docs": "Документация",
        "item.label.Get started": "Начало работы",
        "item.label.FAQ": "Частые вопросы",
        "item.label.Download": "Скачать",
        "sidebar.docs.category.Getting started": "Начало работы",
        "sidebar.docs.category.Doing work": "Работа с ним",
        "sidebar.docs.category.Configuration": "Настройка",
        "sidebar.docs.category.Tutorials": "Руководства",
        "sidebar.docs.category.Help": "Помощь",
        "sidebar.docs.category.Reference": "Справка",
        "link.title.Start here": "Начните отсюда",
        "link.title.Help": "Помощь",
        "link.title.Elsewhere": "Другое",
        "link.item.label.Install": "Установка",
        "link.item.label.Point it at a model": "Указать модель",
        "link.item.label.FAQ": "Частые вопросы",
        "link.item.label.Troubleshooting": "Устранение неполадок",
        "link.item.label.Security": "Безопасность",
        "link.item.label.Issues": "Обращения",
    },
}


def apply(path: Path, words: dict[str, str]) -> int:
    if not path.exists():
        return 0
    body = json.loads(path.read_text(encoding="utf-8"))
    changed = 0
    for key, entry in body.items():
        if key in words and isinstance(entry, dict):
            entry["message"] = words[key]
            changed += 1
    path.write_text(json.dumps(body, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return changed


def main() -> int:
    for locale, words in CHROME.items():
        base = SITE / "i18n" / locale
        total = sum(
            apply(base / part, words)
            for part in (
                "docusaurus-theme-classic/navbar.json",
                "docusaurus-theme-classic/footer.json",
                "docusaurus-plugin-content-docs/current.json",
            )
        )
        print(f"  {locale:<6} {total} translated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
