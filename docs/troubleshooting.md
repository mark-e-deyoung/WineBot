# Troubleshooting

## Missing DLLs or runtimes

Use winetricks to install Visual C++ or .NET dependencies:

`winetricks vcrun2019`

## 32-bit vs 64-bit prefix

Some applications require 32-bit Wine:

`WINEARCH=win32`

## Fonts look wrong

Install core fonts:

`winetricks corefonts`

## No window focus

Ensure `openbox` is running and the app is visible on the virtual desktop.

## CV matching fails

Enforce a fixed resolution and avoid UI scaling. Always use the same `SCREEN` value.

## VNC security

Set `VNC_PASSWORD` and avoid exposing ports publicly. Bind to localhost when running without a password.

