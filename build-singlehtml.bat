cd /D %~dp0
rem rd /S /Q build

SET SPHINXOPTS=-c conf\html -t Macchinetta
call make.bat singlehtml
