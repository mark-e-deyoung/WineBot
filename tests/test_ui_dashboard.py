from pathlib import Path


def test_dashboard_api_console_present():
    ui_path = Path(__file__).resolve().parent.parent / "api" / "ui" / "index.html"
    content = ui_path.read_text(encoding="utf-8")
    assert 'id="api-method"' in content
    assert 'id="api-path"' in content
    assert 'id="api-body"' in content
    assert 'id="api-send"' in content
    assert 'id="api-send-force"' in content
    assert 'id="api-idempotent"' in content
    assert 'id="api-response"' in content
    assert 'data-api-template="sessions"' in content
