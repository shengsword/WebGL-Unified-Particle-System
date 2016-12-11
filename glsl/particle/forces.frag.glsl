#version 100
#extension GL_EXT_draw_buffers: enable

precision highp float;
precision highp int;

uniform sampler2D u_posTex;
uniform sampler2D u_velTex;
uniform sampler2D u_gridTex;
uniform sampler2D u_relPosTex;

uniform int u_particleSide;
uniform float u_diameter;
uniform float u_dt;
uniform float u_bound;

// Grid uniforms
uniform int u_gridSideLength;
uniform int u_gridNumCellsPerSide;
uniform int u_gridTexSize;
uniform int u_gridTexTileDimensions;

varying vec2 v_uv;

vec2 uvFrom3D(vec3 pos) {
    float u = pos.x + float(u_gridNumCellsPerSide) * (pos.z - float(u_gridTexTileDimensions) * floor(pos.z / float(u_gridTexTileDimensions)));

    float v = pos.y + float(u_gridNumCellsPerSide) * floor(pos.x / float(u_gridTexTileDimensions));

    return vec2(u, v) / float(u_gridTexSize) * .5;
}

vec2 getUV(int idx, int side) {
    float v = float(idx / side) / float(side);
    float u = float(idx - (idx / side) * side) / float(side);
    return vec2(u, v);
}

void main() {
    vec4 posTexel = texture2D(u_posTex, v_uv);
    vec4 velTexel = texture2D(u_velTex, v_uv);
    vec4 relPosTexel = texture2D(u_relPosTex, v_uv);
    int index = int(relPosTexel.w);

    float mass = posTexel.w;

    // Spring coefficient
    float k = 400.0;
    float bounds_k = 600.0;

    // Damping coefficient
    float n = 4.0;
    float bounds_n = 40.0;
    // Friction coefficient
    float u = 0.4;

    vec3 spring_total = vec3(0.0);
    vec3 damping_total = vec3(0.0);
    vec3 pos = posTexel.xyz;
    vec3 vel = velTexel.xyz;
    
    // // Naive loop through all particles
    // // Hack because WebGL cannot compare loop index to non-constant expression
    // // Maximum of 1024x1024 = 1048576 for now
    // for (int i = 0; i < 1048576; i++) {
    //     if (i == u_particleSide * u_particleSide)
    //         break;

    //     vec2 uv = getUV(i, u_particleSide);

    //     vec3 p_pos = texture2D(u_posTex, uv).xyz;
    //     if (length(p_pos - pos) < 0.001)
    //         continue;
    //     vec3 p_vel = texture2D(u_velTex, uv).xyz;

    //     vec3 rel_pos = p_pos - pos;
    //     vec3 rel_vel = p_vel - vel;
    //     if (length(rel_pos) < u_diameter) {
    //         spring_total += -k * (u_diameter - length(rel_pos)) * normalize(rel_pos);
    //         damping_total += n * rel_vel;
    //     }
    // }

    //////////
    // GRID //
    //////////
    // Loop through 27 cells in grid
    vec3 voxelIndex = (vec3(pos) - vec3(-u_gridSideLength, -u_gridSideLength, -u_gridSideLength)) / u_diameter;
    for (int i = -1; i < 2; i++) {
        for (int i2 = -1; i2 < 2; i2++) {
            for (int i3 = -1; i3 < 2; i3++) {
                vec3 neighborVoxelIndex = voxelIndex + vec3(i, i2, i3);
                if (neighborVoxelIndex.x < 0. || neighborVoxelIndex.y < 0. || neighborVoxelIndex.z < 0.) {
                    continue;
                }
                if (neighborVoxelIndex.x >= float(u_gridNumCellsPerSide) || neighborVoxelIndex.y >= float(u_gridNumCellsPerSide) ||
                    neighborVoxelIndex.z >= float(u_gridNumCellsPerSide)) {
                        continue;
                }

                vec2 neighborGridUV = uvFrom3D(neighborVoxelIndex);
                
                vec4 p_idx = texture2D(u_gridTex, neighborGridUV);
                for (int c = 0; c < 4; c++) {
                    if (p_idx[c] == 0.) {
                        continue;
                    }
                    vec2 uv = getUV(int(p_idx[c]), u_particleSide);
 
                    vec3 p_pos = texture2D(u_posTex, uv).xyz;
                    if (length(p_pos - pos) < 0.001)
                        continue;
                    vec3 p_vel = texture2D(u_velTex, uv).xyz;

                    vec3 rel_pos = p_pos - pos;
                    vec3 rel_vel = p_vel - vel;
                    if (length(rel_pos) < u_diameter) {
                        spring_total += -k * (u_diameter - length(rel_pos)) * normalize(rel_pos);
                        damping_total += n * rel_vel;
                    }
                }
            }
        }
    }
    // END GRID

    vec3 force = spring_total + damping_total;
    force.y -= 9.8 * mass;

    //Predict next position
    vec3 newPos = pos + vel * u_dt;

    //Boundary conditions
    vec3 dir = normalize(vel);
//    bool applyFriction = false;
    if (newPos.y < u_diameter / 2.0) {
        force.y += 9.8 * mass;
        force.y += bounds_k * (u_diameter / 2.0 - newPos.y) * 1.0;
        force.y -= bounds_n * vel.y;
        //friction = u*n = u*m*g opposite the direction of movement along the ground
        force += -1.0 * normalize(vec3(dir.x, 0, dir.z)) * u * 9.8 * mass;
    }
    if (abs(newPos.x) > u_bound) {
        force.x += bounds_k * (u_bound - abs(newPos.x)) * sign(newPos.x);
        force.x -= bounds_n * vel.x;
    }
    if (abs(newPos.z) > u_bound) {
        force.z += bounds_k * (u_bound - abs(newPos.z)) * sign(newPos.z);
        force.z -= bounds_n * vel.z;
    }

    gl_FragData[0] = posTexel;
    gl_FragData[1] = velTexel;
    gl_FragData[2] = vec4(force, 1.0); //force output
    gl_FragData[3] = relPosTexel;
}
