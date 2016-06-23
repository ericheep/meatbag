#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform vec2 texOffset;

varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform vec2 resolution;

uniform float contrast;

float step_w = 0.0;
float step_h = 0.0;

void main(void) {

  step_w = 1.0/resolution.x;
  step_h = 1.0/resolution.y;

  vec4 color = texture2D(texture, vertTexCoord.st);

  const vec4 lum = vec4(0.2125, 0.7154, 0.0721, 1.0);
  vec4 avg = vec4(0.5, 0.5, 0.5, 1.0);
  vec4 intensity = vec4(dot(color, lum));

  vec4 sat = mix(intensity, color, 1.0);
  vec4 con = mix(avg, sat, contrast);

  gl_FragColor = con;
}