"""Fix macOS Python SSL certificate errors for HuggingFace / model downloads."""

from __future__ import annotations

import os
import ssl


def configure_ssl() -> None:
    try:
        import certifi
    except ImportError:
        return

    ca_bundle = certifi.where()
    os.environ.setdefault("SSL_CERT_FILE", ca_bundle)
    os.environ.setdefault("REQUESTS_CA_BUNDLE", ca_bundle)
    os.environ.setdefault("CURL_CA_BUNDLE", ca_bundle)

    try:
        ssl._create_default_https_context = ssl.create_default_context
    except Exception:
        pass
