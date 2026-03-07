import os

def show_license_info():
    edition = "FREE"
    status = "active"
    source = "env_free"
    restore_limit = "1 GB"

    if os.environ.get("ALTIORA_LICENSE_FILE"):
        edition = "PRO"
        source = "license_file"

    print("")
    print("=== LICENSE INFO ===")
    print("")
    print("Edition :", edition)
    print("License status :", status)
    print("License source :", source)
    print("Restore limit :", restore_limit)
    print("")
