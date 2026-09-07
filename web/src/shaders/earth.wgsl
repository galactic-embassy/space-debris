// Earth shader. A subdivided icosphere with simple Lambert lighting
// from a sun direction the host updates per frame (real ECI sun
// position so the terminator matches actual day/night).

struct Uniforms {
  viewProj : mat4x4<f32>,
  sunDir : vec4<f32>, // xyz = unit vector toward the sun (ECI)
};

@group(0) @binding(0) var<uniform> u : Uniforms;

struct VsOut {
  @builtin(position) clip : vec4<f32>,
  @location(0) normal : vec3<f32>,
  @location(1) worldPos : vec3<f32>,
};

@vertex
fn vs_main(
  @location(0) position : vec3<f32>,
  @location(1) normal : vec3<f32>,
) -> VsOut {
  var out : VsOut;
  out.worldPos = position;
  out.normal = normal;
  out.clip = u.viewProj * vec4<f32>(position, 1.0);
  return out;
}

@fragment
fn fs_main(in : VsOut) -> @location(0) vec4<f32> {
  let n = normalize(in.normal);
  let lambert = max(dot(n, normalize(u.sunDir.xyz)), 0.0);

  // Day side: muted ocean blue. Night side: barely-there indigo so the
  // sphere reads as solid against the starfield without competing with debris.
  let day = vec3<f32>(0.14, 0.32, 0.48);
  let night = vec3<f32>(0.02, 0.03, 0.08);
  let col = mix(night, day, smoothstep(0.0, 0.25, lambert));

  // Faint rim light to define the limb.
  let viewDir = normalize(-in.worldPos);
  let rim = pow(1.0 - max(dot(n, viewDir), 0.0), 3.0) * 0.35;
  return vec4<f32>(col + vec3<f32>(0.3, 0.5, 0.7) * rim, 1.0);
}
