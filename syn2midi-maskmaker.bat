@REM code by goombapatrol
@REM this program is used to automatically create masks for syn2midi
@REM requires imagemagick and ffmpeg
@REM see: https://github.com/minyor/syn2midi
@echo off
setlocal

pushd %~dp0

echo First set user config; delete this line when ready . . . & pause >nul & goto:eof

:::: user config ::::
set im=path\to\ImageMagick\convert.exe
set ff=path\to\ffmpeg.exe
REM default time in video to grab PNG
set "timestamp=1"
REM see reference mask.example.bmp for positioning
set "geometry=1920x100+0+765"
REM color fuzz to handle darker white keys
set "fuzz=5"
:::::::::::::::::::::

set "video=%~1"

if not defined video set /p video="Video file? "
set video="%video:"=%"
if not exist %video% echo File not found? & goto:eof

for %%v in (%video%) do (set "maskName=%%~nv")

set /p timestamp="Timestamp in video? (default %timestamp%) "
set /p geometry="Mask position? (default WxH+X+Y = %geometry%) "
set /p fuzz="Fuzz? (safe roughly 5 - 25, default %fuzz%) "

:maskMaker
%ff% -loglevel error -i %video% -ss %timestamp% -frames:v 1 -y frame.tmp.png

if not exist frame.tmp.png echo Something went wrong & goto:eof

REM crop, reduce color count
%im% frame.tmp.png -crop %geometry% -dither None -colors 3 mask.color.png
REM make whites more white and blacks more black
%im% mask.color.png -contrast-stretch 15%% mask.color.png
REM shift right, make translucent
%im% mask.color.png -page +1+0 -background none -flatten mask.R.png
%im% mask.R.png -alpha set -channel A -evaluate set 50%% mask.R.png
REM flatten
%im% mask.color.png mask.R.png -composite mask.R.png
REM remove black and white
%im% mask.R.png -fuzz %fuzz%%% -transparent white -transparent black mask.R.png

REM shift left, repeat
%im% mask.color.png -page -1+0 -background none -flatten mask.L.png
%im% mask.L.png -alpha set -channel A -evaluate set 50%% mask.L.png
%im% mask.color.png mask.L.png -composite mask.L.png
%im% mask.L.png -fuzz %fuzz%%% -transparent white -transparent black mask.L.png

REM merge both (repage to fix metadata), fill alpha with blue, insert back
%im% mask.R.png mask.L.png -composite +repage mask.merged.png
%im% mask.merged.png -background "rgba(0,0,255,255)" -flatten mask.merged.png
%im% frame.tmp.png mask.merged.png -geometry %geometry% -composite +repage mask.merged.png
REM convert to BMP
%im% mask.merged.png -type truecolor "mask.%maskName%.bmp"

REM cleanup temporary files
del frame.tmp.png & del mask.color.png & del mask.R.png & del mask.L.png & del mask.merged.png

echo Created "mask.%maskName%.bmp"

REM optionally, open it after completion; pause if script was double-clicked
REM start "" "mask.%maskName%.bmp"
@echo %cmdcmdline%|find /i """%~f0""">nul && pause

goto:eof
