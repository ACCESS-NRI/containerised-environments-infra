# This script is used to render a jinja2 template file using environment variables as the context. 
# It takes two arguments: the path to the template file and the path to the output file. 
# The rendered output is written to the specified output file.

import os
import sys

from jinja2 import StrictUndefined, Template

template_file = sys.argv[1]
output_file = sys.argv[2]

with open(template_file) as f:
    template_str = f.read()
    rendered = Template(template_str, undefined=StrictUndefined).render(env=os.environ)

# Log the rendered template so it appears in the build/deploy output
print(f"--- Rendered '{template_file}' template -> '{output_file}' ---")
print(rendered)
print(f"--- End of '{output_file}' ---")

with open(output_file, "w") as f:
    f.write(rendered)