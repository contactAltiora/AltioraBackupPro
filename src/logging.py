# src/logging.py
import logging
import os
import sys
from datetime import datetime


def get_log_dir(app_name: str = "AltioraBackupPro") -> str:
    """
    Dossier des logs :
    - Windows : %APPDATA%\AltioraBackupPro\logs
    - Autres  : ~/.altiora_backup_pro/logs
    """
    if os.name == "nt":
        base = os.environ.get("APPDATA") or os.path.expanduser("~")
        path = os.path.join(base, app_name, "logs")
    else:
        path = os.path.join(os.path.expanduser("~"), ".altiora_backup_pro", "logs")

    os.makedirs(path, exist_ok=True)
    return path


def setup_logging(name: str = "altiora") -> logging.Logger:
    log_dir = get_log_dir()
    log_file = os.path.join(
        log_dir,
        f"{name}_{datetime.now().strftime('%Y%m%d')}.log"
    )

    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)

    # éviter les doublons si rappelé plusieurs fois
    if logger.handlers:
        return logger

    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
    )

    # Log fichier (DEBUG complet)
    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(formatter)
    file_handler.setLevel(logging.DEBUG)

    # Console (INFO et +)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    console_handler.setLevel(logging.INFO)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    logger.debug("Logging Altiora initialisé")
    return logger
