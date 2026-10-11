import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import h5wasm from 'h5wasm';
import { pkgVersion } from './common.js';

function h5wasmVersion() {
  const fromPkg = pkgVersion('h5wasm');
  if (fromPkg) return fromPkg;
  try {
    let dir = dirname(fileURLToPath(import.meta.resolve('h5wasm')));
    for (let i = 0; i < 6; i++) {
      try {
        const pkg = JSON.parse(readFileSync(join(dir, 'package.json'), 'utf8'));
        if (pkg.name === 'h5wasm' && pkg.version) return String(pkg.version);
      } catch {
        /* walk up to the package root */
      }
      const parent = dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  } catch {
    /* import.meta.resolve can fail before the package is installed */
  }
  return '';
}

const ready = h5wasm.ready;

function valuesToXy(grid) {
  const { nx, ny, values } = grid;
  const xy = new Float64Array(nx * ny);
  for (let y = 0; y < ny; y++) {
    for (let x = 0; x < nx; x++) xy[x * ny + y] = values[y * nx + x];
  }
  return xy;
}

function xyToValues(xy, nx, ny) {
  const values = new Array(nx * ny);
  for (let y = 0; y < ny; y++) {
    for (let x = 0; x < nx; x++) values[y * nx + x] = xy[x * ny + y];
  }
  return values;
}

async function withFile(mode, fn) {
  const { FS } = await ready;
  const name = `gld-${mode}-${Date.now()}-${Math.random().toString(16).slice(2)}.h5`;
  try {
    return await fn(FS, name);
  } finally {
    try { FS.unlink(name); } catch { /* already gone */ }
  }
}

export const h5wasmSer = {
  name: 'h5wasm',
  version: h5wasmVersion(),
  supports: (name) => name === 'grid' || name === 'grid_window',
  prepare(typeId, value) {
    this._window = typeId === 'grid_window';
    this._grid = value;
  },
  async serialize(value) {
    const grid = value;
    const xy = valuesToXy(grid);
    return withFile('w', async (FS, name) => {
      const file = new h5wasm.File(name, 'w');
      try {
        file.create_dataset({ name: 'grid', data: xy, shape: [grid.nx, grid.ny], dtype: '<d' });
        file.flush();
        return Buffer.from(FS.readFile(name));
      } finally {
        file.close();
      }
    });
  },
  async deserialize(buf) {
    const grid = this._grid;
    const window = this._window;
    return withFile('r', async (FS, name) => {
      FS.writeFile(name, buf);
      const file = new h5wasm.File(name, 'r');
      try {
        const dataset = file.get('grid');
        if (window) {
          const x1 = grid.x0 + grid.wx;
          const y1 = grid.y0 + grid.wy;
          const xy = dataset.slice([[grid.x0, x1], [grid.y0, y1]]);
          return xyToValues(xy, grid.wx, grid.wy);
        }
        return xyToValues(dataset.value, grid.nx, grid.ny);
      } finally {
        file.close();
      }
    });
  },
};

export function hdf5Serializers() {
  return [h5wasmSer];
}
