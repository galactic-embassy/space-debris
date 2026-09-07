import { fetchActiveCatalog } from './lib/celestrak';
import { startRenderer } from './lib/renderer';

const canvas = document.getElementById('view') as HTMLCanvasElement;
const statusEl = document.getElementById('status') as HTMLElement;
const countEl = document.getElementById('count') as HTMLElement;
const fpsEl = document.getElementById('fps') as HTMLElement;
const clockEl = document.getElementById('clock') as HTMLElement;
const errorEl = document.getElementById('error') as HTMLElement;

setInterval(() => {
  clockEl.textContent = new Date().toISOString().replace('T', ' ').slice(0, 19) + ' UTC';
}, 1000);

async function main() {
  try {
    statusEl.textContent = 'Fetching CelesTrak catalog…';
    const omm = await fetchActiveCatalog();

    statusEl.textContent = 'Initializing propagator…';
    const handles = await startRenderer(canvas, omm);

    statusEl.textContent = 'Tracking';
    countEl.textContent = handles.count.toLocaleString();

    handles.onTick((fps) => {
      fpsEl.textContent = fps.toFixed(0);
    });
  } catch (err) {
    console.error(err);
    errorEl.textContent = (err as Error).message;
    errorEl.style.display = 'block';
    statusEl.textContent = 'Failed';
  }
}

main();
