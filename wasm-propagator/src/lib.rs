//! Orbital propagator for ~30k space objects.
//!
//! Parses NORAD Two-Line Element sets and propagates them with SGP4.
//! Designed to be called from JS once per animation frame; writes
//! XYZ positions (km, ECI) into a flat Float32Array for direct upload
//! to a WebGPU vertex buffer.

use sgp4::{Constants, Elements, MinutesSinceEpoch};
use wasm_bindgen::prelude::*;

#[wasm_bindgen(start)]
pub fn init() {
    #[cfg(feature = "console_error_panic_hook")]
    console_error_panic_hook::set_once();
}

/// A single propagatable object. We cache the SGP4 `Constants` so we
/// don't redo the expensive Brouwer-mean-element conversion per frame.
struct Object {
    name: String,
    norad_id: u64,
    epoch_ms: f64,
    constants: Constants,
}

#[wasm_bindgen]
pub struct Catalog {
    objects: Vec<Object>,
}

#[wasm_bindgen]
impl Catalog {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self { objects: Vec::new() }
    }

    /// Parse a CelesTrak JSON OMM array (the `?FORMAT=json` endpoint).
    /// Returns the count of successfully loaded objects.
    pub fn load_omm_json(&mut self, json: &str) -> Result<usize, JsError> {
        let elements: Vec<Elements> = serde_json::from_str(json)
            .map_err(|e| JsError::new(&format!("JSON parse error: {e}")))?;

        let mut loaded = 0;
        for el in elements {
            let name = el.object_name.clone().unwrap_or_else(|| "UNKNOWN".into());
            let norad_id = el.norad_id;
            let epoch_ms = el.epoch().timestamp_millis() as f64;

            match Constants::from_elements(&el) {
                Ok(constants) => {
                    self.objects.push(Object { name, norad_id, epoch_ms, constants });
                    loaded += 1;
                }
                Err(_) => {
                    // SGP4 init failure (decayed, malformed, etc.) — skip silently.
                }
            }
        }
        Ok(loaded)
    }

    #[wasm_bindgen(getter)]
    pub fn count(&self) -> usize {
        self.objects.len()
    }

    /// Propagate every object to `now_unix_ms` and write positions into
    /// the provided Float32Array as [x0,y0,z0, x1,y1,z1, ...] in km (ECI/TEME).
    /// The caller is expected to size the buffer to count * 3 floats.
    /// Decayed/erroring objects get NaN, which the vertex shader culls.
    pub fn propagate_into(&self, now_unix_ms: f64, out: &mut [f32]) {
        debug_assert!(out.len() >= self.objects.len() * 3);

        for (i, obj) in self.objects.iter().enumerate() {
            let minutes = (now_unix_ms - obj.epoch_ms) / 60_000.0;
            let base = i * 3;

            match obj.constants.propagate(MinutesSinceEpoch(minutes)) {
                Ok(pred) => {
                    out[base]     = pred.position[0] as f32;
                    out[base + 1] = pred.position[1] as f32;
                    out[base + 2] = pred.position[2] as f32;
                }
                Err(_) => {
                    out[base]     = f32::NAN;
                    out[base + 1] = f32::NAN;
                    out[base + 2] = f32::NAN;
                }
            }
        }
    }

    /// Look up an object's display name by its index in the buffer.
    /// Used when the user clicks a point in the scene.
    pub fn name(&self, index: usize) -> Option<String> {
        self.objects.get(index).map(|o| o.name.clone())
    }

    pub fn norad_id(&self, index: usize) -> Option<u64> {
        self.objects.get(index).map(|o| o.norad_id)
    }
}

impl Default for Catalog {
    fn default() -> Self {
        Self::new()
    }
}
