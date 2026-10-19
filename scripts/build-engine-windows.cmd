@echo off
rem transcribe_engine.dll for Windows x64 (TRANSCRIBE_ENGINE_DLL: libtranscribe and ggml whole in one library), CUDA 13,
rem machine code for every listed architecture and no PTX; the CUDA runtime and cuBLAS come from the host application.
rem   scripts\build-engine-windows.cmd [build folder]   (from a shell without the MSVC environment: it calls vcvars64)
setlocal
set ROOT=%~dp0..
set BUILD=%~1
if "%BUILD%"=="" set BUILD=%ROOT%\build-engine
if not defined VCINSTALLDIR (
  for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do call "%%i\VC\Auxiliary\Build\vcvars64.bat" >nul
)
set VSLANG=1033
cmake -S "%ROOT%" -B "%BUILD%" -G Ninja -DCMAKE_BUILD_TYPE=Release -DTRANSCRIBE_CUDA=ON -DTRANSCRIBE_ENGINE_DLL=ON -DGGML_CUDA_NCCL=OFF -DTRANSCRIBE_BUILD_TESTS=OFF -DTRANSCRIBE_BUILD_EXAMPLES=ON "-DCMAKE_CUDA_ARCHITECTURES=75-real;80-real;86-real;89-real;90-real;100-real;120-real" || exit /b 1
cmake --build "%BUILD%" --config Release || exit /b 1
echo [OK] %BUILD%\bin\transcribe_engine.dll
