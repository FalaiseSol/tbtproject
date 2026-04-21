@echo off
pip install pyinstaller --quiet
pyinstaller --onefile --noconsole --name TBT_Launcher launcher.py
echo.
echo Done! Find TBT_Launcher.exe in the dist\ folder.
pause
