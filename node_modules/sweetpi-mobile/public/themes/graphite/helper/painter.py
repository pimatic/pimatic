import cStringIO
import os
import pdb
import shutil
import sys
import yaml
import tinycss

import re

CURRENT_JQM_VERSION = '1.2.0'

DEFAULT_THEME = {
  'a': {
    'bar': '3c3c3c'
  }
}

# Replace the value for the given field name in the CSS.
# For example, to replace the global-radii-blocks field, call this function like this:
# _R('global-radii-blocks', '0.4em')
def _R(css, field_name, value):
  regex = r'(\s*)([^\s]*)(\s*/\*{%s}\*/)' % field_name
  #print "Replacing field", field_name, "with", value
  return re.sub(regex, r'\g<1>' + value + '\g<3>', css)

def _replace_value(props, matchobj):
  match1 = matchobj.group(1)
  match2 = matchobj.group(2)
  match3 = matchobj.group(3)
  match4 = matchobj.group(4)
  if match4 in props:
    v = props[match4]
    ret = match1 + v + match3
    #print "Ret", ret
    return ret
    #return r'\g<1>' + v + '\g<3>'

def _remove_css_definitions(css, defs):
  selector_decl_map = {}

  # Map the selector to the declaration to remove
  for d in defs:
    parts = d.split('|')
    selector_decl_map[parts[0]] = parts[1]

  parser = tinycss.make_parser('page3')
  sheet = parser.parse_stylesheet(css)

  remove_lines = []
  for rule in sheet.rules:
    css_rule = ' '.join(rule.selector.as_css().split('\n'))

    if not (css_rule in selector_decl_map):
      continue

    # Grab the decl to remove
    remove_decl = selector_decl_map[css_rule]

    # Grab the decls for this rule
    decls = rule.declarations

    for d in decls:
      if d.name == remove_decl:
        remove_lines.append(d.line)

  css_lines = css.splitlines()
      
  for line in remove_lines:
    del css_lines[line-1]

  return '\n'.join(css_lines)

def _RF(css, props):
  #if 'remove_css' in props:
  #  css = _remove_css_definitions(css, props['remove_css'])

  keys = '|'.join(props.keys())
  regex = r'(\s*)([^\s]*)(\s*/\*{(%s)}\*/)' % keys
  return re.sub(regex, lambda matchobj: _replace_value(props, matchobj), css)

def make_theme(props, theme_css):
  return _RF(theme_css, props)
  """
  print keys
  for prop in props:
    theme_css = _R(theme_css, prop, props[prop])
  return theme_css
  """

def save_css(name, theme_css, jqm_version=CURRENT_JQM_VERSION):
  filename = 'generated/%s/jquery.mobile-%s.css' % (name, jqm_version)
  d = os.path.dirname(filename)
  
  if not os.path.exists(d):
    os.makedirs(d)

  f = open(filename, 'w')
  f.write(theme_css)
  f.close()

  shutil.copy('res/index.html', d)

  images_dir = os.path.join(d, 'images/')
  if not os.path.exists(images_dir):
    shutil.copytree('res/jqm/%s/images' % jqm_version, images_dir)

def gen_theme(settings_file):
  theme_yaml = open(settings_file, 'r').read()
  base_yaml = open('themes/base.yaml', 'r').read()
  stream = cStringIO.StringIO(theme_yaml + '\n' + base_yaml)

  theme_settings = yaml.load(theme_yaml)
  if 'use_base' in theme_settings and theme_settings['use_base'] == 'false':
    settings = theme_settings
  else:
    settings = yaml.load(stream)

  print "Generating theme", settings['name']

  name = settings['name']
  jqm_version = settings['jqm-version']

  theme_css = open(settings['source-theme'], 'r').read()

  del settings['name']
  del settings['jqm-version']
  del settings['source-theme']

  theme_css = make_theme(settings, theme_css)

  #print theme_css

  if 'extra-css' in settings:
    extra_css = open(settings['extra-css'], 'r').read()
    theme_css += extra_css

  save_css(name, theme_css, jqm_version)

  # Replace the bar color and highlight colors


if __name__ == "__main__":
  if len(sys.argv) < 2:
    print >> sys.stderr, "Usage: painter.py yaml-settings-file"
    sys.exit(1)
  gen_theme(sys.argv[1])
