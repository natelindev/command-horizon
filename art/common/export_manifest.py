"""Keep authored asset metadata consistent after an existing partial export."""
import json


def merge_partial(path, generated):
    """Update existing identities while retaining the complete catalogue order."""
    if not path.exists():
        return
    catalogue = json.loads(path.read_text())
    updates = {entry["name"]: entry for entry in generated}
    for entry in catalogue:
        if entry["name"] in updates:
            entry.update(updates[entry["name"]])
    path.write_text(json.dumps(catalogue, indent=2) + "\n")
