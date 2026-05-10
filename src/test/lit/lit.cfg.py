import os

import lit.formats
import lit.util

config.name = "Luthier"
config.suffixes = {".s", ".luthier", ".ll", ".cpp"}
config.test_format = lit.formats.ShTest(True)

config.excludes = ["linker"]

config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = config.my_obj_root