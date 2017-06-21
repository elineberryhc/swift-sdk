CONFIGURATION?=Release
VERSION=$(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${PWD}/Kinvey/Kinvey/Info.plist")
IPHONE_SE_SIMULATOR_ID=$(shell instruments -s | grep 'iPhone SE (10.3.1)' | awk '{ print substr($$4, 2, 36) }' | head -n 1)

all: build archive pack docs

clean:
	rm -Rf docs
	rm -Rf build
	rm -Rf Carthage
	
checkout-dependencies:
	carthage checkout

build-debug:
	xcodebuild -workspace Kinvey.xcworkspace -scheme Kinvey -configuration Debug BUILD_DIR=build ONLY_ACTIVE_ARCH=NO -sdk iphoneos
	xcodebuild -workspace Kinvey.xcworkspace -scheme Kinvey -configuration Debug BUILD_DIR=build ONLY_ACTIVE_ARCH=NO -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone SE'

build-dependencies-ios: checkout-dependencies
	carthage build --platform iOS

build: checkout-dependencies
	carthage build --no-skip-current

build-ios: checkout-dependencies
	carthage build --no-skip-current --platform iOS

build-macos: checkout-dependencies
	carthage build --no-skip-current --platform macOS

build-tvos: checkout-dependencies
	carthage build --no-skip-current --platform tvOS

build-watchos: checkout-dependencies
	carthage build --no-skip-current --platform watchOS

archive: archive-ios

archive-ios:
	carthage archive Kinvey

test: test-ios test-macos

	
test-ios:
	open -a "simulator" --args -CurrentDeviceUDID "$(IPHONE_SE_SIMULATOR_ID)"; \
	xcodebuild -workspace Kinvey.xcworkspace -scheme Kinvey -destination "id=$(IPHONE_SE_SIMULATOR_ID)" -enableCodeCoverage YES test

test-macos:
	xcodebuild -workspace Kinvey.xcworkspace -scheme Kinvey-macOS -enableCodeCoverage YES test

pack:
	mkdir -p build/Kinvey-$(VERSION)
	cd Carthage/Build/iOS; \
	cp -R Kinvey.framework PromiseKit.framework KeychainAccess.framework Realm.framework RealmSwift.framework ObjectMapper.framework XCGLogger.framework ../../../build/Kinvey-$(VERSION)
	cd build; \
	zip -r Kinvey-$(VERSION).zip Kinvey-$(VERSION)

docs:
	jazzy --author Kinvey \
				--author_url http://www.kinvey.com \
				--module-version $(VERSION) \
				--readme README-API-Reference-Docs.md \
				--min-acl public \
				--theme apple \
				--xcodebuild-arguments -workspace,Kinvey.xcworkspace,-scheme,Kinvey \
				--module Kinvey \
				--output docs
				
deploy-cocoapods:
	pod trunk push Kinvey.podspec --verbose --allow-warnings

test-cocoapods:
	pod spec lint Kinvey.podspec --verbose --no-clean --allow-warnings

show-version:
	@/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${PWD}/Kinvey/Kinvey/Info.plist" | xargs echo 'Info.plist    '
	@cat Kinvey.podspec | grep "s.version\s*=\s*\"[0-9]*.[0-9]*.[0-9]*\"" | awk {'print $$3'} | sed 's/"//g' | xargs echo 'Kinvey.podspec'
	@agvtool what-version | awk '0 == NR % 2' | awk {'print $1'} | xargs echo 'Project Version  '
	
set-version:
	@echo 'Current Version:'
	@echo '----------------------'
	@$(MAKE) show-version
	
	@echo
	
	@echo 'New Version:'
	@read version; \
	\
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $$version" "${PWD}/Kinvey/Kinvey/Info.plist"; \
	sed -i -e "s/s.version[ ]*=[ ]*\"[0-9]*.[0-9]*.[0-9]*\"/s.version      = \"$$version\"/g" Kinvey.podspec; \
	rm Kinvey.podspec-e
	
	@echo
	@echo

	@echo 'New Version:'
	@echo '----------------------'
	@$(MAKE) show-version
