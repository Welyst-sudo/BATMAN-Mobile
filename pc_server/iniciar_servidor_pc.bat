@echo off
title BATMAN PC Server
python -m pip install psutil
python "%~dp0bat_pc_server.py"
pause
