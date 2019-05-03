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
vec3 amb = vec3(1.0);
vec3 atte = vec3(0.89,0.01,0.1);

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

float distSphere(vec3 p,float r)
{
	return length(p) - r;	
}
float distCone( in vec3 p, in float r1, float r2, float h )
{
    vec2 q = vec2( length(p.xz), p.y );
    
    float b = (r1-r2)/h;
    float a = sqrt(1.0-b*b);
    float k = dot(q,vec2(-b,a));
    
    if( k < 0.0 ) return length(q) - r1;
    if( k > a*h ) return length(q-vec2(0.0,h)) - r2;
        
    return dot(q, vec2(a,b) ) - r1;
}

float distBulb(vec3 p)
{
	float cy = distCylinder(p+vec3(0.0,2.0,0.0),0.07,0.3,0.8);
	float sp = distSphere(p+vec3(0.0,4.2,0.0),0.9);
	float sc = distCone(p+vec3(0.0,4.0,0.0),0.89,0.3,1.4);
	float b = distCone(p+vec3(0.0,4.0,0.0),0.3,0.2,0.4);
	
	return min(min(opSubtract(sp,sc),cy),b);
}

float distCup(vec3 p)
{
	vec3 cupRot = rotate(p,radians(-20.0),vec3(0.0,1.0,0.0));
	p = vec3(p.x,cupRot.y,p.z);
	vec3 cupOffset = vec3(0.0,-1.07,0.0);
	float c = distCylinder(p+cupOffset,0.3,0.3,0.5);
	float c2 = distCylinder(p+cupOffset + vec3(0.0,-0.2,0.0),0.265,0.3,0.4);
	float t = distTorus(p+cupOffset + vec3(0.45,0.0,0.0),vec2(0.44,0.14));
	float s = min(p.x + 0.55,1.0);
	float k = max(s,t);
	float c3 = opSubtract(c2,c);
	return smoothMin(k,c3,26.0);
}

float distDesk(vec3 p)
{
	float table = distBox(p,vec3(2.5,0.01,2.5),0.3);
	float reg1 = distBox(p + vec3(2.0,2.3,2.0),vec3(0.1,1.7,0.1),0.2);
	float reg2 = distBox(p + vec3(-2.0,2.3,-2.0),vec3(0.1,1.7,0.1),0.2);
	float reg3 = distBox(p + vec3(-2.0,2.3,2.0),vec3(0.1,1.7,0.1),0.2);
	float reg4 = distBox(p + vec3(2.0,2.3,-2.0),vec3(0.1,1.7,0.1),0.2);
	float r1 = min(reg1,reg2);
	float r2 = min(reg3,reg4);
	float r3 = min(r1,r2);
	return smoothMin(table,r3,5.0);
}

float distFloor(vec3 p)
{
	return distPlane(p+vec3(0.0,-0.06,0.0),vec3(0.0,1.0,0.0));
}


float distFunc(vec3 p)
{
	vec3 rotPos = rotate(p,radians(-50.0),vec3(0.2,1.0,0.0));
	float desk = distDesk(rotPos);
	float mgcup = distCup(rotPos);
	float flr = distFloor(rotPos);
	float bulb = distBulb(p+vec3(0.0,-12.0,0.0));
	return min(min(min(desk,mgcup),flr),bulb);
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

float getShadow(vec3 rayInit,vec3 rayLight)
{
	float h = 0.0;
	float c = 0.001;
	float r = 1.0;
	float shadowCoef = 0.3;
	for(float t = 0.0;t < 50.0;++t){
		h = distFunc(rayInit + rayLight * c);
		if(h < 0.001){return shadowCoef;}
		r = min(r,h * 4.0 / c);
		c += h;
	}
	return 1.0 - shadowCoef + r * shadowCoef;
}

vec4 minDist(vec4 d1,vec4 d2)
{
	return d1.a < d2.a ? d1 : d2;	
}

vec2 brickTile(vec2 p,float zoom)
{
	p *= zoom;
	p.x += step(1.0,mod(p.y,2.0)) * 0.5;
	return fract(p);
}
float tile(vec2 p,vec2 size)
{
	size = vec2(0.5) - size * 0.5;
	vec2 uv = smoothstep(size,size + vec2(1e-4),p);
	uv *= smoothstep(size,size+vec2(1e-4),vec2(2.0)-p);
	return uv.x * uv.y;
}

vec3 getColor(vec3 p)
{
	vec3 rotPos = rotate(p,radians(-50.0),vec3(0.2,1.0,0.0));
	vec4 color = minDist(vec4(vec3(0.53*sin(time-p.y),0.44*cos(p.x-time),0.64),distCup(rotPos)),
			    vec4(vec3(0.80,0.63,0.42),distDesk(rotPos)));
	vec4 c2 = minDist(color,vec4(vec3(0.40,0.23,0.20)*tile(brickTile(rotPos.xz,1.0),vec2(0.89)),distFloor(rotPos)));
	vec4 l = minDist(c2,vec4(vec3(pow(2.3,2.0)),distBulb(p+vec3(0.0,-12.0,0.0))));
	return l.rgb;
}

vec3 cameraMove(vec3 p)
{
	return vec3(p.x * sin(p.y) * cos(p.z),p.x * sin(p.y) * sin(p.z),p.x * cos(p.y));
}

vec4 mainImage(vec2 p)
{
	vec3 cameraPos = vec3(0.0,3.0,12.0);
	cameraPos += cameraMove(vec3(2.0,radians(20.0*time),radians(30.0*time)));
	vec3 ray = normalize(vec3(sin(fov) * p.x,sin(fov) * p.y,-cos(fov)));
	
	float dist = 0.0;
	float rayLen = 0.0;
	vec3 rayPos = cameraPos;
	for(int i = 0;i < 256;++i){
		dist = distFunc(rayPos);
		rayLen += dist;
		rayPos = cameraPos + ray * rayLen;
	}
	float shadow = 1.0;
	vec3 flagColor;
	if(abs(dist) < 0.001){
		vec3 normal = getNormal(rayPos);
		//lightPos = moveSp(lightPos);
		vec3 d = lightPos - rayPos;
		float len = length(d);
		d = normalize(d);
		float b = clamp(dot(normal,d),0.02,1.0);
		float e = smoothstep(abs(cos(time*3.0) * sin(time*0.8)),0.6,0.5) * 0.8;
		float a = e / (atte.x + atte.y * len + atte.z * len * len);
		vec3 color= getColor(rayPos);
		shadow = getShadow(rayPos + normal * 0.001,d) * smoothstep(0.05,0.99,e);
		flagColor = vec3(b*a) * color * amb;
	}else{
		flagColor = vec3(0.01);
	}
	return vec4(flagColor*max(0.5,shadow)*amb,1.0);
}

void main( void ) {
	vec2 p = (gl_FragCoord.xy * 2.0 - resolution.xy) / min(resolution.x,resolution.y);
	gl_FragColor = mainImage(p);
}