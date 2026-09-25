import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
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
const watchSources = [...walk('RallyWatch').filter(f => f.endsWith('.swift')), 'Sources/RallyCore/WatchProtocol.swift'];
const allSources = [...new Set([...sources, ...watchSources])];
for (const file of allSources) assert(pbx.includes(`path = "${file}"`), `Source absent from project: ${file}`);
const id = key => crypto.createHash('sha256').update(key).digest('hex').slice(0, 24).toUpperCase();
const objectLine = key => pbx.split('\n').find(line => line.startsWith(`${id(key)} = `)) ?? '';
for (const [key, prefix, expected] of [['sources', 'build', sources], ['watchSources', 'watchBuild', watchSources]]) {
  const phase = objectLine(key).match(/files = \(([^)]+)\)/)?.[1].split(',').filter(Boolean) ?? [];
  assert.deepEqual(new Set(phase), new Set(expected.map(file => id(`${prefix}:${file}`))), `${key}: incorrect target membership`);
}
assert(objectLine('target').includes(id('watchDependency')));
assert(objectLine('target').includes(id('embedWatch')));
assert(objectLine('embedWatch').includes('$(CONTENTS_FOLDER_PATH)/Watch'));
assert(objectLine('embedWatchBuild').includes(id('watchProduct')));
assert(objectLine('watchDependency').includes(id('watchTarget')));
const watchInfo = read('RallyWatch/Info.plist');
assert(watchInfo.includes('<key>WKApplication</key><true/>'));
assert(watchInfo.includes('<key>WKCompanionAppBundleIdentifier</key><string>de.rallytrip.app</string>'));
assert(watchInfo.includes('<key>WKRunsIndependentlyOfCompanionApp</key><false/>'));
assert(pbx.includes('PRODUCT_BUNDLE_IDENTIFIER = de.rallytrip.app.watchkitapp;'));
assert(pbx.includes('WATCHOS_DEPLOYMENT_TARGET = 10.0;'));
const info = read('RallyTrip/Info.plist');
assert(info.includes('NSLocationWhenInUseUsageDescription'));
assert(info.includes('<string>location</string>'));
assert(info.includes('de.rallytrip.gpx'));
const icon = fs.readFileSync(path.join(root, 'RallyTrip/Assets.xcassets/AppIcon.appiconset/AppIcon.png'));
assert.equal(icon.subarray(1, 4).toString(), 'PNG');
assert.equal(icon.readUInt32BE(16), 1024);
assert.equal(icon.readUInt32BE(20), 1024);
for (const file of [...walk('RallyTrip'), ...walk('RallyWatch')].filter(f => f.endsWith('.json'))) JSON.parse(read(file));
const watchIcon = fs.readFileSync(path.join(root, 'RallyWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png'));
assert.equal(watchIcon.readUInt32BE(16), 1024);
assert.equal(watchIcon.readUInt32BE(20), 1024);
const scheme = read('RallyTrip.xcodeproj/xcshareddata/xcschemes/RallyTrip.xcscheme');
assert(scheme.includes('BlueprintName="RallyTrip"'));
assert(read('RallyTrip.xcodeproj/xcshareddata/xcschemes/RallyWatch.xcscheme').includes('BlueprintName="RallyWatch"'));
const tests = walk('Tests').filter(f => f.endsWith('.swift'));
const testCount = tests.reduce((count, file) => count + [...read(file).matchAll(/func test\w+\(/g)].length, 0);
assert(testCount >= 27, 'Expected at least the baseline 27 XCTest cases');
for (const file of [...allSources, ...tests]) {
  assert(!read(file).includes('\uFFFD'), `Invalid UTF-8 in ${file}`);
  assert(!/^(<<<<<<<|=======|>>>>>>>)/m.test(read(file)), `Conflict marker in ${file}`);
}
console.log(`PASS: ${objects.length} unique project objects; all references resolve.`);
console.log(`PASS: iPhone ${sources.length} sources; Watch ${watchSources.length} sources; correct target membership, companion embedding and schemes.`);
console.log('PASS: 1024×1024 PNG app icon and JSON asset catalogs.');
console.log(`FOUND: ${testCount} XCTest cases. This command checks structure only; see VALIDATION.md for executed tests.`);
