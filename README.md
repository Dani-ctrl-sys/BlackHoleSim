# BlackHoleSim - Simulador de Agujero Negro

Proyecto de simulación de agujero negro usando C++ y OpenGL.

## 📁 Estructura del Proyecto

```
BlackHoleSim/
├── CMakeLists.txt        ✅ Creado
├── README.md             ✅ Este archivo
├── src/                  ✅ Código fuente
│   ├── main.cpp          ✅ Lógica principal (creado)
│   └── glad.c            ⚠️  PLACEHOLDER - Requiere descarga
├── include/              ✅ Cabeceras
│   ├── glad/             ⚠️  Vacío - Requiere descarga
│   ├── KHR/              ⚠️  Vacío - Requiere descarga
│   ├── GLFW/             ⚠️  Vacío - Requiere descarga
│   └── glm/              ⚠️  Vacío - Requiere descarga
├── lib/                  ⚠️  Vacío - Requiere descarga
│   └── glfw3.lib         ⚠️  Requiere descarga
└── shaders/              ✅ Shaders GPU
    ├── vertex_core.glsl  ✅ Creado
    └── fragment_core.glsl ✅ Creado
```

## 🔧 Dependencias Requeridas

### 1. GLAD (OpenGL Loader)
**¿Qué es?** Biblioteca que carga los punteros de funciones OpenGL.

**Descargar:**
1. Visita: https://glad.dav1d.de/
2. Configura:
   - **Language**: C/C++
   - **Specification**: OpenGL
   - **API gl**: Version 3.3 (o superior, ej: 4.6)
   - **Profile**: Core
3. Click en **"Generate"**
4. Descarga el archivo ZIP

**Instalar:**
- Del ZIP descargado, copia:
  - `include/glad/` → `BlackHoleSim/include/glad/`
  - `include/KHR/` → `BlackHoleSim/include/KHR/`
  - `src/glad.c` → `BlackHoleSim/src/glad.c` (⚠️ **REEMPLAZA** el placeholder)

### 2. GLFW (Ventanas y Input)
**¿Qué es?** Biblioteca para crear ventanas, contextos OpenGL, y manejar input.

**Descargar:**
1. Visita: https://www.glfw.org/download.html
2. Descarga: **Windows pre-compiled binaries** (64-bit)

**Instalar:**
- Del ZIP descargado:
  - `include/GLFW/` → `BlackHoleSim/include/GLFW/`
  - `lib-mingw-w64/glfw3.lib` → `BlackHoleSim/lib/glfw3.lib`
    - ⚠️ Nota: Usa la versión **lib-mingw-w64** ya que estamos usando MinGW/g++

### 3. GLM (Matemáticas 3D)
**¿Qué es?** Biblioteca de matemáticas para gráficos (vectores, matrices, etc.).

**Descargar:**
1. Visita: https://github.com/g-truc/glm/releases
2. Descarga el ZIP más reciente (ej: glm-0.9.9.8.zip)

**Instalar:**
- Del ZIP descargado:
  - Toda la carpeta `glm/` → `BlackHoleSim/include/glm/`
  - (Verifica que `BlackHoleSim/include/glm/glm/vec3.hpp` exista)

## 🏗️ Compilación

### Paso 1: Verificar que las herramientas estén instaladas
```powershell
cmake --version
g++ --version
```

Si `g++` no se reconoce, agrega MinGW al PATH:
```powershell
$env:PATH += ";C:\msys64\mingw64\bin"
```

### Paso 2: Generar archivos de compilación
```powershell
cd C:\BlackHoleSim
cmake .
```

### Paso 3: Compilar el proyecto
```powershell
cmake --build .
```

### Paso 4: Ejecutar
```powershell
.\BlackHoleSim.exe
```

## ❗ Solución de Problemas

### Error: "GLAD not found"
- Asegúrate de haber descargado y copiado las carpetas `glad/` y `KHR/` a `include/`
- Reemplaza `src/glad.c` con el archivo real de GLAD

### Error: "Cannot find -lglfw3"
- Verifica que `glfw3.lib` esté en la carpeta `lib/`
- Asegúrate de usar la versión **lib-mingw-w64** de GLFW

### Error: "glm/vec3.hpp not found"
- Verifica la ruta: debe ser `include/glm/glm/vec3.hpp` (nota la doble carpeta `glm`)

### g++ no se reconoce
- Agrega MinGW al PATH permanentemente o ejecuta antes de compilar:
  ```powershell
  $env:PATH += ";C:\msys64\mingw64\bin"
  ```

## 📝 Próximos Pasos

1. ✅ Descargar las 3 dependencias (GLAD, GLFW, GLM)
2. ✅ Copiarlas a las carpetas correspondientes
3. ✅ Compilar con `cmake . && cmake --build .`
4. 🚀 ¡Empezar a programar la simulación del agujero negro!

## 📚 Recursos Adicionales

- [OpenGL Tutorial](https://learnopengl.com/)
- [GLFW Documentation](https://www.glfw.org/documentation.html)
- [GLM Documentation](https://glm.g-truc.net/)
