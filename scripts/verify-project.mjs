import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const pbx = read('RallyTrip.xcodeproj/project.pbxproj');
const objects = [...pbx.matchAll(/^([A-F0-9]{24}) = /gm)].map(m => m[1]);
assert.equal(new Set(objects).size, objects.length, 'Duplicate PBX identifiers');
const references = [...pbx.matchAll(/\b[A-F0-9]{24}\b/g)].map(m => m[0]);
for (const ref of references) assert(objects.includes(ref), `Dangling reference: ${ref}`);

const walk = dir => fs.readdirSync(path.join(root, dir), { withFileTypes: true }).flatMap(entry => {
  const name = `${dir}/${entry.name}`;
  return entry.isDirectory() ? walk(name) : [name];
});
const sources = [...walk('Sources/RallyCore'), ...walk('RallyTrip')].filter(f => f.endsWith('.swift'));
for (const file of sources) assert(pbx.includes(`path = "${file}"`), `Source absent from project: ${file}`);
const sourcePhase = pbx.match(/isa = PBXSourcesBuildPhase;[^}]+files = \(([^)]+)\)/)?.[1] ?? '';
assert.equal(sourcePhase.split(',').filter(Boolean).length, sources.length);
const info = read('RallyTrip/Info.plist');
assert(info.includes('NSLocationWhenInUseUsageDescription'));
assert(info.includes('<string>location</string>'));
assert(info.includes('de.rallytrip.gpx'));
const icon = fs.readFileSync(path.join(root, 'RallyTrip/Assets.xcassets/AppIcon.appiconset/AppIcon.png'));
assert.equal(icon.subarray(1, 4).toString(), 'PNG');
assert.equal(icon.readUInt32BE(16), 1024);
assert.equal(icon.readUInt32BE(20), 1024);
for (const file of walk('RallyTrip').filter(f => f.endsWith('.json'))) JSON.parse(read(file));
const scheme = read('RallyTrip.xcodeproj/xcshareddata/xcschemes/RallyTrip.xcscheme');
assert(scheme.includes('BlueprintName="RallyTrip"'));
const tests = walk('Tests').filter(f => f.endsWith('.swift'));
const testCount = tests.reduce((count, file) => count + [...read(file).matchAll(/func test\w+\(/g)].length, 0);
assert.equal(testCount, 16);
for (const file of [...sources, ...tests]) {
  assert(!read(file).includes('\uFFFD'), `Invalid UTF-8 in ${file}`);
  assert(!/^(<<<<<<<|=======|>>>>>>>)/m.test(read(file)), `Conflict marker in ${file}`);
}
console.log(`PASS: ${objects.length} unique project objects; all references resolve.`);
console.log(`PASS: ${sources.length} Swift sources included; scheme, plist keys, GPX type and resources present.`);
console.log('PASS: 1024×1024 PNG app icon and JSON asset catalogs.');
console.log(`FOUND: ${testCount} XCTest cases. Swift tests and iOS build require a Swift/Xcode host; not executed here.`);
