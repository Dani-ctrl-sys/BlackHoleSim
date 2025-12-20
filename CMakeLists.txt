cmake_minimum_required(VERSION 3.10)
project(BlackHoleSim VERSION 1.0 LANGUAGES CXX C)

# Configuración del estándar C++
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Agregar directorios de inclusión
include_directories(
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/include/GLFW/include
)

# Buscar archivos fuente
file(GLOB_RECURSE SOURCES 
    "${CMAKE_SOURCE_DIR}/src/*.cpp"
    "${CMAKE_SOURCE_DIR}/src/*.c"
)

# Crear el ejecutable
add_executable(${PROJECT_NAME} ${SOURCES})

# Enlazar con las bibliotecas
# NOTA: Usamos glfw3dll.lib para enlazar con la DLL de GLFW (compatible con MinGW)
target_link_libraries(${PROJECT_NAME}
    ${CMAKE_SOURCE_DIR}/lib/lib-vc2022/glfw3dll.lib
    opengl32  # Windows OpenGL library
)

# Configuración específica para Windows/MinGW
if(WIN32)
    # Agregar bibliotecas del sistema necesarias para GLFW
    target_link_libraries(${PROJECT_NAME}
        gdi32
        user32
        kernel32
    )
endif()

# Copiar shaders al directorio de salida
file(COPY ${CMAKE_SOURCE_DIR}/shaders 
     DESTINATION ${CMAKE_BINARY_DIR})

# Configuración adicional para evitar la ventana de consola en Release (opcional)
# if(MSVC)
#     set_target_properties(${PROJECT_NAME} PROPERTIES
#         WIN32_EXECUTABLE TRUE
#     )
# endif()

# Mensaje de información
message(STATUS "Configurando BlackHoleSim...")
message(STATUS "Archivos fuente encontrados: ${SOURCES}")
message(STATUS "Directorio de inclusión: ${CMAKE_SOURCE_DIR}/include")
message(STATUS "Directorio de bibliotecas: ${CMAKE_SOURCE_DIR}/lib")
