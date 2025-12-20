# Guía Rápida: Descarga de Dependencias para BlackHoleSim

Este documento te guía paso a paso para descargar las 3 bibliotecas necesarias.

## 📦 1. GLAD (OpenGL Loader)

### Descargar
1. Abre tu navegador y ve a: **https://glad.dav1d.de/**
2. Configura los siguientes parámetros:
   - **Language**: C/C++
   - **Specification**: OpenGL
   - **API** → **gl**: Version 3.3 o superior (recomendado: 4.6)
   - **Profile**: Core
   - Marca la casilla **"Generate a loader"** (debe estar marcada por defecto)
3. Click en el botón azul **"GENERATE"**
4. Click en **"glad.zip"** para descargar

### Instalar
1. Extrae el archivo `glad.zip`
2. Copia las carpetas y archivos:
   ```
   glad.zip/include/glad/     →  C:\BlackHoleSim\include\glad\
   glad.zip/include/KHR/      →  C:\BlackHoleSim\include\KHR\
   glad.zip/src/glad.c        →  C:\BlackHoleSim\src\glad.c (REEMPLAZA el existente)
   ```

---

## 🪟 2. GLFW (Window & Input Library)

### Descargar
1. Ve a: **https://www.glfw.org/download.html**
2. En la sección **"Windows pre-compiled binaries"**, descarga:
   - **64-bit Windows binaries** (el archivo ZIP más reciente)

### Instalar
1. Extrae el archivo descargado
2. Dentro del ZIP, busca la carpeta **`lib-mingw-w64`** (IMPORTANTE: usa esta, no lib-vc2022)
3. Copia:
   ```
   glfw-X.X.X/include/GLFW/           →  C:\BlackHoleSim\include\GLFW\
   glfw-X.X.X/lib-mingw-w64/glfw3.lib →  C:\BlackHoleSim\lib\glfw3.lib
   ```

> ⚠️ **Nota importante**: Usa `lib-mingw-w64` porque estamos compilando con g++ (MinGW), no con Visual Studio.

---

## 🔢 3. GLM (OpenGL Mathematics)

### Descargar
1. Ve a: **https://github.com/g-truc/glm/releases**
2. Descarga el archivo ZIP más reciente (ej: `glm-1.0.1.zip`)

### Instalar
1. Extrae el archivo descargado
2. Dentro encontrarás una carpeta llamada `glm` que contiene otra carpeta `glm`
3. Copia toda la carpeta:
   ```
   glm-X.X.X/glm/  →  C:\BlackHoleSim\include\glm\
   ```
4. Verifica que exista: `C:\BlackHoleSim\include\glm\glm\vec3.hpp`

---

## ✅ Verificación Final

Después de copiar todo, tu estructura debe verse así:

```
C:\BlackHoleSim\
├── include/
│   ├── glad/
│   │   └── glad.h          ✅ (de GLAD)
│   ├── KHR/
│   │   └── khrplatform.h   ✅ (de GLAD)
│   ├── GLFW/
│   │   └── glfw3.h         ✅ (de GLFW)
│   └── glm/
│       ├── glm/
│       │   ├── vec3.hpp    ✅ (de GLM)
│       │   └── ...más archivos
├── lib/
│   └── glfw3.lib           ✅ (de GLFW lib-mingw-w64)
├── src/
│   ├── glad.c              ✅ (de GLAD, reemplazado)
│   └── main.cpp
```

---

## 🚀 Siguiente Paso: Compilar

Una vez que hayas copiado todas las dependencias:

```powershell
cd C:\BlackHoleSim
cmake .
cmake --build .
```

Si todo está correcto, deberías ver:
```
Configurando BlackHoleSim...
Archivos fuente encontrados: ...
...
Build succeeded
```

¡Y ya tendrás tu ejecutable `BlackHoleSim.exe` listo para ejecutar!
