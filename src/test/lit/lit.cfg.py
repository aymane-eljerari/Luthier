import os

import lit.formats
import lit.util

config.name = "Luthier"
config.suffixes = {".s", ".ll"}
config.test_format = lit.formats.ShTest(True)

config.excludes = ["linker"]

config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = config.my_obj_root

plugin_path = os.path.join(config.my_obj_root, "lib", "LuthierOptPlugin.so")
config.substitutions.append(('%luthier_opt', f"-load-pass-plugin={plugin_path}"))