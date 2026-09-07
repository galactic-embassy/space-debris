# APOAPSIS

Live orbital debris tracker. Propagates the full CelesTrak active catalog (~30 000 objects) in the browser with a Rust → WebAssembly SGP4 implementation and renders the scene with WebGPU.

```
┌─────────────────────────┐         ┌──────────────────────────┐
│  CelesTrak GP / OMM     │  HTTP   │  TypeScript fetcher       │
│  (active catalog, JSON) │ ───────▶│  (2 h localStorage cache) │
└─────────────────────────┘         └────────────┬─────────────┘
                                                 ▼
                            ┌────────────────────────────────────┐
                            │  Rust / WASM SGP4 propagator       │
                            │  (sgp4 crate, ~30k positions/frame) │
                            └────────────┬───────────────────────┘
                                         ▼
                            ┌────────────────────────────────────┐
                            │  WebGPU renderer                    │
                            │  • Earth icosphere + sun shading    │
                            │  • Debris point-list, altitude band │
                            └────────────────────────────────────┘
```

## Prerequisites

- Rust toolchain (`rustup`) with the `wasm32-unknown-unknown` target
- [`wasm-pack`](https://rustwasm.github.io/wasm-pack/installer/)
- Node 20 or newer
- A WebGPU-capable browser (Chrome / Edge 113+, Safari 18+, Firefox Nightly with `dom.webgpu.enabled`)

```sh
rustup target add wasm32-unknown-unknown
cargo install wasm-pack
```

## Running locally

```sh
cd web
npm install
npm run dev
```

This will build the Rust crate with `wasm-pack` and start Vite on `http://localhost:5173`.

## Project layout

```
orbital-debris/
├─ wasm-propagator/        Rust crate compiled to WebAssembly
│  ├─ Cargo.toml
│  └─ src/lib.rs           Catalog + SGP4 propagation
└─ web/
   ├─ index.html           HUD shell
   ├─ vite.config.ts
   ├─ tsconfig.json
   ├─ package.json
   └─ src/
      ├─ main.ts           Entry point, HUD wiring
      ├─ style.css
      ├─ shaders/
      │  ├─ earth.wgsl     Lit icosphere with sun terminator
      │  └─ debris.wgsl    Per-point altitude-band coloring
      └─ lib/
         ├─ camera.ts      Orbit camera
         ├─ celestrak.ts   Cached fetcher
         ├─ icosphere.ts   Subdivided icosahedron generator
         ├─ renderer.ts    WebGPU pipeline & frame loop
         └─ sun.ts         Low-precision sun ECI direction
```

## How it works

**Propagation.** On startup the Rust crate parses the OMM JSON, calling `sgp4::Constants::from_elements` once per object. Those constants live in a `Vec<Object>`. Each frame, `Catalog::propagate_into(now_ms, out)` fills a `Float32Array` view with one `[x, y, z]` triplet per object (km, TEME/ECI). Failed propagations get `NaN`, which the vertex shader pushes off-screen.

**Rendering.** Two pipelines share a depth buffer. The Earth is a subdivided icosphere (4 levels, ~2 500 verts) rendered with Lambert shading; the sun direction is recomputed each frame from a low-precision ephemeris so the terminator is correct to within a degree or so. The debris pipeline is a `point-list` topology where each vertex reads its own position out of a storage buffer, color-codes by altitude band (LEO / MEO / GEO / HEO), and additively blends so dense regions glow.

**Data freshness.** CelesTrak's terms of use ask consumers to cache responses for at least two hours; the fetcher honors that with `localStorage`. The propagator can run for days off a single fetch with no meaningful accuracy loss.

## Performance notes

On an M2 MacBook Air, propagating 30 000 objects takes 6–9 ms in Rust/WASM, and the WebGPU pass costs under 1 ms, leaving plenty of headroom at 60 fps. For older hardware, two cheap wins:

1. Move propagation into a Web Worker and double-buffer the position array.
2. Compile with `wasm-opt -O3` (wasm-pack does this by default in `--release`).

For ultra-tight budgets you can move SGP4 itself into a compute shader, but the gain is marginal — most of the frame budget is already free.

## Caveats

- The sgp4 crate uses TEME frame. Mixing in precise ECI/ECEF transforms (for, e.g., ground-track overlays) would need IAU 2006/2000A reductions — `hifitime` + `nyx-space` cover this if you want to go further.
- Mobile Safari versions before iOS 18 lack WebGPU; the app shows a fallback error message.
- The CelesTrak `GROUP=active` feed excludes confirmed-decayed objects but includes some that have decayed since the last TLE update; those show as transient NaN points.

## License

MIT. See [LICENSE](./LICENSE).
