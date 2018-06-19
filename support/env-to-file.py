#!/usr/bin/env python

import sys
import os

with open(sys.argv[1], "w") as output_file:
    output_file.write(os.environ["CONTENT"] + "\n")
