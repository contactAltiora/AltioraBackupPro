import os
import sys
import threading
import queue
import subprocess
from pathlib import Path

from PySide6.QtCore import Qt, QTimer
from PySide6.QtWidgets import (
    QApplication,
    QFileDialog,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QPlainTextEdit,
    QProgressBar,
    QVBoxLayout,
    QWidget,
)


APP_TITLE = "Altiora Backup Pro v1.2"
DEFAULT_CLI_PATH = Path(r"C:\Dev\AltioraBackupPro\altiora.py")


class BackupWorker(threading.Thread):
    def __init__(self, cmd: list[str], out_queue: queue.Queue):
        super().__init__(daemon=True)
        self.cmd = cmd
        self.out_queue = out_queue

    def run(self) -> None:
        try:
            self.out_queue.put(("status", "Démarrage du backup..."))
            self.out_queue.put(("cmd", " ".join(self.cmd)))

            process = subprocess.Popen(
                self.cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
            )

            assert process.stdout is not None
            for line in process.stdout:
                self.out_queue.put(("log", line.rstrip("\n")))

            process.wait()
            self.out_queue.put(("done", process.returncode))
        except Exception as exc:
            self.out_queue.put(("error", f"{type(exc).__name__}: {exc}"))


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle(APP_TITLE)
        self.setMinimumSize(920, 650)

        self.out_queue: queue.Queue = queue.Queue()
        self.worker: BackupWorker | None = None

        self.cli_path_edit = QLineEdit(str(DEFAULT_CLI_PATH))
        self.source_edit = QLineEdit()
        self.output_edit = QLineEdit("backup.altb")
        self.password_edit = QLineEdit()
        self.password_edit.setEchoMode(QLineEdit.Password)
        self.iterations_edit = QLineEdit("300000")
        self.license_value = QLabel("Non vérifié")
        self.destination_mode_value = QLabel("AUTO")

        self.progress = QProgressBar()
        self.progress.setRange(0, 1)
        self.progress.setValue(0)
        self.progress.setTextVisible(False)

        self.status_label = QLabel("Prêt")
        self.log_output = QPlainTextEdit()
        self.log_output.setReadOnly(True)

        self.start_button = QPushButton("Start Backup")
        self.start_button.clicked.connect(self.start_backup)
        self.verify_cli_button = QPushButton("Vérifier le moteur")
        self.verify_cli_button.clicked.connect(self.verify_cli)
        self.browse_cli_button = QPushButton("Browse")
        self.browse_cli_button.clicked.connect(self.browse_cli)
        self.browse_source_button = QPushButton("Browse")
        self.browse_source_button.clicked.connect(self.browse_source)
        self.browse_output_button = QPushButton("Browse")
        self.browse_output_button.clicked.connect(self.browse_output)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.drain_queue)
        self.timer.start(150)

        self.build_ui()
        self.apply_styles()

    def build_ui(self) -> None:
        central = QWidget()
        root = QVBoxLayout(central)
        root.setContentsMargins(18, 18, 18, 18)
        root.setSpacing(14)

        title = QLabel("Altiora Backup Pro")
        title.setObjectName("title")
        subtitle = QLabel("Backup GUI v1.2 — interface simple pour lancer une sauvegarde sécurisée")
        subtitle.setObjectName("subtitle")

        root.addWidget(title)
        root.addWidget(subtitle)

        config_box = QGroupBox("Configuration")
        grid = QGridLayout(config_box)
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(10)

        grid.addWidget(QLabel("Moteur CLI"), 0, 0)
        grid.addWidget(self.cli_path_edit, 0, 1)
        grid.addWidget(self.browse_cli_button, 0, 2)

        grid.addWidget(QLabel("Source"), 1, 0)
        grid.addWidget(self.source_edit, 1, 1)
        grid.addWidget(self.browse_source_button, 1, 2)

        grid.addWidget(QLabel("Output"), 2, 0)
        grid.addWidget(self.output_edit, 2, 1)
        grid.addWidget(self.browse_output_button, 2, 2)

        grid.addWidget(QLabel("Mot de passe"), 3, 0)
        grid.addWidget(self.password_edit, 3, 1)
        grid.addWidget(QLabel(""), 3, 2)

        grid.addWidget(QLabel("PBKDF2 iterations"), 4, 0)
        grid.addWidget(self.iterations_edit, 4, 1)
        grid.addWidget(QLabel(""), 4, 2)

        info_box = QGroupBox("Informations")
        info_grid = QGridLayout(info_box)
        info_grid.addWidget(QLabel("Mode destination"), 0, 0)
        info_grid.addWidget(self.destination_mode_value, 0, 1)
        info_grid.addWidget(QLabel("Edition/licence"), 1, 0)
        info_grid.addWidget(self.license_value, 1, 1)

        actions = QHBoxLayout()
        actions.addWidget(self.verify_cli_button)
        actions.addStretch(1)
        actions.addWidget(self.start_button)

        logs_box = QGroupBox("Logs")
        logs_layout = QVBoxLayout(logs_box)
        logs_layout.addWidget(self.log_output)

        root.addWidget(config_box)
        root.addWidget(info_box)
        root.addLayout(actions)
        root.addWidget(self.progress)
        root.addWidget(self.status_label)
        root.addWidget(logs_box, 1)

        self.setCentralWidget(central)

    def apply_styles(self) -> None:
        self.setStyleSheet(
            """
            QMainWindow, QWidget {
                background: #f7f5ef;
                color: #1f2937;
                font-size: 13px;
            }
            QLabel#title {
                font-size: 26px;
                font-weight: 700;
                color: #1C2753;
            }
            QLabel#subtitle {
                font-size: 13px;
                color: #475569;
                margin-bottom: 6px;
            }
            QGroupBox {
                border: 1px solid #d6d3d1;
                border-radius: 12px;
                margin-top: 8px;
                padding-top: 14px;
                background: white;
                font-weight: 600;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 12px;
                padding: 0 4px;
                color: #1C2753;
            }
            QLineEdit, QPlainTextEdit {
                border: 1px solid #d4d4d8;
                border-radius: 10px;
                padding: 8px;
                background: white;
            }
            QPushButton {
                border: 1px solid #d4d4d8;
                border-radius: 10px;
                padding: 9px 14px;
                background: white;
                font-weight: 600;
            }
            QPushButton:hover {
                background: #f5f5f5;
            }
            QPushButton:disabled {
                color: #94a3b8;
            }
            QProgressBar {
                border: 1px solid #d4d4d8;
                border-radius: 8px;
                background: white;
                min-height: 14px;
            }
            QProgressBar::chunk {
                background: #1C2753;
                border-radius: 7px;
            }
            """
        )

    def browse_cli(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Choisir altiora.py", str(Path.home()), "Python (*.py);;Executable (*.exe)")
        if path:
            self.cli_path_edit.setText(path)

    def browse_source(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Choisir un fichier source")
        if not path:
            path = QFileDialog.getExistingDirectory(self, "Choisir un dossier source")
        if path:
            self.source_edit.setText(path)

    def browse_output(self) -> None:
        path, _ = QFileDialog.getSaveFileName(self, "Choisir le fichier de sortie", self.output_edit.text() or "backup.altb", "Altiora Backup (*.altb);;All files (*.*)")
        if path:
            self.output_edit.setText(path)

    def append_log(self, text: str) -> None:
        self.log_output.appendPlainText(text)

    def set_busy(self, busy: bool) -> None:
        self.start_button.setDisabled(busy)
        self.verify_cli_button.setDisabled(busy)
        self.browse_cli_button.setDisabled(busy)
        self.browse_source_button.setDisabled(busy)
        self.browse_output_button.setDisabled(busy)
        if busy:
            self.progress.setRange(0, 0)
        else:
            self.progress.setRange(0, 1)
            self.progress.setValue(0)

    def verify_cli(self) -> None:
        cli_path = self.cli_path_edit.text().strip()
        if not cli_path:
            QMessageBox.warning(self, APP_TITLE, "Le chemin du moteur CLI est vide.")
            return

        if not Path(cli_path).exists():
            QMessageBox.warning(self, APP_TITLE, f"Moteur introuvable :\n{cli_path}")
            return

        try:
            if cli_path.lower().endswith(".py"):
                cmd = [sys.executable, cli_path, "license-info"]
            else:
                cmd = [cli_path, "license-info"]

            completed = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=20,
            )

            output = (completed.stdout or "") + (completed.stderr or "")
            self.append_log("[VERIFY_CLI] " + " ".join(cmd))
            if output.strip():
                for line in output.splitlines():
                    self.append_log(line)

            if completed.returncode == 0:
                self.status_label.setText("Moteur CLI détecté et licence lue avec succès.")
                edition = self.extract_value(output, "Edition :") or "Détectée"
                self.license_value.setText(edition)
            else:
                self.status_label.setText("Le moteur CLI a répondu avec une erreur.")
                QMessageBox.warning(self, APP_TITLE, "Le moteur CLI a renvoyé une erreur. Consulte les logs.")
        except Exception as exc:
            QMessageBox.critical(self, APP_TITLE, f"Erreur de vérification :\n{type(exc).__name__}: {exc}")

    def extract_value(self, text: str, prefix: str) -> str | None:
        for line in text.splitlines():
            if line.strip().startswith(prefix):
                return line.split(":", 1)[1].strip()
        return None

    def start_backup(self) -> None:
        cli_path = self.cli_path_edit.text().strip()
        source = self.source_edit.text().strip()
        output = self.output_edit.text().strip()
        password = self.password_edit.text()
        iterations = self.iterations_edit.text().strip() or "300000"

        if not cli_path or not Path(cli_path).exists():
            QMessageBox.warning(self, APP_TITLE, "Le moteur CLI est introuvable.")
            return
        if not source or not Path(source).exists():
            QMessageBox.warning(self, APP_TITLE, "La source est introuvable.")
            return
        if not output:
            QMessageBox.warning(self, APP_TITLE, "Le champ output est vide.")
            return
        if not password:
            QMessageBox.warning(self, APP_TITLE, "Le mot de passe est obligatoire.")
            return
        if not iterations.isdigit():
            QMessageBox.warning(self, APP_TITLE, "Le nombre d'itérations PBKDF2 est invalide.")
            return

        if cli_path.lower().endswith(".py"):
            cmd = [
                sys.executable,
                cli_path,
                "backup",
                source,
                output,
                "-p",
                password,
                "--iterations",
                iterations,
            ]
        else:
            cmd = [
                cli_path,
                "backup",
                source,
                output,
                "-p",
                password,
                "--iterations",
                iterations,
            ]

        self.log_output.clear()
        self.destination_mode_value.setText("AUTO (ALTIORA_BACKUP_1 / ALTIORA_BACKUP_2)")
        self.status_label.setText("Backup en cours...")
        self.set_busy(True)

        self.worker = BackupWorker(cmd, self.out_queue)
        self.worker.start()

    def drain_queue(self) -> None:
        while True:
            try:
                kind, payload = self.out_queue.get_nowait()
            except queue.Empty:
                break

            if kind == "status":
                self.status_label.setText(payload)
            elif kind == "cmd":
                self.append_log("[CMD] " + payload)
            elif kind == "log":
                self.append_log(payload)
            elif kind == "error":
                self.append_log("[ERROR] " + payload)
                self.status_label.setText("Erreur pendant l'exécution.")
                self.set_busy(False)
                QMessageBox.critical(self, APP_TITLE, payload)
            elif kind == "done":
                rc = int(payload)
                self.set_busy(False)
                if rc == 0:
                    self.status_label.setText("Backup terminé avec succès.")
                    QMessageBox.information(self, APP_TITLE, "Backup terminé avec succès.")
                else:
                    self.status_label.setText(f"Backup terminé avec code {rc}.")
                    QMessageBox.warning(self, APP_TITLE, f"Le backup a échoué (code {rc}). Consulte les logs.")


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName(APP_TITLE)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
