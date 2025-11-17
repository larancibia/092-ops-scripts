#!/usr/bin/env python3
"""
Ollama Web Agent - Control autónomo de navegador con LLM de visión local
Optimizado para RTX 3090 con Qwen2-VL

Uso:
  python3 ollama-web-agent.py --task "Login to turboscribe.ai with Google"
  python3 ollama-web-agent.py --task "Extract cookies from turboscribe.ai" --save-cookies cookies.json
"""

import asyncio
import json
import sys
import argparse
import base64
from pathlib import Path
from playwright.async_api import async_playwright
import httpx
from typing import Dict, List, Optional

class OllamaWebAgent:
    def __init__(
        self,
        ollama_url: str = "http://localhost:11434",
        model: str = "qwen2-vl:7b",
        headless: bool = False
    ):
        self.ollama_url = ollama_url
        self.model = model
        self.headless = headless
        self.client = httpx.AsyncClient(timeout=120.0)
        self.action_history = []

    async def check_ollama(self):
        """Verifica que Ollama esté corriendo y el modelo disponible"""
        try:
            response = await self.client.get(f"{self.ollama_url}/api/tags")
            models = response.json()

            available_models = [m['name'] for m in models['models']]
            print(f"📦 Modelos disponibles: {available_models}")

            if not any(self.model in m for m in available_models):
                print(f"⚠️  Modelo {self.model} no encontrado")
                print(f"💡 Descargándolo... (puede tardar unos minutos)")
                await self.pull_model()
            else:
                print(f"✅ Modelo {self.model} listo")

        except Exception as e:
            print(f"❌ Error conectando a Ollama: {e}")
            print(f"💡 ¿Está corriendo Ollama en {self.ollama_url}?")
            print(f"   Ejecutá: ollama serve")
            sys.exit(1)

    async def pull_model(self):
        """Descarga el modelo si no está disponible"""
        print(f"⬇️  Descargando {self.model}...")
        async with self.client.stream(
            'POST',
            f"{self.ollama_url}/api/pull",
            json={"name": self.model}
        ) as response:
            async for line in response.aiter_lines():
                if line:
                    data = json.loads(line)
                    if 'status' in data:
                        print(f"   {data['status']}", end='\r')
        print("\n✅ Modelo descargado")

    async def analyze_screenshot(
        self,
        screenshot_base64: str,
        task: str,
        context: Optional[str] = None
    ) -> Dict:
        """
        Analiza un screenshot y decide qué acción tomar

        Returns:
            {
                "action": "click" | "type" | "scroll" | "wait" | "done",
                "target": "selector CSS o descripción",
                "value": "valor a escribir (si action=type)",
                "coordinates": {"x": 100, "y": 200},
                "reasoning": "por qué tomó esta decisión"
            }
        """

        system_prompt = f"""Sos un agente web autónomo. Tu tarea es: {task}

ACCIONES DISPONIBLES:
1. click - Hacer click en un elemento
2. type - Escribir texto en un input
3. scroll - Hacer scroll (up/down)
4. wait - Esperar que algo cargue
5. done - Tarea completada

REGLAS:
- Analizá la imagen de la página web
- Decidí UNA acción específica
- Si ves un botón de Google OAuth, usá click
- Si ves un formulario, usá type
- Respondé en formato JSON estricto

CONTEXTO PREVIO:
{context or "Primera acción"}

FORMATO DE RESPUESTA:
{{
  "action": "click",
  "target": "button con texto 'Sign in with Google'",
  "coordinates": {{"x": 500, "y": 300}},
  "reasoning": "Necesito hacer login con Google OAuth"
}}
"""

        try:
            response = await self.client.post(
                f"{self.ollama_url}/api/generate",
                json={
                    "model": self.model,
                    "prompt": system_prompt,
                    "images": [screenshot_base64],
                    "stream": False,
                    "format": "json"
                }
            )

            result = response.json()
            decision = json.loads(result['response'])

            print(f"🤖 Decisión: {decision['action']}")
            print(f"💭 Razonamiento: {decision.get('reasoning', 'N/A')}")

            return decision

        except Exception as e:
            print(f"❌ Error analizando screenshot: {e}")
            return {"action": "wait", "reasoning": f"Error: {e}"}

    async def execute_action(self, page, decision: Dict):
        """Ejecuta la acción decidida por el LLM"""
        action = decision.get('action')
        target = decision.get('target', '')
        value = decision.get('value', '')
        coords = decision.get('coordinates', {})

        try:
            if action == 'click':
                if coords and 'x' in coords and 'y' in coords:
                    # Click por coordenadas
                    print(f"🖱️  Click en ({coords['x']}, {coords['y']})")
                    await page.mouse.click(coords['x'], coords['y'])
                else:
                    # Intentar buscar por texto o selector
                    print(f"🖱️  Buscando: {target}")
                    # Intentar múltiples estrategias
                    element = None

                    # 1. Por texto visible
                    try:
                        element = await page.get_by_text(target, exact=False).first
                        if element:
                            await element.click()
                            print(f"✅ Click en elemento con texto '{target}'")
                            return
                    except:
                        pass

                    # 2. Por rol y texto
                    try:
                        element = await page.get_by_role("button", name=target).first
                        if element:
                            await element.click()
                            print(f"✅ Click en botón '{target}'")
                            return
                    except:
                        pass

                    # 3. Por selector CSS genérico
                    try:
                        element = await page.query_selector(f'button:has-text("{target}")')
                        if element:
                            await element.click()
                            print(f"✅ Click en botón con texto '{target}'")
                            return
                    except:
                        pass

                    print(f"⚠️  No se pudo encontrar: {target}")

            elif action == 'type':
                print(f"⌨️  Escribiendo: {value}")
                await page.keyboard.type(value)

            elif action == 'scroll':
                direction = decision.get('direction', 'down')
                print(f"📜 Scroll {direction}")
                if direction == 'down':
                    await page.mouse.wheel(0, 500)
                else:
                    await page.mouse.wheel(0, -500)

            elif action == 'wait':
                seconds = decision.get('seconds', 2)
                print(f"⏳ Esperando {seconds}s...")
                await asyncio.sleep(seconds)

            elif action == 'done':
                print(f"✅ Tarea completada")

            else:
                print(f"❓ Acción desconocida: {action}")

        except Exception as e:
            print(f"❌ Error ejecutando acción: {e}")

    async def run_task(
        self,
        task: str,
        url: str = "https://turboscribe.ai",
        max_steps: int = 20,
        save_cookies: Optional[str] = None
    ):
        """Ejecuta una tarea web autónomamente"""

        print(f"🎯 Tarea: {task}")
        print(f"🌐 URL: {url}")
        print(f"📊 Max pasos: {max_steps}")
        print("="*60)

        await self.check_ollama()

        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=self.headless,
                args=['--disable-blink-features=AutomationControlled']
            )

            context = await browser.new_context(
                viewport={'width': 1280, 'height': 800},
                user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
            )

            page = await context.new_page()

            print(f"🔗 Navegando a {url}...")
            await page.goto(url, wait_until='networkidle')

            for step in range(max_steps):
                print(f"\n--- Paso {step + 1}/{max_steps} ---")

                # Tomar screenshot
                screenshot = await page.screenshot()
                screenshot_base64 = base64.b64encode(screenshot).decode()

                # Analizar con LLM
                context_str = "\n".join([
                    f"Paso {i+1}: {a['action']} - {a.get('reasoning', '')}"
                    for i, a in enumerate(self.action_history[-3:])
                ])

                decision = await self.analyze_screenshot(
                    screenshot_base64,
                    task,
                    context_str
                )

                # Guardar en historial
                self.action_history.append(decision)

                # Ejecutar acción
                await self.execute_action(page, decision)

                # Esperar a que la página se estabilice
                await asyncio.sleep(2)

                # Si terminó, salir
                if decision.get('action') == 'done':
                    print("\n✅ Tarea completada!")
                    break

            # Guardar cookies si se solicitó
            if save_cookies:
                cookies = await context.cookies()
                cookies_path = Path(save_cookies)
                with open(cookies_path, 'w') as f:
                    json.dump(cookies, f, indent=2)
                print(f"\n🍪 Cookies guardadas en: {cookies_path}")

            if not self.headless:
                print("\n⏸️  Presioná Enter para cerrar el navegador...")
                input()

            await browser.close()

        print("\n📊 Resumen de acciones:")
        for i, action in enumerate(self.action_history, 1):
            print(f"{i}. {action['action']} - {action.get('reasoning', 'N/A')}")

async def main():
    parser = argparse.ArgumentParser(
        description='Agente Web Autónomo con Ollama + Visión'
    )
    parser.add_argument(
        '--task',
        required=True,
        help='Tarea a realizar (ej: "Login to turboscribe.ai")'
    )
    parser.add_argument(
        '--url',
        default='https://turboscribe.ai',
        help='URL inicial'
    )
    parser.add_argument(
        '--model',
        default='qwen2-vl:7b',
        help='Modelo de Ollama (default: qwen2-vl:7b)'
    )
    parser.add_argument(
        '--headless',
        action='store_true',
        help='Ejecutar en modo headless (sin UI)'
    )
    parser.add_argument(
        '--save-cookies',
        help='Guardar cookies en este archivo'
    )
    parser.add_argument(
        '--max-steps',
        type=int,
        default=20,
        help='Máximo número de pasos'
    )
    parser.add_argument(
        '--ollama-url',
        default='http://localhost:11434',
        help='URL de Ollama'
    )

    args = parser.parse_args()

    agent = OllamaWebAgent(
        ollama_url=args.ollama_url,
        model=args.model,
        headless=args.headless
    )

    await agent.run_task(
        task=args.task,
        url=args.url,
        max_steps=args.max_steps,
        save_cookies=args.save_cookies
    )

if __name__ == "__main__":
    asyncio.run(main())
