#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
  
out vec3 ourColor;
uniform float offsetX;
out vec3 pos;

void main()
{
    gl_Position = vec4(aPos.x + offsetX, aPos.y, aPos.z, 1.0);
    ourColor = aColor;
    pos = vec3(aPos.x + offsetX, aPos.y, aPos.z);
}