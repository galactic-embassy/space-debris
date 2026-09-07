// Renders each tracked object as a single point.
// Vertex positions come from a storage buffer that the WASM
// propagator writes into every frame. Color encodes altitude
// band (LEO / MEO / GEO / HEO) so the debris belts pop out
// visually. NaN positions (decayed objects) are pushed off-screen.

struct Camera {
  viewProj : mat4x4<f32>,
  cameraPos : vec3<f32>,
  pointSize : f32,
};

@group(0) @binding(0) var<uniform> cam : Camera;
@group(0) @binding(1) var<storage, read> positions : array<f32>;

struct VsOut {
  @builtin(position) clip : vec4<f32>,
  @location(0) color : vec3<f32>,
  @location(1) alpha : f32,
};

// Earth radius in km, used for altitude classification.
const R_EARTH : f32 = 6371.0;

// LEO < 2000 km altitude, MEO < 35000, GEO ~ 35786, above = HEO.
fn altitudeColor(altKm : f32) -> vec3<f32> {
  if (altKm < 2000.0) {
    // LEO — warm coral, the densest, most worrying belt
    return vec3<f32>(1.0, 0.42, 0.38);
  } else if (altKm < 30000.0) {
    // MEO — amber
    return vec3<f32>(1.0, 0.78, 0.35);
  } else if (altKm < 40000.0) {
    // GEO band — pale cyan
    return vec3<f32>(0.55, 0.88, 0.98);
  } else {
    // HEO / deep — soft violet
    return vec3<f32>(0.72, 0.62, 0.95);
  }
}

@vertex
fn vs_main(@builtin(vertex_index) vi : u32) -> VsOut {
  let base = vi * 3u;
  let p = vec3<f32>(positions[base], positions[base + 1u], positions[base + 2u]);

  var out : VsOut;

  // Cull decayed / errored objects.
  if (p.x != p.x) {
    out.clip = vec4<f32>(2.0, 2.0, 2.0, 1.0); // off-screen
    out.color = vec3<f32>(0.0);
    out.alpha = 0.0;
    return out;
  }

  let alt = length(p) - R_EARTH;
  out.color = altitudeColor(alt);
  out.clip = cam.viewProj * vec4<f32>(p, 1.0);
  out.alpha = 0.85;
  return out;
}

@fragment
fn fs_main(in : VsOut) -> @location(0) vec4<f32> {
  return vec4<f32>(in.color, in.alpha);
}
