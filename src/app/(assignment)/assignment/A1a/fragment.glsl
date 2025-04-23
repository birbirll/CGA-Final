precision highp float;              //// set default precision of float variables to high precision

varying vec2 vUv;                   //// screen uv coordinates (varying, from vertex shader)
uniform vec2 iResolution;           //// screen resolution (uniform, from CPU)
uniform float iTime;                //// time elapsed (uniform, from CPU)

const vec3 CAM_POS = vec3(-0.35, 1.0, -3.0); //// camera position


// Data structure to store current object hit
struct HitID {
    float dist;
    int id;
};
HitID hit_id = HitID(2000.0, -1);


//// sphere: p - query point; c - sphere center; r - sphere radius
float sdfSphere(vec3 p, vec3 c, float r)
{
    return length(p - c) - r;
}

//// plane: p - query point; h - height
float sdfPlane(vec3 p, float h)
{
    return p.y - h;
}

//// box: p - query point; c - box center; b - box half size (i.e., the box size is (2*b.x, 2*b.y, 2*b.z))
float sdfBox(vec3 p, vec3 c, vec3 b)
{
    //// your implementation starts

    vec3 d = abs(p - c) - b;
    return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
    
    //// your implementation ends
}


float sdfIntersection(float s1, float s2)
{
    return max(s1, s2);
}

float sdfUnion(float s1, float s2)
{
    return min(s1, s2);
}

float sdfSubtraction(float s1, float s2)
{
    return max(s1, -s2);
}






/**
 * Return a float value between 0.0(0s) and 1.0(10s) that represents a 10s cycle
 * Used for time-based animations
 */
float getSyncedTimeCycle() 
{
    return float(int(iTime * 60.0) % 600) / 600.0; // 10s cycle
}

/**
 * SDF for a curvy ground of sin and cos waves
 * With larger waves for hills and smaller waves for texture
 * @param p: query point
 * @param h: height of the ground
 * @return SDF value
 */
float sdfCurvyGround(vec3 p, float h) 
{
    p -= vec3(0.0, 0.0, 0.0);
    float wave = 0.3 * sin(0.5 * p.x) * cos(1.0 * p.z); // Hills and Valleys
    float texture = 0.02 * sin(40.0 * p.x) * sin(80.0 * p.z); // Texture
    return p.y - (h + wave + texture);
}


float sdfUnionSmooth(float s1, float s2, float k)
{
    return -k * log(exp(-s1 / k) + exp(-s2 / k));
}


float sdfSubtractionSmooth(float s1, float s2, float k)
{
    return -sdfUnionSmooth(-s1, s2, k);
}


float sdfEllipsoid(vec3 p, vec3 c, vec3 r)
{
    p = p - c;
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / k1;
}

/**
 * Rotate a point around a center point with given angles
 * @param p: point to rotate
 * @param c: center point
 * @param angles: rotation angles in degrees
 * @return rotated point
 */
vec3 rotateXYZ(vec3 p, vec3 c, vec3 angles)
{   
    p -= c; // Translate to origin
    angles = radians(angles);
    float c1 = cos(angles.x), s1 = sin(angles.x);
    float c2 = cos(angles.y), s2 = sin(angles.y);
    float c3 = cos(angles.z), s3 = sin(angles.z);

    mat3 m = mat3(
        c1 * c3 + s1 * s2 * s3, c2 * s3, -s1 * c3 + c1 * s2 * s3,
        -c1 * s3 + s1 * s2 * c3, c2 * c3, s1 * s3 + c1 * s2 * c3,
        s1 * c2, -s2, c1 * c2
    );

    return m * p + c; // Rotate and translate back
}

float sdfBorb(vec3 p, vec3 c, float angle, bool birbHair)
{
    
    // Rotate around the Y-axis
    float birb_move1 = 3.0 * sin(iTime * 3.0);
    float birb_move2 = 3.0 * cos(iTime * 1.0);
    vec3 local_p = rotateXYZ(p, c, vec3(angle, birb_move1, birb_move2));

    // Define the borb components
    float r = 0.2;
    vec3 head_c  = c + r * vec3(-0.1, 1.5, 0.0);
    vec3 body_c  = c + r * vec3(0.0, 0.0, 0.0);
    vec3 tail_c  = c + r * vec3(1.5, -0.3, 0.0);
    vec3 wingL_c = c + r * vec3(0.0, 0.1, -1.0);
    vec3 wingR_c = c + r * vec3(0.0, 0.1, 1.0);
    vec3 peak_c  = c + r * vec3(-1.2, 1.4, 0.0);
    vec3 eyeL_c  = c + r * vec3(-0.7, 1.6, -0.95);
    vec3 eyeR_c  = c + r * vec3(-0.7, 1.6, 0.95);
    vec3 hair1_c = c + r * vec3(-0.5, 2.6, 0.0);
    vec3 hair2_c = c + r * vec3(-0.45, 2.7, -0.2);
    vec3 hair3_c = c + r * vec3(-0.45, 2.7, 0.2);

    // Compute SDF for each part
    float head = sdfSphere(local_p, head_c, 0.9 * r);
    float body = sdfSphere(local_p, body_c, 1.3 * r);
    float tail = sdfEllipsoid(local_p, tail_c, vec3(1.2 * r, 0.6 * r, 0.6 * r));
    vec3 local_p_wing = rotateXYZ(local_p, wingL_c, vec3(0.0, 0.0, -20.0));
    float wingL = sdfEllipsoid(local_p_wing, wingL_c, vec3(0.6 * r, 1.0 * r, 1.0 * r));
    float wingR = sdfEllipsoid(local_p_wing, wingR_c, vec3(0.6 * r, 1.0 * r, 1.0 * r));
    float peak = sdfEllipsoid(local_p, peak_c, vec3(0.25 * r, 0.4 * r, 0.2 * r));
    float eyeL = sdfSphere(local_p, eyeL_c, 0.15 * r);
    float eyeR = sdfSphere(local_p, eyeR_c, 0.15 * r);

    vec3 local_p_hair = rotateXYZ(local_p, hair1_c, vec3(0.0, 0.0, 30.0));
    float hair1 = sdfEllipsoid(local_p_hair, hair1_c, vec3(0.08, 0.3, 0.2) * r * 1.7);
    local_p_hair = rotateXYZ(local_p, hair1_c, vec3(0.0, 45.0, 30.0));
    float hair2 = sdfEllipsoid(local_p_hair, hair2_c, vec3(0.08, 0.3, 0.2) * r * 1.7);
    local_p_hair = rotateXYZ(local_p, hair1_c, vec3(0.0, -45.0, 30.0));
    float hair3 = sdfEllipsoid(local_p_hair, hair3_c, vec3(0.08, 0.3, 0.2) * r * 1.7);

    // Combine the parts smoothly
    body = sdfUnionSmooth(sdfUnionSmooth(head, body, .1), tail, .1);
    float wings = sdfUnion(wingL, wingR);
    body = sdfUnion(body, peak);
    body = sdfSubtraction(body, eyeL);
    body = sdfSubtraction(body, eyeR);
    
    if (birbHair) {
        float hair = sdfUnion(sdfUnion(hair1, hair2), hair3);
        body = sdfUnionSmooth(body, hair, .01);
    }   
    return sdfUnion(body, wings);
}


float sdfCloud(vec3 p, vec3 c)
{
    float r = 0.8;
    float space = 0.8;
    float s1 = sdfSphere(p, c, r);
    float s2 = sdfSphere(p, c + r * vec3(1, 1.4, 0.0) * space, r);
    float s3 = sdfSphere(p, c + r * vec3(2, 0.0, 0.0) * space, r);
    float s4 = sdfSphere(p, c + r * vec3(3, 1.4, 0.0) * space, r);
    float s5 = sdfSphere(p, c + r * vec3(4, 0.0, 0.0) * space, r);
    // return sdfUnion(sdfUnion(sdfUnion(sdfUnion(s1, s2), s3), s4), s5);
    return sdfUnionSmooth(sdfUnionSmooth(sdfUnionSmooth(sdfUnionSmooth(s1, s2, 0.1), s3, 0.1), s4, 0.1), s5, 0.1);
}


float sdfRiver(vec3 p)
{
    float riverbody = sdfBox(p, vec3(0.0, -0.65, 0.0), vec3(2.0, 0.1, 100.0));
    float t = getSyncedTimeCycle();
    float wave = 0.0015 * cos(8.0 * p.z - t * 15.0); // Curvy wave effect
    return riverbody + wave;
}



//// sdf2: p - query point
float sdf2(vec3 p, bool record_hit)
{
    float s = 0.;

    // Calculate the SDF for each 5 objects
    float ground = sdfCurvyGround(p, -0.1);
    float mountain1 = sdfSphere(p, vec3(-5.0, -1.0, 20.0), 2.0);
    float mountain2 = sdfSphere(p, vec3(-10.0, -1.5, 30.0), 4.0);
    float mountain3 = sdfSphere(p, vec3(-15.0, -2.0, 25.0), 6.0);
    float mountain4 = sdfSphere(p, vec3(-7.0, -1.0, 15.0), 2.0);
    float mountain5 = sdfSphere(p, vec3(10.0, -1.0, 20.0), 2.0);
    float mountain6 = sdfSphere(p, vec3(13.0, -2.0, 15.0), 4.0);
    ground = sdfUnionSmooth(ground, mountain1, 0.5);
    ground = sdfUnionSmooth(ground, mountain2, 0.5);
    ground = sdfUnionSmooth(ground, mountain3, 0.5);
    ground = sdfUnionSmooth(ground, mountain4, 0.5);
    ground = sdfUnionSmooth(ground, mountain5, 0.5);
    ground = sdfUnionSmooth(ground, mountain6, 0.5);

    // change p for riverbed with respect to p.z
    vec3 riverbed_p = p + vec3(sin(p.z * 0.2), 0.0, 0.0);
    float riverbed = sdfBox(riverbed_p, vec3(0.0, 0.0, 0.0), vec3(1.0, 0.5, 100.0));
    ground = sdfSubtractionSmooth(ground, riverbed, 0.5);
    float riverbody = sdfRiver(p);


    float birb_move = 0.03 * sin(iTime / 2.0);
    float birb1 = sdfBorb(p, vec3(0.5, -0.4 - 0.2 + birb_move, -0.65 + 1.), -80.0, true);
    float birb2 = sdfBorb(p, vec3(-0.2, -0.3 - 0.2 + birb_move, 0.0 + 1.), 160.0, true);
    float birb3 = sdfBorb(p, vec3(0.6, -0.3 - 0.2 + birb_move, 0.5 + 1.), 40.0 , true);

    float background = sdfBox(p, vec3(0.0, 0.0, 50.0), vec3(100.0, 100.0, 1.0));

    // float sun_move = float(int(iTime * 60.0) % 600) / 240.0;
    float sun_move = getSyncedTimeCycle() * 3.0;
    float sun = sdfSphere(p, vec3(1.0, sun_move, 50.0), 2.5);
    
    // float cloud_move = 0.2 * sin(iTime / 1.0);
    // float cloud1 = sdfCloud(p, vec3(-10.0, 10.0, 20.0) + vec3(0.0, cloud_move, 0.0));
    // float cloud2 = sdfCloud(p, vec3(-15.0, 4.0, 15.0) + vec3(0.0, -cloud_move, 0.0));
    // float cloud3 = sdfCloud(p, vec3(12.0, 5.0, 17.0) + vec3(0.0, cloud_move, 0.0));
    // float cloud4 = sdfCloud(p, vec3(3.0, 10.0, 20.0) + vec3(0.0, -cloud_move, 0.0));
    // float cloud5 = sdfCloud(p, vec3(8.0, 3.0, 15.0) + vec3(0.0, cloud_move, 0.0));
    // float cloud6 = sdfCloud(p, vec3(10.0, 7.0, 30.0) + vec3(0.0, -cloud_move, 0.0));
    // float cloud7 = sdfCloud(p, vec3(-3.0, 8.0, 40.0) + vec3(0.0, cloud_move, 0.0));
    float cloud = sdfCloud(p, vec3(-10.0, 10.0, 20.0) + vec3(0.0, sun_move * 0.5, 0.0));

    // Combine the SDF for all objects
    float objects[] = float[](
        ground,
        birb1,
        birb2, 
        birb3,
        background,
        sun,
        cloud,
        riverbody
    );
    // Assign object ids for coloring
    int object_ids[] = int[](
        1,
        2,
        3, 
        4,
        5,
        6,
        7,
        8
    );
    s = 1000.0; // set a large initial distance for union
    for (int i = 0; i < objects.length(); i++) {
        s = sdfUnion(s, objects[i]);
        // Record the closest object hit
        if (record_hit && s < hit_id.dist) {
            hit_id.dist = s;
            hit_id.id = object_ids[i];
        }
    }

    return s;
}

/** 
 * Overload sdf2 without hit_id update
 * E.g. we don't need to know what the object is in normal calculation
 */
float sdf2(vec3 p)
{
    bool record_hit = true; // TODO: Should be false,
                            // but if I disable hit_id in normal calculation, 
                            // there will be artifacts in reflection... Don't know why yet
    return sdf2(p, record_hit);
}

//// ray marching: origin - ray origin; dir - ray direction 
float rayMarching2(vec3 origin, vec3 dir)
{
    float s = 0.0; // distance
    for(int i = 0; i < 1000; i++)
    {
        vec3 p = origin + dir * s;
        float dist = sdf2(p, true); // sdf value in p
        s += dist; // update the distance
        if (s > 200.0 || abs(dist) < 0.0001) {
            break;
        }
    }
    
    return s;
}

// Cloud shader
mat3 m = mat3( 0.00,  0.80,  0.60,
            -0.80,  0.36, -0.48,
            -0.60, -0.48,  0.64 );
float hash( float n )
{
    return fract(sin(n)*43758.5453);
}

float noise( in vec3 x )
{
    vec3 p = floor(x);
    vec3 f = fract(x);

    f = f*f*(3.0-2.0*f);

    float n = p.x + p.y*57.0 + 113.0*p.z;

    float res = mix(mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
                        mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y),
                    mix(mix( hash(n+113.0), hash(n+114.0),f.x),
                        mix( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
    return res;
}

float fbm( vec3 p )
{
    float f;
    f  = 0.5000*noise( p ); p = m*p*2.02;
    f += 0.2500*noise( p ); p = m*p*2.03;
    f += 0.12500*noise( p ); p = m*p*2.01;
    f += 0.06250*noise( p );
    return f;
}
/////////////////////////////////////


// iq's smin
float smin( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); }

float sdTorus( vec3 p, vec2 t )
{
vec2 q = vec2(length(p.xz)-t.x,p.y);
return length(q)-t.y;
}


float map( in vec3 p )
{
    p -= vec3(0.0, 5.0, 10.0);
    p *= 3.0;
    vec3 q = p - vec3(0.0,0.5,1.0)*iTime;
    float f = fbm(q);
    float torus = 1. - sdTorus(p * 2.0, vec2(6.0, 0.005)) + f * 3.5;

    return min(max(0.0, torus), 1.0);
}

float jitter;

#define MAX_STEPS 48
#define SHADOW_STEPS 8
#define VOLUME_LENGTH 15.
#define SHADOW_LENGTH 2.

// Reference
// https://shaderbits.com/blog/creating-volumetric-ray-marcher
vec4 cloudMarch(vec3 p, vec3 ray)
{
    float density = 0.;

    float stepLength = VOLUME_LENGTH / float(MAX_STEPS);
    float shadowStepLength = SHADOW_LENGTH / float(SHADOW_STEPS);
    // vec3 light = normalize(vec3(1.0, 2.0, 1.0));
    vec3 light = normalize(vec3(1.0));

    vec4 sum = vec4(0., 0., 0., 1.);
    
    vec3 pos = p + ray * jitter * stepLength;
    
    for (int i = 0; i < MAX_STEPS; i++)
    {
        if (sum.a < 0.1) {
            break;
        }
        float d = map(pos);
    
        if( d > 0.001)
        {
            vec3 lpos = pos + light * jitter * shadowStepLength;
            float shadow = 0.;
    
            for (int s = 0; s < SHADOW_STEPS; s++)
            {
                lpos += light * shadowStepLength;
                float lsample = map(lpos);
                shadow += lsample;
            }
    
            density = clamp((d / float(MAX_STEPS)) * 20.0, 0.0, 1.0);
            float s = exp((-shadow / float(SHADOW_STEPS)) * 3.);
            sum.rgb += vec3(s * density) * sum.a;
            sum.a *= 1.-density;

            vec3 sky_color = vec3(1.0, 0.64, 0.83);
            sum.rgb += exp(-map(pos + vec3(0,0.25,0.0)) * .2) 
                        * density * sky_color * sum.a;
        }
        pos += ray * stepLength;
    }

    return sum;
}





/**
 * Normal calculation for SDF2 Scene
 * @param p: intersection point query
 * @return norm: normal at the intersection point
 */
vec3 normal2(vec3 p)
{
    float s = sdf2(p); // sdf value in p
    float dx = 0.011; // Can't get smaller than this.. 
                      // 0.010 will produce wired artifacts in reflection... Don't know why yet

    vec3 norm = vec3(
        sdf2(p + vec3(dx, 0.0, 0.0)) - s, // dsx
        sdf2(p + vec3(0.0, dx, 0.0)) - s, // dsy
        sdf2(p + vec3(0.0, 0.0, dx)) - s  // dsz
    );
    return normalize(norm);
}

/**
 * A Copy of phong_shading2 for handling reflection.
 * Because GLSL does not support recursive function calls.
 * This is with further reflection part removed because we just need one bounce.
 */
vec3 phong_shading_reflection(vec3 p, vec3 n, vec3 ray_dir, vec3 origin)
{
    //// phong shading
    float t = getSyncedTimeCycle() * 3.0;
    float brightness_scale = 0.6 + 0.20 * t; // Sun rise simulation
    vec3 lightPos = vec3(1.0, t + 5.0, 30.0);
    vec3 light_color = vec3(0.82, 0.67, 0.58) * 1.2;
    vec3 l = normalize(lightPos - p);               
    float amb = 0.3;
    float dif = max(dot(n, l), 0.) * 0.6;
    vec3 eye = origin;
    float spec = pow(max(dot(reflect(-l, n), normalize(eye - p)), 0.0), 128.0) * 0.7;

    vec3 sunDir = vec3(0, 1, -1);
    float sunDif = max(dot(n, sunDir), 0.) * 0.2;

    //// Coloring
    float birb_brightness = 1.2;
    vec3 color = vec3(1.0, 1.0, 1.0);

    switch (hit_id.id) {
        case 1: // Ground
            color = vec3(1.0) * 1.1;
            break;
        case 2: // Birb 1
            color = vec3(1.0, 0.89, 0.97) * birb_brightness;
            break;
        case 3: // Birb 2
            color = vec3(1.0, 0.61, 0.78) * birb_brightness;
            break;
        case 4: // Birb 3
            color = vec3(0.99, 0.79, 0.68) * birb_brightness;
            break;
        case 5: // Background Sky
            vec3 color1 = vec3(0.77, 0.67, 0.53);
            vec3 color2 = vec3(1.0, 0.25, 0.98);
            color = mix(color1, color2, (p.y + 5.0) / 100.0) * brightness_scale;
            return color;
        case 6: // Sun
            color = vec3(1.0, 0.29, 0.09);
            return color;
        case 7: // Cloud
            color = vec3(1.0);
            return (amb + sunDif + 0.2) * color * light_color * brightness_scale;
        case 8: // River
            color = vec3(0.79, 0.89, 1.0);
            break;

        default: // Unexpected hit_id values
            color = vec3(0.0, 0.18, 1.0); // Blue for debugging reflection
            return color;
    }

    //// shadow
    float s = rayMarching2(p + n * 0.02, l);
    if(s < length(lightPos - p)) dif *= .2; // shadow

    //// Balance the color of the scene
    float fog = 1.0 - exp(-0.03 * p.z);
    vec3 fog_color = vec3(0.5);
    color = mix(color, fog_color, fog);

    return (amb + dif + spec + sunDif) * brightness_scale * color * light_color;
}

/**
 * Phong Shading for SDF2 Scene
 * @param p: intersection point
 * @param n: normal at the intersection point
 * @param ray_dir: ray direction
 * @param origin: camera position
 * @return color: phong shading color
 *
 * Note: Any changes to this function should be copied to phong_shading_reflection
 */
vec3 phong_shading2(vec3 p, vec3 n, vec3 ray_dir, vec3 origin)
{
    //// phong shading
    float t = getSyncedTimeCycle() * 3.0;
    float brightness_scale = 0.6 + 0.20 * t; // Sun rise simulation
    vec3 lightPos = vec3(1.0, t + 5.0, 30.0);
    vec3 light_color = vec3(0.82, 0.67, 0.58) * 1.2;
    vec3 l = normalize(lightPos - p);               
    float amb = 0.3;
    float dif = max(dot(n, l), 0.) * 0.6;
    vec3 eye = origin;
    float spec = pow(max(dot(reflect(-l, n), normalize(eye - p)), 0.0), 128.0) * 0.7;

    vec3 sunDir = vec3(0, 1, -1);
    float sunDif = max(dot(n, sunDir), 0.) * 0.2;



    //// Coloring
    float birb_brightness = 1.2;
    vec3 color = vec3(1.0, 1.0, 1.0);

    switch (hit_id.id) {
        case 1: // Ground
            color = vec3(1.0) * 1.1;
            break;
        case 2: // Birb 1
            color = vec3(1.0, 0.89, 0.97) * birb_brightness;
            break;
        case 3: // Birb 2
            color = vec3(1.0, 0.61, 0.78) * birb_brightness;
            break;
        case 4: // Birb 3
            color = vec3(0.99, 0.79, 0.68) * birb_brightness;
            break;
        case 5: // Background Sky
            vec3 color1 = vec3(0.77, 0.67, 0.53);
            vec3 color2 = vec3(1.0, 0.25, 0.98);
            color = mix(color1, color2, (p.y + 5.0) / 100.0) * brightness_scale;

            //// Cloud marching
            vec4 cloud_color = cloudMarch(origin, ray_dir);
            color = cloud_color.rgb + color * cloud_color.a; // Add cloud color to the scene
            return color;
        case 6: // Sun
            color = vec3(1.0, 0.29, 0.09);
            return color;
        case 7: // Cloud
            color = vec3(1.0);
            return (amb + sunDif + 0.2) * color * light_color * brightness_scale;
        case 8: // River
            vec3 water_color = vec3(0.79, 0.89, 1.0);
            // Reflection on water
            vec3 reflect_dir = reflect(ray_dir, n);
            float reflect_s = rayMarching2(p + n * 0.01, reflect_dir);
            // Get the reflection color
            vec3 reflect_p = p + reflect_dir * reflect_s;
            vec3 reflect_n = normal2(reflect_p);
            vec3 reflect_color = phong_shading_reflection(reflect_p, reflect_n, reflect_dir, p);
            return reflect_color * water_color * 0.9;

        default: // Unexpected hit_id values
            color = vec3(0.13, 1.0, 0.0); // Green for debugging
            return color;
    }

    //// shadow
    float s = rayMarching2(p + n * 0.02, l);
    if(s < length(lightPos - p)) dif *= .2;

    //// Balance the color of the scene
    float fog = 1.0 - exp(-0.03 * p.z);
    vec3 fog_color = vec3(0.5);
    color = mix(color, fog_color, fog);

    return (amb + dif + spec + sunDif) * brightness_scale * color * light_color;

    // vec3 scene_color = (amb + dif + spec + sunDif) * brightness_scale * color * light_color;

    // return cloud_color.rgb + scene_color * cloud_color.a; // Add cloud color to the scene
}




/////////////////////////////////////////////////////
//// main function
/////////////////////////////////////////////////////

void mainImage2(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord.xy - .5 * iResolution.xy) / iResolution.y;           //// screen uv
    
    float cam_move = getSyncedTimeCycle();
    vec3 origin = CAM_POS + vec3(0.0, -0.5, 1.5) 
                          + vec3(0.0, cam_move * 0.3, -cam_move * 2.0);          //// camera position 
    // vec3 origin = CAM_POS;                                                 //// camera position
    vec3 dir = normalize(vec3(uv.x, uv.y, 1));                  //// camera direction
    float s = rayMarching2(origin, dir);                     //// ray marching
    vec3 p = origin + dir * s;                                               //// ray-sdf intersection
    vec3 n = normal2(p);                                         //// sdf normal
    
    // // if objectID is cloud, use cloud marching
    // if (hit_id.id == 7) {
    //     fragColor = vec4(1.0, 1.0, 1.0, 1.0); // White for cloud
    //     return;
    // }

    jitter = 1.0;


    // //// Cloud marching
    // vec4 cloud_color = cloudMarch(origin, dir);
    
    vec3 color = phong_shading2(p, n, dir, origin);    //// phong shading

    // color = cloud_color.rgb + color * cloud_color.a; // Add cloud color to the scene
    
    fragColor = vec4(color, 1.);                                     //// fragment color
}



void main() 
{
    mainImage2(gl_FragColor, gl_FragCoord.xy);
}