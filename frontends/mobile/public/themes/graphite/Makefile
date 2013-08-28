all: generate publish

generate:
	@python helper/painter.py themes/aloe.yaml
	@python helper/painter.py themes/candy.yaml
	@python helper/painter.py themes/melon.yaml
	@python helper/painter.py themes/mint.yaml
	@python helper/painter.py themes/royal.yaml
	@python helper/painter.py themes/sand.yaml
	@python helper/painter.py themes/slate.yaml
	@python helper/painter.py themes/water.yaml

publish:
	echo "Publishing themes"
	@mkdir -p docs/themes/
	@cp -R generated/* docs/themes/
