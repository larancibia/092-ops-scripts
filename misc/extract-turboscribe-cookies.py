#!/usr/bin/env python3
"""
TurboScribe Cookie Extractor
Usa Playwright para extraer cookies de TurboScribe

Uso:
  # Primera vez (con UI para login manual):
  python3 extract-turboscribe-cookies.py --login

  # Extraer cookies (headless):
  python3 extract-turboscribe-cookies.py
"""

import asyncio
import json
import sys
import argparse
from pathlib import Path
from playwright.async_api import async_playwright

# Paths
SCRIPT_DIR = Path(__file__).parent
BROWSER_STATE_DIR = SCRIPT_DIR / ".playwright-state"
OUTPUT_FILE = Path("/home/luis/turboscribe-mcp/cookies.json")

async def login_and_save_state(headless=False):
    """Abre TurboScribe para login manual y guarda el estado del navegador"""
    print("🌐 Abriendo navegador para login...")
    print("📝 Logueate con Google OAuth en la ventana que se abre")
    print("⏳ Una vez logueado, esperá 5 segundos y cerrá el navegador")

    async with async_playwright() as p:
        # Lanzar navegador con UI
        browser = await p.chromium.launch(
            headless=headless,
            args=[
                '--disable-blink-features=AutomationControlled',
                '--disable-dev-shm-usage',
                '--no-sandbox'
            ]
        )

        context = await browser.new_context(
            viewport={'width': 1280, 'height': 720},
            user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        )

        page = await context.new_page()

        print("🔗 Navegando a TurboScribe...")
        await page.goto('https://turboscribe.ai', wait_until='networkidle')

        if not headless:
            print("\n" + "="*60)
            print("✋ ESPERANDO LOGIN MANUAL")
            print("="*60)
            print("1. Hacé click en 'Sign In' o 'Continue with Google'")
            print("2. Logueate con tu cuenta de Google")
            print("3. Esperá que cargue el dashboard")
            print("4. IMPORTANTE: NO cierres el navegador manualmente")
            print("5. Presioná ENTER acá cuando hayas terminado de loguearte")
            print("="*60 + "\n")

            # Esperar input del usuario
            input("Presioná ENTER cuando hayas terminado de loguearte: ")
        else:
            # En headless, esperar más tiempo
            print("⏳ Esperando 30 segundos para completar login...")
            await asyncio.sleep(30)

        # Guardar estado del navegador (incluye cookies, localStorage, etc)
        print("💾 Guardando estado del navegador...")
        BROWSER_STATE_DIR.mkdir(exist_ok=True)
        await context.storage_state(path=str(BROWSER_STATE_DIR / "state.json"))

        # También extraer cookies ahora
        cookies = await context.cookies()
        print(f"🍪 Cookies encontradas: {len(cookies)}")

        await browser.close()

        print("✅ Estado guardado exitosamente!")
        return cookies

async def extract_cookies_from_saved_state():
    """Extrae cookies usando el estado guardado del navegador"""
    if not (BROWSER_STATE_DIR / "state.json").exists():
        print("❌ No hay estado guardado del navegador.")
        print("🔧 Ejecutá primero: python3 extract-turboscribe-cookies.py --login")
        sys.exit(1)

    print("🔄 Extrayendo cookies del estado guardado...")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)

        # Cargar el estado guardado (incluye cookies)
        context = await browser.new_context(
            storage_state=str(BROWSER_STATE_DIR / "state.json")
        )

        page = await context.new_page()

        # Ir a TurboScribe para que las cookies se activen
        print("🌐 Verificando sesión en TurboScribe...")
        await page.goto('https://turboscribe.ai', wait_until='networkidle')

        # Extraer cookies
        cookies = await context.cookies()

        await browser.close()

        return cookies

async def save_cookies(cookies):
    """Guarda las cookies en formato JSON"""
    # Filtrar solo cookies de TurboScribe
    turboscribe_cookies = [
        c for c in cookies
        if 'turboscribe' in c.get('domain', '')
    ]

    print(f"🍪 Cookies de TurboScribe: {len(turboscribe_cookies)}")

    # Crear directorio si no existe
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    # Guardar
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(turboscribe_cookies, f, indent=2)

    print(f"✅ Cookies guardadas en: {OUTPUT_FILE}")

    # Mostrar preview
    print("\n📋 Preview de cookies:")
    for cookie in turboscribe_cookies[:3]:
        print(f"  - {cookie['name']}: {cookie['value'][:20]}...")
    if len(turboscribe_cookies) > 3:
        print(f"  ... y {len(turboscribe_cookies) - 3} más")

async def main():
    parser = argparse.ArgumentParser(description='Extraer cookies de TurboScribe')
    parser.add_argument('--login', action='store_true',
                       help='Modo login: abre navegador para loguearte manualmente')
    parser.add_argument('--headless', action='store_true',
                       help='Usar modo headless (solo con --login, para testing)')

    args = parser.parse_args()

    print("🍪 TurboScribe Cookie Extractor")
    print("="*60)

    if args.login:
        # Login manual y guardar estado
        cookies = await login_and_save_state(headless=args.headless)
    else:
        # Extraer cookies del estado guardado
        cookies = await extract_cookies_from_saved_state()

    # Guardar cookies
    await save_cookies(cookies)

    print("\n✅ ¡Listo! Cookies extraídas exitosamente")
    print(f"📁 Ubicación: {OUTPUT_FILE}")

if __name__ == "__main__":
    asyncio.run(main())
