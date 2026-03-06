import platform
import os

def show_system_info():
    print("")
    print("=== ALTIORA BACKUP PRO ===")
    print("")
    print("Version :", "v1.0.17")
    print("Build date :", "2026-03-06")
    print("")
    print("=== SYSTEM ===")
    print("OS :", platform.system(), platform.release())
    print("Architecture :", platform.machine())
    print("Python runtime :", platform.python_version())
    print("")
    print("=== PATHS ===")
    print("Current working directory :", os.getcwd())
    print("")
    print("System check completed.")
