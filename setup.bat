@echo off
echo Starting setup... > setup_status.log
call flutter create --project-name janggi_master . > flutter_setup.log 2>&1
if %errorlevel% neq 0 echo Flutter create failed >> setup_status.log
echo Flutter create done. >> setup_status.log

echo Cloning Fairy-Stockfish... >> setup_status.log
if not exist native_lib mkdir native_lib
git clone https://github.com/ianfab/Fairy-Stockfish.git native_lib > git_setup.log 2>&1
if %errorlevel% neq 0 echo Git clone failed >> setup_status.log
echo Git clone done. >> setup_status.log
