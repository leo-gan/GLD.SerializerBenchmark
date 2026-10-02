import { test } from 'node:test';
import assert from 'node:assert/strict';
import { serializerDisplayName, serializerSelectLabel } from '../format.js';

test('serializerDisplayName keeps encoding/json and encoding/json/v2 apart', () => {
  assert.equal(serializerDisplayName('encoding/json', 'go1.27.1'), 'encoding/json:go1.27.1');
  assert.equal(
    serializerDisplayName('encoding/json/v2', 'go1.27.1'),
    'encoding/json/v2:go1.27.1',
  );
});

test('select labels drop the shared version when one name extends another', () => {
  const names = [
    'encoding/gob',
    'encoding/json',
    'encoding/json/v2',
    'segmentio/encoding/json',
    'sonic',
  ];
  assert.equal(serializerSelectLabel('encoding/json', 'go1.27.1', names), 'encoding/json');
  assert.equal(serializerSelectLabel('encoding/json/v2', 'go1.27.1', names), 'encoding/json/v2');
  assert.notEqual(
    serializerSelectLabel('encoding/json', 'go1.27.1', names),
    serializerSelectLabel('encoding/json/v2', 'go1.27.1', names),
  );
  assert.equal(serializerSelectLabel('encoding/gob', 'go1.27.1', names), 'encoding/gob:go1.27.1');
  assert.equal(
    serializerSelectLabel('segmentio/encoding/json', '0.5.4', names),
    'segmentio/encoding/json:0.5.4',
  );
  assert.equal(serializerSelectLabel('sonic', '1.15.4', names), 'sonic:1.15.4');
});

test('select label keeps the version when the name is alone', () => {
  assert.equal(
    serializerSelectLabel('encoding/json/v2', 'go1.27.1', ['encoding/json/v2']),
    'encoding/json/v2:go1.27.1',
  );
});
