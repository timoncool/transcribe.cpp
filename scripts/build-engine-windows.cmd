@echo off
rem transcribe_engine.dll for Windows x64 (TRANSCRIBE_ENGINE_DLL: libtranscribe and ggml whole in one library).
rem   cuda (default): CUDA 13, machine code for every listed architecture and no PTX; the CUDA runtime and cuBLAS come
rem                   from the host application.
rem   vulkan:         Vulkan and the CPU, for AMD and Intel cards; needs the Vulkan SDK (VULKAN_SDK) to build.
rem   cpu:            the CPU alone, for a computer without a usable card.
rem   scripts\build-engine-windows.cmd [build folder] [cuda|vulkan|cpu]   (from a shell without the MSVC environment: it
rem   calls vcvars64)
setlocal
set ROOT=%~dp0..
set BUILD=%~1
if "%BUILD%"=="" set BUILD=%ROOT%\build-engine
set BACKEND=%~2
if "%BACKEND%"=="" set BACKEND=cuda
if not defined VCINSTALLDIR (
  for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do call "%%i\VC\Auxiliary\Build\vcvars64.bat" >nul
)
set VSLANG=1033
rem never native: users' processors are not this one; AVX2 is the floor every build takes, the host checks for it before loading
set FLAGS=-DTRANSCRIBE_ENGINE_DLL=ON -DTRANSCRIBE_BUILD_TESTS=OFF -DTRANSCRIBE_BUILD_EXAMPLES=ON -DTRANSCRIBE_X86_CONSERVATIVE=ON -DGGML_SSE42=ON -DGGML_AVX=ON -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON -DGGML_BMI2=ON
if "%BACKEND%"=="cuda" set FLAGS=%FLAGS% -DTRANSCRIBE_CUDA=ON -DGGML_CUDA_NCCL=OFF "-DCMAKE_CUDA_ARCHITECTURES=75-real;80-real;86-real;89-real;90-real;100-real;120-real"
if "%BACKEND%"=="vulkan" set FLAGS=%FLAGS% -DTRANSCRIBE_VULKAN=ON
if not "%BACKEND%"=="cuda" if not "%BACKEND%"=="vulkan" if not "%BACKEND%"=="cpu" (
  echo [ERROR] backend %BACKEND%: cuda, vulkan or cpu
  exit /b 1
)
cmake -S "%ROOT%" -B "%BUILD%" -G Ninja -DCMAKE_BUILD_TYPE=Release %FLAGS% || exit /b 1
cmake --build "%BUILD%" --config Release || exit /b 1
echo [OK] %BUILD%\bin\transcribe_engine.dll (%BACKEND%)
