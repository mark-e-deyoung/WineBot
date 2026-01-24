FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN if [ -f /etc/apt/sources.list ]; then \
        sed -i 's/ main/ main contrib non-free non-free-firmware/' /etc/apt/sources.list; \
    elif [ -f /etc/apt/sources.list.d/debian.sources ]; then \
        sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources; \
    fi \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        wine wine64 wine32 winetricks cabextract \
        xvfb xauth openbox xdotool wmctrl x11vnc novnc websockify \
        python3 python3-pip python3-opencv gdb \
        imagemagick x11-utils procps \
        ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/.X11-unix \
    && chmod 1777 /tmp/.X11-unix

RUN useradd -m -u 1000 -s /bin/bash winebot \
    && mkdir -p /wineprefix /apps /automation \
    && chmod 777 /wineprefix \
    && chown -R winebot:winebot /apps /automation

ENV WINEPREFIX=/wineprefix \
    DISPLAY=:99 \
    SCREEN=1920x1080x24 \
    MODE=headless \
    INIT_PREFIX=1 \
    ENABLE_VNC=0 \
    VNC_PORT=5900 \
    NOVNC_PORT=6080

COPY automation /automation
COPY docker/entrypoint.sh /entrypoint.sh
RUN chown -R winebot:winebot /automation \
    && chmod +x /automation/screenshot.sh /automation/click_xy.sh /automation/find_and_click.py /automation/notepad_create_and_verify.py
RUN chmod +x /entrypoint.sh

WORKDIR /
ENTRYPOINT ["/entrypoint.sh"]
