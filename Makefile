
COFFEE_SCRIPTS= \
	$(wildcard client/util/*.coffee) \
	$(wildcard migrations.coffee) \
	$(wildcard client/api_config.coffee) \
	$(wildcard client/data_models/*.coffee) \
	$(wildcard client/views/*.coffee) \
	$(wildcard client/controllers/*.coffee) \
	$(wildcard client/3d_controllers/*.coffee) \
	$(wildcard client/old-controllers/*.coffee) \
	$(wildcard client/*.coffee) \

# Files bundled in "old_modules"
OLD_COFFEE_SCRIPTS= \
	$(wildcard client/util/*.coffee) \
	$(wildcard migrations.coffee) \
	$(wildcard client/api_config.coffee) \
	$(wildcard client/data_models/*.coffee) \
	$(wildcard client/controllers/*.coffee) \
	$(wildcard client/3d_controllers/*.coffee) \
	$(wildcard client/old-controllers/*.coffee) \

# provisional
JS_HEAD= client/head.js
JS_TAIL= client/tail.js

STYLE_SHEETS= \
	$(wildcard client/style_lib/*.styl) \
	$(wildcard client/old-views/*.styl) \
	$(wildcard client/views/*.styl) \

OUTPUT_DIR=build

OLD_MODULES=client/tmp/old_modules.js
COMPILED_SCRIPTS=$(OUTPUT_DIR)/dragonfly.js
COMPILED_STYLES=$(OUTPUT_DIR)/dragonfly.css

COFFEE=node node_modules/coffee-script/bin/coffee
STYLUS=node node_modules/stylus/bin/stylus
WEBPACK=node node_modules/webpack/bin/webpack.js
WEBPACK_CONFIG=$(shell cygpath .||pwd)/client/webpack.config.js

all: styles scripts copy_static

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)
	mkdir -p $(OUTPUT_DIR)/individual_js

$(OLD_MODULES): Makefile $(OLD_COFFEE_SCRIPTS) node_modules/node-uuid/uuid.js
	mkdir -p client/tmp
	rm -fr $(OUTPUT_DIR)/individual_js || true
	$(COFFEE) -o $(OUTPUT_DIR)/individual_js  --bare -c $(OLD_COFFEE_SCRIPTS)
	cat $(JS_HEAD) $(OUTPUT_DIR)/individual_js/* $(JS_TAIL) > $(OLD_MODULES)
	git log|head -1|sed 's/.*\ \(............\).*/;VIDA_BODY_COMMIT="\1";/' >> $(OLD_MODULES)

$(COMPILED_SCRIPTS): $(OLD_MODULES) $(COFFEE_SCRIPTS) client/webpack.config.js
	rm $(COMPILED_SCRIPTS) || true

	$(WEBPACK) --config $(WEBPACK_CONFIG) --bail

node_modules/node-uuid/uuid.js:
	npm install
	touch node_modules/.x

# Not piping into node.js commands because node doesn't support cygwin pipes
$(COMPILED_STYLES): Makefile $(STYLE_SHEETS) node_modules/node-uuid/uuid.js
	$(STYLUS) -p client/styles.styl > $@

styles: $(OUTPUT_DIR) $(COMPILED_STYLES)

scripts: $(OUTPUT_DIR) $(COMPILED_SCRIPTS)

copy_static: $(OUTPUT_DIR)
	rm -f static_app_files/organ_tree.html # obsolete
	cp -R static_app_files/* $(OUTPUT_DIR)

pack: clean pack_assets all

assets/:
	echo "Error: you need to put here the "assets" library from Seafile." && false

pack_assets: $(OUTPUT_DIR) assets/
	$(COFFEE) pipeline_scripts/packer.coffee
	$(COFFEE) client/views/organ_tree_editor.coffee
	cp assets/generated_textures/Digestive_interior_upper-NM.crn build/assetver/dev/textures/Digestive_interior_upper_Normal.crn
	cp assets/generated_textures/Cerebrum_exterior-TM.orig.crn build/assetver/dev/textures/Cerebrum_colored.crn
	gzip -fk build/assetver/dev/scenes/*/*

tree:
	$(COFFEE) client/views/organ_tree_editor.coffee

get_organ_tree:
	$(COFFEE) ./tree_scripts/get_organ_tree.coffee

validate_organ_tree:
	$(COFFEE) ./tree_scripts/validate_organ_tree.coffee


clean:
	rm -fr $(OUTPUT_DIR) $(OLD_MODULES)

# With "make watch" you can set a custom command
# to be executed after build; e.g:
# CMD='cp -r build /somewhere' make watch

CMD?=true

watch: all
	while sleep 0.1;do \
	inotifywait -e close_write $(COFFEE_SCRIPTS) $(STYLE_SHEETS);\
	make all;\
	${CMD};\
	done
