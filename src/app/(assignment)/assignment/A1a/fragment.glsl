/////////////////////////////////////////////////////
//// CS 8803/4803 CGAI: Computer Graphics in AI Era
//// Assignment 1A: SDF and Ray Marching
/////////////////////////////////////////////////////

precision highp float;              //// set default precision of float variables to high precision

varying vec2 vUv;                   //// screen uv coordinates (varying, from vertex shader)
uniform vec2 iResolution;           //// screen resolution (uniform, from CPU)
uniform float iTime;                //// time elapsed (uniform, from CPU)

const vec3 CAM_POS = vec3(-0.35, 1.0, -3.0); //// camera position


// Global variables
struct HitID {
    float dist;
    int id;
};
HitID hit_id = HitID(2000.0, -1);

/////////////////////////////////////////////////////
//// sdf functions
/////////////////////////////////////////////////////

/////////////////////////////////////////////////////
//// Step 1: sdf primitives
//// You are asked to implement sdf primitive functions for sphere, plane, and box.
//// In each function, you will calculate the sdf value based on the function arguments.
/////////////////////////////////////////////////////

//// sphere: p - query point; c - sphere center; r - sphere radius
float sdfSphere(vec3 p, vec3 c, float r)
{
    //// your implementation starts
    
    return length(p - c) - r;
    
    //// your implementation ends
}

//// plane: p - query point; h - height
float sdfPlane(vec3 p, float h)
{
    //// your implementation starts
    
    return p.y - h;
    
    //// your implementation ends
}

//// box: p - query point; c - box center; b - box half size (i.e., the box size is (2*b.x, 2*b.y, 2*b.z))
float sdfBox(vec3 p, vec3 c, vec3 b)
{
    //// your implementation starts

    vec3 d = abs(p - c) - b;
    return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
    
    //// your implementation ends
}

/////////////////////////////////////////////////////
//// boolean operations
/////////////////////////////////////////////////////

/////////////////////////////////////////////////////
//// Step 2: sdf boolean operations
//// You are asked to implement sdf boolean operations for intersection, union, and subtraction.
/////////////////////////////////////////////////////

float sdfIntersection(float s1, float s2)
{
    //// your implementation starts
    
    return max(s1, s2);

    //// your implementation ends
}

float sdfUnion(float s1, float s2)
{
    //// your implementation starts
    
    return min(s1, s2);

    //// your implementation ends
}

float sdfSubtraction(float s1, float s2)
{
    //// your implementation starts
    
    return max(s1, -s2);

    //// your implementation ends
}

/////////////////////////////////////////////////////
//// sdf calculation
/////////////////////////////////////////////////////

/////////////////////////////////////////////////////
//// Step 3: scene sdf
//// You are asked to use the implemented sdf boolean operations to draw the following objects in the scene by calculating their CSG operations.
/////////////////////////////////////////////////////


//// sdf: p - query point
float sdf(vec3 p)
{
    float s = 0.;

    //// 1st object: plane
    float plane1_h = -0.1;
    
    //// 2nd object: sphere
    vec3 sphere1_c = vec3(-2.0, 1.0, 0.0);
    float sphere1_r = 0.25;

    //// 3rd object: box
    vec3 box1_c = vec3(-1.0, 1.0, 0.0);
    vec3 box1_b = vec3(0.2, 0.2, 0.2);

    //// 4th object: box-sphere subtraction
    vec3 box2_c = vec3(0.0, 1.0, 0.0);
    vec3 box2_b = vec3(0.3, 0.3, 0.3);

    vec3 sphere2_c = vec3(0.0, 1.0, 0.0);
    float sphere2_r = 0.4;

    //// 5th object: sphere-sphere intersection
    vec3 sphere3_c = vec3(1.0, 1.0, 0.0);
    float sphere3_r = 0.4;

    vec3 sphere4_c = vec3(1.3, 1.0, 0.0);
    float sphere4_r = 0.3;

    //// calculate the sdf based on all objects in the scene
    
    //// your implementation starts

    // Calculate the SDF for each 5 objects
    float s1 = sdfPlane(p, plane1_h);

    float s2 = sdfSphere(p, sphere1_c, sphere1_r);

    float s3 = sdfBox(p, box1_c, box1_b);

    float s4_1 = sdfBox(p, box2_c, box2_b);
    float s4_2 = sdfSphere(p, sphere2_c, sphere2_r);
    float s4 = sdfSubtraction(s4_1, s4_2);

    float s5_1 = sdfSphere(p, sphere3_c, sphere3_r);
    float s5_2 = sdfSphere(p, sphere4_c, sphere4_r);
    float s5 = sdfIntersection(s5_1, s5_2);

    // Combine the SDF for all objects
    float objects[] = float[](
        s1, 
        s2, 
        s3, 
        s4, 
        s5);
    int object_ids[] = int[](
        1, 
        2, 
        3, 
        4, 
        5);
    s = 1000.0; // set a large initial distance for union
    for (int i = 0; i < objects.length(); i++) {
        s = sdfUnion(s, objects[i]);
        if (s < hit_id.dist) {
            hit_id.dist = s;
            hit_id.id = object_ids[i]; // Record object hit
        } 
    }


    //// your implementation ends

    return s;
}


/////////////////////////////////////////////////////
//// ray marching
/////////////////////////////////////////////////////

/////////////////////////////////////////////////////
//// Step 4: ray marching
//// You are asked to implement the ray marching algorithm within the following for-loop.
/////////////////////////////////////////////////////

//// ray marching: origin - ray origin; dir - ray direction 
float rayMarching(vec3 origin, vec3 dir)
{
    float s = 0.0; // distance
    for(int i = 0; i < 100; i++)
    {
        //// your implementation starts
        vec3 p = origin + dir * s;
        float dist = sdf(p); // sdf value in p
        s += dist; // update the distance
        if (s > 100.0 || dist < 0.001) {
            break;
        }
        //// your implementation ends
    }
    
    return s;
}

/////////////////////////////////////////////////////
//// normal calculation
/////////////////////////////////////////////////////

/////////////////////////////////////////////////////
//// Step 5: normal calculation
//// You are asked to calculate the sdf normal based on finite difference.
/////////////////////////////////////////////////////

//// normal: p - query point
vec3 normal(vec3 p)
{
    float s = sdf(p);          //// sdf value in p
    float dx = 0.01;           //// step size for finite difference

    //// your implementation starts
    
    return normalize(vec3(
        sdf(p + vec3(dx, 0.0, 0.0)) - sdf(p - vec3(dx, 0.0, 0.0)), // dsx
        sdf(p + vec3(0.0, dx, 0.0)) - sdf(p - vec3(0.0, dx, 0.0)), // dsy
        sdf(p + vec3(0.0, 0.0, dx)) - sdf(p - vec3(0.0, 0.0, dx))  // dsz
    ));

    // your implementation ends
}

/////////////////////////////////////////////////////
//// Phong shading
/////////////////////////////////////////////////////

/////////////////////////////////////////////////////
//// Step 6: lighting and coloring
//// You are asked to specify the color for each object in the scene.
//// Each object must have a separate color without mixing.
//// Notice that we have implemented the default Phong shading model for you.
/////////////////////////////////////////////////////

vec3 phong_shading(vec3 p, vec3 n)
{
    //// background
    if(p.z > 10.0){
        return vec3(0.9, 0.6, 0.2);
    }

    //// phong shading
    vec3 lightPos = vec3(4.*sin(iTime), 4., 4.*cos(iTime));  
    vec3 l = normalize(lightPos - p);               
    float amb = 0.1;
    float dif = max(dot(n, l), 0.) * 0.7;
    vec3 eye = CAM_POS;
    float spec = pow(max(dot(reflect(-l, n), normalize(eye - p)), 0.0), 128.0) * 0.9;

    vec3 sunDir = vec3(0, 1, -1);
    float sunDif = max(dot(n, sunDir), 0.) * 0.2;

    //// your implementation for coloring starts
    vec3 color = vec3(1.0, 1.0, 1.0);
    if (hit_id.id == 1) {
        color = vec3(0.13, 0.72, 0.0);
    } else if (hit_id.id == 2) {
        color = vec3(1.0, 0.0, 0.0);
    } else if (hit_id.id == 3) {
        color = vec3(0.65, 1.0, 0.0);
    } else if (hit_id.id == 4) {
        color = vec3(0.5, 0.0, 1.0);
    } else if (hit_id.id == 5) {
        color = vec3(0.0, 0.52, 1.0);
    }
    //// your implementation for coloring ends

    //// shadow
    float s = rayMarching(p + n * 0.02, l);
    if(s < length(lightPos - p)) dif *= .2; // shadow

    return (amb + dif + spec + sunDif) * color;
}

/////////////////////////////////////////////////////
//// Step 7: creative expression
//// You will create your customized sdf scene with new primitives and CSG operations in the sdf2 function.
//// Call sdf2 in your ray marching function to render your customized scene.
/////////////////////////////////////////////////////

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
    
    float cloud_move = 0.2 * sin(iTime / 1.0);
    float cloud1 = sdfCloud(p, vec3(-10.0, 10.0, 20.0) + vec3(0.0, cloud_move, 0.0));
    float cloud2 = sdfCloud(p, vec3(-15.0, 4.0, 15.0) + vec3(0.0, -cloud_move, 0.0));
    float cloud3 = sdfCloud(p, vec3(12.0, 5.0, 17.0) + vec3(0.0, cloud_move, 0.0));
    float cloud4 = sdfCloud(p, vec3(3.0, 10.0, 20.0) + vec3(0.0, -cloud_move, 0.0));
    float cloud5 = sdfCloud(p, vec3(8.0, 3.0, 15.0) + vec3(0.0, cloud_move, 0.0));
    float cloud6 = sdfCloud(p, vec3(10.0, 7.0, 30.0) + vec3(0.0, -cloud_move, 0.0));
    float cloud7 = sdfCloud(p, vec3(-3.0, 8.0, 40.0) + vec3(0.0, cloud_move, 0.0));

    // Combine the SDF for all objects
    float objects[] = float[](
        ground,
        birb1,
        birb2, 
        birb3,
        background,
        sun,
        cloud1, cloud2, cloud3, cloud4, cloud5, cloud6, cloud7,
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
        7, 7, 7, 7, 7, 7, 7,
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
    float s = rayMarching2(origin, dir);                         //// ray marching
    vec3 p = origin + dir * s;                                               //// ray-sdf intersection
    vec3 n = normal2(p);                                                  //// sdf normal
    vec3 color = phong_shading2(p, n, dir, origin);    //// phong shading
    fragColor = vec4(color, 1.);                                     //// fragment color
}


void mainImage1(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord.xy - .5 * iResolution.xy) / iResolution.y;           //// screen uv

    vec3 origin = CAM_POS;                                                 //// camera position
    vec3 dir = normalize(vec3(uv.x, uv.y, 1));                  //// camera direction
    float s = rayMarching(origin, dir);                         //// ray marching
    vec3 p = origin + dir * s;                                               //// ray-sdf intersection
    vec3 n = normal(p);                                                  //// sdf normal
    vec3 color = phong_shading(p, n);    //// phong shading
    fragColor = vec4(color, 1.);                                     //// fragment color
}


void main() 
{
    ////--- Uncomment the following line to render the Base SDF1 scene ---////
    // mainImage1(gl_FragColor, gl_FragCoord.xy);

    ////--- Uncomment the following line to render the Custom SDF2 scene ---////
    mainImage2(gl_FragColor, gl_FragCoord.xy);
}