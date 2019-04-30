#ifdef GL_ES
precision mediump float;
#endif

#extension GL_OES_standard_derivatives : enable

uniform float time;
uniform vec2 mouse;
uniform vec2 resolution;

const float PI = 3.14159;
float angle = 60.0;
float fov = angle * 0.5 * PI / 180.0;

vec3 lightPos = vec3(-0.53,3.72,0.73);
vec3 atte = vec3(0.89,0.1,0.01);

vec3 moveSp(vec3 p)
{
	float axy = atan(p.y,p.x);	
	float d = min(abs(cos(axy * 2.5)) + 0.4,abs(sin(axy * 2.5)) + 1.1) * 0.32;
	return p + vec3(d+sin(time*0.73) * 3.5,d * cos(time*1.32) - 1.7,d + sin(time+0.53)*2.3+1.7);
}

float smoothMin(float d1,float d2,float k)
{
	float h = exp(-k * d1) + exp(-k * d2);
	return -log(h) / k;
}

float opSubtract(float d1,float d2)
{
	return max(-d1,d2);	
}

vec3 rotate(vec3 p,float angle,vec3 axis)
{
	vec3 a = normalize(axis);
    	float s = sin(angle);
   	float c = cos(angle);
    	float r = 1.0 - c;
   	mat3 m = mat3(
        a.x * a.x * r + c,
        a.y * a.x * r + a.z * s,
        a.z * a.x * r - a.y * s,
        a.x * a.y * r - a.z * s,
        a.y * a.y * r + c,
        a.z * a.y * r + a.x * s,
        a.x * a.z * r + a.y * s,
        a.y * a.z * r - a.x * s,
        a.z * a.z * r + c
    );
    return m * p;
}

float distBox(vec3 p,vec3 b,float r)
{
	vec3 d = abs(p) - b;
	return length(max(d,0.0)) - r
		+ min(max(d.x,max(d.y,d.z)),0.0);
}

float distCylinder(vec3 p,float ra,float rb,float h)
{
	vec2 d = vec2(length(p.xz) - 2.0 * ra + rb,abs(p.y) - h);
	return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float distTorus(vec3 p,vec2 t)
{
	vec2 r = vec2(length(p.xy)-t.x,p.z);
	return length(r) - t.y;
}

float distPlane(vec3 p,vec3 n)
{
	return dot(p,n) + 3.5;
}

float distFunc(vec3 p)
{
	vec3 rotPos = rotate(p,radians(-50.0),vec3(0.2,1.0,0.0));
	float table = distBox(rotPos,vec3(2.5,0.01,2.5),0.3);
	float reg1 = distBox(rotPos + vec3(2.0,1.9,2.0),vec3(0.1,1.5,0.1),0.2);
	float reg2 = distBox(rotPos + vec3(-2.0,1.9,-2.0),vec3(0.1,1.5,0.1),0.2);
	float reg3 = distBox(rotPos + vec3(-2.0,1.9,2.0),vec3(0.1,1.5,0.1),0.2);
	float reg4 = distBox(rotPos + vec3(2.0,1.9,-2.0),vec3(0.1,1.5,0.1),0.2);
	
	vec3 cupRot = rotate(rotPos,radians(-20.0),vec3(0.0,1.0,0.0));
	rotPos = vec3(rotPos.x,cupRot.y,rotPos.z);
	vec3 cupOffset = vec3(0.0,-1.07,0.0);
	float c = distCylinder(rotPos+cupOffset,0.3,0.3,0.5);
	float c2 = distCylinder(rotPos+cupOffset + vec3(0.0,-0.2,0.0),0.265,0.3,0.4);
	float t = distTorus(rotPos+cupOffset + vec3(0.45,0.0,0.0),vec2(0.44,0.14));
	float s = min(rotPos.x + 0.55,1.0);
	float k = max(s,t);
	float c3 = opSubtract(c2,c);
	float cup = smoothMin(k,c3,26.0);
	
	float pl = distPlane(rotPos+vec3(0.0,-0.06,0.0),vec3(0.0,1.0,0.0));
	
	float r1 = min(reg1,reg2);
	float r2 = min(reg3,reg4);
	float r3 = min(r1,r2);
	float tab = smoothMin(table,r3,5.0);
	
	float tabPl = min(tab,pl);
	return min(tabPl,cup);
}

vec3 getNormal(vec3 p)
{
	const float d = 0.001;
	return normalize(vec3(
		distFunc(p + vec3(d,0.0,0.0)) - distFunc(p + vec3(-d,0.0,0.0)),
		distFunc(p + vec3(0.0,d,0.0)) - distFunc(p + vec3(0.0,-d,0.0)),
		distFunc(p + vec3(0.0,0.0,d)) - distFunc(p + vec3(0.0,0.0,-d))
	));
}

vec3 convert(vec3 p)
{
	return vec3(p.x * sin(p.y) * cos(p.z),p.x * sin(p.y) * sin(p.z),p.x * cos(p.y));
}

vec4 mainImage(vec2 p)
{
	vec3 cameraPos = vec3(0.0,1.0,7.0);
	cameraPos += convert(vec3(2.0,radians(20.0*time),radians(30.0*time)));
	vec3 ray = normalize(vec3(sin(fov) * p.x,sin(fov) * p.y,-cos(fov)));
	
	float dist = 0.0;
	float rayLen = 0.0;
	vec3 rayPos = cameraPos;
	for(int i = 0;i < 256;++i){
		dist = distFunc(rayPos);
		rayLen += dist;
		rayPos = cameraPos + ray * rayLen;
	}
	if(abs(dist) < 0.001){
		vec3 normal = getNormal(rayPos);
		vec3 d = moveSp(lightPos) - rayPos;
		float len = length(d);
		d = normalize(d);
		float b = clamp(dot(normal,d),0.02,1.0);
		float a = 1.0 / (atte.x + atte.y * len + atte.z * len * len);
		return vec4(vec3(b * a),1.0);
	}else{
		return vec4(vec3(0.0),1.0);	
	}
}

void main( void ) {
	vec2 p = (gl_FragCoord.xy * 2.0 - resolution.xy) / min(resolution.x,resolution.y);
	gl_FragColor = mainImage(p);
}