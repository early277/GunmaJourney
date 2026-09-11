from pathlib import Path
import json
p=Path(__file__).parent
files=['App.swift','Models.swift','Store.swift','LocationService.swift','Resources/regions.json','Resources/descriptions.json','Resources/municipalities.json','Assets.xcassets','PrivacyInfo.xcprivacy']
objects=[]
def oid(n):return f'{n:024X}'
def add(n,s):objects.append(f'{oid(n)} = {{ {s} }};')
for i,f in enumerate(files):
 typ='sourcecode.swift' if f.endswith('.swift') else 'folder.assetcatalog' if f.endswith('xcassets') else 'text.xml' if f.endswith('xcprivacy') else 'text.json'
 add(100+i,f'isa = PBXFileReference; lastKnownFileType = {typ}; path = "{f}"; sourceTree = "<group>";')
 add(200+i,f'isa = PBXBuildFile; fileRef = {oid(100+i)};')
add(1,f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; TargetAttributes = {{ {oid(2)} = {{ ProvisioningStyle = Automatic; }}; }}; }}; buildConfigurationList = {oid(10)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ja; knownRegions = (ja, en, Base); mainGroup = {oid(3)}; productRefGroup = {oid(5)}; projectDirPath = ""; projectRoot = ""; targets = ({oid(2)});')
add(2,f'isa = PBXNativeTarget; buildConfigurationList = {oid(11)}; buildPhases = ({oid(6)}, {oid(7)}, {oid(8)}); buildRules = (); dependencies = (); name = GunmaJourney; productName = GunmaJourney; productReference = {oid(9)}; productType = "com.apple.product-type.application";')
add(3,f'isa = PBXGroup; children = ({oid(4)}, {oid(5)}); sourceTree = "<group>";')
add(4,'isa = PBXGroup; children = ('+','.join(oid(100+i) for i in range(len(files)))+'); path = GunmaJourney; sourceTree = "<group>";')
add(5,f'isa = PBXGroup; children = ({oid(9)}); name = Products; sourceTree = "<group>";')
add(6,'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+','.join(oid(200+i) for i in range(4))+'); runOnlyForDeploymentPostprocessing = 0;')
add(7,'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ('+','.join(oid(200+i) for i in range(4,len(files)))+'); runOnlyForDeploymentPostprocessing = 0;')
add(8,'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
add(9,'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = GunmaJourney.app; sourceTree = BUILT_PRODUCTS_DIR;')
for n,configs in [(10,[12,13]),(11,[14,15])]:add(n,'isa = XCConfigurationList; buildConfigurations = ('+','.join(oid(c) for c in configs)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
for n,name in [(12,'Debug'),(13,'Release')]:add(n,f'isa = XCBuildConfiguration; buildSettings = {{ SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; }}; name = {name};')
for n,name in [(14,'Debug'),(15,'Release')]:
 add(n,f'''isa = XCBuildConfiguration; buildSettings = {{ ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 63; DEVELOPMENT_TEAM = ""; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = GunmaJourney/Info.plist; MARKETING_VERSION = 1.0; PRODUCT_BUNDLE_IDENTIFIER = jp.abyos.GunmaJourney; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "{'DEBUG' if name=='Debug' else ''}"; SWIFT_OPTIMIZATION_LEVEL = "{'-Onone' if name=='Debug' else '-O'}"; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; }}; name = {name};''')
(p/'GunmaJourney.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+oid(1)+'; }\n')
assets=p/'GunmaJourney/Assets.xcassets/AppIcon.appiconset';assets.mkdir(parents=True,exist_ok=True)
(assets/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}}))
