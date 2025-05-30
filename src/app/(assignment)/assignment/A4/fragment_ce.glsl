precision highp float;
varying vec2 vUv; // UV (screen) coordinates in [0,1]^2

uniform float iTime;
uniform float iTimeDelta;
uniform float iFrame;
uniform vec2 iResolution;
uniform vec4 iMouse;
uniform sampler2D iChannel0;

float remap01(float inp, float inp_start, float inp_end) {
    return clamp((inp - inp_start) / (inp_end - inp_start), 0.0, 1.0);
}
float dist_sqr(vec2 a, vec2 b) {
    vec2 diff = a - b;
    return dot(diff, diff);
}


const float RADIUS = 0.015;

// ------------------------------------------------------------
// Particle structure
struct Particle {
    vec2 pos;
    vec2 pos_prev;
    vec2 vel;
    float inv_mass;
    bool is_fixed;
};

// Simulation constants
const float damp = 2.0;
const float collision_dist = RADIUS * 1.5;
const float ground_collision_dist = collision_dist * 0.1;
const vec2 gravity = vec2(0.0, -1.);

const float PI = 3.14159265359;

// Define n_rope rope particles and add one extra "mouse particle".
const int MAX_PARTICLES = 100;
const int MAX_SPRINGS = 40;

//0: mouse particle
//1...5: rope particles
int n_particles;
Particle particles[MAX_PARTICLES];

int nearest_particle(vec2 p) {
    int idx = 1;
    float min_dist = 1e9;
    for (int i = 1; i < n_particles; i++) {
        float d = dist_sqr(p, particles[i].pos);
        if (d < min_dist) {
            min_dist = d;
            idx = i;
        }
    }
    return idx;
}

// ------------------------------------------------------------
// Spring structure
struct Spring {
    int a;
    int b;
    float restLength;
    float inv_stiffness;
};
// Create springs between adjacent rope particles (n_rope-1 springs)
// and one spring connecting the last rope particle and the mouse particle.
Spring springs[MAX_SPRINGS];
int n_springs;
int selected_particle = -1;
int current_add_particle = -1;

Spring add_spring(int a, int b, float inv_stiffness){
    Spring s;
    s.a = a;
    s.b = b;
    s.restLength = length(particles[a].pos - particles[b].pos);
    s.inv_stiffness = inv_stiffness;
    return s;
}

const int initial_particles = 40;

void init_state(void) {
    n_particles = initial_particles;
    n_springs = initial_particles - 1;

    float x_start = -0.9;
    float x_end = -0.3;
    float y_start = 0.4;
    float y_end = -0.3;

    for (int i = 1; i < initial_particles; i++) {
        float t = float(i - 1) / float(initial_particles - 2);
        float x = mix(x_start, x_end, t);
        float y = mix(y_start, y_end, t);
        particles[i].pos = vec2(x, y);
        particles[i].vel = vec2(0.0);
        particles[i].inv_mass = 1.0;
        particles[i].is_fixed = false;
    }
    current_add_particle = initial_particles;

    // Add springs between adjacent particles
    for (int i = 1; i < initial_particles - 1; i++) {
        springs[i] = add_spring(i, i + 1, 1.0 / 80000.0);
    }
}


vec2 screen_to_xy(vec2 coord) {
    return (coord - 0.5 * iResolution.xy) * 2.0 / iResolution.y;
}

bool is_initializing() {
    return iTime < 0.06 || iFrame < 2.;
}

// Load rope particles from the previous frame and update the mouse particle.
void load_state() {
    //0,0: (num_particles, num_springs, selected_particle)

    vec4 data = texelFetch(iChannel0, ivec2(0, 0), 0);
    n_particles = int(data.x);
    n_springs = int(data.y);
    selected_particle = int(data.z);
    current_add_particle = int(data.w);

    //initialize mouse particle
    {
        int mouse_idx = 0;
        particles[mouse_idx].pos = screen_to_xy(iMouse.xy);
        particles[mouse_idx].vel = vec2(0.0);
        particles[mouse_idx].inv_mass = 0.0; // fixed particle
        particles[mouse_idx].is_fixed = true;
    }
    // Load other particles
    for (int i = 1; i < n_particles; i++) {
        vec4 data = texelFetch(iChannel0, ivec2(i, 0), 0);
        particles[i].pos = data.xy;
        particles[i].vel = data.zw;
        particles[i].inv_mass = 1.0; // all particles have mass 1.0
        particles[i].is_fixed = false;

        if(i==1 || i==initial_particles-1){
        // if(i == 1){
            particles[i].inv_mass = 0.0; // fixed particles at the ends of the rope
            particles[i].is_fixed = true; // make sure the first and last particles are fixed
        }
    }

    //select nearest particle to mouse
    if(iMouse.z == 1.){
        if(selected_particle == -1){
            selected_particle = nearest_particle(particles[0].pos);
        }
    }
    else{
        selected_particle = -1;
    }
    
    if(iMouse.z == 2.){
        particles[current_add_particle].pos = screen_to_xy(iMouse.xy); // update the position of the selected particle
        particles[current_add_particle].vel = vec2(0.0); // reset velocity to zero when mouse is released
        particles[current_add_particle].inv_mass = 1.0; // make sure the selected particle is fixed
        particles[current_add_particle].is_fixed = false; // make sure the selected particle is fixed
        if(current_add_particle >= n_particles){
            // If we reach the maximum number of particles, reset to the first available index.
            n_particles = current_add_particle + 1; // skip the mouse particle at index 0
        }
        current_add_particle++;
        if(current_add_particle >= MAX_PARTICLES){
            current_add_particle = initial_particles;
        }
    }

    //load springs
    springs[0] = Spring(0, selected_particle, 0.0, 1.0 / 100.0); // mouse particle to first rope particle
    for (int i = 1; i < n_springs; i++) {
        vec4 data = texelFetch(iChannel0, ivec2(i, 1), 0);
        springs[i].a = int(data.x);
        springs[i].b = int(data.y);
        springs[i].restLength = data.z;
        springs[i].inv_stiffness = data.w;
    }
}


/////////////////////////////////////////////////////
//// Step 1.1: Computing the spring constraint
//// This function calculates the deviation of a spring's length 
//// from its rest length. The constraint is defined as L - L0, 
//// This constraint is later used to adjust the positions of particles 
//// to enforce the spring constraint.
/////////////////////////////////////////////////////
float spring_constraint(Spring s) {
    // The spring has two endpoints a and b.
    // Their positions are particles[s.a].pos and particles[s.b].pos respectively.
    // The spring constraint is L-L0, where L is the current length of the spring
    // and L0 = s.restLength is the rest length of the spring.

    //// Your implementation starts
    return length(particles[s.a].pos - particles[s.b].pos) - s.restLength;
    //// Your implementation ends
}

/////////////////////////////////////////////////////
//// Step 1.2: Computing the spring constraint gradient
//// This function calculates the gradient of the spring constraint constraint 
//// for a spring a--b with respect to the position of a.
/////////////////////////////////////////////////////
vec2 spring_constraint_gradient(vec2 a, vec2 b) {
    // Gradient of the spring constraint for points a,b with respect to a.
    // Think: what is the gradient of (a-b) with respect to a?

    //// Your implementation starts
    vec2 diff = a - b;
    float dist = length(diff);
    return (dist == 0.0) ? vec2(0.0) : diff / dist;
    //// Your implementation ends
}

// Compute the gradient of the spring constraint with respect to a given particle.
vec2 spring_constraint_grad(Spring s, int particle_idx) {
    float sgn = (particle_idx == s.a) ? 1.0 : -1.0;
    return sgn * spring_constraint_gradient(particles[s.a].pos, particles[s.b].pos);
}

/////////////////////////////////////////////////////
//// Step 1.3: Solving a single spring constraint
//// Calculate the numerator and denominator for the Lagrangian multiplier update.
//// You will calculate the numer/denom for PBD updates.
//// The Lagrangian multiplier update is calculated with lambda=(numer/denom)
//// See the documentation for more details.
/////////////////////////////////////////////////////
void solve_spring(Spring s, float dt) {   
    float numer = 0.;
    float denom = 0.;

    //// Your implementation starts
    // vec2 grad_a = vec2(0.); // only keep for the sake of the compiler
    // vec2 grad_b = vec2(0.); // only keep for the sake of the compiler

    numer = -spring_constraint(s);

    vec2 grad_a = spring_constraint_grad(s, s.a);
    vec2 grad_b = spring_constraint_grad(s, s.b);

    float inertial_a = particles[s.a].inv_mass * dot(grad_a, grad_a);
    float inertial_b = particles[s.b].inv_mass * dot(grad_b, grad_b);

    denom = inertial_a + inertial_b;

    //// Your implementation ends

    // PBD if you comment out the following line
    denom += s.inv_stiffness / (dt * dt);
    
    if (denom == 0.0) return;
    float lambda = numer / denom;
    particles[s.a].pos += lambda * particles[s.a].inv_mass * grad_a;
    particles[s.b].pos += lambda * particles[s.b].inv_mass * grad_b;
}

/////////////////////////////////////////////////////
//// Step 2.1: Computing the collision constraint
//// If two particles a,b are closer than collision_dist,
//// a spring constraint is applied to separate them.
//// The rest length of the spring is set to collision_dist.
//// Otherwise return 0.0.
/////////////////////////////////////////////////////
float collision_constraint(vec2 a, vec2 b, float collision_dist){
    // Compute the distance between two particles a and b.
    // The constraint is defined as L - L0, where L is the current distance between a and b
    // and L0 = collision_dist is the minimum distance between a and b.

    float dist = length(a - b);
    if(dist < collision_dist){
        //// Your implementation starts
        return dist - collision_dist;
        //// Your implementation ends
    }
    else{
        return 0.0;
    }
}

/////////////////////////////////////////////////////
//// Step 2.2: Computing the collision constraint gradient
//// If two particles a,b are closer than collision_dist,
//// calculate the gradient of the collision constraint with respect to a.
//// It's similar to the spring constraint gradient.
//// Otherwise return vec2(0.0, 0.0).
/////////////////////////////////////////////////////
vec2 collision_constraint_gradient(vec2 a, vec2 b, float collision_dist){
    // Compute the gradient of the collision constraint with respect to a.

    float dist = length(a - b);
    if(dist <= collision_dist){
        //// Your implementation starts
        // return (dist == 0.0) ? vec2(0.0) : (a - b) / dist;
        return (a - b) / dist;
        //// Your implementation ends
    }
    else{
        return vec2(0.0, 0.0);
    }
}

/////////////////////////////////////////////////////
//// Step 2.3: Solving a single collision constraint
//// It solves for the collision constraint between particle i and j.
//// Calculate the numerator and denominator for the Lagrangian multiplier update.
//// You will calculate the numer/denom for PBD updates.
//// The Lagrangian multiplier update is calculated with lambda=(numer/denom)
//// See the documentation for more details.
/////////////////////////////////////////////////////
void solve_collision_constraint(int i, int j, float collision_dist, float dt){
    // Compute the collision constraint for particles i and j.
    float numer = 0.0;
    float denom = 0.0;

    //// Your implementation starts
    vec2 a = particles[i].pos;
    vec2 b = particles[j].pos;
    vec2 grad = collision_constraint_gradient(a, b, collision_dist);

    if (grad == vec2(0.0)) return; // no collision

    numer = -collision_constraint(a, b, collision_dist);
    float inertial_a = particles[i].inv_mass * dot(grad, grad);
    float inertial_b = particles[j].inv_mass * dot(grad, grad);
    denom = inertial_a + inertial_b;
    //// Your implementation ends

    //PBD if you comment out the following line, which is faster
    denom += (1. / 1000.) / (dt * dt);

    if (denom == 0.0) return;
    float lambda = numer / denom;
    particles[i].pos += lambda * particles[i].inv_mass * grad;
    particles[j].pos -= lambda * particles[j].inv_mass * grad;
}

float phi(vec2 p){
    const float PI = 3.14159265359;
    //let's do sin(x)+0.5
    return p.y - (0.1 * sin(p.x * 2. * PI) - 0.5);
}

/////////////////////////////////////////////////////
//// Step 3.1: Computing the ground constraint
//// For a point p, if phi(p) < ground_collision_dist,
//// we set a constraint to push the point away from the ground.
//// The constraint is defined as phi(p) - ground_collision_dist.
//// Otherwise return 0.0.
/////////////////////////////////////////////////////
float ground_constraint(vec2 p, float ground_collision_dist){
    if(phi(p) < ground_collision_dist){
        //// Your implementation starts
        return phi(p) - ground_collision_dist;
        //// Your implementation ends
    }
    else{
        return 0.0;
    }    
}

/////////////////////////////////////////////////////
//// Step 3.2: Computing the ground constraint gradient
//// If phi(p) < ground_collision_dist, 
//// compute the gradient of the ground constraint.
//// Otherwise return vec2(0.0, 0.0).
/////////////////////////////////////////////////////
vec2 ground_constraint_gradient(vec2 p, float ground_collision_dist){
    // Compute the gradient of the ground constraint with respect to p.

    if(phi(p) < ground_collision_dist){
        //// Your implementation starts
        float grad_x = -0.2 * PI * cos(2.0 * PI * p.x);
        float grad_y = 1.0;
        return vec2(grad_x, grad_y); 
        //// Your implementation ends
    }
    else{
        return vec2(0.0, 0.0);
    }
}

/////////////////////////////////////////////////////
//// Step 3.3: Solving a single ground constraint
//// It solves for the ground constraint for particle i.
//// Calculate the numerator and denominator for the Lagrangian multiplier update.
//// You will calculate the numer/denom for PBD updates.
//// The Lagrangian multiplier update is calculated with lambda=(numer/denom)
//// See the documentation for more details.
/////////////////////////////////////////////////////
void solve_ground_constraint(int i, float ground_collision_dist, float dt){
    // Compute the ground constraint for particle i.
    float numer = 0.0;
    float denom = 0.0;

    //// Your implementation starts
    vec2 p_i = particles[i].pos;
    vec2 grad = ground_constraint_gradient(p_i, ground_collision_dist);
    
    numer = -ground_constraint(p_i, ground_collision_dist);
    denom = particles[i].inv_mass * dot(grad, grad);

    //// Your implementation ends

    //PBD if you comment out the following line, which is faster
    denom += (1. / 1000.) / (dt * dt);

    if (denom == 0.0) return;
    float lambda = numer / denom;
    particles[i].pos += lambda * particles[i].inv_mass * grad;
}

/////////////////////////////////////////////////////
//// Step 10: Solving all constraints
//// You need to solve for all 3 types of constraints using previously defined functions:
//// 1. Spring constraints defined by springs[1] to springs[n_springs-1]
//// 2. Ground constraints for all particles (except the mouse particle 0).
//// 3. Collision constraints for all pairs of particles (except the mouse particle 0).
/////////////////////////////////////////////////////
void solve_constraints(float dt) {
    //If left mouse is pressed, calculate the spring constraint for the mouse particle to the first rope particle.
    if(iMouse.z == 1.){
        solve_spring(springs[0], dt); // mouse particle to first rope particle
    }

    // Solve all constraints

    //// Your implementation starts

    // Spring Constraints
    for (int i = 1; i < n_springs; i++) {
        solve_spring(springs[i], dt);
    }
    // Collision Constraints between every pair of particles
    for (int i = 1; i < n_particles; i++) {
        for (int j = i + 1; j < n_particles; j++) {
            solve_collision_constraint(i, j, collision_dist, dt);
        }
    }
    // Ground Constraints
    for (int i = 1; i < n_particles; i++) {
        solve_ground_constraint(i, ground_collision_dist, dt);
    }


    //// Your implementation ends
}

float dist_to_segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    // Compute the projection factor and clamp it between 0 and 1.
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    // Return the distance from p to the closest point on the segment.
    return length(pa - h * ba);
}


// quadratic polynomial smoothed minimum: https://iquilezles.org/articles/smin/
float smin( float a, float b, float k )
{
    k *= 4.0;
    float h = max( k-abs(a-b), 0.0 )/k;
    return min(a,b) - h*h*k*(1.0/4.0);
}


vec3 render_scene(vec2 pixel_xy) {
    float phi = phi(pixel_xy);
    vec3 col;
    if(phi < 0.0) {
        float t = remap01(phi, 0.0, -1.0);
        vec3 color1 = vec3(0.82); // light blue
        vec3 color2 = vec3(0.34, 0.35, 0.35); // dark blue
        vec3 color = mix(color1, color2, t);
        return color;
    }
    else{
        // col = vec3(229, 242, 250) / 255.; // background color
        // Render a gradient background
        float t = remap01(pixel_xy.y, 0.0, 1.0);
        vec3 color1 = vec3(0.9, 0.69, 0.46); // light blue
        vec3 color2 = vec3(0.97, 0.73, 1.0); // dark blue
        col = mix(color1, color2, t);
    }
    
    float pixel_size = 2.0 / iResolution.y;
    
    // If still initializing, return the background color.
    if (is_initializing()) {
        return col;
    }

    // Render fluid particles
    {
        float distance = length(pixel_xy - particles[1].pos);

        for (int i = initial_particles; i < n_particles; i++) {
            distance = smin(distance, length(pixel_xy - particles[i].pos), RADIUS);
            // if (distance < RADIUS) {
            //     float t = remap01(distance, RADIUS * 0.7, RADIUS * 2.);
            //     vec3 color1 = vec3(0.17, 0.71, 1.0); // light blue
            //     vec3 color2 = vec3(1.0); // dark blue
            //     vec3 color = mix(color1, color2, t);
            //     // vec3 color = vec3(0.49, 0.69, 0.92);
            //     col = color;
            //     // break;
            // }
        }
        if (distance < RADIUS) {
            float t = remap01(distance, RADIUS * 0.8, RADIUS * 1.1);
            vec3 color1 = vec3(0.45, 0.81, 1.0); // light blue
            vec3 color2 = vec3(1.0); // dark blue
            vec3 color = mix(color1, color2, t);
            // vec3 color = vec3(0.49, 0.69, 0.92);
            col = color;
            // break;
        }
    }
    
    // Render All springs
    {
        float min_dist = 1e9;

        if(iMouse.z == 1.){
            min_dist = dist_to_segment(pixel_xy, particles[0].pos, particles[selected_particle].pos);
        }

        for (int i = 1; i < n_springs; i++) {
            int a = springs[i].a;
            int b = springs[i].b;
            min_dist = min(min_dist, dist_to_segment(pixel_xy, particles[a].pos, particles[b].pos));
        }

        const float thickness = RADIUS;
        if (min_dist < thickness) {
            float t = remap01(min_dist, 0.0, thickness * 2.);
            vec3 color1 = vec3(0.85);
            vec3 color2 = vec3(0.58);
            vec3 color = mix(color1, color2, t);
            col = color;
        }
    }

    // col.z = 1.0;
    return col;
}

vec4 output_color(vec2 pixel_ij){
    int i = int(pixel_ij.x);
    int j = int(pixel_ij.y);
    
    if(j == 0){
        // (0,0): (num_particles, num_springs, selected_particle)
        if(i==0){
            return vec4(float(n_particles), float(n_springs), float(selected_particle), float(current_add_particle));
        }
        else if(i < n_particles){
            //a particle
            return vec4(particles[i].pos, particles[i].vel);
        }
        else{
            return vec4(0.0, 0.0, 0.0, 1.0);
        }
    }
    else if(j == 1){
        if(i < n_springs){
            return vec4(float(springs[i].a), float(springs[i].b), springs[i].restLength, springs[i].inv_stiffness);
        }
        else{
            return vec4(0.0, 0.0, 0.0, 1.0);
        }
    }
    else{
        vec2 pixel_xy = screen_to_xy(pixel_ij);
        vec3 color = render_scene(pixel_xy);
        return vec4(color, 1.0);
    }
}

// ------------------------------------------------------------
// Main function
void main() {
    vec2 pixel_ij = vUv * iResolution.xy;
    int pixel_i = int(pixel_ij.x);
    int pixel_j = int(pixel_ij.y);

    if(is_initializing()){
        init_state();
    }
    else{
        load_state();
        if (pixel_j == 0) {
            if (pixel_i >= n_particles) return;

            float actual_dt = min(iTimeDelta, 0.02);
            const int n_steps = 5;
            float dt = actual_dt / float(n_steps);

            for (int i = 0; i < n_steps; i++) {
                // Update rope particles only; skip updating the mouse particle since it's fixed.
                for (int j = 0; j < n_particles; j++) {
                    if (!particles[j].is_fixed)
                        particles[j].vel += dt * gravity;
                    particles[j].vel *= exp(-damp * dt);
                    particles[j].pos_prev = particles[j].pos;
                    particles[j].pos += dt * particles[j].vel;
                }
                solve_constraints(dt);
                // Update velocities for rope particles only.
                for (int j = 0; j < n_particles; j++) {
                    if (!particles[j].is_fixed){
                        particles[j].vel = (particles[j].pos - particles[j].pos_prev) / dt;
                    }
                }
                // Keep the mouse particle fixed by reassigning its position each step.
                int mouse_idx = 0;
                particles[mouse_idx].pos = screen_to_xy(iMouse.xy);
            }
        }
    }

    gl_FragColor = output_color(pixel_ij);
}
