#!/usr/bin/env python3
"""
Ollama Web Agent con Razonamiento - Usa modelos de reasoning como DeepSeek R1 / Kimi
Optimizado para RTX 3090

Modelos soportados:
- deepseek-r1:8b (RECOMENDADO para 3090 - 8GB VRAM)
- deepseek-r1:14b (14GB VRAM)
- deepseek-r1:32b (requiere >24GB, usar quantizado)
- qwen2.5:32b (alternativa sin reasoning)

Uso:
  python3 ollama-web-agent-reasoning.py --task "Login to turboscribe.ai with Google OAuth"
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
from datetime import datetime

class ReasoningWebAgent:
    def __init__(
        self,
        ollama_url: str = "http://localhost:11434",
        reasoning_model: str = "deepseek-r1:8b",
        vision_model: str = "llava:7b",
        headless: bool = False,
        verbose: bool = True
    ):
        self.ollama_url = ollama_url
        self.reasoning_model = reasoning_model
        self.vision_model = vision_model
        self.headless = headless
        self.verbose = verbose
        self.client = httpx.AsyncClient(timeout=180.0)
        self.action_history = []
        self.reasoning_log = []

    def log(self, message: str, level: str = "INFO"):
        """Log con timestamp"""
        if self.verbose:
            timestamp = datetime.now().strftime("%H:%M:%S")
            print(f"[{timestamp}] [{level}] {message}", flush=True)

    async def check_models(self):
        """Verifica que los modelos estén disponibles"""
        try:
            response = await self.client.get(f"{self.ollama_url}/api/tags")
            models = response.json()
            available = [m['name'] for m in models['models']]

            self.log(f"📦 Modelos disponibles: {', '.join(available)}")

            # Check reasoning model
            if not any(self.reasoning_model in m for m in available):
                self.log(f"⬇️  Descargando {self.reasoning_model}...", "WARN")
                await self.pull_model(self.reasoning_model)

            # Check vision model
            if not any(self.vision_model in m for m in available):
                self.log(f"⬇️  Descargando {self.vision_model}...", "WARN")
                await self.pull_model(self.vision_model)

            self.log("✅ Modelos listos")

        except Exception as e:
            self.log(f"❌ Error: {e}", "ERROR")
            sys.exit(1)

    async def pull_model(self, model_name: str):
        """Descarga un modelo"""
        self.log(f"📥 Descargando {model_name}... (puede tardar)")
        async with self.client.stream(
            'POST',
            f"{self.ollama_url}/api/pull",
            json={"name": model_name}
        ) as response:
            async for line in response.aiter_lines():
                if line:
                    data = json.loads(line)
                    if 'status' in data:
                        status = data['status']
                        if 'total' in data and 'completed' in data:
                            pct = (data['completed'] / data['total']) * 100
                            print(f"   {status} {pct:.1f}%", end='\r')
                        else:
                            print(f"   {status}", end='\r')
        print()
        self.log(f"✅ {model_name} descargado")

    async def analyze_screenshot_with_vision(self, screenshot_base64: str) -> str:
        """Usa modelo de visión para describir la pantalla"""
        self.log("👁️  Analizando screenshot con visión...")

        prompt = """Describe esta página web en detalle:
- ¿Qué elementos interactivos ves? (botones, inputs, links)
- ¿Hay algún formulario de login?
- ¿Ves botones de OAuth (Google, etc)?
- Describe la posición aproximada de cada elemento
- ¿La página está cargada o todavía loading?

Sé específico y técnico."""

        try:
            response = await self.client.post(
                f"{self.ollama_url}/api/generate",
                json={
                    "model": self.vision_model,
                    "prompt": prompt,
                    "images": [screenshot_base64],
                    "stream": False
                }
            )

            result = response.json()
            description = result['response']

            self.log(f"📸 Descripción: {description[:200]}...")
            return description

        except Exception as e:
            self.log(f"❌ Error en visión: {e}", "ERROR")
            return "Error analizando imagen"

    async def reason_next_action(
        self,
        task: str,
        screen_description: str,
        context: str
    ) -> Dict:
        """
        Usa modelo de razonamiento para decidir la próxima acción
        DeepSeek R1 tiene capacidades de chain-of-thought automático
        """
        self.log("🧠 Razonando próxima acción...")

        system_prompt = f"""Sos un agente web experto. Tu tarea: {task}

CONTEXTO ACTUAL:
{context}

DESCRIPCIÓN DE LA PANTALLA:
{screen_description}

ACCIONES DISPONIBLES:
- click: Hacer click en elemento (requiere selector CSS o coordenadas)
- type: Escribir texto
- press: Presionar tecla (Enter, Tab, etc)
- scroll: Hacer scroll
- wait: Esperar X segundos
- done: Tarea completada

IMPORTANTE:
1. Razoná paso a paso qué hacer
2. Si ves un botón de "Sign in with Google", hacer click ahí
3. Si ves un formulario, primero identificar los campos
4. Ser específico con selectores CSS cuando sea posible

Respondé en JSON con este formato:
{{
  "reasoning": "Mi razonamiento detallado...",
  "action": "click",
  "target": "button.sign-in-google",
  "target_description": "Botón de Google OAuth en el centro superior",
  "coordinates": {{"x": 640, "y": 200}},
  "fallback": "Si no funciona el selector, usar coordenadas",
  "confidence": 0.9
}}

RAZONA Y DECIDE:"""

        try:
            response = await self.client.post(
                f"{self.ollama_url}/api/generate",
                json={
                    "model": self.reasoning_model,
                    "prompt": system_prompt,
                    "stream": False,
                    "format": "json",
                    "options": {
                        "temperature": 0.3,  # Más determinístico
                        "top_p": 0.9
                    }
                }
            )

            result = response.json()
            decision = json.loads(result['response'])

            # Guardar razonamiento
            self.reasoning_log.append({
                "step": len(self.action_history) + 1,
                "reasoning": decision.get('reasoning', ''),
                "decision": decision.get('action', ''),
                "confidence": decision.get('confidence', 0.5)
            })

            self.log(f"💭 Razonamiento: {decision.get('reasoning', '')[:150]}...")
            self.log(f"🎯 Acción: {decision.get('action')} - Confianza: {decision.get('confidence', 0):.0%}")

            return decision

        except Exception as e:
            self.log(f"❌ Error razonando: {e}", "ERROR")
            return {
                "action": "wait",
                "reasoning": f"Error: {e}",
                "confidence": 0
            }

    async def execute_action(self, page, decision: Dict):
        """Ejecuta la acción decidida"""
        action = decision.get('action', 'wait')
        target = decision.get('target', '')
        coords = decision.get('coordinates', {})

        try:
            if action == 'click':
                # Intentar selector CSS primero
                if target and not coords:
                    self.log(f"🖱️  Click en selector: {target}")
                    try:
                        await page.click(target, timeout=5000)
                        self.log("✅ Click exitoso")
                        return True
                    except Exception as e:
                        self.log(f"⚠️  Selector falló: {e}", "WARN")

                # Fallback a coordenadas
                if coords and 'x' in coords and 'y' in coords:
                    x, y = coords['x'], coords['y']
                    self.log(f"🖱️  Click en ({x}, {y})")
                    await page.mouse.click(x, y)
                    self.log("✅ Click en coordenadas")
                    return True

                # Fallback a búsqueda por texto
                target_desc = decision.get('target_description', target)
                self.log(f"🔍 Buscando: {target_desc}")
                try:
                    element = await page.get_by_text(target_desc).first
                    await element.click()
                    self.log("✅ Click por texto")
                    return True
                except:
                    self.log("❌ No se encontró el elemento", "ERROR")
                    return False

            elif action == 'type':
                value = decision.get('value', '')
                self.log(f"⌨️  Escribiendo: {value}")
                await page.keyboard.type(value, delay=100)
                return True

            elif action == 'press':
                key = decision.get('key', 'Enter')
                self.log(f"⌨️  Presionando: {key}")
                await page.keyboard.press(key)
                return True

            elif action == 'scroll':
                direction = decision.get('direction', 'down')
                amount = decision.get('amount', 500)
                self.log(f"📜 Scroll {direction} ({amount}px)")
                if direction == 'down':
                    await page.mouse.wheel(0, amount)
                else:
                    await page.mouse.wheel(0, -amount)
                return True

            elif action == 'wait':
                seconds = decision.get('seconds', 2)
                self.log(f"⏳ Esperando {seconds}s")
                await asyncio.sleep(seconds)
                return True

            elif action == 'done':
                self.log("✅ Tarea completada")
                return True

            else:
                self.log(f"❓ Acción desconocida: {action}", "WARN")
                return False

        except Exception as e:
            self.log(f"❌ Error ejecutando: {e}", "ERROR")
            return False

    async def run_task(
        self,
        task: str,
        url: str = "https://turboscribe.ai",
        max_steps: int = 15,
        save_cookies: Optional[str] = None
    ):
        """Ejecuta tarea con razonamiento paso a paso"""

        self.log("="*60)
        self.log(f"🎯 Tarea: {task}")
        self.log(f"🌐 URL: {url}")
        self.log(f"🧠 Modelo razonamiento: {self.reasoning_model}")
        self.log(f"👁️  Modelo visión: {self.vision_model}")
        self.log("="*60)

        await self.check_models()

        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=self.headless,
                args=[
                    '--disable-blink-features=AutomationControlled',
                    '--disable-dev-shm-usage'
                ]
            )

            context = await browser.new_context(
                viewport={'width': 1280, 'height': 900},
                user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
            )

            page = await context.new_page()

            self.log(f"🔗 Navegando a {url}...")
            await page.goto(url, wait_until='networkidle')
            await asyncio.sleep(3)

            for step in range(max_steps):
                self.log(f"\n{'='*60}")
                self.log(f"PASO {step + 1}/{max_steps}")
                self.log(f"{'='*60}")

                # 1. Screenshot
                screenshot = await page.screenshot(full_page=False)
                screenshot_base64 = base64.b64encode(screenshot).decode()

                # 2. Analizar con visión
                screen_description = await self.analyze_screenshot_with_vision(
                    screenshot_base64
                )

                # 3. Razonar próxima acción
                context_str = "\n".join([
                    f"Paso {i+1}: {a['action']} ({a.get('reasoning', '')[:50]}...)"
                    for i, a in enumerate(self.action_history[-3:])
                ])

                decision = await self.reason_next_action(
                    task,
                    screen_description,
                    context_str or "Primer paso"
                )

                # 4. Ejecutar acción
                success = await self.execute_action(page, decision)

                # 5. Guardar en historial
                self.action_history.append({
                    **decision,
                    "success": success,
                    "step": step + 1
                })

                # 6. Esperar estabilización
                await asyncio.sleep(2)

                # 7. Check si terminó
                if decision.get('action') == 'done':
                    self.log("\n✅ TAREA COMPLETADA")
                    break

                # 8. Check si confianza muy baja
                if decision.get('confidence', 1) < 0.3:
                    self.log("⚠️  Confianza muy baja, deteniendo", "WARN")
                    break

            # Guardar cookies si se solicitó
            if save_cookies:
                cookies = await context.cookies()
                with open(save_cookies, 'w') as f:
                    json.dump(cookies, f, indent=2)
                self.log(f"\n🍪 Cookies guardadas: {save_cookies}")

            if not self.headless:
                self.log("\n⏸️  Presioná Enter para cerrar...")
                input()

            await browser.close()

        # Resumen final
        self.log("\n" + "="*60)
        self.log("📊 RESUMEN DE EJECUCIÓN")
        self.log("="*60)

        for i, action in enumerate(self.action_history, 1):
            status = "✅" if action.get('success') else "❌"
            self.log(f"{i}. {status} {action['action']} (conf: {action.get('confidence', 0):.0%})")

        self.log(f"\n💭 Total razonamientos: {len(self.reasoning_log)}")
        self.log(f"✅ Acciones exitosas: {sum(1 for a in self.action_history if a.get('success'))}/{len(self.action_history)}")

async def main():
    parser = argparse.ArgumentParser(
        description='Agente Web con Razonamiento (DeepSeek R1 / Kimi)'
    )
    parser.add_argument('--task', required=True, help='Tarea a realizar')
    parser.add_argument('--url', default='https://turboscribe.ai', help='URL inicial')
    parser.add_argument('--reasoning-model', default='deepseek-r1:8b',
                       help='Modelo de razonamiento (default: deepseek-r1:8b)')
    parser.add_argument('--vision-model', default='llava:7b',
                       help='Modelo de visión (default: llava:7b)')
    parser.add_argument('--headless', action='store_true', help='Modo headless')
    parser.add_argument('--save-cookies', help='Guardar cookies en archivo')
    parser.add_argument('--max-steps', type=int, default=15, help='Max pasos')
    parser.add_argument('--ollama-url', default='http://localhost:11434',
                       help='URL de Ollama')
    parser.add_argument('--quiet', action='store_true', help='Menos verbose')

    args = parser.parse_args()

    agent = ReasoningWebAgent(
        ollama_url=args.ollama_url,
        reasoning_model=args.reasoning_model,
        vision_model=args.vision_model,
        headless=args.headless,
        verbose=not args.quiet
    )

    await agent.run_task(
        task=args.task,
        url=args.url,
        max_steps=args.max_steps,
        save_cookies=args.save_cookies
    )

if __name__ == "__main__":
    asyncio.run(main())
