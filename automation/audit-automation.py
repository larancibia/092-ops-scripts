#!/usr/bin/env python3
"""
Script de auditoría automatizada de proyectos GuanacoLabs
Procesa todos los repositorios y genera informe completo
"""

import json
import subprocess
import os
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple

# Configuración
BASE_PATH = Path("/home/luis")
NGINX_SITES = Path("/etc/nginx/sites-enabled")
REPORT_PATH = BASE_PATH / "mi-wiki" / f"proyectos-auditoria-{datetime.now().strftime('%Y-%m-%d')}.md"

# Repos a ignorar (archivados)
ARCHIVED_PATTERNS = [
    "archived",
    "guanacobot-app-kotlin",
    "guanacobot-python",
    "untitled-python-project",
    "ollama-custom-fork",
    "untitled-java-project",
    "guanaco-labs-old-version",
    "wellness-tracker-app"
]

class ProjectAuditor:
    def __init__(self):
        self.repos = []
        self.audit_results = []
        self.missing_landings = []
        self.errors = []

    def load_repos(self):
        """Carga lista de repositorios desde GitHub"""
        print("📚 Cargando repositorios desde GitHub...")
        result = subprocess.run(
            ["gh", "repo", "list", "larancibia", "--limit", "1000",
             "--json", "name,url,description,isPrivate,updatedAt"],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            raise Exception(f"Error cargando repos: {result.stderr}")

        all_repos = json.loads(result.stdout)

        # Filtrar archivados
        self.repos = [
            r for r in all_repos
            if not any(pattern in r.get('description', '').lower() or
                      pattern in r['name'].lower()
                      for pattern in ARCHIVED_PATTERNS)
        ]

        print(f"✅ {len(self.repos)} repositorios activos encontrados")
        print(f"🗑️  {len(all_repos) - len(self.repos)} repositorios archivados ignorados")

    def find_local_folder(self, repo_name: str) -> Optional[Path]:
        """Busca la carpeta local del proyecto"""
        # Buscar con varios patrones
        patterns = [
            repo_name,
            repo_name.replace("-", "_"),
            repo_name.replace("_", "-"),
        ]

        # Buscar en ubicaciones comunes
        search_paths = [
            BASE_PATH,
            BASE_PATH / "projects" / "active",
            BASE_PATH / "projects" / "company",
            BASE_PATH / "projects" / "experiments",
        ]

        for search_path in search_paths:
            if not search_path.exists():
                continue

            # Buscar directo
            for pattern in patterns:
                potential_path = search_path / pattern
                if potential_path.exists() and potential_path.is_dir():
                    return potential_path

            # Buscar recursivamente (hasta 3 niveles)
            try:
                result = subprocess.run(
                    ["find", str(search_path), "-maxdepth", "3", "-type", "d",
                     "-name", f"*{repo_name}*"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )

                if result.stdout.strip():
                    paths = result.stdout.strip().split('\n')
                    # Filtrar node_modules, .git, etc
                    clean_paths = [
                        p for p in paths
                        if 'node_modules' not in p and '.git' not in p
                    ]
                    if clean_paths:
                        return Path(clean_paths[0])
            except Exception as e:
                continue

        return None

    def find_landing_files(self, project_path: Path) -> List[Path]:
        """Busca archivos de landing en el proyecto"""
        landing_patterns = [
            "**/index.html",
            "**/landing.html",
            "**/landing/index.html",
            "**/public/index.html",
            "**/dist/index.html",
            "**/build/index.html",
            "**/app/page.tsx",
            "**/app/page.js",
            "**/pages/index.tsx",
            "**/pages/index.js",
        ]

        landing_files = []
        for pattern in landing_patterns:
            try:
                found = list(project_path.glob(pattern))
                # Filtrar node_modules
                found = [f for f in found if 'node_modules' not in str(f)]
                landing_files.extend(found)
            except Exception:
                continue

        return landing_files

    def extract_project_name_from_landing(self, landing_file: Path) -> Optional[str]:
        """Extrae el nombre del proyecto desde la landing"""
        try:
            content = landing_file.read_text(encoding='utf-8', errors='ignore')

            # Buscar en title
            title_match = re.search(r'<title>(.*?)</title>', content, re.IGNORECASE)
            if title_match:
                return title_match.group(1).strip()

            # Buscar en h1
            h1_match = re.search(r'<h1[^>]*>(.*?)</h1>', content, re.IGNORECASE | re.DOTALL)
            if h1_match:
                text = re.sub(r'<[^>]+>', '', h1_match.group(1))
                return text.strip()

            # Buscar en meta description
            meta_match = re.search(r'<meta[^>]*name=["\']description["\'][^>]*content=["\']([^"\']+)["\']',
                                  content, re.IGNORECASE)
            if meta_match:
                desc = meta_match.group(1).strip()
                if len(desc) < 50:  # Solo si es corto
                    return desc

        except Exception as e:
            pass

        return None

    def generate_marketable_name(self, repo_name: str, description: str = "") -> str:
        """Genera un nombre vendible basado en el repo"""
        # Mapeo de prefijos comunes a nombres vendibles
        name_mappings = {
            "ai-": "AI ",
            "dev-": "Dev",
            "doc-": "Doc",
            "med-": "Med",
            "agro-": "Agro",
            "ops-": "Ops",
            "web-": "",
            "company-guanacolabs-": "GuanacoLabs ",
            "mcp-": "MCP ",
            "fin-": "Fin",
        }

        name = repo_name
        for prefix, replacement in name_mappings.items():
            if name.startswith(prefix):
                name = replacement + name[len(prefix):]
                break

        # Convertir a Title Case y limpiar
        name = name.replace("-", " ").replace("_", " ")
        name = " ".join(word.capitalize() for word in name.split())

        # Nombres específicos conocidos
        specific_names = {
            "coderx ai assistant": "CoderX",
            "ai gmail organizer": "MailGenius",
            "ai cli memory": "CLIMemory",
            "password rotation game": "PassGuard",
            "web autoscribe": "AutoScribe",
            "botfactory saas": "BotFactory",
            "agro platform": "AgroInsight",
            "fin crypto arbitrage bot": "CryptoArb",
            "fin fintelliview": "FintelliView",
            "orthoposture": "OrthoPosture",
            "web fireman developer": "Fireman Dev",
        }

        name_lower = name.lower()
        for key, value in specific_names.items():
            if key in name_lower:
                return value

        return name

    def check_nginx_config(self, repo_name: str) -> Optional[str]:
        """Verifica si existe config nginx para el proyecto"""
        try:
            nginx_files = list(NGINX_SITES.glob("*"))
            for nginx_file in nginx_files:
                if repo_name.lower() in nginx_file.name.lower():
                    # Extraer server_name
                    content = nginx_file.read_text()
                    server_match = re.search(r'server_name\s+([^;]+);', content)
                    if server_match:
                        return server_match.group(1).strip()
        except Exception:
            pass
        return None

    def audit_project(self, repo: Dict) -> Dict:
        """Audita un proyecto completo"""
        repo_name = repo['name']
        print(f"\n🔍 Auditando: {repo_name}")

        result = {
            "repo_name": repo_name,
            "repo_url": repo['url'],
            "description": repo.get('description', ''),
            "local_path": None,
            "has_landing": False,
            "landing_files": [],
            "extracted_name": None,
            "marketable_name": None,
            "suggested_subdomain": None,
            "current_nginx_config": None,
            "features_promised": [],
            "features_missing": [],
            "needs_landing": False,
            "errors": []
        }

        # 1. Buscar carpeta local
        local_path = self.find_local_folder(repo_name)
        if local_path:
            result["local_path"] = str(local_path)
            print(f"  📁 Carpeta encontrada: {local_path}")

            # 2. Buscar landing
            landing_files = self.find_landing_files(local_path)
            if landing_files:
                result["has_landing"] = True
                result["landing_files"] = [str(f) for f in landing_files]
                print(f"  🎨 Landing encontrada: {len(landing_files)} archivos")

                # 3. Extraer nombre
                for landing in landing_files[:3]:  # Revisar primeros 3
                    extracted = self.extract_project_name_from_landing(landing)
                    if extracted:
                        result["extracted_name"] = extracted
                        print(f"  📝 Nombre extraído: {extracted}")
                        break
            else:
                result["needs_landing"] = True
                self.missing_landings.append(repo_name)
                print(f"  ❌ No tiene landing")
        else:
            print(f"  ⚠️  Carpeta local no encontrada")

        # 4. Generar nombre vendible
        marketable = self.generate_marketable_name(repo_name, result["description"])
        result["marketable_name"] = marketable
        result["suggested_subdomain"] = marketable.lower().replace(" ", "-") + ".guanacolabs.com"
        print(f"  💡 Nombre sugerido: {marketable}")
        print(f"  🌐 Subdominio sugerido: {result['suggested_subdomain']}")

        # 5. Verificar config nginx existente
        nginx_domain = self.check_nginx_config(repo_name)
        if nginx_domain:
            result["current_nginx_config"] = nginx_domain
            print(f"  ✅ Nginx configurado: {nginx_domain}")

        return result

    def run_full_audit(self):
        """Ejecuta auditoría completa"""
        print("\n" + "="*80)
        print("🚀 INICIANDO AUDITORÍA COMPLETA DE PROYECTOS GUANACOLABS")
        print("="*80)

        self.load_repos()

        print(f"\n📊 Procesando {len(self.repos)} repositorios...\n")

        for i, repo in enumerate(self.repos, 1):
            print(f"\n[{i}/{len(self.repos)}] ", end="")
            try:
                audit_result = self.audit_project(repo)
                self.audit_results.append(audit_result)
            except Exception as e:
                error_msg = f"Error auditando {repo['name']}: {str(e)}"
                print(f"  ❌ {error_msg}")
                self.errors.append(error_msg)

        print("\n" + "="*80)
        print("✅ AUDITORÍA COMPLETADA")
        print("="*80)

    def generate_report(self):
        """Genera informe markdown completo"""
        print("\n📝 Generando informe...")

        # Crear directorio si no existe
        REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)

        report = []
        report.append(f"# Auditoría de Proyectos GuanacoLabs")
        report.append(f"\n**Fecha:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"\n## Resumen Ejecutivo\n")
        report.append(f"- **Total de repositorios procesados:** {len(self.repos)}")
        report.append(f"- **Proyectos con carpeta local:** {sum(1 for r in self.audit_results if r['local_path'])}")
        report.append(f"- **Proyectos con landing:** {sum(1 for r in self.audit_results if r['has_landing'])}")
        report.append(f"- **Proyectos SIN landing:** {len(self.missing_landings)}")
        report.append(f"- **Proyectos con Nginx configurado:** {sum(1 for r in self.audit_results if r['current_nginx_config'])}")
        report.append(f"- **Errores encontrados:** {len(self.errors)}")

        report.append(f"\n## Detalle de Proyectos\n")

        for result in self.audit_results:
            report.append(f"\n### {result['repo_name']}")
            report.append(f"\n**Información básica:**")
            report.append(f"- URL: {result['repo_url']}")
            report.append(f"- Descripción: {result['description'] or 'Sin descripción'}")

            if result['local_path']:
                report.append(f"\n**Ubicación local:**")
                report.append(f"- Ruta: `{result['local_path']}`")

                if result['has_landing']:
                    report.append(f"- Landing: ✅ Encontrada ({len(result['landing_files'])} archivos)")
                    if result['extracted_name']:
                        report.append(f"- Nombre actual: **{result['extracted_name']}**")
                else:
                    report.append(f"- Landing: ❌ **NO ENCONTRADA - NECESITA CREACIÓN**")
            else:
                report.append(f"\n**Ubicación local:** ⚠️ No encontrada (repo sin código desplegable o no clonado)")

            report.append(f"\n**Branding propuesto:**")
            report.append(f"- Nombre vendible: **{result['marketable_name']}**")
            report.append(f"- Subdominio sugerido: `{result['suggested_subdomain']}`")

            if result['current_nginx_config']:
                report.append(f"- Nginx actual: `{result['current_nginx_config']}`")
            else:
                report.append(f"- Nginx: ⚠️ No configurado")

            report.append(f"\n**Acciones recomendadas:**")
            if result['needs_landing']:
                report.append(f"- [ ] Crear landing profesional")
            if not result['current_nginx_config'] and result['local_path']:
                report.append(f"- [ ] Configurar Nginx")
                report.append(f"- [ ] Crear entrada DNS en Cloudflare")
            if result['marketable_name'] != result['extracted_name']:
                report.append(f"- [ ] Considerar renombrar proyecto a: {result['marketable_name']}")

            report.append(f"\n---")

        # Sección de proyectos sin landing
        if self.missing_landings:
            report.append(f"\n## Proyectos que Necesitan Landing\n")
            for project in self.missing_landings:
                report.append(f"- {project}")

        # Errores
        if self.errors:
            report.append(f"\n## Errores Encontrados\n")
            for error in self.errors:
                report.append(f"- {error}")

        # Comandos Cloudflare
        report.append(f"\n## Comandos Cloudflare para Ejecutar Manualmente\n")
        report.append(f"\n```bash")
        report.append(f"# Requiere: CLOUDFLARE_API_TOKEN y CLOUDFLARE_ZONE_ID configurados\n")

        for result in self.audit_results:
            if result['local_path'] and not result['current_nginx_config']:
                subdomain = result['suggested_subdomain'].replace('.guanacolabs.com', '')
                report.append(f"# {result['marketable_name']}")
                report.append(f"curl -X POST 'https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records' \\")
                report.append(f"  -H 'Authorization: Bearer $CLOUDFLARE_API_TOKEN' \\")
                report.append(f"  -H 'Content-Type: application/json' \\")
                report.append(f"  --data '{{\"type\":\"A\",\"name\":\"{subdomain}\",\"content\":\"<SERVER_IP>\",\"proxied\":true}}'")
                report.append(f"")

        report.append(f"```")

        # Escribir informe
        report_content = "\n".join(report)
        REPORT_PATH.write_text(report_content, encoding='utf-8')

        print(f"✅ Informe generado en: {REPORT_PATH}")

        return report_content

def main():
    auditor = ProjectAuditor()

    try:
        auditor.run_full_audit()
        report = auditor.generate_report()

        print("\n" + "="*80)
        print("🎉 PROCESO COMPLETADO EXITOSAMENTE")
        print("="*80)
        print(f"\n📄 Ver informe completo en: {REPORT_PATH}")
        print(f"\n📊 Estadísticas finales:")
        print(f"  - Repos procesados: {len(auditor.repos)}")
        print(f"  - Con landing: {sum(1 for r in auditor.audit_results if r['has_landing'])}")
        print(f"  - Sin landing: {len(auditor.missing_landings)}")
        print(f"  - Errores: {len(auditor.errors)}")

    except Exception as e:
        print(f"\n❌ ERROR CRÍTICO: {e}")
        import traceback
        traceback.print_exc()
        return 1

    return 0

if __name__ == "__main__":
    exit(main())
