#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform vec2 texOffset;

varying vec4 vertColor;
varying vec4 vertTexCoord;

//constant variables.
const vec4 one = vec4(1.0);	
const vec4 two = vec4(2.0);
const vec4 lumcoeff = vec4(0.2125, 0.7154, 0.0721, 0.0);

uniform float amount;

vec4 overlay(vec4 myInput, vec4 previousmix, vec4 amt)
{
	float luminance = dot(previousmix,lumcoeff);
	float mixamount = clamp((luminance - 0.45) * 10., 0., 1.);

	vec4 branch1 = two * previousmix * myInput;
	vec4 branch2 = one - (two * (one - previousmix) * (one - myInput));
	
	vec4 result = mix(branch1, branch2, vec4(mixamount));

	return mix(previousmix, result, amt);
}

void main (void) 
{ 		
	vec4 input0 = texture2D(texture, vertTexCoord.st);
				
	vec4 luma = vec4(dot(input0, lumcoeff));

	gl_FragColor = overlay(luma, input0, vec4(amount));
} 