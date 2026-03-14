import os
import json

def _load_license_data():
    env_path = os.environ.get("ALTIORA_LICENSE_FILE")
    candidates = []

    if env_path:
        candidates.append(env_path)

    candidates.append(os.path.join(os.getcwd(), "license", "altiora_license.json"))

    for path in candidates:
        if path and os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                return data, path
            except Exception:
                return None, path

    return None, None


def get_license_snapshot():
    edition = "FREE"
    status = "active"
    source = "fallback_free"
    restore_limit = "1 GB"
    support_level = "community"
    customer = "N/A"
    features = ["backup", "verify", "restore_limited"]

    data, path = _load_license_data()

    if data:
        edition = str(data.get("edition", "FREE"))
        status = str(data.get("status", "active"))
        customer = str(data.get("customer", "N/A"))
        restore_limit = str(data.get("restore_limit", "1 GB"))
        support_level = str(data.get("support_level", "standard"))
        features = data.get("enabled_features", features)
        source = path

    return {
        "edition": edition,
        "status": status,
        "customer": customer,
        "source": source,
        "support_level": support_level,
        "restore_limit": restore_limit,
        "enabled_features": list(features),
    }


def has_feature(feature_name):
    snap = get_license_snapshot()
    features = snap.get("enabled_features", [])
    return feature_name in features


def show_license_info():
    snap = get_license_snapshot()

    print("")
    print("=== LICENSE INFO ===")
    print("")
    print("Edition :", snap["edition"])
    print("Status :", snap["status"])
    print("Customer :", snap["customer"])
    print("License source :", snap["source"])
    print("Support level :", snap["support_level"])
    print("Restore limit :", snap["restore_limit"])
    print("")

    print("Enabled features :")
    for f in snap["enabled_features"]:
        print(" -", f)

    print("")

def show_feature_check(feature_name):
    snap = get_license_snapshot()
    enabled = has_feature(feature_name)

    print("")
    print("=== FEATURE CHECK ===")
    print("")
    print("Feature :", feature_name)
    print("Enabled :", "yes" if enabled else "no")
    print("Edition :", snap["edition"])
    print("Customer :", snap["customer"])
    print("")
