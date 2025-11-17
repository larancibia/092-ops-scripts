#!/usr/bin/env python3
"""
Generador de landings profesionales para proyectos GuanacoLabs
"""

import json
import os
from pathlib import Path
from datetime import datetime

LANDING_TEMPLATE = """<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="{description}">
    <title>{project_name} | GuanacoLabs</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }}

        .container {{
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }}

        header {{
            text-align: center;
            padding: 4rem 0;
            color: white;
        }}

        .logo {{
            font-size: 3rem;
            font-weight: bold;
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }}

        .tagline {{
            font-size: 1.5rem;
            opacity: 0.9;
            font-weight: 300;
        }}

        .hero {{
            background: white;
            border-radius: 20px;
            padding: 3rem;
            margin: 2rem 0;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }}

        .hero h1 {{
            font-size: 2.5rem;
            color: #667eea;
            margin-bottom: 1rem;
        }}

        .hero p {{
            font-size: 1.2rem;
            color: #666;
            margin-bottom: 2rem;
        }}

        .features {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            margin: 3rem 0;
        }}

        .feature-card {{
            background: #f8f9fa;
            padding: 2rem;
            border-radius: 15px;
            border-left: 4px solid #667eea;
            transition: transform 0.3s ease;
        }}

        .feature-card:hover {{
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.2);
        }}

        .feature-card h3 {{
            color: #667eea;
            margin-bottom: 0.5rem;
            font-size: 1.3rem;
        }}

        .feature-card p {{
            color: #666;
        }}

        .cta-section {{
            text-align: center;
            padding: 3rem;
            background: linear-gradient(135deg, #764ba2 0%, #667eea 100%);
            border-radius: 20px;
            color: white;
            margin: 3rem 0;
        }}

        .cta-button {{
            display: inline-block;
            padding: 1rem 2rem;
            background: white;
            color: #667eea;
            text-decoration: none;
            border-radius: 50px;
            font-weight: bold;
            font-size: 1.1rem;
            margin-top: 1rem;
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }}

        .cta-button:hover {{
            transform: scale(1.05);
            box-shadow: 0 10px 30px rgba(255,255,255,0.3);
        }}

        .tech-stack {{
            background: white;
            padding: 2rem;
            border-radius: 15px;
            margin: 2rem 0;
        }}

        .tech-stack h2 {{
            color: #667eea;
            margin-bottom: 1rem;
        }}

        .tech-tags {{
            display: flex;
            flex-wrap: wrap;
            gap: 1rem;
        }}

        .tech-tag {{
            background: #667eea;
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            font-size: 0.9rem;
        }}

        footer {{
            text-align: center;
            padding: 2rem;
            color: white;
            opacity: 0.8;
        }}

        footer a {{
            color: white;
            text-decoration: none;
            font-weight: bold;
        }}

        footer a:hover {{
            text-decoration: underline;
        }}

        @media (max-width: 768px) {{
            .hero h1 {{
                font-size: 2rem;
            }}

            .logo {{
                font-size: 2rem;
            }}

            .features {{
                grid-template-columns: 1fr;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="logo">🦙 GuanacoLabs</div>
            <div class="tagline">Soluciones de Software Innovadoras</div>
        </header>

        <div class="hero">
            <h1>{project_name}</h1>
            <p>{description}</p>
        </div>

        <div class="features">
{features_html}
        </div>

{tech_stack_html}

        <div class="cta-section">
            <h2>¿Listo para comenzar?</h2>
            <p>Descubre cómo {project_name} puede transformar tu flujo de trabajo</p>
            <a href="{github_url}" class="cta-button">Ver en GitHub →</a>
        </div>

        <footer>
            <p>Desarrollado por <a href="https://guanacolabs.com" target="_blank">GuanacoLabs</a></p>
            <p>© {year} - Todos los derechos reservados</p>
        </footer>
    </div>
</body>
</html>
"""

# Información detallada de proyectos
PROJECT_INFO = {
    "coderx-ai-assistant": {
        "name": "CoderX AI Assistant",
        "description": "Asistente de codificación impulsado por IA que supera a Codex, Claude Code, Gemini y Aider. Construido con Rust, arquitectura hexagonal y TDD.",
        "features": [
            {"title": "IA Avanzada", "desc": "Supera a los principales asistentes de código del mercado"},
            {"title": "Arquitectura Hexagonal", "desc": "Código limpio, mantenible y escalable"},
            {"title": "552+ Tests", "desc": "Desarrollo guiado por pruebas (TDD) para máxima confiabilidad"},
            {"title": "Alto Rendimiento", "desc": "Construido en Rust para velocidad y eficiencia"}
        ],
        "tech": ["Rust", "AI", "TDD", "Hexagonal Architecture"]
    },
    "agro-platform": {
        "name": "AgroInsight",
        "description": "Plataforma integral de gestión agrícola - manejo de campos, decisiones de cultivos, análisis NDVI y más.",
        "features": [
            {"title": "Gestión de Campos", "desc": "Administra todos tus campos desde un solo lugar"},
            {"title": "Análisis NDVI", "desc": "Imágenes satelitales para monitoreo de cultivos"},
            {"title": "Decisiones Inteligentes", "desc": "Recomendaciones basadas en datos para mejor rendimiento"},
            {"title": "Panel de Control", "desc": "Visualiza toda tu operación agrícola en tiempo real"}
        ],
        "tech": ["Next.js", "Spring Boot", "PostgreSQL", "Satellite Imagery"]
    },
    "password-rotation-game": {
        "name": "PassGuard",
        "description": "Herramienta gamificada de rotación de contraseñas con integración Bitwarden, automatización del navegador y guía de IA.",
        "features": [
            {"title": "Gamificación", "desc": "Convierte la seguridad en una experiencia divertida"},
            {"title": "Integración Bitwarden", "desc": "Sincronización automática con tu gestor de contraseñas"},
            {"title": "Automatización", "desc": "Cambia contraseñas automáticamente en múltiples sitios"},
            {"title": "Guía IA", "desc": "Asistencia inteligente durante el proceso"}
        ],
        "tech": ["Python", "Bitwarden API", "Playwright", "AI"]
    },
    "ai-scrum-team": {
        "name": "AI Scrum Team",
        "description": "Sistema de desarrollo multi-agente usando Claude CLI - Construido con TDD desde cero.",
        "features": [
            {"title": "Multi-Agente", "desc": "Equipo completo de desarrollo impulsado por IA"},
            {"title": "Metodología Scrum", "desc": "Proceso ágil automatizado"},
            {"title": "Claude CLI", "desc": "Potenciado por el modelo más avanzado de Anthropic"},
            {"title": "TDD First", "desc": "Calidad garantizada desde el inicio"}
        ],
        "tech": ["Python", "Claude AI", "Scrum", "TDD"]
    },
    "canopy-lang": {
        "name": "Canopy Lang",
        "description": "Lenguaje de scripting experimental inspirado en árboles - sintaxis intuitiva y natural.",
        "features": [
            {"title": "Sintaxis Intuitiva", "desc": "Inspirada en la estructura de los árboles"},
            {"title": "Experimental", "desc": "Explorando nuevos paradigmas de programación"},
            {"title": "Fácil de Aprender", "desc": "Diseñado para ser accesible"},
            {"title": "Extensible", "desc": "Sistema de plugins y módulos"}
        ],
        "tech": ["Language Design", "Compiler", "Interpreter"]
    },
    "ai-investigador-system": {
        "name": "AI Investigador",
        "description": "Asistente de investigación impulsado por IA - automatiza búsquedas, análisis y síntesis de información.",
        "features": [
            {"title": "Búsqueda Inteligente", "desc": "Encuentra información relevante automáticamente"},
            {"title": "Análisis Profundo", "desc": "Procesa y analiza grandes volúmenes de datos"},
            {"title": "Síntesis Automática", "desc": "Genera resúmenes y reportes completos"},
            {"title": "Multi-Fuente", "desc": "Integra datos de múltiples fuentes"}
        ],
        "tech": ["Python", "AI", "NLP", "Web Scraping"]
    },
    "ai-dev-team": {
        "name": "AI Dev Team",
        "description": "Sistema de agentes colaborativos usando Claude Code para desarrollo end-to-end.",
        "features": [
            {"title": "Desarrollo End-to-End", "desc": "Desde el diseño hasta el deployment"},
            {"title": "Agentes Colaborativos", "desc": "Equipo de IA trabajando en conjunto"},
            {"title": "Claude Code", "desc": "Utilizando la mejor IA de codificación"},
            {"title": "Automatización Total", "desc": "Minimiza intervención manual"}
        ],
        "tech": ["Python", "Claude Code", "Multi-Agent", "DevOps"]
    },
    "money-maker-system": {
        "name": "Money Maker",
        "description": "Sistema autónomo de generación de ingresos con IA multi-agente.",
        "features": [
            {"title": "Automatización Total", "desc": "Sistema completamente autónomo"},
            {"title": "Multi-Agente", "desc": "Múltiples agentes especializados"},
            {"title": "Generación de Ingresos", "desc": "Estrategias automatizadas de monetización"},
            {"title": "Escalable", "desc": "Crece con tus necesidades"}
        ],
        "tech": ["Python", "AI Agents", "Automation", "APIs"]
    },
    "web-maxwell": {
        "name": "Maxwell",
        "description": "Plataforma web innovadora - soluciones empresariales modernas.",
        "features": [
            {"title": "Diseño Moderno", "desc": "Interfaz limpia y profesional"},
            {"title": "Alto Rendimiento", "desc": "Optimizado para velocidad"},
            {"title": "Escalable", "desc": "Crece con tu negocio"},
            {"title": "Seguro", "desc": "Prácticas de seguridad de primera clase"}
        ],
        "tech": ["Next.js", "React", "TypeScript", "Tailwind CSS"]
    },
    "trading-strategy": {
        "name": "Trading Strategy",
        "description": "Sistema de estrategias de trading automatizadas - backtesting y ejecución en tiempo real.",
        "features": [
            {"title": "Backtesting", "desc": "Prueba estrategias con datos históricos"},
            {"title": "Tiempo Real", "desc": "Ejecución automática de trades"},
            {"title": "Análisis Técnico", "desc": "Indicadores y señales avanzadas"},
            {"title": "Gestión de Riesgo", "desc": "Controles automáticos de riesgo"}
        ],
        "tech": ["Python", "Pandas", "Trading APIs", "Technical Analysis"]
    },
    "platform-deployer": {
        "name": "Platform Deployer",
        "description": "Plataforma central de deployment para proyectos GuanacoLabs - CI/CD automatizado.",
        "features": [
            {"title": "CI/CD Automatizado", "desc": "Deploy automático en cada commit"},
            {"title": "Multi-Proyecto", "desc": "Gestiona todos tus proyectos"},
            {"title": "Monitoreo", "desc": "Seguimiento de health y performance"},
            {"title": "Rollback Rápido", "desc": "Vuelve a versiones anteriores fácilmente"}
        ],
        "tech": ["Docker", "Kubernetes", "GitHub Actions", "Monitoring"]
    }
}

def generate_features_html(features):
    """Genera HTML para las features"""
    html = []
    for feature in features:
        html.append(f"""            <div class="feature-card">
                <h3>{feature['title']}</h3>
                <p>{feature['desc']}</p>
            </div>""")
    return "\n".join(html)

def generate_tech_stack_html(tech_list):
    """Genera HTML para tech stack"""
    if not tech_list:
        return ""

    tags_html = "\n".join([f'            <span class="tech-tag">{tech}</span>' for tech in tech_list])

    return f"""
        <div class="tech-stack">
            <h2>Tecnologías</h2>
            <div class="tech-tags">
{tags_html}
            </div>
        </div>"""

def generate_landing(project_id, output_dir):
    """Genera landing para un proyecto"""
    if project_id not in PROJECT_INFO:
        print(f"⚠️  Información no encontrada para: {project_id}")
        return None

    info = PROJECT_INFO[project_id]

    features_html = generate_features_html(info['features'])
    tech_stack_html = generate_tech_stack_html(info['tech'])

    landing_html = LANDING_TEMPLATE.format(
        project_name=info['name'],
        description=info['description'],
        features_html=features_html,
        tech_stack_html=tech_stack_html,
        github_url=f"https://github.com/larancibia/{project_id}",
        year=datetime.now().year
    )

    # Crear directorio de salida
    output_path = Path(output_dir) / project_id
    output_path.mkdir(parents=True, exist_ok=True)

    # Guardar landing
    landing_file = output_path / "index.html"
    landing_file.write_text(landing_html, encoding='utf-8')

    print(f"✅ Landing generada: {landing_file}")
    return landing_file

def main():
    print("🚀 Generador de Landings GuanacoLabs")
    print("="*80)

    output_dir = "/home/luis/generated-landings"
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    generated_count = 0

    for project_id in PROJECT_INFO.keys():
        try:
            result = generate_landing(project_id, output_dir)
            if result:
                generated_count += 1
        except Exception as e:
            print(f"❌ Error generando {project_id}: {e}")

    print("\n" + "="*80)
    print(f"✨ Proceso completado: {generated_count} landings generadas")
    print(f"📂 Ubicación: {output_dir}")
    print("\n💡 Próximos pasos:")
    print("   1. Revisar las landings generadas")
    print("   2. Copiar a las carpetas de proyecto correspondientes")
    print("   3. Personalizar según necesidades específicas")
    print("   4. Configurar nginx y DNS")

if __name__ == "__main__":
    main()
