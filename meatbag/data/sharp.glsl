#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform vec2 texOffset;

varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform vec2 mouse;
uniform vec2 resolution;

void main(void) {

  vec2 res = resolution;
  vec2 res2 = vec2(res.x * mouse.x, res.y * mouse.y); //*0.55
  vec2 sharpenOffset = vec2(1.0/res2.x, 1.0/res2.y);

  vec4 color = texture2D(texture, vertTexCoord.st);

  color += texture2D(texture, vec2(vertTexCoord.x, vertTexCoord.y - sharpenOffset.x));
  color -= texture2D(texture, vec2(vertTexCoord.x, vertTexCoord.y + sharpenOffset.y * -2.5)); // * mouse.x/mouse.y

  float avg = (color.r+color.g+color.b)/3.0;
  if (avg > 0.95){
  	color = color - 0.15;
  } else {
  	color = color;
  }
  gl_FragColor = color; 
}