import yaml from 'js-yaml';
import { pkgVersion, baseSupports, bufToUtf8 } from './common.js';

/** js-yaml — the usual Node YAML library. https://github.com/nodeca/js-yaml */
export const jsYamlSer = {
  name: 'js-yaml',
  version: pkgVersion('js-yaml'),
  category: 'human',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return Buffer.from(yaml.dump(value, { noRefs: true, lineWidth: -1, sortKeys: false }), 'utf8');
  },
  deserialize(buf) {
    return yaml.load(bufToUtf8(buf));
  },
};

export function yamlSerializers() {
  return [jsYamlSer];
}
