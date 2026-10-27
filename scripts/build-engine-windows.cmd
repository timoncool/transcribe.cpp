@echo off
rem transcribe_engine.dll for Windows x64 (TRANSCRIBE_ENGINE_DLL: libtranscribe and ggml whole in one library).
rem   cuda (default): CUDA 13, machine code for every listed architecture and no PTX; the CUDA runtime and cuBLAS come
rem                   from the host application.
rem   cuda12:         CUDA 12.9 (D:\Projects\_tools\cuda-12.9, MSVC 14.44), sm 52/60/61/70/75/80/86/89/90/120a and no
rem                   PTX, for the cards and drivers CUDA 13 does not run; cudart and cuBLAS 12 from the host application.
rem   vulkan:         Vulkan and the CPU, for AMD and Intel cards; needs the Vulkan SDK (VULKAN_SDK) to build.
rem   cpu:            the CPU alone, for a computer without a usable card.
rem   scripts\build-engine-windows.cmd [build folder] [cuda|cuda12|vulkan|cpu]
rem Each backend is set up by its own label: inside an if-block cmd expands %PATH% before vcvars runs.
setlocal
set ROOT=%~dp0..
set BUILD=%~1
if "%BUILD%"=="" set BUILD=%ROOT%\build-engine
set BACKEND=%~2
if "%BACKEND%"=="" set BACKEND=cuda
set VSLANG=1033
set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
rem never native: users' processors are not this one; AVX2 is the floor every build takes, the host checks for it before loading
set FLAGS=-DTRANSCRIBE_BUILD_SHARED=ON -DTRANSCRIBE_GGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DGGML_NATIVE=OFF -DTRANSCRIBE_BUILD_TESTS=OFF -DTRANSCRIBE_BUILD_EXAMPLES=OFF
if /i not "%BACKEND%"=="cuda" if /i not "%BACKEND%"=="cuda12" if /i not "%BACKEND%"=="vulkan" if /i not "%BACKEND%"=="cpu" (
  echo [ERROR] backend %BACKEND%: cuda, cuda12, vulkan or cpu
  exit /b 1
)
goto :setup_%BACKEND%

:setup_cuda
if not defined VCINSTALLDIR call "%VCVARS%" >nul
set FLAGS=%FLAGS% -DTRANSCRIBE_CUDA=ON -DGGML_CUDA_NCCL=OFF "-DCMAKE_CUDA_ARCHITECTURES=75-real;80-real;86-real;89-real;90-real;100-real;120-real"
goto :configure

:setup_cuda12
set "CUDA_PATH=D:\Projects\_tools\cuda-12.9"
call "%VCVARS%" -vcvars_ver=14.44 >nul
set "PATH=D:\Projects\_tools\cuda-12.9\bin;%PATH%"
set FLAGS=%FLAGS% -DTRANSCRIBE_CUDA=ON -DGGML_CUDA_NCCL=OFF -DCUDAToolkit_ROOT=D:/Projects/_tools/cuda-12.9 -DCMAKE_CUDA_COMPILER=D:/Projects/_tools/cuda-12.9/bin/nvcc.exe -DCMAKE_CUDA_FLAGS=-Wno-deprecated-gpu-targets "-DCMAKE_CUDA_ARCHITECTURES=52-real;60-real;61-real;70-real;75-real;80-real;86-real;89-real;90-real;120a-real"
goto :configure

:setup_vulkan
if not defined VCINSTALLDIR call "%VCVARS%" >nul
set FLAGS=%FLAGS% -DTRANSCRIBE_VULKAN=ON
goto :configure

:setup_cpu
if not defined VCINSTALLDIR call "%VCVARS%" >nul
goto :configure

:configure
where cl >nul 2>&1 || (echo [ERROR] MSVC is not set up for %BACKEND% & exit /b 1)
cmake --fresh -S "%ROOT%" -B "%BUILD%" -G Ninja -DCMAKE_BUILD_TYPE=Release %FLAGS% || exit /b 1
cmake --build "%BUILD%" --config Release || exit /b 1
echo [OK] %BUILD%\bin\transcribe_engine.dll (%BACKEND%)
