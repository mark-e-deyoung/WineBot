import requests
import time
from playwright.sync_api import Page, expect
import pytest
import re

API_URL = "http://winebot-interactive:8000"


@pytest.fixture(autouse=True)
def setup_dashboard(page: Page):
    """Ensure we start with a clean dashboard in Dev Mode."""
    # Add a retry for when the API is coming back from a previous test
    for _ in range(5):
        try:
            page.goto(f"{API_URL}/ui/")
            break
        except Exception:
            time.sleep(2)
    else:
        page.goto(f"{API_URL}/ui/")

    # Enable Dev Mode
    page.click(".mode-toggle", force=True)
    yield


def test_a_palette_policy_compliance(page: Page):
    """Verify that the UI strictly adheres to the Cyber-Industrial Dark palette."""
    # Defined in visual-style-and-ux-policy.md
    # We check the CSS variables on the :root (html) element
    expected_palette = {
        "--bg": "#0b1114",
        "--accent": "#4dd0a1",
        "--accent-2": "#5ec4ff",
        "--danger": "#ff6b6b",
    }

    html = page.locator("html")
    for var, expected_val in expected_palette.items():
        actual_val = html.evaluate(
            f"(el) => getComputedStyle(el).getPropertyValue('{var}').trim()"
        )
        assert (
            actual_val.lower() == expected_val.lower()
        ), f"Style violation: {var} is {actual_val}, expected {expected_val}"


def test_b_recording_state_machine_ui(page: Page):
    """Verify that UI controls correctly reflect the Recording State Machine."""

    # 1. Verify Initial IDLE state
    # Expand section if collapsed
    section = page.locator(".panel-section", has_text="Actions & Artifacts")
    expect(section).to_be_visible()

    toggle = section.locator(".section-toggle")
    if toggle.get_attribute("aria-expanded") == "false":
        toggle.click()
        # Wait for CSS transition
        time.sleep(1)

    # Wait for buttons to be ready (after polling)
    # The panel might be hidden if WINEBOT_RECORD=0, but we run with =1
    recording_panel = page.locator("#recording-panel")
    expect(recording_panel).to_be_visible(timeout=10000)

    start_btn = page.locator("#btn-record-start")
    pause_btn = page.locator("#btn-record-pause")
    stop_btn = page.locator("#btn-record-stop")

    # Wait for visibility
    expect(start_btn).to_be_visible(timeout=10000)
    
    # Wait for first poll to settle UI
    expect(page.locator("#badge-health")).not_to_contain_text("pending", timeout=15000)

    # Reset to idle if needed (force stop via API if UI is stuck)
    requests.post(f"{API_URL}/recording/stop")
    time.sleep(2) # Settle
    
    expect(start_btn).to_be_enabled(timeout=10000)
    expect(pause_btn).to_be_disabled()
    expect(stop_btn).to_be_disabled()

    # 2. Transition to RECORDING
    start_btn.click()
    expect(
        page.locator(".toast", has_text="Recording start successful")
    ).to_be_visible()

    # Wait for poll to sync state
    expect(start_btn).to_be_disabled(timeout=10000)
    expect(pause_btn).to_be_enabled()
    expect(stop_btn).to_be_enabled()

    # 3. Transition to PAUSED
    pause_btn.click()
    expect(
        page.locator(".toast", has_text="Recording pause successful")
    ).to_be_visible()
    expect(pause_btn).to_be_disabled(timeout=10000)
    expect(page.locator("#badge-recording")).to_contain_text("paused")

    # 4. Transition to STOPPED/IDLE
    stop_btn.click()
    expect(page.locator(".toast", has_text="Recording stop successful")).to_be_visible()
    expect(stop_btn).to_be_disabled(timeout=10000)
    expect(start_btn).to_be_enabled()


def test_c_ux_informativeness_badges(page: Page):
    """Verify that specific API errors result in informative UI badges."""
    summary_title = page.locator("#health-summary-title")
    expect(summary_title).to_have_text("System Operational", timeout=15000)

    # Stop Openbox again to see if the badge updates
    requests.post(
        f"{API_URL}/apps/run",
        json={"path": "pkill", "args": "-f openbox", "detach": False},
    )

    openbox_badge = page.locator("#badge-openbox")
    expect(openbox_badge).to_contain_text("down", timeout=15000)
    expect(openbox_badge).to_have_class(re.compile("error"))

    # Restore
    requests.post(f"{API_URL}/apps/run", json={"path": "openbox", "detach": True})
    expect(openbox_badge).to_contain_text("running", timeout=15000)


@pytest.mark.order(-1)  # Run last as it kills the API
def test_z_connection_backoff_ux(page: Page):
    """Verify that Dashboard enters backoff mode and displays the overlay when API is lost."""

    # Verify we are polling
    expect(page.locator("#badge-health")).to_contain_text("ok", timeout=15000)

    # Simulate API downtime by killing uvicorn
    requests.post(
        f"{API_URL}/apps/run", json={"path": "pkill", "args": "-f uvicorn", "detach": False}
    )

    # Wait for the UI to notice the failure (streak >= 2 polls = ~10s)
    overlay = page.locator("#session-ended")
    expect(overlay).to_be_visible(timeout=20000)
    expect(overlay).to_contain_text("API disconnected")
