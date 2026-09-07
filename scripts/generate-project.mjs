// Deterministic Xcode project generator. No npm dependencies or XcodeGen needed.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const id = text => crypto.createHash('sha256').update(text).digest('hex').slice(0, 24).toUpperCase();
const quote = text => JSON.stringify(text);
const walk = dir => fs.readdirSync(path.join(root, dir), { withFileTypes: true }).flatMap(entry => {
  const name = `${dir}/${entry.name}`;
  return entry.isDirectory() ? walk(name) : [name];
});
const sources = [...walk('Sources/RallyCore'), ...walk('RallyTrip')].filter(f => f.endsWith('.swift')).sort();
const resources = ['RallyTrip/Assets.xcassets', 'RallyTrip/PrivacyInfo.xcprivacy'];
const files = [...sources, ...resources];
const objects = [];
const add = (key, body) => objects.push(`${id(key)} = { ${body} };`);
for (const file of files) {
  const type = file.endsWith('.swift') ? 'sourcecode.swift' : file.endsWith('.xcassets') ? 'folder.assetcatalog' : 'text.xml';
  add(`ref:${file}`, `isa = PBXFileReference; lastKnownFileType = ${type}; path = ${quote(file)}; sourceTree = SOURCE_ROOT;`);
  add(`build:${file}`, `isa = PBXBuildFile; fileRef = ${id(`ref:${file}`)};`);
}
add('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = RallyTrip.app; sourceTree = BUILT_PRODUCTS_DIR;');
add('mainGroup', `isa = PBXGroup; children = (${files.map(f => id(`ref:${f}`)).join(',')},${id('productsGroup')},); sourceTree = "<group>";`);
add('productsGroup', `isa = PBXGroup; children = (${id('product')},); name = Products; sourceTree = "<group>";`);
add('sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${sources.map(f => id(`build:${f}`)).join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
add('resources', `isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (${resources.map(f => id(`build:${f}`)).join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
add('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;');
add('target', `isa = PBXNativeTarget; buildConfigurationList = ${id('targetConfigurations')}; buildPhases = (${id('sources')},${id('frameworks')},${id('resources')},); buildRules = (); dependencies = (); name = RallyTrip; productName = RallyTrip; productReference = ${id('product')}; productType = "com.apple.product-type.application";`);
for (const name of ['Debug', 'Release']) {
  const debug = name === 'Debug';
  add(`project:${name}`, `isa = XCBuildConfiguration; name = ${name}; buildSettings = {
    SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; CLANG_ENABLE_MODULES = YES;
    SWIFT_VERSION = 5.0; SWIFT_STRICT_CONCURRENCY = targeted;
    DEBUG_INFORMATION_FORMAT = ${debug ? 'dwarf' : '"dwarf-with-dsym"'};
    SWIFT_OPTIMIZATION_LEVEL = ${quote(debug ? '-Onone' : '-O')};
    SWIFT_ACTIVE_COMPILATION_CONDITIONS = ${quote(debug ? 'DEBUG' : '')};
    ENABLE_TESTABILITY = ${debug ? 'YES' : 'NO'};
  };`);
  add(`target:${name}`, `isa = XCBuildConfiguration; name = ${name}; buildSettings = {
    PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = de.rallytrip.app;
    INFOPLIST_FILE = RallyTrip/Info.plist; GENERATE_INFOPLIST_FILE = NO;
    TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic;
    CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 1.0;
    ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
    SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO;
    LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
  };`);
}
for (const type of ['project', 'target']) {
  add(`${type}Configurations`, `isa = XCConfigurationList; buildConfigurations = (${id(`${type}:Debug`)},${id(`${type}:Release`)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
}
add('project', `isa = PBXProject; attributes = { LastUpgradeCheck = 1600; TargetAttributes = { ${id('target')} = { CreatedOnToolsVersion = 16.0; }; }; }; buildConfigurationList = ${id('projectConfigurations')}; compatibilityVersion = "Xcode 14.0"; developmentRegion = de; hasScannedForEncodings = 0; knownRegions = (de,en,Base,); mainGroup = ${id('mainGroup')}; productRefGroup = ${id('productsGroup')}; projectDirPath = ""; projectRoot = ""; targets = (${id('target')},);`);
const projectDir = path.join(root, 'RallyTrip.xcodeproj');
fs.mkdirSync(path.join(projectDir, 'xcshareddata', 'xcschemes'), { recursive: true });
fs.writeFileSync(path.join(projectDir, 'project.pbxproj'), `// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${objects.join('\n')}\n}; rootObject = ${id('project')}; }\n`);
const reference = `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id('target')}" BuildableName="RallyTrip.app" BlueprintName="RallyTrip" ReferencedContainer="container:RallyTrip.xcodeproj"/>`;
fs.writeFileSync(path.join(projectDir, 'xcshareddata', 'xcschemes', 'RallyTrip.xcscheme'), `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${reference}</BuildActionEntry></BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${reference}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n`);
console.log(`Generated RallyTrip.xcodeproj: ${sources.length} Swift sources, ${resources.length} resources.`);
