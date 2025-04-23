varying vec2 vUv;

uniform float iTime;
uniform vec2 iResolution;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // draw white background
    fragColor = vec4(1.0, 1.0, 1.0, 1.0);

    // draw time-varying background
    // fragColor = vec4(1.0, 1.0, sin(iTime), 1.0);

    // draw gradient background
    // vec2 pos = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    // fragColor = vec4(1.0, pos.y/2.0+0.5, sin(iTime), 1.0);

    //// draw a circle on screen
    vec2 pos = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    vec2 center = vec2(sin(iTime),0.0);
    float r = 0.2;
    vec3 color = vec3(0.0,0.0,0.0);

    if(length(pos-center) < r){
        color = vec3(1.0, 0.0, sin(iTime));
    }
    else{
        color = vec3(0.0, 0.0, 1.0);
    }

    fragColor = vec4(color, 1.0);
}

void main()
{
    mainImage(gl_FragColor, gl_FragCoord.xy);
}