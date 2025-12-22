#include <glad/gl.h>
#include <GLFW/glfw3.h>
#include <iostream>

// Callback para redimensionar la ventana
void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    glViewport(0, 0, width, height);
}

// Procesar entrada del usuario
void processInput(GLFWwindow *window) {
    if(glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);
}

int main() {
    // Inicializar GLFW
    if (!glfwInit()) {
        std::cerr << "ERROR: No se pudo inicializar GLFW" << std::endl;
        return -1;
    }

    // Configurar GLFW
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    // Crear ventana
    GLFWwindow* window = glfwCreateWindow(800, 600, "BlackHoleSim - Simulador de Agujero Negro", NULL, NULL);
    if (window == NULL) {
        std::cerr << "ERROR: No se pudo crear la ventana GLFW" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    // Cargar GLAD (glad2 API)
    if (!gladLoadGL(glfwGetProcAddress)) {
        std::cerr << "ERROR: No se pudo inicializar GLAD" << std::endl;
        return -1;
    }

    std::cout << "OpenGL Version: " << glGetString(GL_VERSION) << std::endl;

    //DEFINE EL LIENZO (Pantalla completa cuádruple)
    //Dos triángulos que cubren toda la pantalla de -1 a 1
    float vertices[] = {
        //posiciones (x, y)
        -1.0f, 1.0f,  //Arriba a la izquierda
        -1.0f, -1.0f,  //Abajo a la izquierda
        1.0f, -1.0f,   //Abajo a la derecha
        
        -1.0f, 1.0f,  //Arriba a la izquierda
        1.0f, -1.0f,  //Abajo a la derecha
        1.0f, 1.0f,   //Arriba a la derecha
    };

    //CONFIGURAR BUFFERS
    unsigned int VBO, VAO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);

    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    //Indica a OpenGL cómo leer los atributos (solo posición: 2 flotantes)
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    // Loop de renderizado
    while (!glfwWindowShouldClose(window)) {
        // Input
        processInput(window);

        // Renderizado
        //glClearColor(0.05f, 0.05f, 0.1f, 1.0f);  // Fondo azul oscuro espacial
        glClearColor(1.0f, 0.0f, 1.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        //Dibujar el lienzo
        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        // Swap buffers y procesar eventos
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    // Limpieza
    glfwTerminate();
    return 0;
}
