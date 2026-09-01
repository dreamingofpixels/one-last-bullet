@echo off
cd /d "%~dp0"
python export_game_data.py
if errorlevel 1 (
    py -3 export_game_data.py
)
if errorlevel 1 (
    echo Could not run Python. Install Python and openpyxl: pip install -r requirements.txt
    pause
)
