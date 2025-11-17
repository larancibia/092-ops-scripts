#!/usr/bin/env python3
"""
Memory Workspace System
Permite crear, editar y combinar contextos de conversaciones antes de usarlos
"""

import json
import os
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime
import chromadb
from sentence_transformers import SentenceTransformer


class MemoryWorkspace:
    """
    Un workspace es una colección curada de conversaciones
    con filtros, metadata y capacidad de export
    """

    def __init__(self, name: str, workspace_dir: str = None):
        self.name = name
        self.conversations: List[str] = []  # session_ids
        self.filters: Dict[str, Any] = {}
        self.metadata: Dict[str, Any] = {
            "created_at": datetime.now().isoformat(),
            "modified_at": datetime.now().isoformat(),
            "tags": [],
            "description": ""
        }

        # Directory para guardar workspaces
        if workspace_dir is None:
            self.workspace_dir = Path.home() / ".claude" / "memory" / "workspaces"
        else:
            self.workspace_dir = Path(workspace_dir)

        self.workspace_dir.mkdir(parents=True, exist_ok=True)

        # ChromaDB connection
        self.client = None
        self.collection = None
        self.model = None

    def _init_db(self, db_path: str = "/opt/apps/cli-memory-system/chroma_db"):
        """Lazy initialization de ChromaDB"""
        if self.client is None:
            self.client = chromadb.PersistentClient(path=db_path)
            self.collection = self.client.get_collection(name="cli_conversations")
            self.model = SentenceTransformer('all-MiniLM-L6-v2')

    def add_conversations(self, session_ids: List[str]):
        """Agregar conversaciones al workspace"""
        for sid in session_ids:
            if sid not in self.conversations:
                self.conversations.append(sid)

        self.metadata["modified_at"] = datetime.now().isoformat()
        return len(session_ids)

    def remove_conversations(self, session_ids: List[str]):
        """Remover conversaciones del workspace"""
        for sid in session_ids:
            if sid in self.conversations:
                self.conversations.remove(sid)

        self.metadata["modified_at"] = datetime.now().isoformat()
        return len(session_ids)

    def apply_filters(self, filters: Dict[str, Any]):
        """
        Aplicar filtros a las conversaciones

        Filtros soportados:
        - date_after: str (ISO date)
        - date_before: str (ISO date)
        - min_messages: int
        - max_messages: int
        - source: str (claude, codex, gemini)
        - has_keywords: List[str]
        - exclude_keywords: List[str]
        """
        self.filters.update(filters)
        self.metadata["modified_at"] = datetime.now().isoformat()

    def get_messages(self, db_path: str = "/opt/apps/cli-memory-system/chroma_db") -> List[Dict[str, Any]]:
        """
        Obtiene todos los mensajes de las conversaciones en el workspace
        aplicando los filtros configurados
        """
        self._init_db(db_path)

        all_messages = []

        for session_id in self.conversations:
            # Obtener mensajes de la conversación
            results = self.collection.get(
                where={"session_id": session_id},
                limit=1000
            )

            if not results['ids']:
                continue

            # Ordenar por orden del mensaje
            messages = []
            for i, doc_id in enumerate(results['ids']):
                msg = {
                    'id': doc_id,
                    'text': results['documents'][i],
                    'metadata': results['metadatas'][i],
                    'order': int(doc_id.split('_')[-1]) if '_' in doc_id else i,
                    'session_id': session_id
                }
                messages.append(msg)

            messages.sort(key=lambda x: x['order'])

            # Aplicar filtros
            if self.filters:
                messages = self._filter_messages(messages)

            all_messages.extend(messages)

        return all_messages

    def _filter_messages(self, messages: List[Dict]) -> List[Dict]:
        """Aplicar filtros a una lista de mensajes"""
        filtered = messages

        # Filtro por fecha
        if 'date_after' in self.filters:
            date_after = self.filters['date_after']
            filtered = [m for m in filtered
                       if m['metadata'].get('date', '') >= date_after]

        if 'date_before' in self.filters:
            date_before = self.filters['date_before']
            filtered = [m for m in filtered
                       if m['metadata'].get('date', '') <= date_before]

        # Filtro por keywords
        if 'has_keywords' in self.filters:
            keywords = self.filters['has_keywords']
            filtered = [m for m in filtered
                       if any(kw.lower() in m['text'].lower() for kw in keywords)]

        if 'exclude_keywords' in self.filters:
            keywords = self.filters['exclude_keywords']
            filtered = [m for m in filtered
                       if not any(kw.lower() in m['text'].lower() for kw in keywords)]

        return filtered

    def generate_summary(self, db_path: str = "/opt/apps/cli-memory-system/chroma_db") -> Dict[str, Any]:
        """
        Genera un resumen ejecutivo del workspace
        """
        messages = self.get_messages(db_path)

        if not messages:
            return {
                "total_conversations": 0,
                "total_messages": 0,
                "date_range": {},
                "sources": {},
                "topics": []
            }

        # Estadísticas básicas
        sources = {}
        for msg in messages:
            source = msg['metadata'].get('source', 'unknown')
            sources[source] = sources.get(source, 0) + 1

        # Rango de fechas
        dates = [m['metadata'].get('date', '') for m in messages if m['metadata'].get('date')]
        date_range = {}
        if dates:
            date_range = {
                "start": min(dates),
                "end": max(dates)
            }

        # Topics (primeras palabras más frecuentes)
        all_text = ' '.join([m['text'][:200] for m in messages[:50]])
        words = all_text.lower().split()
        word_freq = {}
        for word in words:
            if len(word) > 5:  # Solo palabras significativas
                word_freq[word] = word_freq.get(word, 0) + 1

        top_topics = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)[:10]

        return {
            "name": self.name,
            "total_conversations": len(self.conversations),
            "total_messages": len(messages),
            "date_range": date_range,
            "sources": sources,
            "topics": [t[0] for t in top_topics],
            "filters_applied": self.filters,
            "metadata": self.metadata
        }

    def export(self, format: str = "markdown", db_path: str = "/opt/apps/cli-memory-system/chroma_db") -> str:
        """
        Exporta el workspace en diferentes formatos

        Formatos:
        - markdown: Para lectura humana
        - claude-context: Optimizado para Claude
        - json: Estructura completa
        """
        messages = self.get_messages(db_path)

        if format == "json":
            return json.dumps({
                "workspace": self.name,
                "metadata": self.metadata,
                "conversations": self.conversations,
                "filters": self.filters,
                "messages": [{"text": m['text'], "metadata": m['metadata']} for m in messages]
            }, indent=2, ensure_ascii=False)

        elif format == "markdown":
            return self._export_markdown(messages)

        elif format == "claude-context":
            return self._export_claude_context(messages)

        else:
            raise ValueError(f"Unknown format: {format}")

    def _export_markdown(self, messages: List[Dict]) -> str:
        """Export a Markdown legible"""
        lines = [
            f"# Memory Workspace: {self.name}",
            "",
            f"**Created**: {self.metadata['created_at']}",
            f"**Modified**: {self.metadata['modified_at']}",
            f"**Conversations**: {len(self.conversations)}",
            f"**Messages**: {len(messages)}",
            ""
        ]

        if self.metadata.get('description'):
            lines.extend([
                "## Description",
                self.metadata['description'],
                ""
            ])

        if self.filters:
            lines.extend([
                "## Filters Applied",
                "```json",
                json.dumps(self.filters, indent=2),
                "```",
                ""
            ])

        lines.append("## Messages")
        lines.append("")

        current_session = None
        for msg in messages:
            session_id = msg['session_id']

            # Nueva conversación
            if session_id != current_session:
                current_session = session_id
                lines.extend([
                    "",
                    f"### Conversation: {session_id[:8]}",
                    f"**Source**: {msg['metadata'].get('source', 'unknown')}",
                    f"**Date**: {msg['metadata'].get('date', 'unknown')}",
                    ""
                ])

            # Mensaje
            lines.append(f"**Message {msg['order']}**:")
            lines.append(msg['text'])
            lines.append("")

        return '\n'.join(lines)

    def _export_claude_context(self, messages: List[Dict]) -> str:
        """Export optimizado para cargar en Claude"""
        lines = [
            f"# Context from Memory Workspace: {self.name}",
            "",
            f"This workspace contains {len(messages)} messages from {len(self.conversations)} previous conversations.",
            ""
        ]

        if self.metadata.get('description'):
            lines.extend([
                "## Purpose",
                self.metadata['description'],
                ""
            ])

        # Agrupar por conversación
        conversations = {}
        for msg in messages:
            sid = msg['session_id']
            if sid not in conversations:
                conversations[sid] = []
            conversations[sid].append(msg)

        lines.append("## Previous Conversations")
        lines.append("")

        for sid, msgs in conversations.items():
            first_msg = msgs[0]
            lines.extend([
                f"### [{first_msg['metadata'].get('source', 'unknown').upper()}] {first_msg['metadata'].get('date', 'unknown')[:10]}",
                ""
            ])

            # Solo primeros y últimos 3 mensajes para contexto
            if len(msgs) <= 6:
                for msg in msgs:
                    lines.append(msg['text'])
                    lines.append("")
            else:
                for msg in msgs[:3]:
                    lines.append(msg['text'])
                    lines.append("")

                lines.append(f"... [{len(msgs) - 6} messages omitted] ...")
                lines.append("")

                for msg in msgs[-3:]:
                    lines.append(msg['text'])
                    lines.append("")

        return '\n'.join(lines)

    def save(self):
        """Guarda el workspace a disco"""
        filepath = self.workspace_dir / f"{self.name}.json"

        data = {
            "name": self.name,
            "conversations": self.conversations,
            "filters": self.filters,
            "metadata": self.metadata
        }

        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        return str(filepath)

    @classmethod
    def load(cls, name: str, workspace_dir: str = None) -> 'MemoryWorkspace':
        """Carga un workspace desde disco"""
        if workspace_dir is None:
            workspace_dir = Path.home() / ".claude" / "memory" / "workspaces"
        else:
            workspace_dir = Path(workspace_dir)

        filepath = workspace_dir / f"{name}.json"

        if not filepath.exists():
            raise FileNotFoundError(f"Workspace '{name}' not found")

        with open(filepath, 'r') as f:
            data = json.load(f)

        workspace = cls(name, str(workspace_dir))
        workspace.conversations = data.get('conversations', [])
        workspace.filters = data.get('filters', {})
        workspace.metadata = data.get('metadata', {})

        return workspace

    @classmethod
    def list_workspaces(cls, workspace_dir: str = None) -> List[str]:
        """Lista todos los workspaces guardados"""
        if workspace_dir is None:
            workspace_dir = Path.home() / ".claude" / "memory" / "workspaces"
        else:
            workspace_dir = Path(workspace_dir)

        if not workspace_dir.exists():
            return []

        workspaces = []
        for filepath in workspace_dir.glob("*.json"):
            workspaces.append(filepath.stem)

        return sorted(workspaces)


if __name__ == "__main__":
    # Demo
    import sys

    if len(sys.argv) < 2:
        print("Usage:")
        print("  python workspace.py create <name> [description]")
        print("  python workspace.py list")
        print("  python workspace.py summary <name>")
        print("  python workspace.py export <name> [format]")
        sys.exit(1)

    command = sys.argv[1]

    if command == "create":
        name = sys.argv[2]
        desc = sys.argv[3] if len(sys.argv) > 3 else ""
        from workspace import create_workspace
        ws = MemoryWorkspace(name)
        ws.metadata['description'] = desc
        ws.save()
        print(f"✓ Created workspace: {name}")

    elif command == "list":
        workspaces = MemoryWorkspace.list_workspaces()
        print(f"Workspaces ({len(workspaces)}):")
        for ws_name in workspaces:
            print(f"  • {ws_name}")

    elif command == "summary":
        name = sys.argv[2]
        ws = MemoryWorkspace.load(name)
        summary = ws.generate_summary()
        print(json.dumps(summary, indent=2))

    elif command == "export":
        name = sys.argv[2]
        format = sys.argv[3] if len(sys.argv) > 3 else "markdown"
        ws = MemoryWorkspace.load(name)
        print(ws.export(format))
