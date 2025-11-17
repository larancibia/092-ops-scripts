#!/usr/bin/env python3
"""
Export Claude Code Conversation to Markdown
Genera un resumen markdown de una conversación específica
"""

import json
import sys
import os
from pathlib import Path
from datetime import datetime

def find_conversation_file(session_id: str) -> Path:
    """Encuentra el archivo de conversación por session_id"""
    claude_dir = Path.home() / '.claude' / 'projects'

    # Buscar en todos los subdirectorios de proyectos
    for project_dir in claude_dir.iterdir():
        if project_dir.is_dir():
            conv_file = project_dir / f"{session_id}.jsonl"
            if conv_file.exists():
                return conv_file

    return None

def extract_messages(jsonl_file: Path) -> list:
    """Extrae los mensajes de usuario y asistente del archivo JSONL"""
    messages = []

    with open(jsonl_file, 'r') as f:
        for line in f:
            try:
                entry = json.loads(line.strip())

                # Mensajes de usuario
                if entry.get('type') == 'user' and 'message' in entry:
                    msg = entry['message']
                    content = msg.get('content', '')
                    messages.append({
                        'role': 'user',
                        'content': [content] if isinstance(content, str) else content,
                        'timestamp': entry.get('timestamp')
                    })

                # Mensajes del asistente
                elif entry.get('type') == 'assistant' and 'message' in entry:
                    msg = entry['message']
                    content = msg.get('content', [])
                    messages.append({
                        'role': 'assistant',
                        'content': content if isinstance(content, list) else [content],
                        'timestamp': entry.get('timestamp')
                    })

            except json.JSONDecodeError:
                continue

    return messages

def content_to_text(content: list) -> str:
    """Convierte el contenido de un mensaje a texto plano"""
    text_parts = []

    for item in content:
        if isinstance(item, dict):
            if item.get('type') == 'text':
                text_parts.append(item.get('text', ''))
            elif item.get('type') == 'tool_use':
                tool_name = item.get('name', 'unknown')
                text_parts.append(f"[Usó herramienta: {tool_name}]")
            elif item.get('type') == 'tool_result':
                text_parts.append("[Resultado de herramienta]")
        elif isinstance(item, str):
            text_parts.append(item)

    return '\n\n'.join(text_parts)

def export_to_markdown(session_id: str, output_file: str = None, max_length: int = None) -> str:
    """Exporta una conversación a Markdown"""
    conv_file = find_conversation_file(session_id)

    if not conv_file:
        return f"❌ No se encontró conversación con session_id: {session_id}"

    messages = extract_messages(conv_file)

    if not messages:
        return f"❌ No se pudieron extraer mensajes de la conversación"

    # Generar Markdown
    md_lines = [
        f"# Conversación: {session_id[:8]}",
        f"",
        f"**Session ID**: `{session_id}`  ",
        f"**Total mensajes**: {len(messages)}  ",
        f"",
        "---",
        ""
    ]

    for i, msg in enumerate(messages):
        role = "👤 **Usuario**" if msg['role'] == 'user' else "🤖 **Claude**"
        content = content_to_text(msg['content'])

        # Limitar longitud si se especifica
        if max_length and len(content) > max_length:
            content = content[:max_length] + "\n\n[... contenido truncado ...]"

        md_lines.append(f"### {role}")
        md_lines.append("")
        md_lines.append(content)
        md_lines.append("")
        md_lines.append("---")
        md_lines.append("")

    markdown = '\n'.join(md_lines)

    # Guardar si se especificó archivo de salida
    if output_file:
        with open(output_file, 'w') as f:
            f.write(markdown)
        return f"✅ Conversación exportada a: {output_file}"

    return markdown

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: export-conversation.py <session_id> [output_file.md]")
        print("\nEjemplo:")
        print("  export-conversation.py cd7b656e-51e3-40bb-84cc-c660ebfeb855")
        print("  export-conversation.py cd7b656e-51e3-40bb-84cc-c660ebfeb855 conversation.md")
        sys.exit(1)

    session_id = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    # Si no hay archivo de salida, mostrar solo primeras 50000 caracteres
    max_len = None if output_file else 50000

    result = export_to_markdown(session_id, output_file, max_len)
    print(result[:100000])  # Limitar output en terminal
